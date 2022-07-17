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

module OpenC3
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
                       'list_settings',
                       'get_all_settings',
                       'get_setting',
                       'get_settings',
                       'save_setting'
                     ])

    def list_settings(scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system', scope: scope, token: token)
      SettingsModel.names(scope: scope)
    end

    def get_all_settings(scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system', scope: scope, token: token)
      SettingsModel.all(scope: scope)
    end

    def get_setting(name, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system', scope: scope, token: token)
      setting = SettingsModel.get(name: name, scope: scope)
      if setting
        return setting["data"]
      else
        return nil
      end
    end

    def get_settings(*args, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system', scope: scope, token: token)
      ret = []
      args.each do |name|
        setting = SettingsModel.get(name: name, scope: scope)
        if setting
          ret << setting["data"]
        else
          ret << nil
        end
      end
      return ret
    end

    def save_setting(name, data, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'admin', scope: scope, token: token)
      SettingsModel.set({ name: name,  data: data }, scope: scope)
    end
  end
end
