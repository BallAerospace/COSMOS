# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
Cosmos.require_file 'json'
Cosmos.require_file 'redis'
Cosmos.require_file 'fileutils'
Cosmos.require_file 'zip'
Cosmos.require_file 'zip/filesystem'
Cosmos.require_file 'cosmos/io/json_rpc'
Cosmos.require_file 'cosmos/utilities/store'
Cosmos.require_file 'cosmos/utilities/s3'

module Cosmos
  class Microservice
    def self.run
      begin
        microservice = self.new(ARGV[0])
        microservice.run
      rescue Exception => err
        unless err.class == SystemExit or err.class == Interrupt
          Logger.fatal("Microservice #{ARGV[0]} dying from exception\n#{err.formatted}")
        end
      end
    end

    def initialize(name)
      raise "Microservice must be named" unless name
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
      @redis = Redis.new(url: ENV['COSMOS_REDIS_URL'] || (ENV['COSMOS_DEVEL'] ? 'redis://127.0.0.1:6379/0' : 'redis://cosmos-redis:6379/0'))
      @config = @redis.hget("cosmos_microservices", name)
      if @config
        @config = JSON.parse(@config)
        @topics = @config['topics']
      else
        @config = {}
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
    end

    def shutdown
      @cancel_thread = true
      FileUtils.remove_entry(@temp_dir) if File.exists?(@temp_dir)
    end
  end
end