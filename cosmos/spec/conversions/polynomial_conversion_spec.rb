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
require 'cosmos/conversions/polynomial_conversion'

module Cosmos
  describe PolynomialConversion, no_ext: true do
    describe "initialize" do
      it "takes a coefficents array" do
        gc = PolynomialConversion.new([1, 2, 3])
        expect(gc.converted_type).to eql :FLOAT
        expect(gc.converted_bit_size).to eql 64
      end
    end

    describe "call" do
      it "calls the code to eval and return the result" do
        gc = PolynomialConversion.new([1, 2, 3])
        expect(gc.call(1, nil, nil)).to eql 6.0
      end
    end

    describe "to_s" do
      it "returns the equation" do
        expect(PolynomialConversion.new([1, 2, 3]).to_s).to eql "1.0 + 2.0x + 3.0x^2"
      end
    end
  end
end
