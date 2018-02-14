# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'rails_helper'
require 'dart_decommutator'
require 'packet_log_entry'
require 'dart_packet_log_writer'

describe DartDecommutator do
  before(:each) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
  end

  describe "run" do
    let(:common) { Object.new.extend(DartCommon) }

    def check_val(val, expected)
      case val
      when Float
        expect(val).to be_within(0.001).of expected
      when String
        expect(val).to eq expected.to_s
      else
        expect(val).to eq expected
      end
    end

    it "decommutates packet log entries" do
      meta_packet = Cosmos::System.telemetry.packet("SYSTEM","META")
      meta_packet.received_count = 0

      writer = DartPacketLogWriter.new(
        :TLM,    # Log telemetry
        'test_decom_', # File name suffix
        true,    # Enable logging
        nil,     # Don't cycle on time
        2_000_000_000, # Cycle the log at 2GB
        Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir

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

      PacketLogEntry.all.each do |ple|
        expect(ple.decom_state).to eq PacketLogEntry::NOT_STARTED
      end

      thread = Thread.new do
        decom = DartDecommutator.new
        decom.run
      end
      sleep 5 # Allow the decommutator to work
      thread.exit

      PacketLogEntry.all.each do |ple|
        expect(ple.decom_state).to eq PacketLogEntry::COMPLETE
      end

      decom_tables = ActiveRecord::Base.connection.tables.select do |table_name|
        table_name =~ /^t\d+_\d+/ # t1_0, t1_0_m, t1_0_h, t1_0_d, t2_0, etc
      end
      # There should be 8 tables, 4 each for SYSTEM META and INST HEALTH_STATUS
      # The base decommutation table and three reduction tables
      expect(decom_tables.length).to eq 8

      system_target = Target.where("name = 'SYSTEM'").first
      meta = Packet.where("target_id = ? AND name = 'META'", system_target.id).first
      packet_config = PacketConfig.where("packet_id = ?", meta.id).first
      model = writer.get_decom_table_model(packet_config.id, 0)

      meta_packet = Cosmos::System.telemetry.packet("SYSTEM","META")
      meta_item_names = meta_packet.sorted_items.collect {|item| item.name unless item.name == 'RECEIVED_COUNT'}.compact
      expect(model.count).to eq 1 # One SYSTEM META packet
      meta_row = model.first
      expect(meta_row.reduced_state).to eq DartDecommutator::READY_TO_REDUCE
      # Grab all the iXX column names which hold the actual data values
      model.column_names.select {|name| name =~ /^i\d+/}.each_with_index do |item, index|
        db_value = meta_row.send(item.intern)
        check_val(db_value, meta_packet.read(meta_item_names[index]))
      end

      system_target = Target.where("name = 'INST'").first
      hs = Packet.where("target_id = ? AND name = 'HEALTH_STATUS'", system_target.id).first
      packet_config = PacketConfig.where("packet_id = ?", hs.id).first
      model = writer.get_decom_table_model(packet_config.id, 0)
      expect(model.count).to eq 3 # We wrote 3 INST HEALTH_STATUS packets
      decom_column_names = model.column_names.select {|name| name =~ /^i\d+/}

      hs_packets.each_with_index do |packet, packet_index|
        row = model.find(packet_index + 1)
        expect(row.reduced_state).to eq DartDecommutator::READY_TO_REDUCE
        db_index = 0
        packet.sorted_items.each do |item|
          next if item.name == 'RECEIVED_COUNT'
          next if item.read_conversion.class == Cosmos::ProcessorConversion
          # Database skips DERIVED items that aren't well defined
          if item.data_type == :DERIVED
            next unless item.read_conversion && item.read_conversion.converted_type && item.read_conversion.converted_bit_size
          end
          name = decom_column_names[db_index].intern
          db_value = row.send(name)
          # puts "#{db_index} item:#{item.name} db:#{db_value} raw pkt:#{packet.read_item(item, :RAW)}"
          check_val(db_value, packet.read_item(item, :RAW))
          if writer.separate_raw_con?(item)
            db_index += 1
            name = decom_column_names[db_index].intern
            db_value = row.send(name)
            puts "#{db_index} citem:#{item.name} db:#{db_value} type:#{db_value.class} conv pkt:#{packet.read_item(item)}"
            check_val(db_value, packet.read_item(item))
          end
          db_index += 1
        end
      end
    end

    it "marks and skips entries with no SYSTEM META PacketLogEntry" do
      common.sync_targets_and_packets
      target_id, packet_id = common.lookup_target_and_packet_id("INST", "HEALTH_STATUS", true)
      packet_log = PacketLog.create(:filename => "filename", :is_tlm => true)
      ple = PacketLogEntry.new
      ple.target_id = target_id
      ple.packet_id = packet_id
      ple.time = Time.now
      ple.packet_log_id = packet_log.id
      ple.data_offset = 0
      ple.meta_id = 0
      ple.is_tlm = true
      ple.ready = true
      ple.save!

      thread = Thread.new do
        decom = DartDecommutator.new
        decom.run
      end
      sleep 1 # Allow the decommutator to work
      thread.exit

      PacketLogEntry.all.each do |ple|
        expect(ple.decom_state).to eq PacketLogEntry::NO_META_PLE
      end
      decom_tables = ActiveRecord::Base.connection.tables.select do |table_name|
        table_name =~ /^t\d/
      end
      expect(decom_tables.length).to eq 0
    end

    it "marks and skips entries if the SYSTEM META packet can't be read" do
      common.sync_targets_and_packets
      target_id, packet_id = common.lookup_target_and_packet_id("INST", "HEALTH_STATUS", true)
      packet_log = PacketLog.create(:filename => "filename", :is_tlm => true)
      ple = PacketLogEntry.new
      ple.target_id = target_id
      ple.packet_id = packet_id
      ple.time = Time.now
      ple.packet_log_id = packet_log.id
      ple.data_offset = 0
      ple.meta_id = 0
      ple.is_tlm = true
      ple.ready = true
      ple.save!
      # Set the meta_id to itself to act as the SYSTEM META PLE
      ple.meta_id = ple.id
      ple.save!

      thread = Thread.new do
        decom = DartDecommutator.new
        decom.run
      end
      sleep 1 # Allow the decommutator to work
      thread.exit

      PacketLogEntry.all.each do |ple|
        expect(ple.decom_state).to eq PacketLogEntry::NO_META_PACKET
      end
      decom_tables = ActiveRecord::Base.connection.tables.select do |table_name|
        table_name =~ /^t\d/
      end
      expect(decom_tables.length).to eq 0
    end

    def setup_ples
      meta = Cosmos::System.commands.packet("SYSTEM", "META")
      hs_packet = Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS")
      # 128 byte file header, SYSTEM META has 14 byte header + length of SYSTEM & META
      # INST HEALTH_STATUS has 14 byte header + length of INST & HEALTH_STATUS
      length = 128 + 24 + meta.length + 31 + hs_packet.length

      writer = DartPacketLogWriter.new(
        :TLM,    # Log telemetry
        'test_decom_', # File name suffix
        true,    # Enable logging
        nil,     # Don't cycle on time
        length, # Cycle the log after a single INST HEALTH_STATUS packet
        Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir

      # Write packet. The first packet is always SYSTEM META.
      hs_packet.received_time = Time.now
      writer.write(hs_packet)
      sleep 0.1
      writer.shutdown

      # The first two entries (SYSTEM META and INST HEALTH_STATUS)
      # should be flushed and ready for decommutation
      (1..2).each do |id|
        ple = PacketLogEntry.find(id)
        expect(ple.ready).to eq true
        expect(ple.decom_state).to eq PacketLogEntry::NOT_STARTED
      end
    end

    it "marks and skips entries with no SystemConfig" do
      setup_ples()
      allow(SystemConfig).to receive(:create).and_return(nil)

      thread = Thread.new do
        decom = DartDecommutator.new
        decom.run
      end
      sleep 1 # Allow the decommutator to work
      thread.exit

      (1..2).each do |id|
        expect(PacketLogEntry.find(id).decom_state).to eq PacketLogEntry::NO_SYSTEM_CONFIG
      end
      decom_tables = ActiveRecord::Base.connection.tables.select do |table_name|
        table_name =~ /^t\d/
      end
      expect(decom_tables.length).to eq 0
    end

    it "marks and skips entries with no actual system configuration" do
      setup_ples()
      allow_any_instance_of(DartCommon).to receive(:switch_and_get_system_config).and_raise("ERROR")

      thread = Thread.new do
        decom = DartDecommutator.new
        decom.run
      end
      sleep 1 # Allow the decommutator to work
      thread.exit

      (1..2).each do |id|
        expect(PacketLogEntry.find(id).decom_state).to eq PacketLogEntry::NO_CONFIG
      end
      decom_tables = ActiveRecord::Base.connection.tables.select do |table_name|
        table_name =~ /^t\d/
      end
      expect(decom_tables.length).to eq 0
    end

    it "marks and skips entries with no packet" do
      setup_ples()
      packet_log = PacketLog.create(:filename => "filename", :is_tlm => true)
      # Break the ability to read the HEALTH_STATUS packet
      ple = PacketLogEntry.find(2)
      ple.packet_log_id = packet_log.id
      ple.save!

      thread = Thread.new do
        decom = DartDecommutator.new
        decom.run
      end
      sleep 1 # Allow the decommutator to work
      thread.exit

      expect(PacketLogEntry.find(2).decom_state).to eq PacketLogEntry::NO_PACKET
      decom_tables = ActiveRecord::Base.connection.tables.select do |table_name|
        table_name =~ /^t\d/
      end
      # SYSTEM META was setup correctly so it should have 4 tables
      expect(decom_tables.length).to eq 4
    end

    it "marks and skips entries with no PacketConfig" do
      setup_ples()
      allow(PacketConfig).to receive(:create).and_raise("PacketConfig ERROR!")

      thread = Thread.new do
        decom = DartDecommutator.new
        decom.run
      end
      sleep 1 # Allow the decommutator to work
      thread.exit

      (1..2).each do |id|
        expect(PacketLogEntry.find(id).decom_state).to eq PacketLogEntry::NO_PACKET_CONFIG
      end
      decom_tables = ActiveRecord::Base.connection.tables.select do |table_name|
        table_name =~ /^t\d/
      end
      expect(decom_tables.length).to eq 0
    end

    it "waits for the PacketConfig to be ready" do
      setup_ples()

      # Remove the const to avoid a warning when we redefine it
      DartDecommutator.send(:remove_const, "PACKET_CONFIG_READY_TIMEOUT")
      DartDecommutator.const_set("PACKET_CONFIG_READY_TIMEOUT", 2)
      # Don't allow the PacketConfig to be set ready
      allow_any_instance_of(DartCommon).to receive(:setup_packet_config).and_return

      thread = Thread.new do
        decom = DartDecommutator.new
        begin
          decom.run
        rescue SystemExit => e
          expect(e.status).to eq 1
          expect(e.success?).to eq false
        end
      end
      thread.join

      decom_tables = ActiveRecord::Base.connection.tables.select do |table_name|
        table_name =~ /^t\d/
      end
      expect(decom_tables.length).to eq 0
    end
  end
end
