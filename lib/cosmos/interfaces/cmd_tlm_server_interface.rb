# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
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

      @limits_groups = true
      begin
        System.telemetry.packet("SYSTEM", "LIMITS_GROUPS")
      rescue
        @limits_groups = false
      end
    end

    # Start the limits event subscription
    def connect
      @limit_id = CmdTlmServer.instance.subscribe_limits_events
      @sleeper = Sleeper.new
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
      @sleeper.cancel
    end

    # Continuously wait for limits events and returning
    # SYSTEM LIMITS_CHANGE packets.
    #
    # @return [Packet] returns SYSTEM LIMITS_CHANGE packets as limits events are generated.
    def read
      limits_change = true
      while connected?
        if limits_change
          begin
            event = CmdTlmServer.instance.get_limits_event(@limit_id, true)
            if event
              if event[0] == :LIMITS_CHANGE
                data = event[1]
                packet = System.telemetry.packet("SYSTEM","LIMITS_CHANGE")
                packet.received_time = Time.now.sys
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
                @read_raw_data_time = Time.now
                @read_raw_data = packet.buffer
                return packet
              end
            end
          rescue ThreadError
            # Nominal processing if no events
          rescue => error
            puts error.formatted
            # if they haven't defined SYSTEM LIMITS_CHANGE we stop checking limits events
            limits_change = false
          end
        end

        # Limit the rate to 1Hz
        @sleeper.sleep(1)

        begin
          if @limits_groups
            packet = System.telemetry.packet("SYSTEM", "LIMITS_GROUPS")
            packet.write("PKT_ID", 99)
            packet.received_time = Time.now.sys
            @read_count += 1
            @read_raw_data_time = Time.now
            @read_raw_data = packet.buffer
            return packet
          end
        rescue => error
          puts error.formatted
          # Guess something is wrong with limits groups. Disable them.
          @limits_groups = false
        end
      end
      return nil
    end

    # Write a packet to the CmdTlmServer to change various settings.
    #
    # @param packet [Packet] Must be one of SYSTEM SETLOGLABEL, STARTLOGGING,
    #   STARTCMDLOG, STARTTLMLOG, STOPLOGGING, STOPCMDLOG or STOPTLMLOG.
    def write(packet)
      @write_count += 1
      command_data = packet.buffer
      @bytes_written += command_data.length
      @written_raw_data_time = Time.now
      @written_raw_data = command_data

      identified_command = System.commands.identify(command_data, ['SYSTEM'])
      if identified_command
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
          raise "Command unhandled at SYSTEM interface. : #{identifed_command.packet_name}"
        end
      else
        raise "Unknown command received at SYSTEM Interface."
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
  end
end
