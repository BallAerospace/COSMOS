# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'rails_helper'
require 'dart_packet_log_writer'

describe DartPacketLogWriter do
  before(:all) do
    if File.exist?(Cosmos::System.paths['DART_DATA'])
      Dir["#{Cosmos::System.paths['DART_DATA']}/*"].each do |file|
        FileUtils.rm_f file
      end
    else
      FileUtils.mkdir_p Cosmos::System.paths['DART_DATA']
    end
  end

  before(:each) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
  end

  after(:all) do
    FileUtils.rm_rf Cosmos::System.paths['DART_DATA']
  end

  describe "write" do
    it "creates PacketLogEntries and flushes the file" do
      writer = DartPacketLogWriter.new(
        :TLM,    # Log telemetry
        'test_dart_tlm_', # Put dart_ in the log file name
        true,    # Enable logging
        nil,     # Don't cycle on time
        2_000_000_000, # Cycle the log at 2GB
        Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir

      hs_packet = Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS")
      (DartPacketLogWriter::DEFAULT_SYNC_COUNT_LIMIT - 1).times do
        hs_packet.received_time = Time.now
        writer.write(hs_packet)
        sleep 0.01
      end
      sleep 0.1

      # The first Log Entry is always SYSTEM META
      ple = PacketLogEntry.find(1)
      expect(ple.target.name).to eq "SYSTEM"
      expect(ple.packet.name).to eq "META"
      expect(ple.ready).to eq false # Hasn't been flushed yet

      packet = writer.read_packet_from_ple(ple)
      expect(packet.class).to eq Cosmos::Packet
      expect(packet.target_name).to eq "SYSTEM"
      expect(packet.packet_name).to eq "META"

      target = Target.find_by_name("INST")
      packet = Packet.find_by_name("HEALTH_STATUS")
      count = 0
      previous_time = Time.now
      PacketLogEntry.where("target_id = ? and packet_id = ?", target.id, packet.id).each do |ple|
        expect(ple.target.name).to eq "INST"
        expect(ple.packet.name).to eq "HEALTH_STATUS"
        expect(ple.ready).to eq false # Hasn't been flushed yet

        packet = writer.read_packet_from_ple(ple)
        expect(packet.target_name).to eq "INST"
        expect(packet.packet_name).to eq "HEALTH_STATUS"
        expect(packet.received_time).to_not eq previous_time
        previous_time = packet.received_time
        count += 1
      end
      expect(count).to eq (DartPacketLogWriter::DEFAULT_SYNC_COUNT_LIMIT - 1)

      hs_packet.received_time = Time.now
      writer.write(hs_packet) # Write the packet that causes the flush
      sleep 0.1
      count = 0
      PacketLogEntry.all.each do |ple|
        if count < DartPacketLogWriter::DEFAULT_SYNC_COUNT_LIMIT
          expect(ple.ready).to eq true # Flushed!
        else
          # The last write isn't flushed
          expect(ple.ready).to eq false
        end
        count += 1
      end
      # We wrote one SYSTEM META plus (DartPacketLogWriter::DEFAULT_SYNC_COUNT_LIMIT - 1)
      # plus one more to cause the flush
      expect(count).to eq DartPacketLogWriter::DEFAULT_SYNC_COUNT_LIMIT + 1
      writer.shutdown
      sleep 0.1

      files = Dir["#{Cosmos::System.paths['DART_DATA']}/*_test_dart_tlm_*"]
      expect(files.length).to eq 1
    end

    it "creates command logs" do
      DatabaseCleaner.clean
      meta = Cosmos::System.commands.packet("SYSTEM", "META")
      clr_cmd = Cosmos::System.commands.packet("INST", "CLEAR")
      # 128 byte file header, SYSTEM META has 24 byte header,
      # INST CLEAR has 23 byte header
      length = 128 + 24 + meta.length + 23 + clr_cmd.length

      writer = DartPacketLogWriter.new(
        :CMD,    # Log commands
        'test_dart_cmd_', # Put dart_ in the log file name
        true,    # Enable logging
        nil,     # Don't cycle on time
        length, # Cycle the log at 1 Meta plus 1 Cmd
        Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir

      clr_cmd.received_time = Time.now
      writer.write(clr_cmd)
      sleep 0.1

      # The first Log Entry is always SYSTEM META
      ple = PacketLogEntry.find(1)
      expect(ple.target.name).to eq "SYSTEM"
      expect(ple.packet.name).to eq "META"
      expect(ple.ready).to eq false # Hasn't been flushed yet

      # The second Log Entry is the command
      ple = PacketLogEntry.find(2)
      expect(ple.target.name).to eq "INST"
      expect(ple.packet.name).to eq "CLEAR"
      expect(ple.ready).to eq false # Hasn't been flushed yet

      clr_cmd.received_time = Time.now
      writer.write(clr_cmd) # The second command should create a new log
      sleep 0.1

      # Check the the first two have been flushed
      ple = PacketLogEntry.find(1)
      expect(ple.ready).to eq true # Flushed
      ple = PacketLogEntry.find(2)
      expect(ple.ready).to eq true # Flushed

      # The third and fourth are SYSTEM META and the command
      ple = PacketLogEntry.find(3)
      expect(ple.target.name).to eq "SYSTEM"
      expect(ple.packet.name).to eq "META"
      expect(ple.ready).to eq false # Hasn't been flushed yet
      ple = PacketLogEntry.find(4)
      expect(ple.target.name).to eq "INST"
      expect(ple.packet.name).to eq "CLEAR"
      expect(ple.ready).to eq false # Hasn't been flushed yet

      writer.shutdown
      sleep 0.1

      files = Dir["#{Cosmos::System.paths['DART_DATA']}/*_test_dart_cmd_*"]
      expect(files.length).to eq 2
    end
  end
end
