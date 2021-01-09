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

module Cosmos
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
    def get_saved_config(configuration_name = nil, scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    def list_configs(tool, scope: $cosmos_scope, token: $cosmos_token)
      Store.instance.hkeys("#{scope}__config__#{tool}")
    end

    def load_config(tool, name, scope: $cosmos_scope, token: $cosmos_token)
      Store.instance.hget("#{scope}__config__#{tool}", name)
    end

    def save_config(tool, name, data, scope: $cosmos_scope, token: $cosmos_token)
      Store.instance.hset("#{scope}__config__#{tool}", name, data)
    end

    def delete_config(tool, name, scope: $cosmos_scope, token: $cosmos_token)
      Store.instance.hdel("#{scope}__config__#{tool}", name)
    end
  end
end