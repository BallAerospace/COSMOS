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

require 'openc3/models/tool_config_model'

module OpenC3
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
                       'get_saved_config',
                       'list_configs',
                       'load_config',
                       'save_config',
                       'delete_config'
                     ])

    # Get a saved configuration zip file
    def get_saved_config(configuration_name = nil, scope: $openc3_scope, token: $openc3_token)
      raise "Not supported by OpenC3 5"
    end

    def list_configs(tool, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system', scope: scope, token: token)
      ToolConfigModel.list_configs(tool, scope: scope)
    end

    def load_config(tool, name, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system', scope: scope, token: token)
      ToolConfigModel.load_config(tool, name, scope: scope)
    end

    def save_config(tool, name, data, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system_set', scope: scope, token: token)
      ToolConfigModel.save_config(tool, name, data, scope: scope)
    end

    def delete_config(tool, name, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system_set', scope: scope, token: token)
      ToolConfigModel.delete_config(tool, name, scope: scope)
    end
  end
end
