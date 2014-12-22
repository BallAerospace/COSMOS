# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/conversions/processor_conversion'

module Cosmos

  describe PolynomialConversion do

    describe "initialize" do
      it "should take processor_name, result_name, converted_type, and converted_bit_size" do
        c = ProcessorConversion.new('TEST', 'TEST', 'FLOAT', '64')
        c.instance_variable_get("@processor_name").should eql 'TEST'
        c.instance_variable_get("@result_name").should eql :TEST
        c.converted_type.should eql :FLOAT
        c.converted_bit_size.should eql 64
      end
    end

    describe "call" do
      it "should retrieve the result from the processor" do
        c = ProcessorConversion.new('TEST', 'TEST', 'FLOAT', '64')
        packet = Packet.new("tgt","pkt")
        packet.append_item('ITEM1', 64, :FLOAT)
        packet.processors['TEST'] = double("processor", :results => {:TEST => 6.0})
        c.call(1,packet,nil).should eql 6.0
      end
    end

    describe "to_s" do
      it "should return the equation" do
        ProcessorConversion.new('TEST1', 'TEST2', 'FLOAT', '64').to_s.should eql "ProcessorConversion TEST1 TEST2"
      end
    end
  end
end

