# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

ENV['RAILS_ENV'] = 'production'
require File.expand_path('../../config/environment', __FILE__)
require 'dart_packet_log_writer'
require 'dart_logging'

# Handles packets by writing them to the dart log file. New SYSTEM META packets
# cause a new log file to be started.
class DartInterfaceThread < Cosmos::InterfaceThread
  attr_writer :packet_log_writer
  attr_writer :log_type

  def handle_packet(packet)
    if packet.target_name == 'SYSTEM'.freeze and packet.packet_name == 'META'.freeze
      Cosmos::Logger.info("#{@log_type}: #{packet.target_name} #{packet.packet_name}")
      # Update Current Value Table Used By Packet Log Writer
      cvt_packet = Cosmos::System.telemetry.update!(packet.target_name, packet.packet_name, packet.buffer)
      cvt_packet.received_time = packet.received_time
      cvt_packet.stored = packet.stored
      cvt_packet.extra = packet.extra
      @packet_log_writer.start
      @packet_log_writer.write(cvt_packet)
    else
      @packet_log_writer.write(packet)
    end
  end
end

Cosmos.catch_fatal_exception do
  DartCommon.handle_argv

  Cosmos::Logger.level = Cosmos::Logger::INFO
  dart_logging = DartLogging.new('dart_ingester')

  tlm_log_writer = DartPacketLogWriter.new(
    :TLM,    # Log telemetry
    'dart_', # Put dart_ in the log file name
    true,    # Enable logging
    nil,     # Don't cycle on time
    2_000_000_000, # Cycle the log at 2GB
    Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir

  tlm_interface = Cosmos::TcpipClientInterface.new(
    Cosmos::System.connect_hosts['CTS_PREIDENTIFIED'], # Connect to the CTS machine
    nil, # Don't write commands
    Cosmos::System.ports['CTS_PREIDENTIFIED'], # Read telemetry from the CTS port
    nil, # No write timeout
    nil, # No read timeout
    'PREIDENTIFIED') # PREIDENTIFIED protocol

  tlm_thread = DartInterfaceThread.new(tlm_interface)
  tlm_thread.packet_log_writer = tlm_log_writer
  tlm_thread.log_type = :TLM

  cmd_log_writer = DartPacketLogWriter.new(
    :CMD,    # Log commands
    'dart_', # Put dart_ in the log file name
    true,    # Enable logging
    nil,     # Don't cycle on time
    2_000_000_000, # Cycle the log at 2GB
    Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir

  cmd_interface = Cosmos::TcpipClientInterface.new(
    Cosmos::System.connect_hosts['CTS_CMD_ROUTER'], # Connect to the CTS machine
    nil, # Don't write commands
    Cosmos::System.ports['CTS_CMD_ROUTER'], # Read commands from the CMD port
    nil, # No write timeout
    nil, # No read timeout
    'PREIDENTIFIED') # PREIDENTIFIED protocol

  cmd_thread = DartInterfaceThread.new(cmd_interface)
  cmd_thread.packet_log_writer = cmd_log_writer
  cmd_thread.log_type = :CMD

  begin
    tlm_thread.start
    cmd_thread.start
    sleep(1) while true
  rescue Interrupt
    tlm_thread.stop
    cmd_thread.stop
    tlm_log_writer.shutdown
    cmd_log_writer.shutdown
    dart_logging.stop
  end
end
