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

require 'spec_helper'
require 'cosmos/conversions/packet_time_seconds_conversion'
require 'cosmos/packets/packet'

module Cosmos

  describe PacketTimeSecondsConversion do

    describe "initialize" do
      it "initializes converted_type and converted_bit_size" do
        gc = PacketTimeSecondsConversion.new()
        expect(gc.converted_type).to eql :FLOAT
        expect(gc.converted_bit_size).to eql 64
      end
    end

    describe "call" do
      it "returns the formatted packet time" do
        gc = PacketTimeSecondsConversion.new()
        packet = Packet.new("TGT","PKT")
        time = Time.new(2020,1,31,12,15,30)
        packet.received_time = time
        expect(gc.call(nil,packet,nil)).to eql time.to_f
      end

      it "returns the formatted packet time from a packet item" do
        gc = PacketTimeSecondsConversion.new()
        packet = Packet.new("TGT","PKT")
        item = packet.define_item("PACKET_TIME", 0, 0, :DERIVED)
        time = Time.new(2020,1,31,12,15,30)
        item.read_conversion = GenericConversion.new("Time.new(2020,1,31,12,15,30)")
        packet.received_time = nil
        expect(gc.call(nil,packet,nil)).to eql time.to_f
      end

      it "returns 0.0 if packet time isn't set" do
        gc = PacketTimeSecondsConversion.new()
        packet = Packet.new("TGT","PKT")
        expect(gc.call(nil,packet,nil)).to eql 0.0
      end
    end

    describe "to_s" do
      it "returns the class" do
        expect(PacketTimeSecondsConversion.new().to_s).to eql "PacketTimeSecondsConversion"
      end
    end
  end
end
