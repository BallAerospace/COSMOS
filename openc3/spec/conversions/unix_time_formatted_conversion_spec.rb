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
require 'openc3/conversions/unix_time_formatted_conversion'
require 'openc3/packets/packet'

module OpenC3
  describe UnixTimeFormattedConversion do
    describe "initialize" do
      it "initializes converted_type and converted_bit_size" do
        gc = UnixTimeFormattedConversion.new('TIME')
        expect(gc.converted_type).to eql :STRING
        expect(gc.converted_bit_size).to eql 0
      end
    end

    describe "call" do
      it "returns the formatted packet time based on seconds" do
        gc = UnixTimeFormattedConversion.new('TIME')
        packet = Packet.new("TGT", "PKT")
        packet.append_item("TIME", 32, :UINT)
        packet.write("TIME", Time.new(2020, 1, 31, 12, 15, 30).to_f)
        expect(gc.call(nil, packet, packet.buffer)).to eql "2020/01/31 12:15:30.000"
      end

      it "returns the formatted packet time based on seconds and microseconds" do
        gc = UnixTimeFormattedConversion.new('TIME', 'TIME_US')
        packet = Packet.new("TGT", "PKT")
        packet.append_item("TIME", 32, :UINT)
        packet.write("TIME", Time.new(2020, 1, 31, 12, 15, 30).to_f)
        packet.append_item("TIME_US", 32, :UINT)
        packet.write("TIME_US", 500000)
        expect(gc.call(nil, packet, packet.buffer)).to eql "2020/01/31 12:15:30.500"
      end

      it "complains if the seconds item doesn't exist" do
        gc = UnixTimeFormattedConversion.new('TIME')
        packet = Packet.new("TGT", "PKT")
        expect { gc.call(nil, packet, packet.buffer) }.to raise_error("Packet item 'TGT PKT TIME' does not exist")
      end

      it "complains if the microseconds item doesn't exist" do
        gc = UnixTimeFormattedConversion.new('TIME', 'TIME_US')
        packet = Packet.new("TGT", "PKT")
        packet.append_item("TIME", 32, :UINT)
        expect { gc.call(nil, packet, packet.buffer) }.to raise_error("Packet item 'TGT PKT TIME_US' does not exist")
      end
    end

    describe "to_s" do
      it "returns the seconds conversion" do
        gc = UnixTimeFormattedConversion.new('TIME')
        expect(gc.to_s).to eql "Time.at(packet.read('TIME', :RAW, buffer), 0).sys.formatted"
      end

      it "returns the microseconds conversion" do
        gc = UnixTimeFormattedConversion.new('TIME', 'TIME_US')
        expect(gc.to_s).to eql "Time.at(packet.read('TIME', :RAW, buffer), packet.read('TIME_US', :RAW, buffer)).sys.formatted"
      end
    end
  end
end
