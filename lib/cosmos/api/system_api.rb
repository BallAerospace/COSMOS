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
      'get_server_status',
      'cmd_tlm_clear_counters',
    ])

    # Get JSON DRB information
    #
    # @return [String, Integer, Integer, Integer, Float, Integer] Server
    #   status including Limits Set, API Port, JSON DRB num clients,
    #   JSON DRB request count, JSON DRB average request time, and the total
    #   number of Ruby threads in the server/
    def get_server_status(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      set = Store.instance.hget("#{scope}__cosmos_system", 'limits_set')
      [ set, 0, 0, 0, 0,
        # TODO: What do we want to expose here?
        # CmdTlmServer.mode == :CMD_TLM_SERVER ? System.ports['CTS_API'] : System.ports['REPLAY_API'],
        # CmdTlmServer.json_drb.num_clients,
        # CmdTlmServer.json_drb.request_count,
        # CmdTlmServer.json_drb.average_request_time,
        Thread.list.length
      ]
    end

    # Clear server counters
    def cmd_tlm_clear_counters(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', scope: scope, token: token)
      CmdTlmServer.clear_counters
    end
  end
end