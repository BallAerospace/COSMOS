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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos/conversions/processor_conversion'

module Cosmos
  describe PolynomialConversion do
    describe "initialize" do
      it "takes processor_name, result_name, converted_type, and converted_bit_size" do
        c = ProcessorConversion.new('TEST', 'TEST', 'FLOAT', '64')
        expect(c.instance_variable_get("@processor_name")).to eql 'TEST'
        expect(c.instance_variable_get("@result_name")).to eql :TEST
        expect(c.converted_type).to eql :FLOAT
        expect(c.converted_bit_size).to eql 64
      end
    end

    describe "call" do
      it "retrieves the result from the processor" do
        c = ProcessorConversion.new('TEST', 'TEST', 'FLOAT', '64')
        packet = Packet.new("tgt", "pkt")
        packet.append_item('ITEM1', 64, :FLOAT)
        packet.processors['TEST'] = double("processor", :results => { :TEST => 6.0 })
        expect(c.call(1, packet, nil)).to eql 6.0
      end
    end

    describe "to_s" do
      it "returns the equation" do
        expect(ProcessorConversion.new('TEST1', 'TEST2', 'FLOAT', '64').to_s).to eql "ProcessorConversion TEST1 TEST2"
      end
    end
  end
end
