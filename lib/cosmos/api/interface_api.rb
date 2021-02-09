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
require 'cosmos/topics/interface_topics'

module Cosmos
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
      'get_interface',
      'get_interface_names',
      'connect_interface',
      'disconnect_interface',
      'start_raw_logging_interface',
      'stop_raw_logging_interface',
      # DEPRECATED:
      'interface_state',
      'get_interface_targets',
      'get_interface_info',
      'get_all_interface_info',
    ])

    # Get information about an interface
    #
    # @param interface_name [String] Interface name
    # @return [Hash] Hash of all the interface information
    def get_interface(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', interface_name: interface_name, scope: scope, token: token)
      interface = InterfaceModel.get(name: interface_name, scope: scope)
      raise "Interface '#{interface_name}' does not exist" unless interface
      interface.merge(InterfaceStatusModel.get(name: interface_name, scope: scope))
    end

    # @return [Array<String>] All the interface names
    def get_interface_names(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      InterfaceModel.names(scope: scope)
    end

    # Connects an interface and starts its telemetry gathering thread
    #
    # @param interface_name [String] The name of the interface
    def connect_interface(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', interface_name: interface_name, scope: scope, token: token)
      InterfaceTopics.connect_interface(interface_name, scope: scope)
    end

    # Disconnects from an interface and kills its telemetry gathering thread
    #
    # @param interface_name [String] The name of the interface
    def disconnect_interface(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', interface_name: interface_name, scope: scope, token: token)
      InterfaceTopics.disconnect_interface(interface_name, scope: scope)
    end

    # Starts raw logging for an interface
    #
    # @param interface_name [String] The name of the interface
    def start_raw_logging_interface(interface_name = 'ALL', scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', interface_name: interface_name, scope: scope, token: token)
      if interface_name == 'ALL'
        get_interface_names().each do |interface_name|
          InterfaceTopics.start_raw_logging(interface_name, scope: scope)
        end
      else
        InterfaceTopics.start_raw_logging(interface_name, scope: scope)
      end
    end

    # Stop raw logging for an interface
    #
    # @param interface_name [String] The name of the interface
    def stop_raw_logging_interface(interface_name = 'ALL', scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', interface_name: interface_name, scope: scope, token: token)
      if interface_name == 'ALL'
        get_interface_names().each do |interface_name|
          InterfaceTopics.stop_raw_logging(interface_name, scope: scope)
        end
      else
        InterfaceTopics.stop_raw_logging(interface_name, scope: scope)
      end
    end

    ###########################################################################
    # DEPRECATED METHODS
    ###########################################################################

    # @deprecated Use #get_interface
    # @param interface_name (see #connect_interface)
    # @return [String] The state of the interface which is one of 'CONNECTED',
    #   'ATTEMPTING' or 'DISCONNECTED'.
    def interface_state(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      get_interface(interface_name, scope: scope, token: token)['state']
    end

    # @deprecated Use #get_interface
    # @return [Array<String>] All the targets mapped to the given interface
    def get_interface_targets(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      get_interface(interface_name, scope: scope, token: token)['target_names']
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
      int = get_interface(interface_name, scope: scope, token: token)
      return [int['state'], int['clients'], int['txsize'], int['rxsize'],
              int['txbytes'], int['rxbytes'], int['txcnt'], int['rxcnt']]
    end

    # Get information about all interfaces
    #
    # @deprecated Use get_interface_names and get_interface
    # @return [Array<Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>>] Array of Arrays containing \[name, state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Command count,
    #   Telemetry count] for all interfaces
    def get_all_interface_info(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      info = []
      InterfaceStatusModel.all(scope: scope).each do |int_name, int|
        info << [int['name'], int['state'], int['clients'], int['txsize'], int['rxsize'],
                  int['txbytes'], int['rxbytes'], int['txcnt'], int['rxcnt']]
      end
      info.sort! {|a,b| a[0] <=> b[0] }
      info
    end
  end
end
