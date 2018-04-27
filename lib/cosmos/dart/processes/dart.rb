# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

ENV['RAILS_ENV'] = 'production'
require File.expand_path('../../config/environment', __FILE__)
require 'dart_common'
require 'dart_logging'
require 'childprocess'
require 'dart_database_cleaner'

class Dart
  include DartCommon

  @@force_cleanup = false
  def self.force_cleanup=(value)
    @@force_cleanup = value
  end

  # Start all the DART processes:
  # 1. Ingester - writes all packets to the DART log file
  # 2. Reducer - reduces decommutated data by minute, hour, and day
  # 3. Stream Server - TCPIP server which handles requests for raw data
  #      streamed from the packet log binary file
  # 4. Decom Server - JSON DRB server which handles requests for decommutated
  #      or reduced data from the database
  # 5..n Worker - Decommutates data from the packet log binary file into the DB
  def run
    Cosmos::Logger.level = Cosmos::Logger::INFO
    dart_logging = DartLogging.new('dart')

    # Cleanup the database before starting processes
    DartDatabaseCleaner.clean(@@force_cleanup)

    ruby_process_name = ENV['DART_RUBY']
    if RUBY_ENGINE != 'ruby'
      ruby_process_name ||= 'jruby'
    else
      ruby_process_name ||= 'ruby'
    end

    num_workers = ENV['DART_NUM_WORKERS']
    num_workers ||= 2
    num_workers = num_workers.to_i

    process_definitions = [
      [ruby_process_name, File.join(__dir__, 'dart_ingester.rb')],
      [ruby_process_name, File.join(__dir__, 'dart_reducer.rb')],
      [ruby_process_name, File.join(__dir__, 'dart_stream_server.rb')],
      [ruby_process_name, File.join(__dir__, 'dart_decom_server.rb')]
    ]

    num_workers.times do |index|
      process_definitions << [ruby_process_name, File.join(__dir__, 'dart_worker.rb'), index.to_s, num_workers.to_s]
    end

    processes = []
    p_mutex = Mutex.new

    # Start all the processes.rb
    Cosmos::Logger.info("Dart starting each process...")

    process_definitions.each do |p|
      Cosmos::Logger.info("Starting: #{p.join(' ')}")
      processes << ChildProcess.build(*p)
      processes[-1].start
    end

    # Setup signal handlers to shutdown cleanly
    ["TERM", "INT"].each do |sig|
      Signal.trap(sig) do
        @shutdown = true
        Thread.new do
          p_mutex.synchronize do
            Cosmos::Logger.info("Shutting down processes...")
            processes.each_with_index do |p, index|
              Thread.new do
                Cosmos::Logger.info("Soft Shutting down process: #{process_definitions[index].join(' ')}")
                Process.kill("SIGINT", p.pid)
              end
            end
            sleep(2)
            processes.each_with_index do |p, index|
              unless p.exited?
                Cosmos::Logger.info("Hard Shutting down process: #{process_definitions[index].join(' ')}")
                p.stop
              end
            end
            @shutdown_complete = true
          end
        end
      end
    end

    # Monitor processes and respawn if died
    @shutdown = false
    @shutdown_complete = false
    Cosmos::Logger.info("Dart Monitoring processes...")
    loop do
      p_mutex.synchronize do
        processes.each_with_index do |p, index|
          break if @shutdown
          unless p.alive?
            # Respawn process
            Cosmos::Logger.error("Unexpected process died... respawning! #{process_definitions[index].join(' ')}")
            processes[index] = ChildProcess.build(*process_definitions[index])
            processes[index].leader = true
            processes[index].start
          end
        end
      end
      break if @shutdown
      sleep(1)
      break if @shutdown
    end

    loop do
      break if @shutdown_complete
      sleep(1)
    end

  ensure
    Cosmos::Logger.info("Dart shutdown complete")
    shutdown_cmd_tlm()
    dart_logging.stop
  end

  def self.run
    Cosmos.catch_fatal_exception do
      a = self.new
      a.run
    end
  end
end

parser = DartCommon.handle_argv(false)
parser.on("--force-cleanup", "Force database cleanup") do |arg|
  Dart.force_cleanup = true
end
parser.parse!
