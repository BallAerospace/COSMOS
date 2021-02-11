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
    ])

    # Returns the list of all target names
    #
    # @return [Array<String>] All target names
    def get_target_list(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      TargetModel.names(scope: scope)
    end

    # Gets the full target hash
    #
    # @since 5.0.0
    # @param target_name [String] Target name
    # @return [Hash] Hash of all the target properties
    def get_target(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, scope: scope, token: token)
      TargetModel.get(name: target_name, scope: scope)
    end

    # Get information about all targets
    #
    # @return [Array<Array<String, Numeric, Numeric>] Array of Arrays \[name, interface, cmd_cnt, tlm_cnt]
    def get_all_target_info(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      info = []
      get_target_list(scope: scope, token: token).each do |target_name|
        cmd_cnt = 0
        packets = TargetModel.packets(target_name, type: :CMD, scope: scope)
        packets.each do |packet|
          cmd_cnt += _get_cnt("#{scope}__COMMAND__#{target_name}__#{packet['packet_name']}")
        end
        tlm_cnt = 0
        packets = TargetModel.packets(target_name, type: :TLM, scope: scope)
        packets.each do |packet|
          tlm_cnt += _get_cnt("#{scope}__TELEMETRY__#{target_name}__#{packet['packet_name']}")
        end
        interface_name = ''
        InterfaceModel.all(scope: scope).each do |name, interface|
          if interface['target_names'].include? target_name
            interface_name = interface['name']
            break
          end
        end
        info << [target_name, interface_name, cmd_cnt, tlm_cnt]
      end
      info
    end
  end
end
