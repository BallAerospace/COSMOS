# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packets/packet_config'

module Cosmos

  # Commands uses PacketConfig to parse the command and telemetry
  # configuration files. It contains all the knowledge of which command packets
  # exist in the system and how to access them. This class is the API layer
  # which other classes use to access commands.
  #
  # This should not be confused with the Api module which implements the JSON
  # API that is used by tools when accessing the Server. The Api module always
  # provides Ruby primatives where the PacketDefinition class can return actual
  # Packet or PacketItem objects. While there are some overlapping methods between
  # the two, these are separate interfaces into the system.
  class Commands
    attr_accessor :config

    LATEST_PACKET_NAME = 'LATEST'.freeze

    # @param config [PacketConfig] Packet configuration to use to access the
    #  commands
    def initialize(config)
      @config = config
    end

    # (see PacketConfig#warnings)
    def warnings
      return @config.warnings
    end

    # @return [Array<String>] The command target names
    def target_names
      return @config.commands.keys.sort
    end

    # @param target_name [String] The target name
    # @return [Hash<packet_name=>Packet>] Hash of the command packets for the given
    #   target name keyed by the packet name
    def packets(target_name)
      target_packets = @config.commands[target_name.to_s.upcase]
      raise "Command target '#{target_name.to_s.upcase}' does not exist" unless target_packets
      target_packets
    end

    # @param target_name [String] The target name
    # @param packet_name [String] The packet name. Must be a defined packet name
    #   and not 'LATEST'.
    # @return [Packet] The command packet for the given target and packet name
    def packet(target_name, packet_name)
      target_packets = packets(target_name)
      packet = target_packets[packet_name.to_s.upcase]
      raise "Command packet '#{target_name.to_s.upcase} #{packet_name.to_s.upcase}' does not exist" unless packet
      packet
    end

    # @param target_name (see #packet)
    # @param packet_name (see #packet)
    # @return [Array<PacketItem>] The command parameters for the given target and packet name
    def params(target_name, packet_name)
      return packet(target_name, packet_name).sorted_items
    end

    # Identifies an unknown buffer of data as a defined command and sets the
    # commands's data to the given buffer. Identifying a command uses the fields
    # marked as ID_PARAMETER to identify if the buffer passed represents the
    # command defined. Incorrectly sized buffers are still processed but an
    # error is logged.
    #
    # Note: Subsequent requests for the command (using packet) will return
    # an uninitialized copy of the command. Thus you must use the return value
    # of this method.
    #
    # @param (see #identify_tlm!)
    # @return (see #identify_tlm!)
    def identify(packet_data, target_names = nil)
      identified_packet = nil

      target_names = target_names() unless target_names

      target_names.each do |target_name|
        target_packets = nil
        begin
          target_packets = packets(target_name)
        rescue RuntimeError
          # No commands for this target
          next
        end

        # Iterate through the packets and see if any represent the buffer
        target_packets.each do |packet_name, packet|
          if (packet.identify?(packet_data))
            identified_packet = packet.clone
            identified_packet.received_time  = nil
            identified_packet.received_count = 0
            identified_packet.buffer = packet_data
            break
          end
        end

        break if identified_packet
      end

      return identified_packet
    end

    # Returns a copy of the specified command packet with the parameters
    # initialzed to the given params values.
    #
    # @param target_name (see #packet)
    # @param packet_name (see #packet)
    # @param params [Hash<param_name=>param_value>] Parameter items to override
    #   in the given command.
    # @param range_checking [Boolean] Whether to perform range checking on the
    #   passed in parameters.
    # @param raw [Boolean] Indicates whether or not to run conversions on command parameters
    def build_cmd(target_name, packet_name, params = {}, range_checking = true, raw = false)
      target_upcase = target_name.to_s.upcase
      packet_upcase = packet_name.to_s.upcase

      # Lookup the command and create a light weight copy
      command = packet(target_upcase, packet_upcase).clone

      # Set time, parameters, and restore defaults
      command.received_time = Time.now
      command.given_values = params
      command.restore_defaults
      command.raw = raw

      # Set any parameters
      given_item_names = []
      params.each do |item_name, value|
        item_upcase = item_name.to_s.upcase
        item = command.get_item(item_upcase)
        range_check_value = value

        # Convert from state to value if possible
        if item.states and item.states[value.to_s.upcase]
          range_check_value = item.states[value.to_s.upcase]
        end

        if range_checking
          range = item.range
          if range
            # Perform Range Check on command parameter
            if not range.include?(range_check_value)
              range_check_value = "'#{range_check_value}'" if String === range_check_value
              raise "Command parameter '#{target_upcase} #{packet_upcase} #{item_upcase}' = #{range_check_value} not in valid range of #{range.first} to #{range.last}"
            end
          end
        end

        # Update parameter in command
        if raw
          command.write(item_upcase, value, :RAW)
        else
          command.write(item_upcase, value, :CONVERTED)
        end

        given_item_names << item_upcase
      end # cmd_params.each

      # Script Runner could call this command with only some parameters
      # so make sure any required parameters were actually passed in.
      item_defs = command.items
      item_defs.each do |item_name, item_def|
        if item_def.required and not given_item_names.include? item_name
          raise "Required command parameter '#{target_upcase} #{packet_upcase} #{item_name}' not given"
        end
      end

      return command
    end

    # Formatted version of a command
    def format(packet, ignored_parameters = [])
      first = true
      if packet.raw
        items = packet.read_all(:RAW)
        string = "cmd_raw('#{packet.target_name} #{packet.packet_name}"
      else
        items = packet.read_all(:FORMATTED)
        string = "cmd('#{packet.target_name} #{packet.packet_name}"
      end
      items.each do |item_name, item_value|
        unless ignored_parameters.include?(item_name)
          if first
            string << ' with '
            first = false
          else
            string << ', '
          end

          item = packet.get_item(item_name)
          if item.data_type ==:STRING or item.data_type == :BLOCK
            item_value = item_value.inspect
            if item_value.length > 256
              item_value = item_value[0..255] + '..."'
            end
            string << "#{item_name} #{item_value}"
          else
            if (Array === item_value) && (!packet.raw)
              string << "#{item_name} [#{item_value.join(", ")}]"
            else
              string << "#{item_name} #{item_value}"
            end
          end
        end
      end
      string << "')"
      string
    end

    # Returns whether the given command is hazardous. Commands are hazardous
    # if they are marked hazardous overall or if any of their hardardous states
    # are set. Thus any given parameter values are first applied to the command
    # and then checked for hazardous states.
    #
    # @param target_name (see #packet)
    # @param packet_name (see #packet)
    # @param params (see #build_cmd)
    def cmd_hazardous?(target_name, packet_name, params = {})
      target_upcase = target_name.to_s.upcase
      packet_upcase = packet_name.to_s.upcase

      # Lookup the command
      command = packet(target_upcase, packet_upcase)

      # Overall command hazardous check
      return [true, command.hazardous_description] if command.hazardous

      # Create a light weight copy of command
      command = command.clone()
      # Set given command parameters and restore defaults
      command.given_values = params
      command.restore_defaults()

      # Set any parameters
      params.each do |item_name, value|
        item_upcase = item_name.to_s.upcase
        item = command.get_item(item_upcase)

        if item.states
          state_value = item.states[value.to_s.upcase]
          value = state_value if state_value
        end

        # Update parameter in command
        command.write(item_upcase, value)
      end

      # Check each item for hazardous states
      item_defs = command.items
      item_defs.each do |item_name, item_def|
        if item_def.hazardous
          state_name = command.read(item_name)
          # Nominally the command.read will return a valid state_name
          # If it doesn't, the if check will fail and we'll fall through to
          # the bottom where we return [false, nil] which means this
          # command is not hazardous.
          return [true, item_def.hazardous[state_name]] if item_def.hazardous[state_name]
        end
      end

      return [false, nil]
    end

    def clear_counters
      @config.commands.each do |target_name, target_packets|
        target_packets.each do |packet_name, packet|
          packet.received_count = 0
        end
      end
    end

    def all
      @config.commands
    end

  end # class Commands

end # module Cosmos
