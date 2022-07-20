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
require 'openc3/conversions/polynomial_conversion'

module OpenC3
  describe PolynomialConversion, no_ext: true do
    describe 'initialize' do
      it 'takes a coefficents array' do
        gc = PolynomialConversion.new(1, 2, 3)
        expect(gc.converted_type).to eql :FLOAT
        expect(gc.converted_bit_size).to eql 64
      end
    end

    describe 'call' do
      it 'calls the code to eval and return the result' do
        gc = PolynomialConversion.new(1, 2, 3)
        expect(gc.call(1, nil, nil)).to eql 6.0
      end
    end

    describe 'to_s' do
      it 'returns the equation' do
        expect(
          PolynomialConversion.new(1, 2, 3).to_s,
        ).to eql '1.0 + 2.0x + 3.0x^2'
      end
    end

    describe 'as_json' do
      it 'creates a reproducable format' do
        pc = PolynomialConversion.new(1, 2, 3)
        json = pc.as_json(:allow_nan => true)
        expect(json['class']).to eql 'OpenC3::PolynomialConversion'
        new_pc = OpenC3.const_get(json['class']).new(*json['params'])
        expect(pc.coeffs).to eql (new_pc.coeffs)
        expect(pc.converted_type).to eql (new_pc.converted_type)
        expect(pc.converted_bit_size).to eql (new_pc.converted_bit_size)
        expect(pc.converted_array_size).to eql (new_pc.converted_array_size)
        expect(pc.call(1, nil, nil)).to eql 6.0
        expect(new_pc.call(1, nil, nil)).to eql 6.0
      end
    end
  end
end
