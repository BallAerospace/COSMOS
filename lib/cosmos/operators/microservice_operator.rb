# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/operators/operator'
require 'redis'
require 'open3'

module Cosmos
  # Creates new OperatorProcess objects based on querying the Redis key value store.
  # Any keys under 'cosmos_microservices' will be created into microservices.
  class MicroserviceOperator < Operator
    def initialize
      Logger.microservice_name = 'MicroserviceOperator'
      Logger.stdout = true
      super

      @microservices = {}
      @previous_microservices = {}
      @new_microservices = {}
      @changed_microservices = {}
      @removed_microservices = {}
    end

    def convert_microservice_to_process_definition(microservice_name, microservice_config)
      microservice_config_parsed = JSON.parse(microservice_config)
      work_dir = microservice_config_parsed["work_dir"]
      cmd_array = microservice_config_parsed["cmd"]
      env = microservice_config_parsed["env"]
      scope = microservice_name.split("__")[0]
      ruby_filename = nil
      #STDOUT.puts cmd_array
      cmd_array.each do |part|
        if part =~ /\.rb$/
          ruby_filename = part
          break
        end
      end
      if ruby_filename
        Cosmos.set_working_dir(work_dir) do
          if File.exist?(ruby_filename)
            # Run ruby syntax so we can log those
            syntax_check, _ = Open3.capture2e("ruby -c #{ruby_filename}")
            if syntax_check =~ /Syntax OK/
              Logger.info("Ruby microservice #{microservice_name} file #{ruby_filename} passed syntax check\n", scope: scope)
            else
              Logger.error("Ruby microservice #{microservice_name} file #{ruby_filename} failed syntax check\n#{syntax_check}", scope: scope)
            end
          else
            Logger.error("Ruby microservice #{microservice_name} file #{ruby_filename} does not exist", scope: scope)
          end
        end
      end
      return cmd_array, work_dir, env, scope
    end

    def update
      @previous_microservices = @microservices.dup
      # Get all the microservice configuration from Redis
      @redis ||= Redis.new(url: ENV['COSMOS_REDIS_URL'] || (ENV['COSMOS_DEVEL'] ? 'redis://127.0.0.1:6379/0' : 'redis://cosmos-redis:6379/0'))
      @microservices = @redis.hgetall('cosmos_microservices')

      # Detect new and changed microservices
      @new_microservices = {}
      @changed_microservices = {}
      @microservices.each do |microservice_name, microservice_config|
        if @previous_microservices[microservice_name]
          if @previous_microservices[microservice_name] != microservice_config
            @changed_microservices[microservice_name] = microservice_config
          end
        else
          @new_microservices[microservice_name] = microservice_config
        end
      end

      # Detect removed microservices
      @removed_microservices = {}
      @previous_microservices.each do |microservice_name, microservice_config|
        unless @microservices[microservice_name]
          @removed_microservices[microservice_name] = microservice_config
        end
      end

      # Convert to processes
      @mutex.synchronize do
        @new_microservices.each do |microservice_name, microservice_config|
          cmd_array, work_dir, env, scope = convert_microservice_to_process_definition(microservice_name, microservice_config)
          if cmd_array
            process = OperatorProcess.new(cmd_array, work_dir: work_dir, env: env, scope: scope)
            @new_processes[microservice_name] = process
            @processes[microservice_name] = process
          end
        end

        @changed_microservices.each do |microservice_name, microservice_config|
          cmd_array, work_dir, env, scope = convert_microservice_to_process_definition(microservice_name, microservice_config)
          if cmd_array
            process = @processes[microservice_name]
            if process
              process.process_definition = cmd_array
              process.work_dir = work_dir
              process.env = env
              @changed_processes[microservice_name] = process
            else # TODO: How is this even possible?
              Logger.error("Changed microservice #{microservice_name} does not exist. Creating new...", scope: scope)
              process = OperatorProcess.new(cmd_array, work_dir: work_dir, env: env, scope: scope)
              @new_processes[microservice_name] = process
              @processes[microservice_name] = process
            end
          end
        end

        @removed_microservices.each do |microservice_name, microservice_config|
          process = @processes[microservice_name]
          @processes.delete(microservice_name)
          @removed_processes[microservice_name] = process
        end
      end
    end
  end
end

Cosmos::MicroserviceOperator.run if __FILE__ == $0