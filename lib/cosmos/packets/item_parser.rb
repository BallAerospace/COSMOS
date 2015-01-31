# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packets/cmd_tlm_parser'

module Cosmos

  class ItemParser < CmdTlmParser
    def self.parse(parser, current_packet, current_cmd_or_tlm)
      usage = get_usage(parser)
      raise parser.error("ITEM types are only valid with TELEMETRY", usage) if current_cmd_or_tlm == 'Command'
      max_options = usage.count("<")
      parser.verify_num_parameters(max_options-2, max_options, usage)
      # If this is an APPEND we don't have a bit offset so the index
      # into the parameters changes
      begin
      params = parser.parameters
      index = (parser.keyword =~ /APPEND/) ? 3 : 4
      id_value = (parser.keyword =~ /ID_ITEM/) ? params[index] : nil
      array_size = (parser.keyword =~ /ARRAY_ITEM/) ? Integer(params[index]) : nil
      endianness = get_endianness(params, usage, current_packet)
      current_item = nil
      case parser.keyword
      when 'ITEM',  'ID_ITEM', 'ARRAY_ITEM'
        current_item = current_packet.define_item(params[0], # name
                                           Integer(params[1]), # bit offset
                                           Integer(params[2]), # bit size
                                           params[3].upcase.to_sym, # data_type
                                           array_size, # array size
                                           endianness, # endianness
                                           :ERROR, # overflow
                                           nil, # format string
                                           nil, # read conversion
                                           nil, # write conversion
                                           id_value) # id value
      when 'APPEND_ITEM', 'APPEND_ID_ITEM', 'APPEND_ARRAY_ITEM'
        current_item = current_packet.append_item(params[0], # name
                                           Integer(params[1]), # bit size
                                           params[2].upcase.to_sym, # data_type
                                           array_size, # array size
                                           endianness, # endianness
                                           :ERROR, # overflow
                                           nil, # format string
                                           nil, # read conversion
                                           nil, # write conversion
                                           id_value) # id value
      end
      current_item.description = parser.parameters[max_options-2] if parser.parameters[max_options-2]
      current_item
      rescue => err
        raise parser.error(err, usage)
      end
    end

  end
end # module Cosmos
