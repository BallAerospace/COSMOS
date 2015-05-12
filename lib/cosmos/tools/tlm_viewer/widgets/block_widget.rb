# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation and BlockWidget class.   This class
# implements the block widget to display block data

require 'cosmos'
require 'cosmos/tools/tlm_viewer/widgets/textbox_widget'

module Cosmos

  class BlockWidget < TextboxWidget

    def initialize (parent_layout, target_name, packet_name, item_name, width = 200, height = 100, format_string = "%02X", bytes_per_word = 4, words_per_row = 4, addr_format = nil, value_type = :RAW)
      super(parent_layout, target_name, packet_name, item_name, width, height, value_type)
      @format_string = format_string.to_s
      @bytes_per_word = bytes_per_word.to_i
      @words_per_row  = words_per_row.to_i
      @bytes_per_row  = @bytes_per_word * @words_per_row
      @addr_format = ConfigParser.handle_nil(addr_format)
      @addr_format << ' ' if @addr_format
      setFont(Cosmos.get_default_font)
    end

    def format_value(data)
      text = ""
      space = ' '
      new_line = "\n"

      byte_count = 0
      addr       = 0
      data.each_byte do |value|
        if @addr_format and byte_count == 0
          text << sprintf(@addr_format, addr)
          addr += @bytes_per_row
        end
        text << sprintf(@format_string, value)
        byte_count += 1
        if (byte_count % @bytes_per_row) == 0
          byte_count = 0
          text << new_line
        elsif (byte_count % @bytes_per_word) == 0
          text << space
        end
      end
      text
    end
  end

end # module Cosmos
