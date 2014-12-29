# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/ext/cosmos_io'

# COSMOS specific additions to the Ruby IO and StringIO classes
module CosmosIO
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
  # def read_length_bytes(length_num_bytes)
end
