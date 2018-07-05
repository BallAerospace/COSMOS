# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/conversions/packet_time_formatted_conversion'
require 'cosmos/packets/packet'

module Cosmos

  describe PacketTimeFormattedConversion do

    describe "initialize" do
      it "initializes converted_type and converted_bit_size" do
        gc = PacketTimeFormattedConversion.new()
        expect(gc.converted_type).to eql :STRING
        expect(gc.converted_bit_size).to eql 0
      end
    end

    describe "call" do
      it "returns the formatted packet time" do
        gc = PacketTimeFormattedConversion.new()
        packet = Packet.new("TGT","PKT")
        packet.received_time = Time.new(2020,1,31,12,15,30)
        expect(gc.call(nil,packet,nil)).to eql "2020/01/31 12:15:30.000"
      end

      it "returns the formatted packet time from a packet item" do
        gc = PacketTimeFormattedConversion.new()
        packet = Packet.new("TGT","PKT")
        item = packet.define_item("PACKET_TIME", 0, 0, :DERIVED)
        item.read_conversion = GenericConversion.new("Time.new(2020,1,31,12,15,30)")
        packet.received_time = nil
        expect(gc.call(nil,packet,nil)).to eql "2020/01/31 12:15:30.000"
      end

      it "returns a string if packet time isn't set" do
        gc = PacketTimeFormattedConversion.new()
        packet = Packet.new("TGT","PKT")
        expect(gc.call(nil,packet,nil)).to eql "No Packet Time"
      end
    end

    describe "to_s" do
      it "returns the class" do
        expect(PacketTimeFormattedConversion.new().to_s).to eql "PacketTimeFormattedConversion"
      end
    end
  end
end

