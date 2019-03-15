# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
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
  # provides Ruby primatives where the PacketConfig class can return actual
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

    # @return [Array<String>] The command target names (excluding UNKNOWN)
    def target_names
      result = @config.commands.keys.sort
      result.delete('UNKNOWN'.freeze)
      return result
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
        target_name = target_name.to_s.upcase
        
        target_packets = nil
        begin
          target_packets = packets(target_name)
        rescue RuntimeError
          # No commands for this target
          next
        end

        target = System.targets[target_name]
        if target and target.cmd_unique_id_mode
          # Iterate through the packets and see if any represent the buffer
          target_packets.each do |packet_name, packet|
            if packet.identify?(packet_data)
              identified_packet = packet
              break
            end
          end
        else
          # Do a hash lookup to quickly identify the packet
          if target_packets.length > 0
            packet = target_packets.first[1]
            key = packet.read_id_values(packet_data)
            hash = @config.cmd_id_value_hash[target_name]
            identified_packet = hash[key]
            identified_packet = hash['CATCHALL'.freeze] unless identified_packet
          end          
        end

        if identified_packet
          identified_packet = identified_packet.clone
          identified_packet.received_time = nil
          identified_packet.stored = false
          identified_packet.extra = nil
          identified_packet.received_count = 0
          identified_packet.buffer = packet_data
          break
        end
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
    # @param check_required_params [Boolean] Indicates whether or not to check
    #   that the required command parameters are present
    def build_cmd(target_name, packet_name, params = {}, range_checking = true, raw = false, check_required_params = true)
      target_upcase = target_name.to_s.upcase
      packet_upcase = packet_name.to_s.upcase

      # Lookup the command and create a light weight copy
      command = packet(target_upcase, packet_upcase).clone

      # Restore the command's buffer to a zeroed string of defined length
      # This will undo any side effects from earlier commands that may have altered the size
      # of the buffer
      command.buffer = "\x00" * command.defined_length

      # Set time, parameters, and restore defaults
      command.received_time = Time.now.sys
      command.stored = false
      command.extra = nil
      command.given_values = params
      command.restore_defaults(command.buffer(false), params.keys)
      command.raw = raw

      given_item_names = set_parameters(command, params, range_checking)
      check_required_params(command, given_item_names) if check_required_params

      return command
    end

    # Formatted version of a command
    def format(packet, ignored_parameters = [])
      if packet.raw
        items = packet.read_all(:RAW)
        raw = true
      else
        items = packet.read_all(:FORMATTED)
        raw = false
      end
      items.delete_if {|item_name, item_value| ignored_parameters.include?(item_name)}
      return build_cmd_output_string(packet.target_name, packet.packet_name, items, raw)
    end

    def build_cmd_output_string(target_name, cmd_name, cmd_params, raw = false)
      if raw
        output_string = 'cmd_raw("'
      else
        output_string = 'cmd("'
      end
      output_string << target_name + ' ' + cmd_name
      if cmd_params.nil? or cmd_params.empty?
        output_string << '")'
      else
        begin
          command_items = packet(target_name, cmd_name).items
        rescue
        end

        params = []
        cmd_params.each do |key, value|

          begin
            item_type = command_items[key].data_type
          rescue
            item_type = nil
          end

          if value.is_a?(String)
            value = value.dup
            if item_type == :BLOCK or item_type == :STRING
              if !value.is_printable?
                value = "0x" + value.simple_formatted
              else
                value = value.inspect
              end
            else
              value = value.convert_to_value.to_s
            end
            if value.length > 256
              value = value[0..255] + "...'"
            end
            value.tr!('"',"'")
          elsif value.is_a?(Array)
            value = "[#{value.join(", ")}]"
          end
          params << "#{key} #{value}"
        end
        params = params.join(", ")
        output_string << ' with ' + params + '")'
      end
      return output_string
    end

    # Returns whether the given command is hazardous. Commands are hazardous
    # if they are marked hazardous overall or if any of their hardardous states
    # are set. Thus any given parameter values are first applied to the command
    # and then checked for hazardous states.
    #
    # @param command [Packet] The command to check for hazardous
    def cmd_pkt_hazardous?(command)
      return [true, command.hazardous_description] if command.hazardous

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

    # Returns whether the given command is hazardous. Commands are hazardous
    # if they are marked hazardous overall or if any of their hardardous states
    # are set. Thus any given parameter values are first applied to the command
    # and then checked for hazardous states.
    #
    # @param target_name (see #packet)
    # @param packet_name (see #packet)
    # @param params (see #build_cmd)
    def cmd_hazardous?(target_name, packet_name, params = {})
      # Build a command without range checking, perform conversions, and don't
      # check required parameters since we're not actually using the command.
      cmd_pkt_hazardous?(build_cmd(target_name, packet_name, params, false, false, false))
    end

    def clear_counters
      @config.commands.each do |target_name, target_packets|
        target_packets.each do |packet_name, packet|
          packet.received_count = 0
        end
      end
    end

    # Returns an array with a "TARGET_NAME PACKET_NAME" string for every command in the system (PACKET_NAME == command name)
    def all_packet_strings(include_hidden = false, splash = nil)
      strings = []
      tnames = target_names()
      total = tnames.length.to_f
      tnames.each_with_index do |target_name, index|
        if splash
          splash.message = "Processing #{target_name} command"
          splash.progress = index / total
        end

        ignored_items = System.targets[target_name].ignored_items

        packets(target_name).each do |command_name, packet|
          # We don't audit against hidden or disabled packets/commands
          next if !include_hidden and (packet.hidden || packet.disabled)
          strings << "#{target_name} #{command_name}"
        end
      end
      strings
    end

    def all
      @config.commands
    end

    protected

    def set_parameters(command, params, range_checking)
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
              raise "Command parameter '#{command.target_name} #{command.packet_name} #{item_upcase}' = #{range_check_value} not in valid range of #{range.first} to #{range.last}"
            end
          end
        end

        # Update parameter in command
        if command.raw
          command.write(item_upcase, value, :RAW)
        else
          command.write(item_upcase, value, :CONVERTED)
        end

        given_item_names << item_upcase
      end
      given_item_names
    end

    def check_required_params(command, given_item_names)
      # Script Runner could call this command with only some parameters
      # so make sure any required parameters were actually passed in.
      item_defs = command.items
      item_defs.each do |item_name, item_def|
        if item_def.required and not given_item_names.include? item_name
          raise "Required command parameter '#{command.target_name} #{command.packet_name} #{item_name}' not given"
        end
      end
    end

  end # class Commands

end # module Cosmos
