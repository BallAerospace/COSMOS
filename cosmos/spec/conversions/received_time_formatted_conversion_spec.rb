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
require 'cosmos/conversions/received_time_formatted_conversion'
require 'cosmos/packets/packet'

module Cosmos

  describe ReceivedTimeFormattedConversion do

    describe "initialize" do
      it "initializes converted_type and converted_bit_size" do
        gc = ReceivedTimeFormattedConversion.new()
        expect(gc.converted_type).to eql :STRING
        expect(gc.converted_bit_size).to eql 0
      end
    end

    describe "call" do
      it "returns the formatted packet time" do
        gc = ReceivedTimeFormattedConversion.new()
        packet = Packet.new("TGT","PKT")
        packet.received_time = Time.new(2020,1,31,12,15,30)
        expect(gc.call(nil,packet,nil)).to eql "2020/01/31 12:15:30.000"
      end

      it "returns a string if packet time isn't set" do
        gc = ReceivedTimeFormattedConversion.new()
        packet = Packet.new("TGT","PKT")
        expect(gc.call(nil,packet,nil)).to eql "No Packet Received Time"
      end
    end

    describe "to_s" do
      it "returns the class" do
        expect(ReceivedTimeFormattedConversion.new().to_s).to eql "ReceivedTimeFormattedConversion"
      end
    end
  end
end
