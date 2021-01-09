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

    def initialize(name:, updated_at: nil, scope: nil)
      super(PRIMARY_KEY, name: name, updated_at: updated_at)
    end

    def as_json
      { 'name' => @name,
        'updated_at' => @updated_at
      }
    end

    def as_config
      "SCOPE #{@name}\n"
    end

    def self.handle_config(primary_key, parser, model, keyword, parameters)
      case keyword
      when 'SCOPE'
        parser.verify_num_parameters(1, 1, "SCOPE <Name>")
        return self.new(name: parameters[0])
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Scope: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def self.get(name:, scope: nil)
      super(PRIMARY_KEY, name: name)
    end

    def self.names(scope: nil)
      super(PRIMARY_KEY)
    end

    def self.all(scope: nil)
      super(PRIMARY_KEY)
    end
  end
end