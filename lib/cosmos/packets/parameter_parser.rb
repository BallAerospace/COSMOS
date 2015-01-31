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

  class ParameterParser < CmdTlmParser
    def self.parse(parser, current_packet, current_cmd_or_tlm)
      usage = get_usage(parser)
      raise parser.error("PARAMETER types are only valid with COMMAND", usage) if current_cmd_or_tlm == 'Telemetry'
      max_options = usage.count("<")
      parser.verify_num_parameters(max_options-2, max_options, usage)

      keyword = parser.keyword
      params = parser.parameters
      endianness = get_endianness(params, usage, current_packet)
      index = 3
      index -= 1 if parser.keyword.include?("APPEND")
      array_size = (keyword.include?('ARRAY_PARAMETER')) ? Integer(params[index+1]) : nil
      parameter = nil

      # define_item and append_item can throw errors we want to wrap in a parser error
      begin
        if index == 3
          parameter = current_packet.define_item(params[0], # name
                                             Integer(params[1]), # bit offset
                                             Integer(params[2]), # bit size
                                             get_data_type(parser, index), # data_type
                                             array_size, # array size
                                             endianness, # endianness
                                             :ERROR, # overflow
                                             nil, # format string
                                             nil, # read conversion
                                             nil, # write conversion
                                             get_id_value(parser, index)) # id value
        else
          parameter = current_packet.append_item(params[0], # name
                                             Integer(params[1]), # bit size
                                             get_data_type(parser, index), # data_type
                                             array_size, # array size
                                             endianness, # endianness
                                             :ERROR, # overflow
                                             nil, # format string
                                             nil, # read conversion
                                             nil, # write conversion
                                             get_id_value(parser, index)) # id value
        end
      rescue => err
        raise parser.error(err, usage)
      end

      finish_parameter(parser, parameter)
      parameter.description = parser.parameters[max_options-2] if parser.parameters[max_options-2]
      parameter
    end

    def self.finish_parameter(parser, parameter)
      params = parser.parameters
      if parser.keyword.include?('ARRAY')
        parameter.default = []
      else
        params_index = 3
        params_index -= 1 if parser.keyword.include?("APPEND")
        data_type = params[params_index].upcase.to_sym

        if data_type == :STRING or data_type == :BLOCK
          parameter.default = params[params_index+1]
        else
          parameter.range =
            (ConfigParser.handle_defined_constants(params[params_index+1].convert_to_value))..(ConfigParser.handle_defined_constants(params[params_index+2].convert_to_value))
          parameter.default = ConfigParser.handle_defined_constants(params[params_index+3].convert_to_value)
        end
      end
    end

  end
end # module Cosmos
