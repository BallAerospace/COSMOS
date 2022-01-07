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

require 'cosmos/models/model'
require 'cosmos/models/microservice_model'

module Cosmos
  class ScopeModel < Model
    PRIMARY_KEY = 'cosmos_scopes'

    # NOTE: The following three class methods are used by the ModelController
    # and are reimplemented to enable various Model class methods to work
    def self.get(name:, scope: nil)
      super(PRIMARY_KEY, name: name)
    end

    def self.names(scope: nil)
      super(PRIMARY_KEY)
    end

    def self.all(scope: nil)
      super(PRIMARY_KEY)
    end

    def initialize(name:, updated_at: nil, scope: nil)
      super(PRIMARY_KEY, name: name, scope: name, updated_at: updated_at)
    end

    def as_json
      { 'name' => @name,
        'updated_at' => @updated_at }
    end

    def deploy(gem_path, variables)
      seed_database()

      # Cleanup Microservice
      microservice_name = "#{@scope}__CLEANUP__S3"
      microservice = MicroserviceModel.new(
        name: microservice_name,
        cmd: ["ruby", "cleanup_microservice.rb", microservice_name],
        work_dir: '/cosmos/lib/cosmos/microservices',
        options: [
          ["SIZE", "20_000_000_000"], # Max Size to keep in S3
          ["DELAY", "300"], # Delay between size checks
          ["BUCKET", "logs"], # Bucket to monitor
          ["PREFIX", @scope + "/"], # Path into bucket to monitor
        ],
        scope: @scope
      )
      microservice.create
      microservice.deploy(gem_path, variables)
      Logger.info "Configured microservice #{microservice_name}"

      # COSMOS Log Microservice
      microservice_name = "#{@scope}__COSMOS__LOG"
      microservice = MicroserviceModel.new(
        name: microservice_name,
        cmd: ["ruby", "text_log_microservice.rb", microservice_name],
        work_dir: '/cosmos/lib/cosmos/microservices',
        options: [
          # The following options are optional (600 and 50_000_000 are the defaults)
          # ["CYCLE_TIME", "600"], # Keep at most 10 minutes per log
          # ["CYCLE_SIZE", "50_000_000"] # Keep at most ~50MB per log
        ],
        topics: ["#{@scope}__cosmos_log_messages"],
        scope: @scope
      )
      microservice.create
      microservice.deploy(gem_path, variables)
      Logger.info "Configured microservice #{microservice_name}"

      # Notification Log Microservice
      microservice_name = "#{@scope}__NOTIFICATION__LOG"
      microservice = MicroserviceModel.new(
        name: microservice_name,
        cmd: ["ruby", "text_log_microservice.rb", microservice_name],
        work_dir: '/cosmos/lib/cosmos/microservices',
        options: [
          # The following options are optional (600 and 50_000_000 are the defaults)
          ["CYCLE_TIME", "3600"], # Keep at most 1 hour per log
        ],
        topics: ["#{@scope}__cosmos_notifications"],
        scope: @scope
      )
      microservice.create
      microservice.deploy(gem_path, variables)
      Logger.info "Configured microservice #{microservice_name}"

      # UNKNOWN CommandLog Microservice
      Store.initialize_streams(["#{@scope}__COMMAND__{UNKNOWN}__UNKNOWN"])
      microservice_name = "#{@scope}__COMMANDLOG__UNKNOWN"
      microservice = MicroserviceModel.new(
        name: microservice_name,
        cmd: ["ruby", "log_microservice.rb", microservice_name],
        work_dir: '/cosmos/lib/cosmos/microservices',
        options: [
          ["RAW_OR_DECOM", "RAW"],
          ["CMD_OR_TLM", "CMD"],
          ["CYCLE_TIME", "3600"], # Keep at most 1 hour per log
        ],
        topics: ["#{@scope}__COMMAND__{UNKNOWN}__UNKNOWN"],
        target_names: ['UNKNOWN'],
        scope: @scope
      )
      microservice.create
      microservice.deploy(gem_path, variables)
      Logger.info "Configured microservice #{microservice_name}"

      # UNKNOWN PacketLog Microservice
      Store.initialize_streams(["#{@scope}__TELEMETRY__{UNKNOWN}__UNKNOWN"])
      microservice_name = "#{@scope}__PACKETLOG__UNKNOWN"
      microservice = MicroserviceModel.new(
        name: microservice_name,
        cmd: ["ruby", "log_microservice.rb", microservice_name],
        work_dir: '/cosmos/lib/cosmos/microservices',
        options: [
          ["RAW_OR_DECOM", "RAW"],
          ["CMD_OR_TLM", "TLM"],
          ["CYCLE_TIME", "3600"], # Keep at most 1 hour per log
        ],
        topics: ["#{@scope}__TELEMETRY__{UNKNOWN}__UNKNOWN"],
        target_names: ['UNKNOWN'],
        scope: @scope
      )
      microservice.create
      microservice.deploy(gem_path, variables)
      Logger.info "Configured microservice #{microservice_name}"
    end

    def undeploy
      model = MicroserviceModel.get_model(name: "#{@scope}__CLEANUP__S3", scope: @scope)
      model.destroy if model
      model = MicroserviceModel.get_model(name: "#{@scope}__COSMOS__LOG", scope: @scope)
      model.destroy if model
      model = MicroserviceModel.get_model(name: "#{@scope}__NOTIFICATION__LOG", scope: @scope)
      model.destroy if model
      model = MicroserviceModel.get_model(name: "#{@scope}__COMMANDLOG__UNKNOWN", scope: @scope)
      model.destroy if model
      model = MicroserviceModel.get_model(name: "#{@scope}__PACKETLOG__UNKNOWN", scope: @scope)
      model.destroy if model
    end

    def seed_database
      # Set default values for items in the db that should be set
      # Use the "nx" (not-exists) variant of redis calls here to not overwrite things the user has already set
      Cosmos::Store.hsetnx('cosmos__settings', 'source_url', 'https://github.com/BallAerospace/COSMOS')
      Cosmos::Store.hsetnx('cosmos__settings', 'version', ENV['COSMOS_VERSION'] || '5.0.X')
    end
  end
end
