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
    SETTINGS_KEY = "cosmos__settings"

    WHITELIST ||= []
    WHITELIST.concat([
      'list_settings',
      'get_all_settings',
      'get_setting',
      'save_setting'
    ])

    def list_settings(scope: $cosmos_scope, token: $cosmos_token)
      Store.instance.hkeys(SETTINGS_KEY)
    end

    def get_all_settings(scope: $cosmos_scope, token: $cosmos_token)
      Store.instance.hgetall(SETTINGS_KEY)
    end
    
    def get_setting(name, scope: $cosmos_scope, token: $cosmos_token)
      Store.instance.hget(SETTINGS_KEY, name)
    end

    def save_setting(name, data, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'superadmin', scope: scope, token: token)
      Store.instance.hset(SETTINGS_KEY, name, data)
    end
  end
end
