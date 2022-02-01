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

require 'cosmos/models/model'

module Cosmos
  class MicroserviceStatusModel < Model
    PRIMARY_KEY = 'cosmos_microservice_status'

    attr_accessor :state
    attr_accessor :count
    attr_accessor :error
    attr_accessor :custom

    # NOTE: The following three class methods are used by the ModelController
    # and are reimplemented to enable various Model class methods to work
    def self.get(name:, scope:)
      super("#{scope}__#{PRIMARY_KEY}", name: name)
    end

    def self.names(scope:)
      super("#{scope}__#{PRIMARY_KEY}")
    end

    def self.all(scope:)
      super("#{scope}__#{PRIMARY_KEY}")
    end

    def initialize(
      name:,
      state: nil,
      count: 0,
      error: nil,
      custom: nil,
      updated_at: nil,
      plugin: nil,
      scope:
    )
      super("#{scope}__#{PRIMARY_KEY}", name: name, updated_at: updated_at, plugin: plugin, scope: scope)
      @state = state
      @count = count
      @error = error
      @custom = custom
    end

    def as_json
      {
        'name' => @name,
        'state' => @state,
        'count' => @count,
        'error' => @error.as_json,
        'custom' => @custom.as_json,
        'plugin' => @plugin,
        'updated_at' => @updated_at
      }
    end
  end
end
