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
  class TelemetryTopic < Topic
    def self.write_packet(packet, scope:)
      msg_hash = { time: packet.received_time.to_nsec_from_epoch,
        stored: packet.stored,
        target_name: packet.target_name,
        packet_name: packet.packet_name,
        received_count: packet.received_count,
        buffer: packet.buffer(false) }
      Store.write_topic("#{scope}__TELEMETRY__{#{packet.target_name}}__#{packet.packet_name}", msg_hash)
    end
  end
end
