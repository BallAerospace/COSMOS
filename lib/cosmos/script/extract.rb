# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  module Extract
    SCANNING_REGULAR_EXPRESSION = %r{ (?:"(?:[^\\"]|\\.)*") | (?:'(?:[^\\']|\\.)*') | (?:\[(?:[^\\\[\]]|\\.)*\]) | \S+ }x #"

    private

    def add_cmd_parameter(keyword, value, cmd_params)
      quotes_removed = value.remove_quotes
      if value == quotes_removed
        cmd_params[keyword] = value.convert_to_value
      else
        cmd_params[keyword] = quotes_removed
      end
    end

    def extract_fields_from_cmd_text(text)
      split_string = text.split(/\s+with\s+/i, 2)
      raise "ERROR: text must not be empty" if split_string.length == 0
      raise "ERROR: 'with' must be followed by parameters : #{text}" if (split_string.length == 1 and text =~ /\s*with\s*/i) or (split_string.length == 2 and split_string[1].empty?)

      # Extract target_name and cmd_name
      first_half = split_string[0].split
      raise "ERROR: Both Target Name and Command Name must be given : #{text}" if first_half.length < 2
      raise "ERROR: Only Target Name and Command Name must be given before 'with' : #{text}" if first_half.length > 2
      target_name = first_half[0]
      cmd_name = first_half[1]
      cmd_params = {}

      if split_string.length == 2
        # Extract Command Parameters
        second_half = split_string[1].scan(SCANNING_REGULAR_EXPRESSION)
        keyword = nil
        value = nil
        comma = nil
        second_half.each do |item|
          unless keyword
            keyword = item
            next
          end
          unless value
            if item[-1..-1] == ','
              value = item[0..-2]
              comma = true
            else
              value = item
              next
            end
          end
          unless comma
            raise "Missing comma in command parameters: #{text}" if item != ','
          end
          add_cmd_parameter(keyword, value, cmd_params)
          keyword = nil
          value = nil
          comma = nil
        end
        if keyword
          if value
            add_cmd_parameter(keyword, value, cmd_params)
          else
            raise "Missing value for last command parameter: #{text}"
          end
        end
      end

      return [target_name, cmd_name, cmd_params]
    end

    def extract_fields_from_tlm_text(text)
      split_string = text.split
      raise "ERROR: Telemetry Item must be specified as 'TargetName PacketName ItemName' : #{text}" if split_string.length != 3
      target_name = split_string[0]
      packet_name = split_string[1]
      item_name = split_string[2]
      return [target_name, packet_name, item_name]
    end

    def extract_fields_from_set_tlm_text(text)
      error_msg = "ERROR: Set Telemetry Item must be specified as 'TargetName PacketName ItemName = Value' : #{text}"
      # We have to handle these cases:
      # set_tlm("TGT PKT ITEM='new item'")
      # set_tlm("TGT PKT ITEM = 'new item'")
      # set_tlm("TGT PKT ITEM= 'new item'")
      # set_tlm("TGT PKT ITEM ='new item'")
      split_string = text.split('=')
      raise error_msg if split_string.length < 2 || split_string[1].strip.empty?
      split_string = split_string[0].strip.split << split_string[1..-1].join('=').strip
      raise error_msg if split_string.length != 4 # Ensure tgt,pkt,item,value
      target_name = split_string[0]
      packet_name = split_string[1]
      item_name = split_string[2]
      value = split_string[3].strip.convert_to_value
      value = value.remove_quotes if String === value
      return [target_name, packet_name, item_name, value]
    end

    def extract_fields_from_check_text(text)
      split_string = text.split
      raise "ERROR: Check improperly specified: #{text}" if split_string.length < 3
      target_name = split_string[0]
      packet_name = split_string[1]
      item_name = split_string[2]
      comparison_to_eval = nil
      return [target_name, packet_name, item_name, comparison_to_eval] if split_string.length == 3
      raise "ERROR: Check improperly specified: #{text}" if split_string.length < 4
      comparison_to_eval = split_string[3..(split_string.length - 1)].join(" ")
      raise "ERROR: Use '==' instead of '=': #{text}" if split_string[3] == '='
      return [target_name, packet_name, item_name, comparison_to_eval]
    end

  end # module Extract

end # module Cosmos
