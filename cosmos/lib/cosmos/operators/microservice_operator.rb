# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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

require 'cosmos'
require 'cosmos/models/microservice_model'
require 'cosmos/operators/operator'
require 'redis'
require 'open3'

module Cosmos
  # Creates new OperatorProcess objects based on querying the Redis key value store.
  # Any keys under 'cosmos_microservices' will be created into microservices.
  class MicroserviceOperator < Operator
    def initialize
      Logger.microservice_name = "MicroserviceOperator"
      super

      @microservices = {}
      @previous_microservices = {}
      @new_microservices = {}
      @changed_microservices = {}
      @removed_microservices = {}
    end

    def convert_microservice_to_process_definition(microservice_name, microservice_config)
      process_definition = ["ruby", "plugin_microservice.rb", microservice_name]
      work_dir = "/cosmos/lib/cosmos/microservices"
      env = microservice_config["env"]
      container = microservice_config["container"]
      scope = microservice_name.split("__")[0]
      return process_definition, work_dir, env, scope, container
    end

    def update
      @previous_microservices = @microservices.dup
      # Get all the microservice configuration
      @microservices = MicroserviceModel.all

      # Detect new and changed microservices
      @new_microservices = {}
      @changed_microservices = {}
      @microservices.each do |microservice_name, microservice_config|
        if @previous_microservices[microservice_name]
          if @previous_microservices[microservice_name] != microservice_config
            scope = microservice_name.split("__")[0]
            Logger.info("Changed microservice detected: #{microservice_name}", scope: scope)
            @changed_microservices[microservice_name] = microservice_config
          end
        else
          scope = microservice_name.split("__")[0]
          Logger.info("New microservice detected: #{microservice_name}", scope: scope)
          @new_microservices[microservice_name] = microservice_config
        end
      end

      # Detect removed microservices
      @removed_microservices = {}
      @previous_microservices.each do |microservice_name, microservice_config|
        unless @microservices[microservice_name]
          scope = microservice_name.split("__")[0]
          Logger.info("Removed microservice detected: #{microservice_name}", scope: scope)
          @removed_microservices[microservice_name] = microservice_config
        end
      end

      # Convert to processes
      @mutex.synchronize do
        @new_microservices.each do |microservice_name, microservice_config|
          cmd_array, work_dir, env, scope, container = convert_microservice_to_process_definition(microservice_name, microservice_config)
          if cmd_array
            process = OperatorProcess.new(cmd_array, work_dir: work_dir, env: env, scope: scope, container: container)
            @new_processes[microservice_name] = process
            @processes[microservice_name] = process
          end
        end

        @changed_microservices.each do |microservice_name, microservice_config|
          cmd_array, work_dir, env, scope, container = convert_microservice_to_process_definition(microservice_name, microservice_config)
          if cmd_array
            process = @processes[microservice_name]
            if process
              process.process_definition = cmd_array
              process.work_dir = work_dir
              process.new_temp_dir = nil
              process.env = env
              @changed_processes[microservice_name] = process
            else # TODO: How is this even possible?
              Logger.error("Changed microservice #{microservice_name} does not exist. Creating new...", scope: scope)
              process = OperatorProcess.new(cmd_array, work_dir: work_dir, env: env, scope: scope, container: container)
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
