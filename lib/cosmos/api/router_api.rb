require 'cosmos/models/router_model'
require 'cosmos/models/router_status_model'

module Cosmos
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
      'get_router_names',
      'connect_router',
      'disconnect_router',
      'router_state',
      'get_router_info',
      'get_all_router_info',
    ])

    # @return [Array<String>] All the router names
    def get_router_names(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      RouterModel.names(scope: scope)
    end

    # Connects a router and starts its command gathering thread. If
    # optional parameters are given, the router is recreated with new
    # parameters.
    #
    # @param router_name [String] The name of the router
    # @param params [Array] Parameters to pass to the router.
    def connect_router(router_name, *params, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', router_name: router_name, scope: scope, token: token)
      CmdTlmServer.routers.connect(router_name, *params)
      nil
    end

    # Disconnects a router and kills its command gathering thread
    #
    # @param router_name (see #connect_router)
    def disconnect_router(router_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', router_name: router_name, scope: scope, token: token)
      CmdTlmServer.routers.disconnect(router_name)
      nil
    end

    # @param router_name (see #connect_router)
    # @return [String] The state of the router which is one of 'CONNECTED',
    #   'ATTEMPTING' or 'DISCONNECTED'.
    def router_state(router_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', router_name: router_name, scope: scope, token: token)
      CmdTlmServer.routers.state(router_name)
    end


    # Get information about a router
    #
    # @param router_name [String] Router name
    # @return [Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>] Array containing \[state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Pkts received,
    #   Pkts sent] for the router
    def get_router_info(router_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', router_name: router_name, scope: scope, token: token)
      RouterStatusModel.get(name: router_name, scope: scope)
    end

    # Get information about all routers
    #
    # @return [Array<Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>>] Array of Arrays containing \[name, state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Command count,
    #   Telemetry count] for all routers
    def get_all_router_info(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      info = []
      Store.instance.get_routers(scope: scope).each do |int|
        info << [int['name'], int['state'], int['clients'], int['txsize'], int['rxsize'],\
                  int['txbytes'], int['rxbytes'], int['cmdcnt'], int['tlmcnt']]
      end
      info.sort! {|a,b| a[0] <=> b[0] }
      info
    end

  end
end