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

module OpenC3
  # Performs a general conversion via the implementation of the call method
  class Conversion
    # @return [Symbol] The converted data type. Must be one of
    #   {OpenC3::StructureItem#data_type}
    attr_reader :converted_type
    # @return [Integer] The size in bits of the converted value
    attr_reader :converted_bit_size
    # @return [Integer] The size in bits of the converted array value
    attr_reader :converted_array_size

    # Create a new conversion
    def initialize
      @converted_type = nil
      @converted_bit_size = nil
      @converted_array_size = nil
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

    # @param read_or_write [String] Either 'READ' or 'WRITE'
    # @return [String] Config fragment for this conversion
    def to_config(read_or_write)
      "    #{read_or_write}_CONVERSION #{self.class.name.class_name_to_filename}\n"
    end

    def as_json(*a)
      { 'class' => self.class.name.to_s }
    end
  end
end
