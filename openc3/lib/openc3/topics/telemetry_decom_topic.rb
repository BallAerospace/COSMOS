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
  class TelemetryDecomTopic < Topic
    def self.topics(scope:)
      super(scope, 'DECOM')
    end

    def self.write_packet(packet, id: nil, scope:)
      # Need to build a JSON hash of the decommutated data
      # Support "downward typing"
      # everything base name is RAW (including DERIVED)
      # Request for WITH_UNITS, etc will look down until it finds something
      # If nothing - item does not exist - nil
      # __ as seperators ITEM1, ITEM1__C, ITEM1__F, ITEM1__U

      json_hash = CvtModel.build_json_from_packet(packet)
      # Write to stream
      msg_hash = {
        :time => packet.packet_time.to_nsec_from_epoch,
        :stored => packet.stored,
        :target_name => packet.target_name,
        :packet_name => packet.packet_name,
        :received_count => packet.received_count,
        :json_data => JSON.generate(json_hash.as_json(:allow_nan => true)),
      }
      Topic.write_topic("#{scope}__DECOM__{#{packet.target_name}}__#{packet.packet_name}", msg_hash, id)

      unless packet.stored
        # Also update the current value table with the latest decommutated data
        CvtModel.set(json_hash, target_name: packet.target_name, packet_name: packet.packet_name, scope: scope)
      end
    end
  end
end
