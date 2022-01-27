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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

module Cosmos
  class LimitsResponseParser
    # @param parser [ConfigParser] Configuration parser
    # @param item [Packet] The current item
    # @param cmd_or_tlm [String] Whether this is a command or telemetry packet
    def self.parse(parser, item, cmd_or_tlm)
      @parser = LimitsResponseParser.new(parser)
      @parser.verify_parameters(cmd_or_tlm)
      @parser.create_limits_response(item)
    end

    # @param parser [ConfigParser] Configuration parser
    def initialize(parser)
      @parser = parser
    end

    # @param cmd_or_tlm [String] Whether this is a command or telemetry packet
    def verify_parameters(cmd_or_tlm)
      if cmd_or_tlm == PacketConfig::COMMAND
        raise @parser.error("LIMITS_RESPONSE only applies to telemetry items")
      end

      @usage = "LIMITS_RESPONSE <RESPONSE CLASS FILENAME> <RESPONSE SPECIFIC OPTIONS>"
      @parser.verify_num_parameters(1, nil, @usage)
    end

    # @param item [PacketItem] The item the limits response should be added to
    def create_limits_response(item)
      # require should be performed in target.txt
      klass = @parser.parameters[0].filename_to_class_name.to_class
      raise @parser.error("#{@parser.parameters[0].filename_to_class_name} class not found. Did you require the file in target.txt?", @usage) unless klass

      if @parser.parameters[1]
        item.limits.response = klass.new(*@parser.parameters[1..(@parser.parameters.length - 1)])
      else
        item.limits.response = klass.new
      end
    rescue Exception => err
      raise @parser.error(err, @usage)
    end
  end
end # module Cosmos
