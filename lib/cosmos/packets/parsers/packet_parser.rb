# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packets/packet'

module Cosmos

  class PacketParser
    # @param parser [ConfigParser] Configuration parser
    def self.parse_command(parser, target_name, commands, warnings)
      parser = PacketParser.new(parser)
      parser.verify_parameters()
      parser.create_command(target_name, commands, warnings)
    end

    def self.parse_telemetry(parser, target_name, telemetry, latest_data, warnings)
      parser = PacketParser.new(parser)
      parser.verify_parameters()
      parser.create_telemetry(target_name, telemetry, latest_data, warnings)
    end

    # @param parser [ConfigParser] Configuration parser
    def initialize(parser)
      @parser = parser
    end

    def verify_parameters
      @usage = "#{@parser.keyword} <TARGET NAME> <PACKET NAME> <ENDIANNESS: BIG_ENDIAN/LITTLE_ENDIAN> <DESCRIPTION (Optional)>"
      @parser.verify_num_parameters(3, 4, @usage)
    end

    def create_command(target_name, commands, warnings)
      packet = create_packet(target_name)
      warning = check_for_duplicate('Command', commands, packet)
      warnings << warning if warning
      commands[packet.target_name] ||= {}
      packet
    end

    def create_telemetry(target_name, telemetry, latest_data, warnings)
      packet = create_packet(target_name)
      warning = check_for_duplicate('Telemetry', telemetry, packet)
      warnings << warning if warning

      # Add received time packet items
      item = packet.define_item('RECEIVED_TIMESECONDS', 0, 0, :DERIVED, nil, packet.default_endianness, :ERROR, '%0.6f', ReceivedTimeSecondsConversion.new)
      item.description = 'COSMOS Received Time (UTC, Floating point, Unix epoch)'
      item = packet.define_item('RECEIVED_TIMEFORMATTED', 0, 0, :DERIVED, nil, packet.default_endianness, :ERROR, nil, ReceivedTimeFormattedConversion.new)
      item.description = 'COSMOS Received Time (Local time zone, Formatted string)'
      item = packet.define_item('RECEIVED_COUNT', 0, 0, :DERIVED, nil, packet.default_endianness, :ERROR, nil, ReceivedCountConversion.new)
      item.description = 'COSMOS packet received count'

      unless telemetry[packet.target_name]
        telemetry[packet.target_name] = {}
        latest_data[packet.target_name] = {}
      end
      packet
    end

    private

    def create_packet(target_name)
      params = @parser.parameters
      target_name = params[0].to_s.upcase if target_name == 'SYSTEM'
      packet_name = params[1].to_s.upcase
      endianness = params[2].to_s.upcase.to_sym
      description = params[3].to_s
      if endianness != :BIG_ENDIAN and endianness != :LITTLE_ENDIAN
        raise @parser.error("Invalid endianness #{params[2]}. Must be BIG_ENDIAN or LITTLE_ENDIAN.", @usage)
      end
      Packet.new(target_name, packet_name, endianness, description)
    end

    def check_for_duplicate(type, list, packet)
      msg = nil
      if list[packet.target_name]
        if list[packet.target_name][packet.packet_name]
          msg = "#{type} Packet #{packet.target_name} #{packet.packet_name} redefined."
          Logger.instance.warn msg
        end
      end
      msg
    end

  end
end # module Cosmos
