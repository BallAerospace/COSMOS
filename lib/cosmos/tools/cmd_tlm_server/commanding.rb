# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  # Sends command packets to targets or interfaces. Utilizes the System
  # knowledge of targets and commands to correctly identify interfaces and
  # commands before sending. Also provides {#send_raw} to directly send raw
  # binary data to an interface.
  class Commanding
    # @param cmd_tlm_server_config [CmdTlmServerConfig] The configuration which
    #   defines the interfaces
    def initialize(cmd_tlm_server_config)
      @config = cmd_tlm_server_config
    end

    # Sends a command to the interface associated with the given target
    # and logs the command using its log writer
    #
    # Commands should be identified before this method is called.
    #
    # @param target_name [String] Name of the target to send to
    # @param packet [Packet] Packet to send
    def send_command_to_target(target_name, packet)
      # Create guaranteed uppercase target name
      target = System.targets[target_name.upcase]
      raise "Unknown target: #{target_name}" unless target
      raise "Target not mapped to an interface: #{target_name}" unless target.interface

      # Send the command
      send_command_to_interface(target.interface, packet)
    end

    # Sends the packet to the given interface and performs other common command
    # sending tasks.
    #
    # @param interface [Interface] The interface to send the packet to
    # @param packet [Packet] Packet to send
    def send_command_to_interface(interface, packet)
      # Make sure packet received time is set
      packet.received_time ||= Time.now

      unless packet.identified?
        identified_command = System.commands.identify(packet.buffer, interface.target_names)
        if identified_command
          identified_command.received_time = packet.received_time
          identified_command.raw = packet.raw
          packet = identified_command
        end
      end

      # Log to messages command being sent, update counters, and initially update current value table
      target = nil
      if packet.identified?
        command = System.commands.packet(packet.target_name, packet.packet_name)
        raise "Cannot send DISABLED command #{packet.target_name} #{packet.packet_name}" if packet.disabled
        target = System.targets[packet.target_name]
        target.cmd_cnt += 1
      else
        command = System.commands.packet('UNKNOWN', 'UNKNOWN')
        Logger.warn "Unidentified packet of #{packet.length} bytes being sent to interface #{interface.name}"
      end
      command.received_time = packet.received_time
      command.raw = packet.raw
      command.buffer = packet.buffer
      command.received_count += 1
      Logger.info System.commands.format(command, target.ignored_parameters) if !command.messages_disabled and command.target_name != 'UNKNOWN'

      if packet.identified?
        # Write the identified and defined packet to the interface
        interface.write(command)
      else
        # Write the unidentified and undefined packet to the interface
        # We do not want to give interfaces packets identified and defined as UNKNOWN UNKNOWN
        interface.write(packet)

        # Note: packet may have been modified by the interface to fill in a CRC, length, etc.
        # The following actions are done after a successful write to incorporate these possible
        # changes.

        # Update current value table again after successful write
        command.buffer = packet.buffer
      end

      # Write to command packet logs
      interface.packet_log_writer_pairs.each do |packet_log_writer_pair|
        packet_log_writer_pair.cmd_log_writer.write(command)
      end
    end

    # Sends raw data to the specified interface. Note: Raw data is not logged
    # to the command packet log, because packet boundaries are not known.
    #
    # @param interface_name [String] Name of the interface to send to
    # @param data [String] Binary string of data
    def send_raw(interface_name, data)
      interface = @config.interfaces[interface_name.upcase]
      raise "Unknown interface: #{interface_name}" unless interface
      Logger.warn "Unlogged raw data of #{data.length} bytes being sent to interface #{interface_name}"
      interface.write_raw(data)
    end

  end # class Commanding

end # module Cosmos
