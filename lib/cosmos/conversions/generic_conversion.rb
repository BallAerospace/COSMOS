# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/conversions/conversion'
require 'cosmos/packets/binary_accessor'

module Cosmos

  # Performs a generic conversion by evaluating Ruby code
  class GenericConversion < Conversion

    # @return [String] The Ruby code to evaluate which should return the
    #   converted value
    attr_accessor :code_to_eval

    # @param code_to_eval [String] The Ruby code to evaluate which should
    #   return the converted value
    # @param converted_type [Symbol] The converted data type. Must be one of
    #   {BinaryAccessor::DATA_TYPES}
    # @param converted_bit_size [Integer] The size in bits of the converted
    #   value
    def initialize(code_to_eval, converted_type = nil, converted_bit_size = nil)
      super()
      @code_to_eval = code_to_eval
      if ConfigParser.handle_nil(converted_type)
        converted_type = converted_type.to_s.upcase.intern
        raise "Invalid type #{converted_type}" unless BinaryAccessor::DATA_TYPES.include?(converted_type)
        @converted_type = converted_type
      end
      @converted_bit_size = Integer(converted_bit_size) if ConfigParser.handle_nil(converted_bit_size)
    end

    # (see Cosmos::Conversion#call)
    def call(value, packet, buffer)
      myself = packet # For backwards compatibility
      if true or myself # Remove unused variable warning for myself
        return eval(@code_to_eval)
      end
    end

    # @return [String] The conversion class followed by the code to evaluate
    def to_s
      "#{@code_to_eval}"
    end

    # @param (see Conversion#to_config)
    # @return [String] Config fragment for this conversion
    def to_config(read_or_write)
      config = "    GENERIC_#{read_or_write}_CONVERSION_START"
      config << " #{@converted_type}" if @converted_type
      config << " #{@converted_bit_size}" if @converted_bit_size
      config << "\n"
      config << @code_to_eval
      config << "    GENERIC_#{read_or_write}_CONVERSION_END\n"
      config
    end

  end # class GenericConversion

end # module Cosmos
