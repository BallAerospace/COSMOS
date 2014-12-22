# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/conversions/conversion'

module Cosmos

  # Segmented polynomial conversions consist of polynomial conversions that are
  # applied for a range of values.
  class SegmentedPolynomialConversion < Conversion

    # A polynomial conversion segment which applies the conversion from the
    # lower bound (inclusive) until another segment's lower bound is
    # encountered.
    class Segment
      # @return [Integer] The value at which point this polynomial conversion
      #   should apply. All values >= to this value will be converted using the
      #   given coefficients.
      attr_reader :lower_bound
      # @return [Array<Integer>] The polynomial coefficients
      attr_reader :coeffs

      # Creates a polynomial conversion segment. Multiple Segments are used to
      # implemnt a {SegmentedPolynomialConversion}.
      #
      # @param lower_bound [Integer] The value at which point this polynomial conversion
      #   should apply. All values >= to this value will be converted using the
      #   given coefficients.
      # @param coeffs [Array<Integer>] The polynomial coefficients
      def initialize(lower_bound, coeffs)
        @lower_bound = lower_bound
        @coeffs = coeffs
      end

      # Implement the comparison operator to compared based on the lower_bound
      # but sort in reverse order so the segment with the largest lower_bound
      # comes first. This makes the calculation code in call easier.
      #
      # @param other_segment [Segment] The segment to compare
      # @return [Integer] 1 if self.lower_bound > other_segment.lower_bound, 0
      #   if they are equal, -1 if self.lower_bound < other_segment.lower_bound
      def <=>(other_segment)
        return other_segment.lower_bound <=> @lower_bound
      end

      # Perform the polynomial conversion
      #
      # @param value [Numeric] The value to convert
      # @return [Float] The converted value
      def calculate(value)
        converted = 0.0
        @coeffs.length.times do |index|
          converted += @coeffs[index].to_f * (value ** index)
        end
        return converted
      end
    end

    # Initialize the converted_type to :FLOAT and converted_bit_size to 64.
    def initialize
      @segments = []
      @converted_type = :FLOAT
      @converted_bit_size = 64
    end

    # Add a segment to the segmented polynomial. The lower bound is inclusive, but
    # is ignored for the segment with the lowest lower_bound.
    #
    # @param lower_bound [Integer] The value at which point this polynomial conversion
    #   should apply. All values >= to this value will be converted using the
    #   given coefficients.
    # @param coeffs [Array<Integer>] The polynomial coefficients
    def add_segment(lower_bound, *coeffs)
      @segments << Segment.new(lower_bound, coeffs)
      @segments.sort!
    end

    # @param (see Conversion#call)
    # @return [Float] The value with the polynomial applied
    def call(value, packet, buffer)
      # Try to find correct segment
      @segments.each do |segment|
        if value >= segment.lower_bound
          return segment.calculate(value)
        end
      end

      # Default to using segment with smallest lower_bound
      segment = @segments[-1]
      if segment
        return @segments[-1].calculate(value)
      else
        return nil
      end
    end

    # @return [String] The name of the class followed by a description of all
    #   the polynomial segments.
    def to_s
      result = ""
      count = 0
      @segments.each do |segment|
        result << "\n" if count > 0
        result << "Lower Bound: #{segment.lower_bound} Polynomial: "
        segment.coeffs.length.times do |index|
          if index == 0
            result << "#{segment.coeffs[index]}"
          elsif index == 1
            result << " + #{segment.coeffs[index]}x"
          else
            result << " + #{segment.coeffs[index]}x^#{index}"
          end
        end
        count += 1
      end
      result
    end

  end # class SegmentedPolynomialConversion

end # module Cosmos
