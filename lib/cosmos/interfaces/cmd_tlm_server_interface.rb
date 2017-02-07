# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/interfaces/interface'

module Cosmos
  # Allows commands to be sent and telemetry received from the the
  # CmdTlmServer.
  class CmdTlmServerInterface < Interface
    # Create the interface and disallow raw writes
    def initialize
      super()
      @raw_logger_pair = nil
      @write_raw_allowed = false
      @limit_id = nil
    end

    # Start the limits event subscription
    def connect
      @limit_id = CmdTlmServer.instance.subscribe_limits_events
    end

    # @return [Boolean] Returns whether subscribed to limits events
    def connected?
      return true if @limit_id
      false
    end

    # Unsubscribe from the limits events
    def disconnect
      CmdTlmServer.instance.unsubscribe_limits_events(@limit_id) if @limit_id
      @limit_id = nil
    end

    # Read from the CmdTlmServer interface by first getting the COSMOS VERSION
    # packet and then continuously waiting for limits events and returning
    # COSMOS LIMITS_CHANGE packets.
    #
    # @return [Packet] Initially returns the COSMOS VERSION packet and then
    #   returns COSMOS LIMITS_CHANGE packets as limits events are generated.
    def read
      if @read_count.zero?
        version = cosmos_version_packet()
        return version if version
      end
      return nil unless connected?
      process_limits_change_events()
    end

    # Write a packet to the CmdTlmServer to change various settings.
    #
    # @param packet [Packet] Must be one of COSMOS SETLOGLABEL, STARTLOGGING,
    #   STARTCMDLOG, STARTTLMLOG, STOPLOGGING, STOPCMDLOG or STOPTLMLOG.
    def write(packet)
      @write_count += 1
      command_data = packet.buffer
      @bytes_written += command_data.length

      identified_command = System.commands.identify(command_data, ['COSMOS'])
      raise "Unknown command received at COSMOS Server Interface." unless identified_command
      case identified_command.packet_name
      when 'STARTLOGGING'
        interface_name = identified_command.read('interface')
        label = identified_command.read('label')
        CmdTlmServer.instance.start_logging(interface_name, label)
      when 'STARTCMDLOG'
        interface_name = identified_command.read('interface')
        CmdTlmServer.instance.start_cmd_log(interface_name)
      when 'STARTTLMLOG'
        interface_name = identified_command.read('interface')
        CmdTlmServer.instance.start_tlm_log(interface_name)
      when 'STOPLOGGING'
        interface_name = identified_command.read('interface')
        CmdTlmServer.instance.stop_logging(interface_name)
      when 'STOPCMDLOG'
        interface_name = identified_command.read('interface')
        CmdTlmServer.instance.stop_cmd_log(interface_name)
      when 'STOPTLMLOG'
        interface_name = identified_command.read('interface')
        CmdTlmServer.instance.stop_tlm_log(interface_name)
      else
        raise "Command unhandled at COSMOS server interface. : #{identifed_command.packet_name}"
      end
    end

    # Raise an error because this method is not implemented for this interface
    def write_raw(_data)
      raise "write_raw not implemented for CmdTlmServerInterface"
    end

    # Raise an error because raw logging is not supported for this interface
    def raw_logger_pair=(_raw_logger_pair)
      raise "Raw logging not supported for CmdTlmServerInterface"
    end

    protected

    # Get the COSMOS VERSION packet and populate it
    def cosmos_version_packet
      packet = System.telemetry.packet("COSMOS", "VERSION")
      packet.write('PKT_ID', 1)
      packet.write('COSMOS', Cosmos::VERSION)
      packet.write('RUBY', "#{RUBY_VERSION}p#{RUBY_PATCHLEVEL}")
      packet.write('CTDB', System.cmd_tlm_version)
      packet.write('USER', USER_VERSION) if defined? USER_VERSION
      @read_count += 1
      packet
    rescue RuntimeError
      puts "Consider defining the COSMOS VERSION packet to allow "\
        "startup version information to be logged"
      nil
    end

    def process_limits_change_events
      event = []
      loop do
        event = CmdTlmServer.instance.get_limits_event(@limit_id)
        return nil unless event # Force a disconnect
        # get_limits_event can return several events but we only want to
        # process the :LIMITS_CHANGE event
        break if event[0] == :LIMITS_CHANGE
      end
      data = event[1]
      packet = System.telemetry.packet("COSMOS", "LIMITS_CHANGE")
      packet.received_time = Time.now
      packet.write('PKT_ID', 2)
      packet.write('TARGET', data[0])
      packet.write('PACKET', data[1])
      packet.write('ITEM', data[2])
      # For the first limits change the old_state is nil
      # so set it to a usable string
      data[3] = 'UNKNOWN' unless data[3]
      packet.write('OLD_STATE', data[3])
      packet.write('NEW_STATE', data[4])
      @read_count += 1
      packet
    rescue RuntimeError
      puts "The COSMOS LIMITS_CHANGE packet is required to allow "\
        "limits change information packets to be generated."
      nil # Force a disconnect
    end
  end
end
