# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'childprocess'
require 'cosmos'

module Cosmos

  class Operator

    def initialize
      Logger.level = Logger::INFO

      @ruby_process_name = ENV['COSMOS_RUBY']
      if RUBY_ENGINE != 'ruby'
        @ruby_process_name ||= 'jruby'
      else
        @ruby_process_name ||= 'ruby'
      end

      @process_definitions = []
      @processes = []
      @mutex = Mutex.new
      @shutdown = false
      @shutdown_complete = false
    end

    def run
      # Start all the processes.rb
      Logger.info("#{self.class} starting each process...")

      @process_definitions.each do |p|
        Logger.info("Starting: #{p.join(' ')}")
        @processes << ChildProcess.build(*p)
        @processes[-1].start
      end

      # Use at_exit to shutdown cleanly
      at_exit do
        @shutdown = true
        @mutex.synchronize do
          Logger.info("Shutting down processes...")
          @processes.each_with_index do |p, index|
            Thread.new do
              Logger.info("Soft Shutting down process: #{@process_definitions[index].join(' ')}")
              Process.kill("SIGINT", p.pid)
            end
          end
          sleep(2)
          @processes.each_with_index do |p, index|
            unless p.exited?
              Logger.info("Hard Shutting down process: #{@process_definitions[index].join(' ')}")
              p.stop
            end
          end
          @shutdown_complete = true
        end
      end

      # Monitor processes and respawn if died
      Logger.info("#{self.class} Monitoring processes...")
      loop do
        @mutex.synchronize do
          @processes.each_with_index do |p, index|
            break if @shutdown
            unless p.alive?
              # Respawn process
              Logger.error("Unexpected process died... respawning! #{@process_definitions[index].join(' ')}")
              @processes[index] = ChildProcess.build(*@process_definitions[index])
              @processes[index].leader = true
              @processes[index].start
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
      Logger.info("#{self.class} shutdown complete")
    end

    def self.run
      #Cosmos.catch_fatal_exception do
        a = self.new
        a.run
      #end
    end

  end # class Operator

end # module Cosmos
