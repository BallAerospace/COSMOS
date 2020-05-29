# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/conversions/conversion'
require 'cosmos/ext/polynomial_conversion' if RUBY_ENGINE == 'ruby' and !ENV['COSMOS_NO_EXT']

module Cosmos

  # Performs a polynomial conversion on the value
  class PolynomialConversion < Conversion

    # @return [Array<Float>] The polynomial coefficients
    attr_accessor :coeffs

    # Initializes the conversion with the given polynomial coefficients. Sets
    # the converted_type to :FLOAT and the converted_bit_size to 64.
    #
    # @param coeff_array [Array<Float>] The polynomial coefficients
    def initialize(coeff_array)
      super()
      @coeffs = []
      coeff_array.each do |coeff|
        @coeffs << coeff.to_f
      end
      @converted_type = :FLOAT
      @converted_bit_size = 64
    end

    if RUBY_ENGINE != 'ruby' or ENV['COSMOS_NO_EXT']
      # @param (see Conversion#call)
      # @return [Float] The value with the polynomial applied
      def call(value, myself, buffer)
        value = value.to_f

        # Handle C0
        result = @coeffs[0]

        # Handle Coefficients raised to a power
        raised_to_power = 1.0
        @coeffs[1..-1].each do |coeff|
          raised_to_power *= value
          result += (coeff * raised_to_power)
        end

        return result
      end
    end

    # @return [String] Class followed by the list of coefficients
    def to_s
      result = ""
      @coeffs.length.times do |index|
        if index == 0
          result << "#{@coeffs[index]}"
        elsif index == 1
          result << " + #{@coeffs[index]}x"
        else
          result << " + #{@coeffs[index]}x^#{index}"
        end
      end
      result
    end

    # @param (see Conversion#to_config)
    # @return [String] Config fragment for this conversion
    def to_config(read_or_write)
      "    POLY_#{read_or_write}_CONVERSION #{@coeffs.join(' ')}\n"
    end

    def as_json
      { 'class' => self.class.name.to_s, 'params' => @coeffs }
    end

  end # class PolynomialConversion

end # module Cosmos
