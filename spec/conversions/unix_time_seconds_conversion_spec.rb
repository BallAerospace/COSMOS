# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/conversions/unix_time_seconds_conversion'
require 'cosmos/packets/packet'

module Cosmos

  describe UnixTimeSecondsConversion do

    describe "initialize" do
      it "initializes converted_type and converted_bit_size" do
        gc = UnixTimeSecondsConversion.new('TIME')
        expect(gc.converted_type).to eql :FLOAT
        expect(gc.converted_bit_size).to eql 64
      end
    end

    describe "call" do
      it "returns the formatted packet time based on seconds" do
        gc = UnixTimeSecondsConversion.new('TIME')
        packet = Packet.new("TGT","PKT")
        packet.append_item("TIME",32,:UINT)
        time = Time.new(2020,1,31,12,15,30).to_f
        packet.write("TIME",time)
        expect(gc.call(nil,packet,packet.buffer)).to eql time
      end

      it "returns the formatted packet time based on seconds and microseconds" do
        gc = UnixTimeSecondsConversion.new('TIME','TIME_US')
        packet = Packet.new("TGT","PKT")
        packet.append_item("TIME",32,:UINT)
        time = Time.new(2020,1,31,12,15,30).to_f
        packet.write("TIME",time)
        packet.append_item("TIME_US",32,:UINT)
        packet.write("TIME_US",500000)
        expect(gc.call(nil,packet,packet.buffer)).to eql time + 0.5
      end

      it "complains if the seconds item doesn't exist" do
        gc = UnixTimeSecondsConversion.new('TIME')
        packet = Packet.new("TGT","PKT")
        expect { gc.call(nil,packet,packet.buffer) }.to raise_error("Packet item 'TGT PKT TIME' does not exist")
      end

      it "complains if the microseconds item doesn't exist" do
        gc = UnixTimeSecondsConversion.new('TIME','TIME_US')
        packet = Packet.new("TGT","PKT")
        packet.append_item("TIME",32,:UINT)
        expect { gc.call(nil,packet,packet.buffer) }.to raise_error("Packet item 'TGT PKT TIME_US' does not exist")
      end

    end

    describe "to_s" do
      it "returns the seconds conversion" do
        gc = UnixTimeSecondsConversion.new('TIME')
        expect(gc.to_s).to eql "Time.at(packet.read('TIME', :RAW, buffer), 0).to_f"
      end

      it "returns the microseconds conversion" do
        gc = UnixTimeSecondsConversion.new('TIME','TIME_US')
        expect(gc.to_s).to eql "Time.at(packet.read('TIME', :RAW, buffer), packet.read('TIME_US', :RAW, buffer)).to_f"
      end
    end
  end
end

