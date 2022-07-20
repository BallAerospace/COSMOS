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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'openc3/models/model'

module OpenC3

  class EnvironmentError < StandardError; end

  class EnvironmentModel < Model
    PRIMARY_KEY = '__openc3__environment'.freeze

    # NOTE: The following three class methods are used by the ModelController
    # and are reimplemented to enable various Model class methods to work
    def self.get(name:, scope:)
      super("#{scope}#{PRIMARY_KEY}", name: name)
    end

    def self.all(scope:)
      super("#{scope}#{PRIMARY_KEY}")
    end

    def self.destroy(scope:, name:)
      Store.hdel("#{scope}#{PRIMARY_KEY}", name)
    end

    def initialize(name:, scope:, key:, value:)
      super("#{scope}#{PRIMARY_KEY}", name: name, scope: scope)
      @key = key
      @value = value
    end

    def as_json(*a)
      {
        'name' => @name,
        'updated_at' => @updated_at,
        'key' => @key,
        'value' => @value
      }
    end
  end
end
