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

require 'cosmos/script/extract'
require 'cosmos/script/api_shared'
require 'cosmos/api/cmd_api'
require 'cosmos/api/config_api'
require 'cosmos/api/interface_api'
require 'cosmos/api/limits_api'
require 'cosmos/api/logging_api'
require 'cosmos/api/replay_api'
require 'cosmos/api/router_api'
require 'cosmos/api/target_api'
require 'cosmos/api/tlm_api'
require 'cosmos/utilities/authorization'

module Cosmos
  module Api
    include Extract
    include ApiShared
    include Authorization

    # PRIVATE - Shared by cmd_api and tlm_api

    def _get_cnt(topic)
      _, packet = Store.instance.read_topic_last(topic)
      packet ? packet["received_count"].to_i : 0
    end

    def get_all_cmd_tlm_info(type, scope:, token:)
      authorize(permission: 'system', scope: scope, token: token)
      result = []
      keys = []
      count = 0
      loop do
        count, part = Store.scan(0, :match => "#{scope}__#{type}__*", :count => 1000)
        keys.concat(part)
        break if count.to_i == 0
      end
      keys.each do |key|
        _, _, target, packet = key.split('__') # split off scope and type
        result << [target, packet, _get_cnt(key)]
      end
      # Return the results sorted by target, packet
      result.sort_by { |a| [a[0], a[1]] }
    end
  end
end
