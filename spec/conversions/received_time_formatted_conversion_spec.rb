# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/conversions/received_time_formatted_conversion'
require 'cosmos/packets/packet'

module Cosmos

  describe ReceivedTimeFormattedConversion do

    describe "initialize" do
      it "should initialize converted_type and converted_bit_size" do
        gc = ReceivedTimeFormattedConversion.new()
        gc.converted_type.should eql :STRING
        gc.converted_bit_size.should eql 0
      end
    end

    describe "call" do
      it "should return the formatted packet time" do
        gc = ReceivedTimeFormattedConversion.new()
        packet = Packet.new("TGT","PKT")
        packet.received_time = Time.new(2020,1,31,12,15,30)
        gc.call(nil,packet,nil).should eql "2020/01/31 12:15:30.000"
      end

      it "should return a string if packet time isn't set" do
        gc = ReceivedTimeFormattedConversion.new()
        packet = Packet.new("TGT","PKT")
        gc.call(nil,packet,nil).should eql "No Packet Received Time"
      end
    end

    describe "to_s" do
      it "should return the class" do
        ReceivedTimeFormattedConversion.new().to_s.should eql "ReceivedTimeFormattedConversion"
      end
    end
  end
end

