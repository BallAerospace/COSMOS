# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/packets/packet_config'
require 'cosmos/ext/telemetry'

module Cosmos

  # Telemetry uses PacketConfig to parse the command and telemetry
  # configuration files. It contains all the knowledge of which telemetry packets
  # exist in the system and how to access them. This class is the API layer
  # which other classes use to access telemetry.
  #
  # This should not be confused with the Api module which implements the JSON
  # API that is used by tools when accessing the Server. The Api module always
  # provides Ruby primatives where the Telemetry class can return actual
  # Packet or PacketItem objects. While there are some overlapping methods between
  # the two, these are separate interfaces into the system.
  class Telemetry
    attr_accessor :config

    LATEST_PACKET_NAME = 'LATEST'.freeze

    # @param config [PacketConfig] Packet configuration to use to access the
    #   telemetry
    def initialize(config)
      @config = config
    end

    # (see PacketConfig#warnings)
    def warnings
      return @config.warnings
    end

    # @return [Array<String>] The telemetry target names (excluding UNKNOWN)
    def target_names
      result = @config.telemetry.keys.sort
      result.delete('UNKNOWN'.freeze)
      return result
    end

    # @param target_name [String] The target name
    # @return [Hash<packet_name=>Packet>] Hash of the telemetry packets for the given
    #   target name keyed by the packet name
    # def packets(target_name)

    # @param target_name [String] The target name
    # @param packet_name [String] The packet name. Must be a defined packet name
    #   and not 'LATEST'.
    # @return [Packet] The telemetry packet for the given target and packet name
    # def packet(target_name, packet_name)

    # @param target_name (see #packet)
    # @param packet_name (see #packet)
    # @return [Array<PacketItem>] The telemetry items for the given target and packet name
    def items(target_name, packet_name)
      return packet(target_name, packet_name).sorted_items
    end

    # @param target_name (see #packet)
    # @param packet_name (see #packet) The packet name.  LATEST is supported.
    # @return [Array<PacketItem>] The telemetry item names for the given target and packet name
    def item_names(target_name, packet_name)
      if LATEST_PACKET_NAME.casecmp(packet_name) == 0
        target_upcase = target_name.to_s.upcase
        target_latest_data = @config.latest_data[target_upcase]
        raise "Telemetry Target '#{target_upcase}' does not exist" unless target_latest_data
        item_names = target_latest_data.keys
      else
        tlm_packet = packet(target_name, packet_name)
        item_names = []
        tlm_packet.sorted_items.each {|item| item_names << item.name}
      end
      item_names
    end

    # @param target_name (see #packet)
    # @param packet_name [String] The packet name. 'LATEST' can also be given
    #   to specify the last received (or defined if no packets have been
    #   received) packet within the given target that contains the
    #   item_name.
    # @param item_name [String] The item name
    # @return [Packet, PacketItem] The packet and the packet item
    # def packet_and_item(target_name, packet_name, item_name)

    # Return a telemetry value from a packet.
    #
    # @param target_name (see #packet_and_item)
    # @param packet_name (see #packet_and_item)
    # @param item_name (see #packet_and_item)
    # @param value_type [Symbol] How to convert the item before returning.
    #   Must be one of {Packet::VALUE_TYPES}
    # @return The value. :FORMATTED and :WITH_UNITS values are always returned
    #   as Strings. :RAW values will match their data_type. :CONVERTED values
    #   can be any type.
    # def value(target_name, packet_name, item_name, value_type = :CONVERTED)

    # Set a telemetry value in a packet.
    #
    # @param target_name (see #packet_and_item)
    # @param packet_name (see #packet_and_item)
    # @param item_name (see #packet_and_item)
    # @param value The value to set in the packet
    # @param value_type (see #tlm)
    def set_value(target_name, packet_name, item_name, value, value_type = :CONVERTED)
      packet, _ = packet_and_item(target_name, packet_name, item_name)
      packet.write(item_name, value, value_type)
    end

    # @param target_name (see #packet_and_item)
    # @param item_name (see #packet_and_item)
    # @return [Array<Packet>] The latest (most recently arrived) packets with
    #   the specified target and item.
    def latest_packets(target_name, item_name)
      target_upcase = target_name.to_s.upcase
      item_upcase = item_name.to_s.upcase
      target_latest_data = @config.latest_data[target_upcase]
      raise "Telemetry target '#{target_upcase}' does not exist" unless target_latest_data
      packets = @config.latest_data[target_upcase][item_upcase]
      raise "Telemetry item '#{target_upcase} #{LATEST_PACKET_NAME} #{item_upcase}' does not exist" unless packets
      return packets
    end

    # @param target_name (see #packet_and_item)
    # @param item_name (see #packet_and_item)
    # @return [Packet] The packet with the most recent timestamp that contains
    #   the specified target and item.
    def newest_packet(target_name, item_name)
      # Handle LATEST_PACKET_NAME - Lookup packets for this target/item
      packets = latest_packets(target_name, item_name)

      # Find packet with newest timestamp
      newest_packet = nil
      newest_received_time = nil
      packets.each do |packet|
        received_time = packet.received_time
        if newest_received_time
          # See if the received time from this packet is newer.
          # Having the >= makes this method return the last defined packet
          # whether the timestamps are both nil or both equal.
          if received_time and received_time >= newest_received_time
            newest_packet = packet
            newest_received_time = newest_packet.received_time
          end
        else
          # No received time yet so take this packet
          newest_packet = packet
          newest_received_time = newest_packet.received_time
        end
      end
      return newest_packet
    end

    # Identifies an unknown buffer of data as a defined packet and sets the
    # packet's data to the given buffer. Identifying a packet uses the fields
    # marked as ID_ITEM to identify if the buffer passed represents the
    # packet defined. Incorrectly sized buffers are still processed but an
    # error is logged.
    #
    # Note: This affects all subsequent requests for the packet (for example
    # using packet) which is why the method is marked with a bang!
    #
    # @param packet_data [String] The binary packet data buffer
    # @param target_names [Array<String>] List of target names to limit the search. The
    #   default value of nil means to search all known targets.
    # @return [Packet] The identified packet with its data set to the given
    #   packet_data buffer. Returns nil if no packet could be identified.
    def identify!(packet_data, target_names = nil)
      identified_packet = nil

      target_names = target_names() unless target_names

      target_names.each do |target_name|
        target_packets = nil
        begin
          target_packets = packets(target_name)
        rescue RuntimeError
          # No telemetry for this target
          next
        end

        # Iterate through the packets and see if any represent the buffer
        target_packets.each do |packet_name, packet|
          if packet.identify?(packet_data)
            identified_packet = packet
            identified_packet.buffer = packet_data
            break
          end
        end
        break if identified_packet
      end
      return identified_packet
    end

    # Updates the specified packet with the given packet data. Raises an error
    # if the packet could not be found.
    #
    # Note: This affects all subsequent requests for the packet which is why
    # the method is marked with a bang!
    #
    # @param target_name (see #packet)
    # @param packet_name (see #packet)
    # @param packet_data (see #identify_tlm!)
    # @return [Packet] The packet with its data set to the given packet_data
    #   buffer.
    def update!(target_name, packet_name, packet_data)
      identified_packet = packet(target_name, packet_name)
      identified_packet.buffer = packet_data
      return identified_packet
    end

    # Assigns a limits change callback to all telemetry packets
    #
    # @param limits_change_callback
    def limits_change_callback=(limits_change_callback)
      @config.telemetry.each do |target_name, packets|
        packets.each do |packet_name, packet|
          packet.limits_change_callback = limits_change_callback
        end
      end
    end

    # Reads the specified list of items and returns their values and limits
    # state.
    #
    # @param item_array [Array<Array(String String String)>] An array
    #   consisting of [target name, packet name, item name]
    # @param value_types [Symbol|Array<Symbol>] How to convert the items before
    #   returning. A single symbol of {Packet::VALUE_TYPES}
    #   can be passed which will convert all items the same way. Or
    #   an array of symbols can be passed to control how each item is
    #   converted.
    # @return [Array, Array, Array] The first array contains the item values and the
    #   second their limits state, and the third their limits settings which includes
    #   the red, yellow, and green (if given) limits values.
    # def values_and_limits_states(item_array, value_types = :CONVERTED)

    # Iterates through all the telemetry packets and marks them stale if they
    # haven't been received for over the System.staleness_seconds value.
    def check_stale
      time = Time.now
      @config.telemetry.each do |target_name, target_packets|
        target_packets.each do |packet_name, packet|
          packet.set_stale if packet.received_time and (!packet.stale) and (time - packet.received_time > System.staleness_seconds)
        end
      end
    end

    # Clears the received_count value on every packet in every target
    def clear_counters
      @config.telemetry.each do |target_name, target_packets|
        target_packets.each do |packet_name, packet|
          packet.received_count = 0
        end
      end
    end

    # Resets metadata on every packet in every target
    def reset
      @config.telemetry.each do |target_name, target_packets|
        target_packets.each do |packet_name, packet|
          packet.reset
        end
      end
    end

    # Returns the first non-hidden packet
    def first_non_hidden
      @config.telemetry.each do |target_name, target_packets|
        next if target_name == 'UNKNOWN'
        target_packets.each do |packet_name, packet|
          return packet unless packet.hidden
        end
      end
      nil
    end

    # Returns an array with a "TARGET_NAME PACKET_NAME ITEM_NAME" string for every item in the system
    def all_item_strings(include_hidden = false, splash = nil)
      strings = []
      tnames = target_names()
      total = tnames.length.to_f
      tnames.each_with_index do |target_name, index|
        if splash
          splash.message = "Processing #{target_name} telemetry"
          splash.progress = index / total
        end

        ignored_items = System.targets[target_name].ignored_items

        packets(target_name).each do |packet_name, packet|
          # We don't audit against hidden or disabled packets
          next if !include_hidden and (packet.hidden || packet.disabled)
          packet.items.each_key do |item_name|
            # Skip ignored items
            next if !include_hidden and ignored_items.include? item_name
            strings << "#{target_name} #{packet_name} #{item_name}"
          end
        end
      end
      strings
    end

    # @return [Hash<String=>Packet>] Hash of all the telemetry packets
    #   keyed by the packet name.
    def all
      @config.telemetry
    end

  end # class Telemetry

end # module Cosmos
