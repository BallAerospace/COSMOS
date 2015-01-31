# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  class CmdTlmParser
    def self.get_data_type(parser, index)
      parser.parameters[index].upcase.to_sym
    end

    def self.get_id_value(parser, index)
      data_type = get_data_type(parser, index)
      id_value = nil
      if parser.keyword.include?('ID_PARAMETER')
        if data_type == :DERIVED
          raise "DERIVED data type not allowed"
        elsif data_type == :STRING or data_type == :BLOCK
          id_value = parser.parameters[index+1]
        else
          id_value = parser.parameters[index+3]
        end
      end
      return id_value
    end

    def self.get_endianness(params, usage, current_packet)
      max_options = usage.count("<")
      if params[max_options-1]
        endianness = params[max_options-1].to_s.upcase.intern
        if endianness != :BIG_ENDIAN and endianness != :LITTLE_ENDIAN
          raise parser.error("Invalid endianness #{params[2]}. Must be BIG_ENDIAN or LITTLE_ENDIAN.", usage)
        end
      else
        endianness = current_packet.default_endianness
      end
      endianness
    end

    # There are many different usages of the ITEM keyword so parse the keyword
    # and parameters to generate the correct usage information.
    def self.get_usage(parser)
      keyword = parser.keyword
      params = parser.parameters
      usage = "#{keyword} <ITEM NAME> "
      usage << "<BIT OFFSET> " unless keyword.include?("APPEND")
      if keyword.include?("ARRAY")
        usage << "<ARRAY ITEM BIT SIZE> "
      else
        usage << "<BIT SIZE> "
      end
      if keyword.include?("PARAMETER")
        if keyword.include?("ARRAY")
          usage << "<TYPE: INT/UINT/FLOAT/STRING/BLOCK> "
        else
          if keyword.include?("APPEND")
            data_type = params[2].upcase.to_sym
          else
            data_type = params[3].upcase.to_sym
          end
          if data_type == :STRING or data_type == :BLOCK
            if keyword.include?("ID")
              usage << "<TYPE: STRING/BLOCK> "
            else
              usage << "<TYPE: STRING/BLOCK> <DEFAULT VALUE>"
            end
          else
            if keyword.include?("ID")
              usage << "<TYPE: INT/UINT/FLOAT> <MIN VALUE> <MAX VALUE> "
            else
              usage << "<TYPE: INT/UINT/FLOAT/DERIVED> <MIN VALUE> <MAX VALUE> <DEFAULT VALUE>"
            end
          end
        end
      else
        usage << "<TYPE: INT/UINT/FLOAT/STRING/BLOCK/DERIVED> "
      end
      usage << "<TOTAL ARRAY BIT SIZE> " if keyword.include?("ARRAY")
      if keyword.include?("ID")
        if keyword.include?("PARAMETER")
          usage << "<DEFAULT AND ID VALUE> "
        else
          usage << "<ID VALUE> "
        end
      end
      usage << "<DESCRIPTION (Optional)> <ENDIANNESS (Optional)>"
      return usage
    end

  end
end # module Cosmos
