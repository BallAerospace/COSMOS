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

require 'cosmos/processors'

module Cosmos

  class ProcessorParser
    # @param parser [ConfigParser] Configuration parser
    # @param packet [Packet] The current packet
    # @param cmd_or_tlm [String] Whether this is a command or telemetry packet
    def self.parse(parser, packet, cmd_or_tlm)
      @parser = ProcessorParser.new(parser)
      @parser.verify_parameters(cmd_or_tlm)
      @parser.create_processor(packet)
    end

    # @param parser [ConfigParser] Configuration parser
    def initialize(parser)
      @parser = parser
    end

    # @param cmd_or_tlm [String] Whether this is a command or telemetry packet
    def verify_parameters(cmd_or_tlm)
      if cmd_or_tlm == PacketConfig::COMMAND
        raise @parser.error("PROCESSOR only applies to telemetry packets")
      end
      @usage = "PROCESSOR <PROCESSOR NAME> <PROCESSOR CLASS FILENAME> <PROCESSOR SPECIFIC OPTIONS>"
      @parser.verify_num_parameters(2, nil, @usage)
    end

    # @param packet [Packet] The packet the processor should be added to
    def create_processor(packet)
      # require should be performed in target.txt
      klass = @parser.parameters[1].filename_to_class_name.to_class
      raise @parser.error("#{@parser.parameters[1].filename_to_class_name} class not found. Did you require the file in target.txt?", @usage) unless klass
      if @parser.parameters[2]
        processor = klass.new(*@parser.parameters[2..(@parser.parameters.length - 1)])
      else
        processor = klass.new
      end
      raise ArgumentError, "processor must be a Cosmos::Processor but is a #{processor.class}" unless Cosmos::Processor === processor
      processor.name = get_processor_name()
      packet.processors[processor.name] = processor
    rescue Exception => err
      raise @parser.error(err, @usage)
    end

    private
    def get_processor_name
      @parser.parameters[0].to_s.upcase
    end

  end
end # module Cosmos
