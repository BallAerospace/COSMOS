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

require 'cosmos/models/interface_model'
require 'cosmos/models/interface_status_model'

module Cosmos
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
      'get_interface_targets',
      'get_interface_names',
      'connect_interface',
      'disconnect_interface',
      'interface_state',
      'map_target_to_interface',
      'get_interface_info',
      'get_interface',
      'get_all_interface_info',
    ])

    # @deprecated Use #get_interface
    # @return [Array<String>] All the targets mapped to the given interface
    def get_interface_targets(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', interface_name: interface_name, scope: scope, token: token)
      interface = JSON.parse(Store.instance.hget("#{scope}__cosmos_microservices", "INTERFACE__#{interface_name}"))
      targets = []
      interface['target_list'].each do |target|
        targets << target['target_name']
      end
      targets
    end

    # @return [Array<String>] All the interface names
    def get_interface_names(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      InterfaceModel.names(scope: scope)
    end

    # Connects to an interface and starts its telemetry gathering thread. If
    # optional parameters are given, the interface is recreated with new
    # parameters.
    #
    # @param interface_name [String] The name of the interface
    # TODO: Should we deprecate this params? No one seems to use it?
    # @param params [Array] Parameters to pass to the interface.
    def connect_interface(interface_name, *params, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', interface_name: interface_name, scope: scope, token: token)
      Store.instance.write_interface(interface_name, {'connect' => true}, scope: scope)
    end

    # Disconnects from an interface and kills its telemetry gathering thread
    #
    # @param interface_name (see #connect_interface)
    def disconnect_interface(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', interface_name: interface_name, scope: scope, token: token)
      Store.instance.write_interface(interface_name, {'disconnect' => true }, scope: scope)
    end

    # @param interface_name (see #connect_interface)
    # @return [String] The state of the interface which is one of 'CONNECTED',
    #   'ATTEMPTING' or 'DISCONNECTED'.
    def interface_state(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', interface_name: interface_name, scope: scope, token: token)
      CmdTlmServer.interfaces.state(interface_name)
    end

    # Associates a target and all its commands and telemetry with a particular
    # interface. All the commands will go out over and telemetry be received
    # from that interface.
    #
    # @param target_name [String] The name of the target
    # @param interface_name (see #connect_interface)
    def map_target_to_interface(target_name, interface_name, scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported in COSMOS 5 - Targets cannot be dynamically remapped"
    end

    # Get information about an interface
    #
    # @param interface_name [String] Interface name
    # @return [Hash] Hash of all the interface information
    def get_interface(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', interface_name: interface_name, scope: scope, token: token)
      InterfaceStatusModel.get(name: interface_name, scope: scope)
    end

    # Get information about an interface
    #
    # @deprecated Use #get_interface
    # @param interface_name [String] Interface name
    # @return [Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>] Array containing \[state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Command count,
    #   Telemetry count] for the interface
    def get_interface_info(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', interface_name: interface_name, scope: scope, token: token)
      int = InterfaceStatusModel.get(name: interface_name, scope: scope)
      return [int['state'], int['clients'], int['txsize'], int['rxsize'],
              int['txbytes'], int['rxbytes'], int['cmdcnt'], int['tlmcnt']]
    end

    # Get information about all interfaces
    #
    # @return [Array<Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>>] Array of Arrays containing \[name, state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Command count,
    #   Telemetry count] for all interfaces
    def get_all_interface_info(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      info = []
      InterfaceStatusModel.all(scope: scope).each do |int_name, int|
        info << [int['name'], int['state'], int['clients'], int['txsize'], int['rxsize'],
                  int['txbytes'], int['rxbytes'], int['cmdcnt'], int['tlmcnt']]
      end
      info.sort! {|a,b| a[0] <=> b[0] }
      info
    end

  end
end