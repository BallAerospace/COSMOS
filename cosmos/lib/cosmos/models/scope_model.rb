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
        'updated_at' => @updated_at
      }
    end

    def deploy(gem_path, variables)
      # Cleanup Microservice
      microservice_name = "#{@scope}__CLEANUP__S3"
      microservice = MicroserviceModel.new(
        name: microservice_name,
        cmd: ["ruby", "cleanup_microservice.rb", microservice_name],
        work_dir: '/cosmos/lib/cosmos/microservices',
        options: [["SIZE", "20000000000"], ["DELAY", "300"], ["BUCKET", "logs"], ["PREFIX", @scope + "/"]],
        scope: @scope)
      microservice.create
      microservice.deploy(gem_path, variables)
      Logger.info "Configured microservice #{microservice_name}"
    end

    def undeploy
      model = MicroserviceModel.get_model(name: "#{@scope}__CLEANUP", scope: @scope)
      model.destroy if model
    end
  end
end