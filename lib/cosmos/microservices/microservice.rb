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
Cosmos.require_file 'json'
Cosmos.require_file 'redis'
Cosmos.require_file 'fileutils'
Cosmos.require_file 'zip'
Cosmos.require_file 'zip/filesystem'
Cosmos.require_file 'cosmos/utilities/store'
Cosmos.require_file 'cosmos/utilities/s3'
Cosmos.require_file 'cosmos/utilities/sleeper'
Cosmos.require_file 'cosmos/models/microservice_model'
Cosmos.require_file 'cosmos/models/microservice_status_model'

module Cosmos

  class Microservice
    attr_accessor :microservice_status_thread
    attr_accessor :name
    attr_accessor :state
    attr_accessor :count
    attr_accessor :error
    attr_accessor :custom
    attr_accessor :scope

    def self.run
      microservice = nil
      begin
        microservice = self.new(ARGV[0])
        MicroserviceStatusModel.set(microservice.as_json, scope: microservice.scope)
        microservice.state = 'RUNNING'
        microservice.run
        microservice.state = 'FINISHED'
      rescue Exception => err
        if err.class == SystemExit or err.class == Interrupt
          microservice.state = 'KILLED'
        else
          microservice.error = err
          microservice.state = 'DIED_ERROR'
          Logger.fatal("Microservice #{ARGV[0]} dying from exception\n#{err.formatted}")
        end
      ensure
        MicroserviceStatusModel.set(microservice.as_json, scope: microservice.scope)
      end
    end

    def as_json
      {
        'name' => @name,
        'state' => @state,
        'count' => @count,
        'error' => @error.as_json,
        'custom' => @custom.as_json,
        'plugin' => @plugin,
      }
    end

    def initialize(name)
      raise "Microservice must be named" unless name
      @name = name
      split_name = name.split("__")
      raise "Microservice names should be scope, type, and then name" if split_name.length != 3
      @scope = split_name[0]
      Logger.scope = @scope
      @name = name
      @cancel_thread = false
      Logger.microservice_name = @name
      Logger.tag = @name + ".log"

      # Create temp folder for this microservice
      @temp_dir = Dir.mktmpdir

      # Get microservice configuration from Redis
      @config = MicroserviceModel.get(name: @name, scope: @scope)
      if @config
        @topics = @config['topics']
        @plugin = @config['plugin']
      else
        @config = {}
        @plugin = nil
      end
      Logger.info("Microservice initialized with config:\n#{@config}")
      @topics ||= []

      # Get configuration for any targets from Minio/S3
      @target_names = @config["target_names"]
      @target_names ||= []
      System.setup_targets(@target_names, @temp_dir, scope: @scope)

      # Use at_exit to shutdown cleanly no matter how we are die
      at_exit do
        shutdown()
      end

      @count = 0
      @error = nil
      @custom = nil
      @state = 'INITIALIZED'

      @microservice_sleeper = Sleeper.new
      @microservice_status_period_seconds = 5
      @microservice_status_thread = Thread.new do
        until @cancel_thread
          MicroserviceStatusModel.set(as_json(), scope: @scope) unless @cancel_thread
          break if @microservice_sleeper.sleep(@microservice_status_period_seconds)
        end
      end
    end

    def shutdown
      @cancel_thread = true
      @microservice_sleeper.cancel
      MicroserviceStatusModel.set(as_json(), scope: @scope)
      FileUtils.remove_entry(@temp_dir) if File.exists?(@temp_dir)
    end
  end
end