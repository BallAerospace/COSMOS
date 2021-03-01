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

require 'cosmos/topics/topic'

module Cosmos
  class TelemetryDecomTopic < Topic
    def self.write_packet(packet, scope:)
      # Need to build a JSON hash of the decommutated data
      # Support "downward typing"
      # everything base name is RAW (including DERIVED)
      # Request for WITH_UNITS, etc will look down until it finds something
      # If nothing - item does not exist - nil
      # __ as seperators ITEM1, ITEM1__C, ITEM1__F, ITEM1__U

      json_hash = {}
      packet.sorted_items.each do |item|
        json_hash[item.name] = packet.read_item(item, :RAW)
        json_hash[item.name + "__C"] = packet.read_item(item, :CONVERTED) if item.read_conversion or item.states
        json_hash[item.name + "__F"] = packet.read_item(item, :FORMATTED) if item.format_string
        json_hash[item.name + "__U"] = packet.read_item(item, :WITH_UNITS) if item.units
        limits_state = item.limits.state
        json_hash[item.name + "__L"] = limits_state if limits_state
      end

      # Write to stream
      msg_hash = { time: packet.packet_time.to_nsec_from_epoch,
        stored: packet.stored,
        target_name: packet.target_name,
        packet_name: packet.packet_name,
        received_count: packet.received_count,
        json_data: JSON.generate(json_hash.as_json)
      }

      # NOTE: The final parameter is important! (See DecomLogMicroservice)
      # It must be greater than the size of a log file to allow the decom_log_microservice
      # to write and close the previous log file and still have data available
      # for the streaming_api to switch between a closed log file and the active Redis stream.
      # TODO: How do we handle various data rates?
      Store.write_topic("#{scope}__DECOM__{#{packet.target_name}}__#{packet.packet_name}", msg_hash, nil, 4000)
    end
  end
end
