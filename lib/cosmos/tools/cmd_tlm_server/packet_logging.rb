# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  # Controls the packet loggers which were configured by CmdTlmServerConfig.
  # This includes starting and stopping both command and telemetry logging.
  class PacketLogging
    # @param cmd_tlm_server_config [CmdTlmServerConfig] The configuration which
    #   defines the packet loggers
    def initialize(cmd_tlm_server_config)
      @config = cmd_tlm_server_config
    end

    # @param packet_log_writer_name [String] The name of the log writer to
    #   start or 'ALL' to start all command and telemetry log writers
    # @param label [String|nil] Label to append to the log file name. See
    #   {PacketLogWriter#start} for more information.
    def start(packet_log_writer_name = 'ALL', label = nil)
      start_cmd(packet_log_writer_name, label)
      start_tlm(packet_log_writer_name, label)
    end

    # @param packet_log_writer_name [String] The name of the log writer to
    #   stop or 'ALL' to stop all command and telemetry log writers
    def stop(packet_log_writer_name = 'ALL')
      stop_cmd(packet_log_writer_name)
      stop_tlm(packet_log_writer_name)
    end

    # Stop packet logging and kill the logger threads!
    def shutdown
      @config.packet_log_writer_pairs.each do |name, packet_log_writer_pair|
        packet_log_writer_pair.cmd_log_writer.shutdown
      end
      @config.packet_log_writer_pairs.each do |name, packet_log_writer_pair|
        packet_log_writer_pair.tlm_log_writer.shutdown
      end
    end

    # @param packet_log_writer_name [String] The name of the log writer to
    #   start or 'ALL' to start all command log writers
    # @param label [String|nil] Label to append to the log file name. See
    #   {PacketLogWriter#start} for more information.
    def start_cmd(packet_log_writer_name = 'ALL', label = nil)
      if packet_log_writer_name.upcase == 'ALL'
        @config.packet_log_writer_pairs.each do |name, packet_log_writer_pair|
          packet_log_writer_pair.cmd_log_writer.start(label)
        end
      else
        packet_log_writer_pair = @config.packet_log_writer_pairs[packet_log_writer_name.upcase]
        raise "Unknown packet log writer: #{packet_log_writer_name}" unless packet_log_writer_pair
        packet_log_writer_pair.cmd_log_writer.start(label)
      end
    end

    # @param packet_log_writer_name [String] The name of the log writer to
    #   start or 'ALL' to start all telemetry log writers
    # @param label [String|nil] Label to append to the log file name. See
    #   {PacketLogWriter#start} for more information.
    def start_tlm(packet_log_writer_name = 'ALL', label = nil)
      if packet_log_writer_name.upcase == 'ALL'
        @config.packet_log_writer_pairs.each do |name, packet_log_writer_pair|
          packet_log_writer_pair.tlm_log_writer.start(label)
        end
      else
        packet_log_writer_pair = @config.packet_log_writer_pairs[packet_log_writer_name.upcase]
        raise "Unknown packet log writer: #{packet_log_writer_name}" unless packet_log_writer_pair
        packet_log_writer_pair.tlm_log_writer.start(label)
      end
    end

    # @param packet_log_writer_name [String] The name of the log writer to
    #   stop or 'ALL' to stop all command log writers
    def stop_cmd(packet_log_writer_name = 'ALL')
      if packet_log_writer_name.upcase == 'ALL'
        @config.packet_log_writer_pairs.each do |name, packet_log_writer_pair|
          packet_log_writer_pair.cmd_log_writer.stop
        end
      else
        packet_log_writer_pair = @config.packet_log_writer_pairs[packet_log_writer_name.upcase]
        raise "Unknown packet log writer: #{packet_log_writer_name}" unless packet_log_writer_pair
        packet_log_writer_pair.cmd_log_writer.stop
      end
    end

    # @param packet_log_writer_name [String] The name of the log writer to
    #   stop or 'ALL' to stop all telemetry log writers
    def stop_tlm(packet_log_writer_name = 'ALL')
      if packet_log_writer_name.upcase == 'ALL'
        @config.packet_log_writer_pairs.each do |name, packet_log_writer_pair|
          packet_log_writer_pair.tlm_log_writer.stop
        end
      else
        packet_log_writer_pair = @config.packet_log_writer_pairs[packet_log_writer_name.upcase]
        raise "Unknown packet log writer: #{packet_log_writer_name}" unless packet_log_writer_pair
        packet_log_writer_pair.tlm_log_writer.stop
      end
    end

    # @param packet_log_writer_name [String] The name of the command log writer
    # @return [String] The command log writer filename
    def cmd_filename(packet_log_writer_name = 'DEFAULT')
      packet_log_writer_pair = @config.packet_log_writer_pairs[packet_log_writer_name.upcase]
      raise "Unknown packet log writer: #{packet_log_writer_name}" unless packet_log_writer_pair
      return packet_log_writer_pair.cmd_log_writer.filename
    end

    # @param packet_log_writer_name [String] The name of the telemetry log writer
    # @return [String] The telemetry log writer filename
    def tlm_filename(packet_log_writer_name = 'DEFAULT')
      packet_log_writer_pair = @config.packet_log_writer_pairs[packet_log_writer_name.upcase]
      raise "Unknown packet log writer: #{packet_log_writer_name}" unless packet_log_writer_pair
      return packet_log_writer_pair.tlm_log_writer.filename
    end

    # @return [Hash<String, PacketLogWriterPair>] Packet log writer hash. Each
    #   pair encapsulates a command and telemetry log writer.
    def all
      @config.packet_log_writer_pairs
    end

  end # class PacketLogging

end # module Cosmos
