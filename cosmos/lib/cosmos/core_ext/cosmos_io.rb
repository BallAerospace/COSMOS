# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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

require 'cosmos/packets/binary_accessor'
require 'cosmos/ext/cosmos_io' if RUBY_ENGINE == 'ruby' and !ENV['COSMOS_NO_EXT']

# COSMOS specific additions to the Ruby IO and StringIO classes
module CosmosIO
  if RUBY_ENGINE != 'ruby' or ENV['COSMOS_NO_EXT']
    # Reads a length field and then return the String resulting from reading the
    # number of bytes the length field indicates
    #
    # For example:
    #   io = StringIO.new
    #   # where io is "\x02\x01\x02\x03\x04...."
    #   result = io.read_length_bytes(1)
    #   # result will be "\x01x02" because the length field was given
    #   # to be 1 byte. We read 1 byte which is a 2. So we then read two
    #   # bytes and return.
    #
    # @param length_num_bytes [Integer] Number of bytes in the length field
    # @return [String] A String of "length field" number of bytes
    def read_length_bytes(length_num_bytes, max_read_size = nil)
      return nil unless (length_num_bytes == 1) || (length_num_bytes == 2) or (length_num_bytes == 4)

      # Read bytes for string length
      temp_string_length = self.read(length_num_bytes)
      return nil if (temp_string_length.nil?) || (temp_string_length.length != length_num_bytes)

      string_length = Cosmos::BinaryAccessor.read(0, length_num_bytes * 8, :UINT, temp_string_length, :BIG_ENDIAN)

      # Read String
      return nil if max_read_size and string_length > max_read_size

      string = self.read(string_length)
      return nil if (string.nil?) || (string.length != string_length)

      return string
    end
  end
end
