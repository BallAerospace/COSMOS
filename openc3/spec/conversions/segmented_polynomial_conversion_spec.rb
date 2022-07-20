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
require 'openc3/conversions/segmented_polynomial_conversion'

module OpenC3
  describe SegmentedPolynomialConversion do
    describe "initialize" do
      it "initializes converted_type and converted_bit_size" do
        gc = SegmentedPolynomialConversion.new()
        expect(gc.converted_type).to eql :FLOAT
        expect(gc.converted_bit_size).to eql 64
      end
    end

    describe "call" do
      it "performs the conversion and return the result" do
        gc = SegmentedPolynomialConversion.new()
        gc.add_segment(10, 1, 2)
        gc.add_segment(5,  2, 2)
        gc.add_segment(15, 3, 2)
        expect(gc.call(1, nil, nil)).to eql 4.0
        expect(gc.call(5, nil, nil)).to eql 12.0
        expect(gc.call(11, nil, nil)).to eql 23.0
        expect(gc.call(20, nil, nil)).to eql 43.0
      end
    end

    describe "to_s" do
      it "returns the equations" do
        expect(SegmentedPolynomialConversion.new().to_s).to eql ""
        gc = SegmentedPolynomialConversion.new()
        gc.add_segment(10, 1)
        gc.add_segment(5,  2, 2)
        gc.add_segment(15, 3, 2, 3)
        expect(gc.to_s).to eql "Lower Bound: 15 Polynomial: 3 + 2x + 3x^2\nLower Bound: 10 Polynomial: 1\nLower Bound: 5 Polynomial: 2 + 2x"
      end
    end

    describe "as_json" do
      it "creates a reproducable format" do
        spc = SegmentedPolynomialConversion.new()
        spc.add_segment(10, 1, 2)
        spc.add_segment(5,  2, 2)
        spc.add_segment(15, 3, 2)
        json = spc.as_json(:allow_nan => true)
        expect(json['class']).to eql "OpenC3::SegmentedPolynomialConversion"
        new_spc = OpenC3::const_get(json['class']).new(*json['params'])
        spc.segments.each_with_index do |segment, index|
          expect(segment).to be == new_spc.segments[index]
        end
        expect(spc.converted_type).to eql (new_spc.converted_type)
        expect(spc.converted_bit_size).to eql (new_spc.converted_bit_size)
        expect(spc.converted_array_size).to eql (new_spc.converted_array_size)
        expect(spc.call(1, nil, nil)).to eql new_spc.call(1, nil, nil)
        expect(spc.call(5, nil, nil)).to eql new_spc.call(5, nil, nil)
        expect(spc.call(11, nil, nil)).to eql new_spc.call(11, nil, nil)
        expect(spc.call(20, nil, nil)).to eql new_spc.call(20, nil, nil)
      end
    end
  end
end
