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

require 'openc3/topics/topic'

module OpenC3
  class CommandDecomTopic < Topic
    def self.topics(scope:)
      super(scope, 'DECOMCMD')
    end

    def self.write_packet(packet, scope:)
      topic = "#{scope}__DECOMCMD__{#{packet.target_name}}__#{packet.packet_name}"
      msg_hash = { time: packet.received_time.to_nsec_from_epoch,
                   target_name: packet.target_name,
                   packet_name: packet.packet_name,
                   stored: packet.stored,
                   received_count: packet.received_count }
      json_hash = {}
      packet.sorted_items.each do |item|
        json_hash[item.name] = packet.read_item(item, :RAW)
        json_hash[item.name + "__C"] = packet.read_item(item, :CONVERTED) if item.write_conversion or item.states
        json_hash[item.name + "__F"] = packet.read_item(item, :FORMATTED) if item.format_string
        json_hash[item.name + "__U"] = packet.read_item(item, :WITH_UNITS) if item.units
      end
      msg_hash['json_data'] = JSON.generate(json_hash.as_json(:allow_nan => true))
      Topic.write_topic(topic, msg_hash)
    end

    def self.get_cmd_item(target_name, packet_name, param_name, type: :WITH_UNITS, scope: $openc3_scope)
      msg_id, msg_hash = Topic.get_newest_message("#{scope}__DECOMCMD__{#{target_name}}__#{packet_name}")
      if msg_id
        # TODO: We now have these reserved items directly on command packets
        # Do we still calculate from msg_hash['time'] or use the times directly?
        #
        # if param_name == 'RECEIVED_TIMESECONDS' || param_name == 'PACKET_TIMESECONDS'
        #   Time.from_nsec_from_epoch(msg_hash['time'].to_i).to_f
        # elsif param_name == 'RECEIVED_TIMEFORMATTED' || param_name == 'PACKET_TIMEFORMATTED'
        #   Time.from_nsec_from_epoch(msg_hash['time'].to_i).formatted
        if param_name == 'RECEIVED_COUNT'
          msg_hash['received_count'].to_i
        else
          json = msg_hash['json_data']
          hash = JSON.parse(json, :allow_nan => true, :create_additions => true)
          # Start from the most complex down to the basic raw value
          value = hash["#{param_name}__U"]
          return value if value && type == :WITH_UNITS

          value = hash["#{param_name}__F"]
          return value if value && (type == :WITH_UNITS || type == :FORMATTED)

          value = hash["#{param_name}__C"]
          return value if value && (type == :WITH_UNITS || type == :FORMATTED || type == :CONVERTED)

          return hash[param_name]
        end
      end
    end
  end
end
