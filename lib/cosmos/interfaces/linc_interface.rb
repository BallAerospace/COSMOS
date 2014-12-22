# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/interfaces/tcpip_client_interface'
require 'uuidtools'

module Cosmos

  # Interface for connecting to Ball Aerospace LINC Labview targets
  class LincInterface < TcpipClientInterface
    # The maximum number of handshake responses we can wait for at a time.
    # We don't ever expect to get close to this but we need to limit it
    # to ensure the Array doesn't grow out of control.
    MAX_CONCURRENT_HANDSHAKES = 100

    def initialize(
      hostname,
      port,
      handshake_enabled = true,
      response_timeout = 5.0,
      read_timeout = nil,
      write_timeout = 5.0,
      length_bitoffset = 0,
      length_bitsize = 16,
      length_value_offset = 4,
      fieldname_guid = 'HDR_GUID',
      endianness = 'BIG_ENDIAN',
      fieldname_cmd_length = 'HDR_LENGTH'
    )
      # Initialize Super Class
      super(hostname, port, port, write_timeout, read_timeout, 'LENGTH',
        length_bitoffset, length_bitsize, length_value_offset, 1, endianness, 0, nil, nil)

      # Configuration Settings
      @handshake_enabled = ConfigParser.handle_true_false(handshake_enabled)
      @response_timeout  = response_timeout.to_f
      @length_value_offset = Integer(length_value_offset)
      @fieldname_guid = ConfigParser.handle_nil(fieldname_guid)
      @fieldname_cmd_length = ConfigParser.handle_nil(fieldname_cmd_length)

      # Other instance variables
      @ignored_error_codes = []
      @handshakes = []
      @handshakes_mutex = Mutex.new
      @handshakes_resource = ConditionVariable.new

      # Call this once now because the first time is slow
      UUIDTools::UUID.random_create.raw
    end # def initialize

    def connect
      # Packet definitions need to be retrieved here because @target_names is not filled in until after initialize
      @handshake_packet = System.telemetry.packet(@target_names[0], 'HANDSHAKE')
      @error_packet = System.telemetry.packet(@target_names[0], 'ERROR')

      # Handle not defining the interface configuration commands (May not want to support this functionality)
      begin
        @error_ignore_command = nil
        @error_ignore_command = System.commands.packet(@target_names[0], 'COSMOS_ERROR_IGNORE')
      rescue
      end
      begin
        @error_handle_command = nil
        @error_handle_command = System.commands.packet(@target_names[0], 'COSMOS_ERROR_HANDLE')
      rescue
      end
      begin
        @handshake_enable_command = nil
        @handshake_enable_command = System.commands.packet(@target_names[0], 'COSMOS_HANDSHAKE_EN')
      rescue
      end
      begin
        @handshake_disable_command = nil
        @handshake_disable_command = System.commands.packet(@target_names[0], 'COSMOS_HANDSHAKE_DS')
      rescue
      end

      @handshakes_mutex.synchronize do
        @handshakes = []
      end

      # Actually connect
      super()
    end

    def write(packet)
      ######################################
      # Commands handled in the COSMOS interface not the LINC target
      ######################################

      if @error_ignore_command and @error_ignore_command.identify?(packet.buffer(false))
        linc_cmd = @error_ignore_command.clone
        linc_cmd.buffer = packet.buffer
        code = linc_cmd.read('CODE')
        @ignored_error_codes << code unless @ignored_error_codes.include? code
        return
      end

      if @error_handle_command and @error_handle_command.identify?(packet.buffer(false))
        linc_cmd = @error_handle_command.clone
        linc_cmd.buffer = packet.buffer
        code = linc_cmd.read('CODE')
        @ignored_error_codes.delete(code) if @ignored_error_codes.include? code
        return
      end

      if @handshake_enable_command and @handshake_enable_command.identify?(packet.buffer(false))
        @handshake_enabled = true
        return
      end

      if @handshake_disable_command and @handshake_disable_command.identify?(packet.buffer(false))
        @handshake_enabled = false
        return
      end

      # Verify we are connected to the LINC target
      if connected?()
        # Add a GUID to the GUID field if its defined
        if @fieldname_guid
          if not packet.read(@fieldname_guid) =~ /[\x01-\xFF]/
            # The GUID has not been set already (it has all \x00 values), so make a new one.
            # This enables a router GUI to make the GUIDs so it can process handshakes too.
            my_guid = UUIDTools::UUID.random_create.raw
            packet.write(@fieldname_guid, my_guid, :RAW)
          else
            my_guid = packet.read(@fieldname_guid)
          end
        end

        # Fix the length field to handle the cases where a variable length packet
        # is defined. COSMOS does not do this automatically.
        if @fieldname_cmd_length
          my_length = packet.length - @length_value_offset
          packet.write(@fieldname_cmd_length, my_length, :RAW)
        end

        # Always take the mutex (even if we aren't handshaking)
        @handshakes_mutex.synchronize do

          # Send the command
          super(packet)

          # Wait for the response if handshaking
          if @handshake_enabled
            begin
              my_handshake = nil

              # The time after which we will give up waiting for a response
              deadline = Time.now + @response_timeout

              # Loop until we find our response
              while my_handshake.nil?
                # How long should we wait in this loop. We could get notified
                # multiple times for handshakes that aren't ours so we need to
                # recalculate the wait time each time.
                to_wait = deadline - Time.now

                # If there is no more time to wait then this is a timeout so we break
                # out of the loop looking for handshakes
                if to_wait <= 0
                  raise "Timeout waiting for handshake from #{System.commands.format(packet, System.targets[@target_names[0]].ignored_parameters)}"
                end

                # Wait until the telemetry side signals that there is a new handshake to check or timeout.
                # This releases the mutex until the telemetry side signals us
                @handshakes_resource.wait(@handshakes_mutex, to_wait)
                # We now have the mutex again

                # Loop if we have timed out so we can handle the timeout with common code
                next if (deadline - Time.now) <= 0

                if @fieldname_guid
                  # A GUID means it's an asychronous packet type.
                  # So look at the list of incoming handshakes and pick off (deleting)
                  # the handshake from the list if it's for this command.
                  #
                  # The mutex is required because the telemetry task
                  # could enqueue a response between the index lookup and the slice
                  # function which would remove the wrong response. FAIL!
                  my_handshake_index = @handshakes.index {|hs| hs.get_cmd_guid(@fieldname_guid) == my_guid}
                  my_handshake = @handshakes.slice!(my_handshake_index) if my_handshake_index
                else
                  # This is the synchronous version
                  my_handshake = @handshakes.pop
                end
              end # while my_handshake.nil?

              # Handle handshake warnings and errors
              if my_handshake.handshake.read('STATUS') == "OK" and my_handshake.handshake.read('CODE') != 0
                unless @ignored_error_codes.include? my_handshake.handshake.read('CODE')
                  Logger.warn "Warning sending command (#{my_handshake.handshake.read('CODE')}): #{my_handshake.error_source}"
                end
              elsif my_handshake.handshake.read('STATUS') == "ERROR"
                unless @ignored_error_codes.include? my_handshake.handshake.read('CODE')
                  raise "Error sending command (#{my_handshake.handshake.read('CODE')}): #{my_handshake.error_source}"
                end
              end
            rescue Exception => err
              # If anything goes wrong after successfully writing the packet to the LINC target
              # ensure that the packet gets updated in the CVT and logged to the packet log writer.
              # COSMOS normally only does this if write returns successfully
              if packet.identified?
                command = System.commands.packet(packet.target_name, packet.packet_name)
              else
                command = System.commands.packet('UNKNOWN', 'UNKNOWN')
              end
              command.buffer = packet.buffer

              @packet_log_writer_pairs.each do |packet_log_writer_pair|
                packet_log_writer_pair.cmd_log_writer.write(packet)
              end

              raise err
            end
          end # if @handshake_enabled
        end # @handshakes_mutex.synchronize
      else
        raise "Interface not connected"
      end # if connected

    end # def write

    def read
      packet = super()
      if packet
        if @handshake_packet.identify?(packet.buffer(false))
          handshake_packet = @handshake_packet.clone
          handshake_packet.buffer = packet.buffer
          my_handshake = LincHandshake.new(handshake_packet, @target_names[0])

          if handshake_packet.read('origin') == "LCL"
            # Update the current value table for this command
            command = System.commands.packet(my_handshake.identified_command.target_name, my_handshake.identified_command.packet_name)
            command.received_time = my_handshake.identified_command.received_time
            command.buffer = my_handshake.identified_command.buffer
            command.received_count += 1

            # Put a log of the command onto the server for the user to see
            Logger.info("External Command: " + System.commands.format(my_handshake.identified_command, System.targets[@target_names[0]].ignored_parameters))

            # Log the command to the command log(s)
            @packet_log_writer_pairs.each do |packet_log_writer_pair|
              packet_log_writer_pair.cmd_log_writer.write(my_handshake.identified_command)
            end
          else
            # This is a remote packet (sent from here).
            # Add to the array of handshake packet responses (only if handshakes are enabled).
            # The mutex is required by the command task due to the way it
            # first looks up the handshake before removing it.
            if @handshake_enabled
              @handshakes_mutex.synchronize do
                @handshakes.push(my_handshake)
                if @handshakes.length > MAX_CONCURRENT_HANDSHAKES
                  len = @handshakes.length
                  @handshakes = []
                  raise "The handshakes response array has grown to #{len}. Clearing all handshakes!"
                end
                # Tell all waiting commands to take a look
                @handshakes_resource.broadcast
              end # @handshakes_mutex.synchronize
            end # if @handshake_enabled

          end # if handshake_packet.read('origin') == "LCL"
        end # @handshake_packet.identify?(packet.buffer(false))
      end # if packet

      return packet
    end

  end # class LincInterface

  # The LincHandshake class is used only by the LincInterface.  It processes the handshake and
  # helps with finding the information regarding the internal command.
  class LincHandshake
    attr_accessor :handshake
    attr_accessor :identified_command
    attr_accessor :error_source

    def initialize(handshake, interface_target_name)
      @handshake = handshake

      # Interpret the command field of the handshake packet
      # Where DATA is defined as:
      # 1 byte target name length
      # X byte target name
      # 1 byte packet name length
      # X byte packet name
      # 4 byte packet data length
      # X byte packet data
      # 4 byte error source length
      # X byte error source
      data = handshake.read('DATA')
      raise "Data field too short for target name length" if data.length == 0

      # Get target name length
      target_name_length = data[0..0].unpack('C')[0]
      raise "Invalid target name length" if target_name_length == 0
      data = data[1..-1]

      # get target name
      raise "Data field too short for target name" if data.length < target_name_length
      # target_name = data[0..(target_name_length - 1)] # Unused
      data = data[target_name_length..-1]

      # get packet name length
      raise "Data field too short for packet name length" if data.length == 0
      packet_name_length = data[0..0].unpack('C')[0]
      raise "Invalid packet name length" if packet_name_length == 0
      data = data[1..-1]

      # get packet name
      raise "Data field too short for packet name" if data.length < packet_name_length
      packet_name = data[0..(packet_name_length - 1)]
      data = data[packet_name_length..-1]

      # get packet data length
      raise "Data field too short for packet data length" if data.length < 4
      packet_data_length = data[0..3].unpack('N')[0]
      raise "Invalid data length" if packet_data_length == 0
      data = data[4..-1]

      # get packet data
      raise "Data field too short for packet data" if data.length < packet_data_length
      packet_data = data[0..(packet_data_length - 1)]
      data = data[packet_data_length..-1]

      # get error source length
      raise "Data field too short for error source length" if data.length < 4
      error_source_length = data[0..3].unpack('N')[0]
      # note it is OK to have a 0 source length
      data = data[4..-1]

      # get error source - store on object
      if error_source_length > 0
        @error_source = data[0..(error_source_length - 1)]
      else
        @error_source = ''
      end

      # make packet - store on object as a defined packet of type command that this handshakes
      @identified_command = System.commands.packet(interface_target_name, packet_name).clone
      @identified_command.buffer = packet_data
      @identified_command.received_time = Time.at(handshake.read('TIME_SECONDS'), handshake.read('TIME_MICROSECONDS'))
    end

    def get_cmd_guid(fieldname_guid)
      return @identified_command.read(fieldname_guid)
    end

  end  # class LincHandshake

end # module Cosmos
