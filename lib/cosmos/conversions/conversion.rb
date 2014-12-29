# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  # Performs a general conversion via the implementation of the call method
  class Conversion

    # @return [Symbol] The converted data type. Must be one of
    #   {Cosmos::StructureItem#data_type}
    attr_reader :converted_type
    # @return [Integer] The size in bits of the converted value
    attr_reader :converted_bit_size

    # Create a new conversion
    def initialize
      @converted_type = nil
      @converted_bit_size = nil
    end

    # Perform the conversion on the value.
    #
    # @param value [Object] The value to convert
    # @param packet [Packet] The packet which contains the value. This can
    #   be useful to reach into the packet and use other values in the
    #   conversion.
    # @param buffer [String] The packet buffer
    # @return The converted value
    def call(value, packet, buffer)
      raise "call method must be defined by subclass"
    end

    # @return [String] The conversion class
    def to_s
      self.class.to_s.split('::')[-1]
    end

  end # class Conversion

end # module Cosmos
