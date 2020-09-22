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

  class MicroserviceOperator < Operator

    def initialize
      Logger.microservice_name = 'MicroserviceOperator'
      super

      @microservices = {}
      @previous_microservices = {}
      @new_microservices = {}
      @changed_microservices = {}
      @removed_microservices = {}
    end

    def convert_microservice_to_process_definition(microservice_name, microservice_config)
      microservice_config_parsed = JSON.parse(microservice_config)
      filename = microservice_config_parsed["filename"]
      relative_filename = File.expand_path(File.join(__dir__, "../microservices/#{filename}"))
      scope = microservice_name.split("__")[0]
      if File.exist?(relative_filename)
        # Run ruby syntax so we can log those
        syntax_check, _ = Open3.capture2e("#{@ruby_process_name} -c #{relative_filename}")
        if syntax_check =~ /Syntax OK/
          return [@ruby_process_name, relative_filename, microservice_name]
        else
          Logger.error("Microservice #{relative_filename} failed syntax check\n#{syntax_check}", scope: scope)
        end
      else
        Logger.error("Microservice #{relative_filename} does not exist", scope: scope)
      end
      return nil
    end

    def update
      @previous_microservices = @microservices.dup
      # Get all the microservice configuration from Redis
      @redis ||= Redis.new(url: ENV['COSMOS_REDIS_URL'] || ENV['COSMOS_DEVEL'] ? 'redis://127.0.0.1:6379/0' : 'redis://cosmos_redis:6379/0')
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
          process_definition = convert_microservice_to_process_definition(microservice_name, microservice_config)
          if process_definition
            scope = microservice_name.split("__")[0]
            process = OperatorProcess.new(process_definition, scope)
            @new_processes[microservice_name] = process
            @processes[microservice_name] = process
          end
        end

        @changed_microservices.each do |microservice_name, microservice_config|
          process_definition = convert_microservice_to_process_definition(microservice_name, microservice_config)
          if process_definition
            process = @processes[microservice_name]
            if process
              process.process_definition = process_definition
              @changed_processes[microservice_name] = process
            else
              scope = microservice_name.split("__")[0]
              Logger.error("Changed microservice #{microservice_name} does not exist. Creating new...", scope: scope)
              process = OperatorProcess.new(process_definition, scope)
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

  end # class

end # module

Cosmos::MicroserviceOperator.run if __FILE__ == $0