# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/conversions/received_count_conversion'
require 'cosmos/packets/packet'

module Cosmos

  describe ReceivedCountConversion do

    describe "initialize" do
      it "should initialize converted_type and converted_bit_size" do
        gc = ReceivedCountConversion.new()
        gc.converted_type.should eql :UINT
        gc.converted_bit_size.should eql 32
      end
    end

    describe "call" do
      it "should call the code to eval and return the result" do
        gc = ReceivedCountConversion.new()
        packet = Packet.new("TGT","PKT")
        packet.received_count = 100
        gc.call(nil,packet,nil).should eql 100
      end
    end

    describe "to_s" do
      it "should return the class" do
        ReceivedCountConversion.new().to_s.should eql "ReceivedCountConversion"
      end
    end
  end
end

