# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'childprocess'
require 'cosmos'
require 'fileutils'
require 'tempfile'

module Cosmos
  class OperatorProcess
    attr_accessor :process_definition
    attr_accessor :work_dir
    attr_accessor :env
    attr_accessor :new_temp_dir
    attr_reader :temp_dir
    attr_reader :scope

    def self.setup
      # Perform any setup steps necessary
    end

    def initialize(process_definition, work_dir: '/cosmos/lib/cosmos/microservices', temp_dir: nil, env: {}, scope:, container: nil) # container is not used, it's just here for Enterprise
      @process = nil
      @process_definition = process_definition
      @work_dir = work_dir
      @temp_dir = temp_dir
      @new_temp_dir = temp_dir
      @env = env
      @scope = scope
    end

    def start
      @temp_dir = @new_temp_dir
      @new_temp_dir = nil
      Logger.info("Starting: #{@process_definition.join(' ')}", scope: @scope)
      @process = ChildProcess.build(*@process_definition)
      # This lets the ChildProcess use the parent IO ... but it breaks unit tests
      @process.io.inherit!
      @process.cwd = @work_dir
      # Spawned process should not be controlled by same Bundler constraints as spawning process
      ENV.each do |key, value|
        if key =~ /^BUNDLER/
          @process.environment[key] = nil
        end
      end
      @env['RUBYOPT'] = nil # Removes loading bundler setup
      @env.each do |key, value|
        @process.environment[key] = value
      end
      @process.environment['COSMOS_SCOPE'] = @scope
      # @process.io.stdout = Tempfile.new("child-output")
      # @process.io.stderr = Tempfile.new("child-output")
      @process.start
    end

    def alive?
      if @process
        @process.alive?
      else
        false
      end
    end

    def exit_code
      if @process
        @process.exit_code
      else
        nil
      end
    end

    def soft_stop
      Thread.new do
        Logger.info("Soft shutting down process: #{@process_definition.join(' ')}", scope: @scope)
        Process.kill("SIGINT", @process.pid) if @process # Signal the process to stop
      end
    end

    def hard_stop
      if @process and !@process.exited?
        Logger.info("Hard shutting down process: #{@process_definition.join(' ')}", scope: @scope)
        @process.stop
      end
      FileUtils.remove_entry(@temp_dir) if @temp_dir and File.exist?(@temp_dir)
      @process = nil
    end

    def stdout
      @process.io.stdout
    end

    def stderr
      @process.io.stderr
    end

    def extract_output(max_length_stdout = 65536, max_length_stderr = 65536)
      # if @process
      #   @process.io.stdout.rewind
      #   output = @process.io.stdout.read
      #   @process.io.stdout.close
      #   @process.io.stdout.unlink
      #   @process.io.stderr.rewind
      #   err_output = @process.io.stderr.read
      #   @process.io.stderr.close
      #   @process.io.stderr.unlink
      #   return "Stdout:\n#{output[-max_length_stdout..-1] || output}\n\nStderr:\n#{err_output[-max_length_stderr..-1] || err_output}\n"
      # else
        return ""
      # end
    end
  end

  class Operator
    attr_reader :processes, :cycle_time

    @@instance = nil

    CYCLE_TIME = 15.0 # cycle time to check for new microservices

    def initialize
      Logger.level = Logger::INFO
      # TODO: This is pretty generic. Can we pass in more information to help identify the operator?
      Logger.microservice_name = 'MicroserviceOperator'
      Logger.tag = "operator.log"

      OperatorProcess.setup()
      @cycle_time = (ENV['OPERATOR_CYCLE_TIME'] and ENV['OPERATOR_CYCLE_TIME'].to_f) || CYCLE_TIME # time in seconds

      @ruby_process_name = ENV['COSMOS_RUBY']
      if RUBY_ENGINE != 'ruby'
        @ruby_process_name ||= 'jruby'
      else
        @ruby_process_name ||= 'ruby'
      end

      @processes = {}
      @new_processes = {}
      @changed_processes = {}
      @removed_processes = {}
      @mutex = Mutex.new
      @shutdown = false
      @shutdown_complete = false
    end

    def update
      raise "Implement in subclass"
    end

    def start_new
      @mutex.synchronize do
        if @new_processes.length > 0
          # Start all the processes
          Logger.info("#{self.class} starting each new process...")
          @new_processes.each { |name, p| p.start }
          @new_processes = {}
        end
      end
    end

    def respawn_changed
      @mutex.synchronize do
        if @changed_processes.length > 0
          Logger.info("Cycling #{@changed_processes.length} changed microservices...")
          shutdown_processes(@changed_processes)
          break if @shutdown

          @changed_processes.each { |name, p| p.start }
          @changed_processes = {}
        end
      end
    end

    def remove_old
      @mutex.synchronize do
        if @removed_processes.length > 0
          Logger.info("Shutting down #{@removed_processes.length} removed microservices...")
          shutdown_processes(@removed_processes)
          @removed_processes = {}
        end
      end
    end

    def respawn_dead
      @mutex.synchronize do
        @processes.each do |name, p|
          break if @shutdown

          unless p.alive?
            # Respawn process
            # p.stdout.rewind
            # output = p.stdout.read
            # p.stdout.close
            # p.stdout.unlink
            # p.stderr.rewind
            # err_output = p.stderr.read
            # p.stderr.close
            # p.stderr.unlink
            Logger.error("Unexpected process died... respawning!") #{p.process_definition.join(' ')}\nStdout:\n#{output}\nStderr:\n#{err_output}\n", scope: p.scope)
            # p.start
          end
        end
      end
    end

    def shutdown_processes(processes)
      processes.each { |name, p| p.soft_stop }
      sleep(2) # TODO: This is an arbitrary sleep of 2s ...
      processes.each { |name, p| p.hard_stop }
    end

    def run
      # Use at_exit to shutdown cleanly
      at_exit do
        @shutdown = true
        @mutex.synchronize do
          Logger.info("Shutting down processes...")
          shutdown_processes(@processes)
          @shutdown_complete = true
        end
      end

      # Monitor processes and respawn if died
      Logger.info("#{self.class} Monitoring processes every #{@cycle_time} sec...")
      loop do
        update()
        remove_old()
        respawn_changed()
        start_new()
        respawn_dead()
        break if @shutdown

        sleep(@cycle_time)
        break if @shutdown
      end

      loop do
        break if @shutdown_complete

        sleep(1)
      end
    ensure
      Logger.info("#{self.class} shutdown complete")
    end

    def stop
      @shutdown = true
    end

    def self.run
      @@instance = self.new
      @@instance.run
    end

    def self.processes
      @@instance.processes
    end

    def self.instance
      @@instance
    end
  end
end
