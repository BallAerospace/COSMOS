# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/conversions/received_time_seconds_conversion'
require 'cosmos/packets/packet'

module Cosmos

  describe ReceivedTimeSecondsConversion do

    describe "initialize" do
      it "should initialize converted_type and converted_bit_size" do
        gc = ReceivedTimeSecondsConversion.new()
        gc.converted_type.should eql :FLOAT
        gc.converted_bit_size.should eql 64
      end
    end

    describe "call" do
      it "should return the formatted packet time" do
        gc = ReceivedTimeSecondsConversion.new()
        packet = Packet.new("TGT","PKT")
        time = Time.new(2020,1,31,12,15,30)
        packet.received_time = time
        gc.call(nil,packet,nil).should eql time.to_f
      end

      it "should return 0.0 if packet time isn't set" do
        gc = ReceivedTimeSecondsConversion.new()
        packet = Packet.new("TGT","PKT")
        gc.call(nil,packet,nil).should eql 0.0
      end
    end

    describe "to_s" do
      it "should return the class" do
        ReceivedTimeSecondsConversion.new().to_s.should eql "ReceivedTimeSecondsConversion"
      end
    end
  end
end

