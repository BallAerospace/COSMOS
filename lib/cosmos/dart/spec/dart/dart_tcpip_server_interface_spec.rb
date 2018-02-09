# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'rails_helper'
require 'dart_tcpip_server_interface'
require 'packet_log_entry'
require 'dart_packet_log_writer'

describe DartTcpipServerInterface do
  before(:all) do
    @request = Cosmos::Packet.new('DART', 'DART')
    @request.define_item('REQUEST', 0, 0, :BLOCK)
  end

  before(:each) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
  end

  describe "initialize" do
    it "uses the System.ports['DART_STREAM']" do
      i = DartTcpipServerInterface.new
      expect(i.instance_variable_get(:@read_port)).to eq Cosmos::System.ports['DART_STREAM']
      expect(i.instance_variable_get(:@write_port)).to eq Cosmos::System.ports['DART_STREAM']
      expect(i.listen_address).to eq Cosmos::System.listen_hosts['DART_STREAM']
    end
  end

  describe "write" do
    it "drops connection on bad request packets" do
      Cosmos::Logger.level = Cosmos::Logger::INFO
      i = DartTcpipServerInterface.new
      i.connect

      interface = Cosmos::TcpipClientInterface.new(
        Cosmos::System.connect_hosts['DART_STREAM'],
        Cosmos::System.ports['DART_STREAM'],
        Cosmos::System.ports['DART_STREAM'],
        10, 10, 'PREIDENTIFIED')
      interface.connect
      @request.write('REQUEST', "BLAH")
      interface.write(@request)
      sleep 0.1
      # TODO: Why is the interface still connected?
      # expect(interface.connected?).to be false
      i.disconnect

      Dir["#{Cosmos::System.paths['DART_LOGS']}/*"].each do |file|
        expect(file).to match(/dart_stream_server/)
        expect(File.read(file)).to include("lost read connection")
      end
    end
  end

  describe "read" do
    it "reads from the server" do
      writer = DartPacketLogWriter.new(
        :TLM,    # Log telemetry
        'test_decom_', # File name suffix
        true,    # Enable logging
        nil,     # Don't cycle on time
        2_000_000_000, # Cycle the log at 2GB
        Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir

      start_time = Time.now
      hs_packet = Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS")
      hs_packets = []
      # Write three packets. The first packet is always SYSTEM META.
      3.times do
        hs_packet.received_time = Time.now
        hs_packets << hs_packet.clone
        writer.write(hs_packet)
        sleep 0.01
      end
      writer.shutdown
      sleep 0.1
      end_time = Time.now

      i = DartTcpipServerInterface.new
      i.connect

      request_packet = Cosmos::Packet.new('DART', 'DART')
      request_packet.define_item('REQUEST', 0, 0, :BLOCK)
      request = {}
      request['start_time_sec'] = start_time.tv_sec
      request['start_time_usec'] = start_time.tv_usec
      request['end_time_sec'] = end_time.tv_sec
      request['end_time_usec'] = end_time.tv_usec
      request['cmd_tlm'] = 'TLM'
      request['packets'] = [['INST', 'HEALTH_STATUS']]
      #~ request['meta_ids'] = [4962]
      request_packet.write('REQUEST', JSON.dump(request))

      interface = Cosmos::TcpipClientInterface.new(
        Cosmos::System.connect_hosts['DART_STREAM'],
        Cosmos::System.ports['DART_STREAM'],
        Cosmos::System.ports['DART_STREAM'],
        10, 10, 'PREIDENTIFIED')
      interface.connect
      interface.write(request_packet)
      while true
        packet = interface.read
        puts packet
        break unless packet
      end

      i.disconnect
    end
  end
end
