# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# Usage Notes:
# The metadata packet must exist with exactly the same fields as both a command and as a telemetry packet
# The new_packet_log_conversion.rb WRITE_CONVERSION should be placed on at least one item in the meta packets

require 'cosmos/packet_logs/packet_log_writer'

module Cosmos

  # Writes a given packet at the beginning of each telemetry packet log file
  class MetaPacketLogWriter < PacketLogWriter

    # See PacketLogWriter#initialize
    # @param target_name [String] Target name of the metadata packet
    # @param packet_name [String] Packet name of the metadata packet
    # @param meta_default_filename [String] Filename containing key/value pairs for default meta packet values
    # @param log_meta_packet [Boolean] true to log the metadata packet if received during logging.  false to only
    #   log metadata packets at the beginning of the log.
    # @param use_tlm_packet [Boolean] true to put the data from the telemetry packet into
    #   each log.  false to put the data from the command packet.
    def initialize(
      log_type,
      target_name = nil,
      packet_name = nil,
      meta_default_filename = nil,
      log_meta_packet = false,
      use_tlm_packet = true,
      log_name = nil,
      logging_enabled = true,
      cycle_time = nil,
      cycle_size = 2000000000,
      log_directory = nil,
      asynchronous = false
    )
      @target_name = ConfigParser.handle_nil(target_name)
      @packet_name = ConfigParser.handle_nil(packet_name)
      @packet = nil
      @log_meta_packet = ConfigParser.handle_true_false(log_meta_packet)
      @meta_default_filename = ConfigParser.handle_nil(meta_default_filename)
      @use_tlm_packet = ConfigParser.handle_true_false(use_tlm_packet)

      # Make sure the packet exists in both commands and telemetry (if given)
      if @target_name and @packet_name
        packet = System.telemetry.packet(@target_name, @packet_name)
        @packet = packet if @use_tlm_packet
        packet = System.commands.packet(@target_name, @packet_name)
        @packet = packet if !@use_tlm_packet
      end

      # Initialize the meta packet (if given)
      if @meta_default_filename and @packet
        parser = ConfigParser.new
        Cosmos.set_working_dir do
          parser.parse_file(@meta_default_filename) do |keyword, params|
            begin
            item = @packet.get_item(keyword)
            if item.data_type == :STRING or item.data_type == :BLOCK
              value = params[0]
            else
              value = params[0].convert_to_value
            end
            @packet.write(keyword, value)
            rescue => err
              raise parser.error(err, "ITEM_NAME VALUE")
            end
          end
        end
      end

      super(log_type, log_name, logging_enabled, cycle_time, cycle_size, log_directory, asynchronous)
    end

    # Optionally doesn't write the meta packet
    def write(packet)
      if @log_meta_packet or !(packet.target_name == @target_name and packet.packet_name == @packet_name)
        super(packet)
      end
    end

    protected

    # Adds the meta packet at the beginning of telemetry packet logs
    # Mutex is held during this hook
    def start_new_file_hook
      if @target_name and @packet_name
        if @use_tlm_packet
          packet = System.telemetry.packet(@target_name, @packet_name)
        else
          packet = System.commands.packet(@target_name, @packet_name)
        end
        # Don't take the mutex because it is already held
        write_packet(packet, false)
      end
    end

  end # class MetaPacketLogWriter

end # module Cosmos
