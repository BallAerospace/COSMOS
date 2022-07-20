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
require 'openc3/conversions/generic_conversion'

module OpenC3
  describe GenericConversion do
    describe "initialize" do
      it "takes code_to_eval, converted_type and converted_bit_size" do
        gc = GenericConversion.new("10 / 2", :UINT, 8)
        expect(gc.code_to_eval).to eql "10 / 2"
        expect(gc.converted_type).to eql :UINT
        expect(gc.converted_bit_size).to eql 8
      end

      it "complains about invalid converted_type" do
        expect { GenericConversion.new("", :MINE, 8) }.to raise_error("Invalid type MINE")
      end
    end

    describe "call" do
      it "calls the code to eval and return the result" do
        gc = GenericConversion.new("10 / 2", :UINT, 8)
        expect(gc.call(0, 0, 0)).to eql 5
      end
    end

    describe "to_s" do
      it "returns the code to eval" do
        expect(GenericConversion.new("10 / 2").to_s).to eql "10 / 2"
      end
    end

    describe "as_json" do
      it "creates a reproducable format" do
        gc = GenericConversion.new("10.0 / 2", "FLOAT", "32")
        json = gc.as_json(:allow_nan => true)
        expect(json['class']).to eql "OpenC3::GenericConversion"
        new_gc = OpenC3::const_get(json['class']).new(*json['params'])
        expect(gc.code_to_eval).to eql (new_gc.code_to_eval)
        expect(gc.converted_type).to eql (new_gc.converted_type)
        expect(gc.converted_bit_size).to eql (new_gc.converted_bit_size)
        expect(gc.converted_array_size).to eql (new_gc.converted_array_size)
        expect(gc.call(0, 0, 0)).to eql 5.0
        expect(new_gc.call(0, 0, 0)).to eql 5.0
      end
    end
  end
end
