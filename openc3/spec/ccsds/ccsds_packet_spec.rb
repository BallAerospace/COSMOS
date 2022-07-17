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

require 'spec_helper'
require 'openc3/ccsds/ccsds_packet'

module OpenC3
  describe CcsdsPacket do
    describe "constants" do
      it "defines COMMAND and TELEMETRY" do
        expect(CcsdsPacket::TELEMETRY).to eql 0
        expect(CcsdsPacket::COMMAND).to eql 1
      end

      it "defines sequence flags" do
        expect(CcsdsPacket::CONTINUATION).to eql 0
        expect(CcsdsPacket::FIRST).to eql 1
        expect(CcsdsPacket::LAST).to eql 2
        expect(CcsdsPacket::STANDALONE).to eql 3
      end
    end

    describe "initialize" do
      it "sets the target_name and packet_name" do
        p = CcsdsPacket.new("tgt", "pkt")
        expect(p.target_name).to eql "TGT"
        expect(p.packet_name).to eql "PKT"

        version = p.get_item("CCSDSVERSION")
        expect(version.bit_offset).to eql 0
        expect(version.bit_size).to eql 3
        type = p.get_item("CCSDSTYPE")
        expect(type.bit_offset).to eql 3
        expect(type.bit_size).to eql 1
        type = p.get_item("CCSDSSHF")
        expect(type.bit_offset).to eql 4
        expect(type.bit_size).to eql 1
        type = p.get_item("CCSDSAPID")
        expect(type.bit_offset).to eql 5
        expect(type.bit_size).to eql 11
        type = p.get_item("CCSDSSEQFLAGS")
        expect(type.bit_offset).to eql 16
        expect(type.bit_size).to eql 2
        type = p.get_item("CCSDSSEQCNT")
        expect(type.bit_offset).to eql 18
        expect(type.bit_size).to eql 14
        expect(type.overflow).to eql :TRUNCATE
        type = p.get_item("CCSDSLENGTH")
        expect(type.bit_offset).to eql 32
        expect(type.bit_size).to eql 16
        type = p.get_item("CCSDSDATA")
        expect(type.bit_offset).to eql 48
        expect(type.bit_size).to eql 0 # fill the packet
      end
    end
  end
end
