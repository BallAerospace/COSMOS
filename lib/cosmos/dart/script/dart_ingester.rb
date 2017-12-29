require File.expand_path('../../config/environment', __FILE__)
require 'dart_packet_log_writer'
require 'dart_logging'

class DartInterfaceThread < Cosmos::InterfaceThread
  attr_writer :packet_log_writer
  attr_writer :log_type

  def handle_packet(packet)
    if packet.target_name == 'SYSTEM'.freeze and packet.packet_name == 'META'.freeze
      Cosmos::Logger.info("#{@log_type}: #{packet.target_name} #{packet.packet_name}")
      # Update Current Value Table Used By Packet Log Writer
      cvt_packet = Cosmos::System.telemetry.update!(packet.target_name, packet.packet_name, packet.buffer)
      cvt_packet.received_time = packet.received_time
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

  tlm_log_writer = DartPacketLogWriter.new(:TLM, 'dart_', true, nil, 2000000000, Cosmos::System.paths['DART_DATA'])
  tlm_interface = Cosmos::TcpipClientInterface.new(Cosmos::System.connect_hosts['CTS_PREIDENTIFIED'], nil, Cosmos::System.ports['CTS_PREIDENTIFIED'], nil, nil, 'PREIDENTIFIED')
  tlm_thread = DartInterfaceThread.new(tlm_interface)
  tlm_thread.packet_log_writer = tlm_log_writer
  tlm_thread.log_type = :TLM

  cmd_log_writer = DartPacketLogWriter.new(:CMD, 'dart_', true, nil, 2000000000, Cosmos::System.paths['DART_DATA'])
  cmd_interface = Cosmos::TcpipClientInterface.new(Cosmos::System.connect_hosts['CTS_CMD_ROUTER'], nil, Cosmos::System.ports['CTS_CMD_ROUTER'], nil, nil, 'PREIDENTIFIED')
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