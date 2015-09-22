# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
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
    # The maximum number of asynchronous commands we can wait for at a time.
    # We don't ever expect to get close to this but we need to limit it
    # to ensure the Array doesn't grow out of control.
    MAX_CONCURRENT_HANDSHAKES = 1000

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
      @handshake_cmds = []
      @handshakes_mutex = Mutex.new

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
        @handshake_cmds = []
      end

      # Actually connect
      super()
    end

    def write(packet)
      return if linc_interface_command(packet)
      raise "Interface not connected" unless connected?()

      # Add a GUID to the GUID field if its defined
      # A GUID means it's an asychronous packet type.
      if @fieldname_guid
        guid = get_guid(packet)
      else
        # If @fieldname_guid is not defined (syncronous) we don't care what the
        # GUID is because we're not trying to match it up with anything.
        # As soon as we get a response we free the command.
        guid = 0
      end

      # Fix the length field to handle the cases where a variable length packet
      # is defined. COSMOS does not do this automatically.
      update_length_field(packet) if @fieldname_cmd_length

      # Always take the mutex (even if we aren't handshaking)
      # We do not want any incoming telemetry to be missed because
      # it could be the handshake to this command.
      @handshakes_mutex.synchronize do
        super(packet) # Send the command
        wait_for_response(packet, guid) if @handshake_enabled
      end
    end

    def linc_interface_command(packet)
      result = false
      if @error_ignore_command and @error_ignore_command.identify?(packet.buffer(false))
        linc_cmd = @error_ignore_command.clone
        linc_cmd.buffer = packet.buffer
        code = linc_cmd.read('CODE')
        @ignored_error_codes << code unless @ignored_error_codes.include? code
        result = true
      end

      if @error_handle_command and @error_handle_command.identify?(packet.buffer(false))
        linc_cmd = @error_handle_command.clone
        linc_cmd.buffer = packet.buffer
        code = linc_cmd.read('CODE')
        @ignored_error_codes.delete(code) if @ignored_error_codes.include? code
        result = true
      end

      if @handshake_enable_command and @handshake_enable_command.identify?(packet.buffer(false))
        @handshake_enabled = true
        result = true
      end

      if @handshake_disable_command and @handshake_disable_command.identify?(packet.buffer(false))
        @handshake_enabled = false
        result = true
      end
      return result
    end

    def get_guid(packet)
      if not packet.read(@fieldname_guid) =~ /[\x01-\xFF]/
        # The GUID has not been set already (it has all \x00 values), so make a new one.
        # This enables a router GUI to make the GUIDs so it can process handshakes too.
        guid = UUIDTools::UUID.random_create.raw
        packet.write(@fieldname_guid, guid, :RAW)
      else
        guid = packet.read(@fieldname_guid)
      end
      return guid
    end

    def update_length_field(packet)
      length = packet.length - @length_value_offset
      packet.write(@fieldname_cmd_length, length, :RAW)
    end

    def wait_for_response(packet, guid)
      # Check the number of commands waiting for handshakes.  This is just for sanity
      # If the number of commands waiting for handshakes is very large then it can't be real
      # So raise an error.  Something has gone horribly wrong.
      if @handshake_cmds.length > MAX_CONCURRENT_HANDSHAKES
        len = @handshake_cmds.length
        @handshake_cmds = []
        raise "The number of commands waiting for handshakes to #{len}. Clearing all commands!"
      end

      # Create a handshake command object and add it to the list of commands waiting
      handshake_cmd = LincHandshakeCommand.new(@handshakes_mutex, guid)
      @handshake_cmds.push(handshake_cmd)

      # wait for that handshake. This releases the mutex so that the telemetry and other commands can start running again.
      timed_out = handshake_cmd.wait_for_handshake(@response_timeout)
      # We now have the mutex again.  This interface is blocked for the rest of the command handling,
      # which should be quick because it's just checking variables and logging.
      # We want to hold the mutex during that so that the commands get logged in order of handshake from here.

      if timed_out
        # Clean this command out of the array of items that require handshakes.
        @handshake_cmds.delete_if {|hsc| hsc == handshake_cmd}
        raise "Timeout waiting for handshake from #{System.commands.format(packet, System.targets[@target_names[0]].ignored_parameters)}"
      end

      process_handshake_results(handshake_cmd)

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

    def process_handshake_results(handshake_cmd)
      status = handshake_cmd.handshake.handshake.read('STATUS')
      code = handshake_cmd.handshake.handshake.read('CODE')
      source = handshake_cmd.handshake.error_source

      # Handle handshake warnings and errors
      if status == "OK" and code != 0
        unless @ignored_error_codes.include? code
          Logger.warn "Warning sending command (#{code}): #{source}"
        end
      elsif status == "ERROR"
        unless @ignored_error_codes.include? code
          raise "Error sending command (#{code}): #{source}"
        end
      end
    end

    def read
      packet = super()
      if packet
        if @handshake_packet.identify?(packet.buffer(false))
          handshake_packet = @handshake_packet.clone
          handshake_packet.buffer = packet.buffer
          linc_handshake = LincHandshake.new(handshake_packet, @target_names[0])

          # Check for a local handshake
          if handshake_packet.read('origin') == "LCL"
            handle_local_handshake(linc_handshake)
          else
            handle_remote_handshake(linc_handshake) if @handshake_enabled
          end # if handshake_packet.read('origin') == "LCL"
        end # @handshake_packet.identify?(packet.buffer(false))
      end # if packet

      return packet
    end

    def handle_local_handshake(linc_handshake)
      # Update the current value table for this command
      command = System.commands.packet(linc_handshake.identified_command.target_name, linc_handshake.identified_command.packet_name)
      command.received_time = linc_handshake.identified_command.received_time
      command.buffer = linc_handshake.identified_command.buffer
      command.received_count += 1

      # Put a log of the command onto the server for the user to see
      Logger.info("External Command: " + System.commands.format(linc_handshake.identified_command, System.targets[@target_names[0]].ignored_parameters))

      # Log the command to the command log(s)
      @packet_log_writer_pairs.each do |packet_log_writer_pair|
        packet_log_writer_pair.cmd_log_writer.write(linc_handshake.identified_command)
      end
    end

    def handle_remote_handshake(linc_handshake)
      # This is a remote packet (sent from here).
      # Add to the array of handshake packet responses
      # The mutex is required by the command task due to the way it
      # first looks up the handshake before removing it.
      @handshakes_mutex.synchronize do
        if @fieldname_guid
          # A GUID means it's an asychronous packet type.
          # So look at the list of incoming handshakes and pick off (deleting)
          # the handshake from the list if it's for this command.
          #
          # The mutex is required because the telemetry task
          # could enqueue a response between the index lookup and the slice
          # function which would remove the wrong response. FAIL!

          # Loop through all waiting commands to see if this handshake belongs to them
          this_handshake_guid = linc_handshake.get_cmd_guid(@fieldname_guid)
          handshake_cmd_index = @handshake_cmds.index {|hsc| hsc.get_cmd_guid == this_handshake_guid}

          # If command was waiting (ie the loop above found one), then remove it from waiters and signal it
          if handshake_cmd_index
            handshake_cmd = @handshake_cmds.slice!(handshake_cmd_index)
            handshake_cmd.got_your_handshake(linc_handshake)
          else
            # No command match found!  Either it gave up and timed out or this wasn't originated from here.
            # Ignore this typically.  This case here for clarity.
          end

        else
          # Synchronous version: just pop the array (pull the command off) and send it the handshake
          handshake_cmd = @handshakes_cmds.pop
          handshake_cmd.got_your_handshake(linc_handshake)
        end # of handshaking type check
      end # @handshakes_mutex.synchronize
    end

  end # class LincInterface

  # The LincHandshakeCommand class is used only by the LincInterface.
  # It is the command with other required items that is passed to the telemetry
  # thread so it can match it with the handshake.
  class LincHandshakeCommand
    attr_accessor :handshake

    def initialize(handshakes_mutex,cmd_guid)
      @cmd_guid = cmd_guid
      @handshakes_mutex = handshakes_mutex
      @resource = ConditionVariable.new
      @handshake = nil
    end

    def wait_for_handshake(response_timeout)
      timed_out = false

      @resource.wait(@handshakes_mutex,response_timeout)
      if @handshake
        timed_out = false
      else
        Logger.warn "No handshake - must be timeout."
        timed_out = true
      end

      return timed_out
    end

    def got_your_handshake(handshake)
      @handshake = handshake
      @resource.signal
    end

    def get_cmd_guid
      return @cmd_guid
    end
  end # class LincHandshakeCommand

  # The LincHandshake class is used only by the LincInterface. It processes the handshake and
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
