# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/ccsds/ccsds_packet'

module Cosmos

  describe CcsdsPacket do

    describe "constants" do
      it "should define COMMAND and TELEMETRY" do
        CcsdsPacket::TELEMETRY.should eql 0
        CcsdsPacket::COMMAND.should eql 1
      end

      it "should define sequence flags" do
        CcsdsPacket::CONTINUATION.should eql 0
        CcsdsPacket::FIRST.should eql 1
        CcsdsPacket::LAST.should eql 2
        CcsdsPacket::STANDALONE.should eql 3
      end
    end

    describe "initialize" do
      it "should set the target_name and packet_name" do
        p = CcsdsPacket.new("tgt", "pkt")
        p.target_name.should eql "TGT"
        p.packet_name.should eql "PKT"

        version = p.get_item("CCSDSVERSION")
        version.bit_offset.should eql 0
        version.bit_size.should eql 3
        type = p.get_item("CCSDSTYPE")
        type.bit_offset.should eql 3
        type.bit_size.should eql 1
        type = p.get_item("CCSDSSHF")
        type.bit_offset.should eql 4
        type.bit_size.should eql 1
        type = p.get_item("CCSDSAPID")
        type.bit_offset.should eql 5
        type.bit_size.should eql 11
        type = p.get_item("CCSDSSEQFLAGS")
        type.bit_offset.should eql 16
        type.bit_size.should eql 2
        type = p.get_item("CCSDSSEQCNT")
        type.bit_offset.should eql 18
        type.bit_size.should eql 14
        type.overflow.should eql :TRUNCATE
        type = p.get_item("CCSDSLENGTH")
        type.bit_offset.should eql 32
        type.bit_size.should eql 16
        type = p.get_item("CCSDSDATA")
        type.bit_offset.should eql 48
        type.bit_size.should eql 0 # fill the packet
      end
    end
  end
end

