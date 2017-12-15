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
    # @param target_name [String] The name of the target to create the packet
    #   under. If the target name is 'SYSTEM' the keyword parameter will be
    #   used instead of this parameter.
    # @param commands [Hash] Hash of the currently defined commands
    # @param warnings [Array<String>] Any warning strings generated while
    #   parsing this command will be appened to this array
    def self.parse_command(parser, target_name, commands, warnings)
      parser = PacketParser.new(parser)
      parser.verify_parameters()
      parser.create_command(target_name, commands, warnings)
    end

    # @param parser [ConfigParser] Configuration parser
    # @param target_name [String] The name of the target to create the packet
    #   under. If the target name is 'SYSTEM' the keyword parameter will be
    #   used instead of this parameter.
    # @param telemetry [Hash] Hash of the currently defined telemetry packets
    # @param latest_data [Hash<String=>Hash<String=>Array(Packet)>>] Hash of hashes keyed
    #   first by the target name and then by the item name. This results in an
    #   array of packets containing that target and item. This structure is
    #   used to perform lookups when the packet and item are known but the
    #   packet is not.
    # @param warnings [Array<String>] Any warning strings generated while
    #   parsing this command will be appened to this array
    def self.parse_telemetry(parser, target_name, telemetry, latest_data, warnings)
      parser = PacketParser.new(parser)
      parser.verify_parameters()
      parser.create_telemetry(target_name, telemetry, latest_data, warnings)
    end

    # @param packet [Packet] Packet to check all default and range items for
    #   appropriate data types. Only applicable to COMMAND packets.
    def self.check_item_data_types(packet)
      packet.sorted_items.each do |item|
        item.check_default_and_range_data_types()
      end
    rescue
      # Add the target name and packet name to the error message so the user
      # can debug where the error occurred
      raise $!, "#{packet.target_name} #{packet.packet_name} #{$!}", $!.backtrace
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
      PacketParser.finish_create_command(packet, commands, warnings)
    end

    def create_telemetry(target_name, telemetry, latest_data, warnings)
      packet = create_packet(target_name)
      PacketParser.finish_create_telemetry(packet, telemetry, latest_data, warnings)
    end

    #private

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

    def self.check_for_duplicate(type, list, packet)
      msg = nil
      if list[packet.target_name]
        if list[packet.target_name][packet.packet_name]
          msg = "#{type} Packet #{packet.target_name} #{packet.packet_name} redefined."
          Logger.instance.warn msg
        end
      end
      msg
    end

    def self.finish_create_command(packet, commands, warnings)
      warning = PacketParser.check_for_duplicate('Command', commands, packet)
      warnings << warning if warning
      commands[packet.target_name] ||= {}
      packet
    end

    def self.finish_create_telemetry(packet, telemetry, latest_data, warnings)
      warning = PacketParser.check_for_duplicate('Telemetry', telemetry, packet)
      warnings << warning if warning
      packet.define_reserved_items()

      unless telemetry[packet.target_name]
        telemetry[packet.target_name] = {}
        latest_data[packet.target_name] = {}
      end
      packet
    end

  end
end
