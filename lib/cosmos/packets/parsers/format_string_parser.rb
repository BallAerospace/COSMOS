# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  class FormatStringParser
    # @param parser [ConfigParser] Configuration parser
    # @param item [Packet] The current item
    def self.parse(parser, item)
      raise parser.error("Items with STATES can not define FORMAT_STRING") if item.states
      @parser = FormatStringParser.new(parser)
      @parser.verify_parameters()
      @parser.create_format_string(item)
    end

    # @param parser [ConfigParser] Configuration parser
    def initialize(parser)
      @parser = parser
    end

    def verify_parameters
      @usage = "FORMAT_STRING <PRINTF STYLE STRING>"
      @parser.verify_num_parameters(1, 1, @usage)
    end

    # @param item [PacketItem] The item the limits response should be added to
    def create_format_string(item)
      item.format_string = @parser.parameters[0]
      # Only test the format string if there is not a read conversion because
      # read conversion can return any type
      test_format_string(item) unless item.read_conversion
    end

    private

    def test_format_string(item)
      case item.data_type
      when :INT, :UINT
        sprintf(item.format_string, 0)
      when :FLOAT
        sprintf(item.format_string, 0.0)
      when :STRING, :BLOCK
        sprintf(item.format_string, 'Hello')
      else
        # Nothing to do
      end
    rescue Exception
      raise @parser.error("Invalid FORMAT_STRING specified for type #{item.data_type}: #{@parser.parameters[0]}", @usage)
    end

  end
end # module Cosmos
