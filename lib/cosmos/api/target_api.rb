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

require 'cosmos/models/target_model'

module Cosmos
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
      'get_target_list',
      'get_target',
      'get_all_target_info',
      'get_target_info',
      'get_target_ignored_parameters',
      'get_target_ignored_items',
    ])

    # Returns the list of all target names
    #
    # @return [Array<String>] All target names
    def get_target_list(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      TargetModel.names(scope: scope)
    end

    # Get cmd and tlm counts for a target
    #
    # @deprecated Use #get_target
    # @param target_name [String] Target name
    # @return [Array<Numeric, Numeric>] Array of \[cmd_cnt, tlm_cnt]
    def get_target_info(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, scope: scope, token: token)
      cmd_cnt = 0
      tlm_cnt = 0
      Store.instance.get_commands(target_name, scope: scope).each do |packet|
        cmd_cnt += get_cmd_cnt(target_name, packet["packet_name"])
      end
      Store.instance.get_telemetry(target_name, scope: scope).each do |packet|
        tlm_cnt += get_tlm_cnt(target_name, packet["packet_name"])
      end
      return [cmd_cnt, tlm_cnt]
    end

    # Get information about all targets
    #
    # @return [Array<Array<String, Numeric, Numeric>] Array of Arrays \[name, interface, cmd_cnt, tlm_cnt]
    def get_all_target_info(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      info = []
      get_target_list(scope: scope, token: token).each do |target_name|
        target = TargetModel.get(name: target_name, scope: scope)
        info << [target['name'], target['interface'], target['cmd_cnt'], target['tlm_cnt']]
      end
      info
    end

    # Gets the full target hash
    #
    # @since 5.0.0
    # @param target_name [String] Target name
    # @return [Hash] Hash of all the target properties
    def get_target(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, scope: scope, token: token)
      return TargetModel.get(name: target_name, scope: scope)
    end

    # Get the list of ignored command parameters for a target
    #
    # @deprecated Use #get_target
    # @param target_name [String] Target name
    # @return [Array<String>] All of the ignored command parameters for a target.
    def get_target_ignored_parameters(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, scope: scope, token: token)
      return TargetModel.get(name: target_name, scope: scope)['ignored_parameters']
    end

    # Get the list of ignored telemetry items for a target
    #
    # @deprecated Use get_target
    # @param target_name [String] Target name
    # @return [Array<String>] All of the ignored telemetry items for a target.
    def get_target_ignored_items(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, scope: scope, token: token)
      return TargetModel.get(name: target_name, scope: scope)['ignored_items']
    end

  end
end