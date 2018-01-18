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

  after(:all) do
    FileUtils.rm_rf Cosmos::System.paths['DART_DATA']
  end

  describe "write" do
    it "starts packet log and updates the database" do
      writer = DartPacketLogWriter.new(
        :TLM,    # Log telemetry
        'test_dart_', # Put dart_ in the log file name
        true,    # Enable logging
        nil,     # Don't cycle on time
        2_000, # Cycle the log at 2KB
        Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir
      writer.write(Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS"))
      wait 0.1
      writer.shutdown

      target = Target.find_by_name("INST")
      packet = Packet.where({target: target, name: "HEALTH_STATUS", is_tlm: true}).first
      ple = PacketLogEntry.where({target: target, packet: packet})
      puts ple
      expect(ple.target.name).to eq "INST"
      expect(ple.packet.name).to eq "HEALTH_STATUS"

      # ple = PacketLogEntry.new
      # ple.target_id = target_id
      # ple.packet_id = packet_id
      # ple.time = time
      # ple.packet_log_id = packet_log_id
      # ple.data_offset = data_offset
      # ple.meta_id = @meta_id
      # ple.is_tlm = is_tlm
      # ple.ready = false


      Dir["#{Cosmos::System.paths['DART_DATA']}/*"].each do |file|
        expect(file).to match(/test_dart_/)
      #   data = File.read(file)
      #   expect(File.read(file)).to include(test_string)
      end
    end
  end
end
