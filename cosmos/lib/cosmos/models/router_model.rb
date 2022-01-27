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

require 'cosmos/models/interface_model'

module Cosmos
  class RouterModel < InterfaceModel
    # Called by the PluginModel to allow this class to validate it's top-level keyword: "ROUTER"
    def self.handle_config(parser, keyword, parameters, plugin: nil, needs_dependencies: false, scope:)
      case keyword
      when 'ROUTER'
        parser.verify_num_parameters(2, nil, "ROUTER <Name> <Filename> <Specific Parameters>")
        return self.new(name: parameters[0].upcase, config_params: parameters[1..-1], plugin: plugin, scope: scope)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Router: #{keyword} #{parameters.join(" ")}")
      end
    end
  end
end
