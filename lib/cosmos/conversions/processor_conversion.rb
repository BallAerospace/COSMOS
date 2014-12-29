# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/conversions/conversion'

module Cosmos

  # Retrieves the result from an item processor
  class ProcessorConversion < Conversion

    # @param processor_name [String] The name of the associated processor
    # @param result_name [String] The name of the associated result in the processor
    # @param converted_type [String or nil] The datatype of the result of the processor
    # @param converted_bit_size [Integer or nil] The bit size of the result of the processor
    def initialize(processor_name, result_name, converted_type = nil, converted_bit_size = nil)
      super()
      @processor_name = processor_name.to_s.upcase
      @result_name = result_name.to_s.upcase.intern
      if ConfigParser.handle_nil(converted_type)
        @converted_type = converted_type.to_s.upcase.intern
        raise ArgumentError, "Unknown converted type: #{converted_type}" if !BinaryAccessor::DATA_TYPES.include?(@converted_type)
      end
      @converted_bit_size = Integer(converted_bit_size) if ConfigParser.handle_nil(converted_bit_size)
    end

    # @param (see Conversion#call)
    # @return [Varies] The result of the associated processor
    def call(value, packet, buffer)
      packet.processors[@processor_name].results[@result_name] || 0 # Never return nil
    end

    # @return [String] The type of processor
    def to_s
      "ProcessorConversion #{@processor_name} #{@result_name}"
    end

  end # class ProcessorConversion

end # module Cosmos
