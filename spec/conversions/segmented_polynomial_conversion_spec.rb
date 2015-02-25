# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/conversions/segmented_polynomial_conversion'

module Cosmos

  describe SegmentedPolynomialConversion do

    describe "initialize" do
      it "initializes converted_type and converted_bit_size" do
        gc = SegmentedPolynomialConversion.new()
        gc.converted_type.should eql :FLOAT
        gc.converted_bit_size.should eql 64
      end
    end

    describe "call" do
      it "performs the conversion and return the result" do
        gc = SegmentedPolynomialConversion.new()
        gc.add_segment(10, 1,2)
        gc.add_segment(5,  2,2)
        gc.add_segment(15, 3,2)
        gc.call(1,nil,nil).should eql 4.0
        gc.call(5,nil,nil).should eql 12.0
        gc.call(11,nil,nil).should eql 23.0
        gc.call(20,nil,nil).should eql 43.0
      end
    end

    describe "to_s" do
      it "returns the equations" do
        SegmentedPolynomialConversion.new().to_s.should eql ""
        gc = SegmentedPolynomialConversion.new()
        gc.add_segment(10, 1)
        gc.add_segment(5,  2,2)
        gc.add_segment(15, 3,2,3)
        gc.to_s.should eql "Lower Bound: 15 Polynomial: 3 + 2x + 3x^2\nLower Bound: 10 Polynomial: 1\nLower Bound: 5 Polynomial: 2 + 2x"
      end
    end
  end
end

