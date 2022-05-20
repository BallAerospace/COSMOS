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
  class SettingsModel < Model
    PRIMARY_KEY = 'cosmos__settings'

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
    # END NOTE

    def initialize(name:, scope: nil, data:)
      super(PRIMARY_KEY, name: name, scope: scope)
      @data = data
    end

    # @return [Hash] JSON encoding of this model
    def as_json
      {
        'name' => @name,
        'data' => @data,
        'updated_at' => @updated_at
      }
    end
  end
end
