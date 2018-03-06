# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'rails_helper'
require 'dart_database_cleaner'
require 'dart_packet_log_writer'
require 'dart_decommutator'

describe DartDatabaseCleaner do
  before(:each) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
    @cleaner = DartDatabaseCleaner.new
  end

  describe "clean" do
    it "calls the cleaning methods" do
      messages = []
      allow(Cosmos::Logger).to receive(:info) { |msg| messages << msg }
      DartDatabaseCleaner.clean(false)
      expect(messages.select{|m| m =~ /Cleaning up SystemConfig/}.length).to eq 1
      expect(messages.select{|m| m =~ /Cleaning up PacketLog\./}.length).to eq 1
      expect(messages.select{|m| m =~ /Cleaning up PacketConfig/}.length).to eq 1
      expect(messages.select{|m| m =~ /Cleaning up PacketLogEntry/}.length).to eq 1
      expect(messages.select{|m| m =~ /Cleaning up Decommutation/}.length).to eq 1
      expect(messages.select{|m| m =~ /Database cleanup complete/}.length).to eq 1
    end
  end

  describe "clean_system_configs" do
    it "ensures all system configs are local" do
      # Create a bogus SystemConfig to cause an error
      SystemConfig.create(:name => "test")

      expect(Cosmos::Logger).to receive(:error) do |msg|
        expect(msg).to match(/Could not load system_config: test/)
      end
      config, error = @cleaner.clean_system_configs
      # Ensure the configuration is loaded
      expect(config).to eq Cosmos::System.configuration_name
    end
  end

  describe "clean_packet_logs" do
    before(:each) do
      @target = Target.create(:name => "test")
      @packet = Packet.create(:target_id => @target.id, :name => "test", :is_tlm => true)
    end

    it "ensures all packet logs exist" do
      # Create a good file which exists where we expect
      filename = File.join(Cosmos::System.paths['DART_DATA'], 'test_file.bin')
      File.open(filename, 'w') { |file| file.puts "This is test data" }
      packet_log = PacketLog.create(:filename => filename, :is_tlm => true)

      ple = PacketLogEntry.new
      ple.target_id = @target.id
      ple.packet_id = @packet.id
      ple.time = Time.now
      ple.packet_log_id = packet_log.id
      ple.data_offset = 0
      ple.meta_id = 0
      ple.is_tlm = true
      ple.ready = true
      ple.save!

      @cleaner.clean_packet_logs(false)
      # Ensure nothing changed
      log = PacketLog.find(1)
      expect(log.filename).to eq filename
      entry = PacketLogEntry.find(1)
      expect(entry.packet_log.filename).to eq filename
    end

    it "checks for files moved to DART_DATA and updates the path" do
      # Create a good file which exists where we expect
      filename = File.join(Cosmos::System.paths['DART_DATA'], 'test_file.bin')
      File.open(filename, 'w') { |file| file.puts "This is test data" }
      # Create a PacketLog with a bad path
      bad_path = File.join("C:/somewhere/that/does/not/exist", File.basename(filename))
      packet_log = PacketLog.create(:filename => bad_path, :is_tlm => true)

      ple = PacketLogEntry.new
      ple.target_id = @target.id
      ple.packet_id = @packet.id
      ple.time = Time.now
      ple.packet_log_id = packet_log.id
      ple.data_offset = 0
      ple.meta_id = 0
      ple.is_tlm = true
      ple.ready = true
      ple.save!

      @cleaner.clean_packet_logs(false)
      # Ensure the path is updated
      log = PacketLog.find(1)
      expect(log.filename).to eq filename
      entry = PacketLogEntry.find(1)
      expect(entry.packet_log.filename).to eq filename
    end

    it "exits if a file is missing and force == false" do
      # Create a PacketLog with a non-existant file
      packet_log = PacketLog.create(:filename => "C:/no/file/here/test.bin", :is_tlm => true)
      expect { @cleaner.clean_packet_logs(false) }.to raise_error(SystemExit)
    end

    it "deletes if a file is missing and force == true" do
      # Create a PacketLog with a non-existant file
      packet_log = PacketLog.create(:filename => "C:/no/file/here/test.bin", :is_tlm => true)
      10.times do
        ple = PacketLogEntry.new
        ple.target_id = @target.id
        ple.packet_id = @packet.id
        ple.time = Time.now
        ple.packet_log_id = packet_log.id
        ple.data_offset = 0
        ple.meta_id = 0
        ple.is_tlm = true
        ple.ready = true
        ple.save!
      end

      @cleaner.clean_packet_logs(true)
      expect { PacketLog.find(1) }.to raise_error(ActiveRecord::RecordNotFound)
      # Also any PacketLogEntries linked to that PacketLog are deleted
      expect(PacketLogEntry.all.count).to eq 0
    end
  end

  describe "clean_packet_configs" do
    it "raises if the SystemConfig can't be found" do
      target = Target.create(:name => "test")
      packet = Packet.create(:target_id => target.id, :name => "test", :is_tlm => true)
      PacketConfig.create(:packet_id => packet.id, :name => "test", :first_system_config_id => 1)
      expect { @cleaner.clean_packet_configs }.to raise_error(/Cleanup failure/)
    end

    it "complains about bad SystemConfigs" do
      @cleaner.sync_targets_and_packets
      target_id, packet_id = @cleaner.lookup_target_and_packet_id("INST", "HEALTH_STATUS", true)
      packet = Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS")
      sys_config = SystemConfig.create(:name => "test")
      PacketConfig.create(:packet_id => packet_id, :name => packet.config_name, :first_system_config_id => sys_config.id)

      expect(Cosmos::Logger).to receive(:error) do |msg|
        expect(msg).to match(/Could not switch to system config: test/)
      end
      @cleaner.clean_packet_configs
    end

    it "recreates the PacketConfig if it is not 'ready'" do
      @cleaner.sync_targets_and_packets
      target_id, packet_id = @cleaner.lookup_target_and_packet_id("INST", "HEALTH_STATUS", true)
      packet = Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS")
      meta_packet = Cosmos::System.telemetry.packet("SYSTEM", "META")
      sys_config = SystemConfig.create(:name => meta_packet.read("CONFIG"))
      PacketConfig.create(:packet_id => packet_id, :name => packet.config_name, :first_system_config_id => sys_config.id)

      # By default new PacketConfig items should not be marked ready
      packet_config = PacketConfig.where(:packet_id => packet_id, :name => packet.config_name, :first_system_config_id => sys_config.id).first
      expect(packet_config.ready).to be false

      item = Item.create(:packet_id => packet_id, :name => "TEST_ITEM")
      # Create an item to decom table mapping to ensure it gets cleaned up
      ItemToDecomTableMapping.create(
        :item_id => item.id,
        :value_type => ItemToDecomTableMapping::RAW,
        :reduced => true,
        :packet_config_id => packet_config.id,
        :table_index => 0,
        :item_index => 999999) # Bogus value we can check
      expect(ItemToDecomTableMapping.find_by_item_index(999999)).to_not be_nil
      # Create a decommutation table to ensure it gets cleaned up
      table_name = "t#{packet_config.id}_0"
      table = ActiveRecord::Base.connection.create_table(table_name) do |table|
        table.integer :delete_me # Bogus column
      end
      # Need to create model
      model = Class.new(ActiveRecord::Base) do
        self.table_name = table_name.dup
      end
      model.reset_column_information
      model_name = table_name.upcase
      Cosmos.send(:remove_const, model_name) if Cosmos.const_defined?(model_name)
      Cosmos.const_set(model_name, model)

      expect(model.column_names).to include("delete_me")
      # Create reduction tables to ensure they are cleaned up
      %w(_h _m _d).each do |id|
        table_name = "t#{packet_config.id}_0#{id}"
        table = ActiveRecord::Base.connection.create_table(table_name) do |table|
          table.integer :delete_me # Bogus column
        end
        # Need to create model
        model = Class.new(ActiveRecord::Base) do
          self.table_name = table_name.dup
        end
        model.reset_column_information
        model_name = table_name.upcase
        Cosmos.send(:remove_const, model_name) if Cosmos.const_defined?(model_name)
        Cosmos.const_set(model_name, model)

        expect(model.column_names).to include("delete_me")
      end
      messages = [] # Store all Logger.info messages
      allow(Cosmos::Logger).to receive(:info) { |msg| messages << msg }

      @cleaner.clean_packet_configs # <--- PERFORM THE TEST

      # Check messages for success
      expect(messages.select {|msg| msg =~ /Successfully cleaned/ }[0]).to match(/packet_config: 1/)
      packet_config = PacketConfig.where(:packet_id => packet_id, :name => packet.config_name, :first_system_config_id => sys_config.id).first
      expect(packet_config.ready).to be true # ready is not true
      # The item should still be there
      expect(Item.find(1).name).to eq "TEST_ITEM"
      # The old ItemToDecomTableMapping should be removed
      expect(ItemToDecomTableMapping.find_by_item_index(999999)).to be_nil
      # All new items should have the PacketConfig ID set
      ItemToDecomTableMapping.all.each do |item|
        expect(item.packet_config_id).to eq packet_config.id
      end
      # The decom table should have been recreated
      model = @cleaner.get_decom_table_model(packet_config.id, 0)
      expect(model.column_names).to_not include("delete_me")
      expect(model.column_names).to include("i0") # as well as i1, i2, etc
      # The reduction table should have been recreated
      %w(_h _m _d).each do |id|
      model = @cleaner.get_decom_table_model(packet_config.id, 0, id)
        expect(model.column_names).to_not include("delete_me")
        expect(model.column_names).to include("i0min")
        expect(model.column_names).to include("i0max")
        expect(model.column_names).to include("i0avg")
        expect(model.column_names).to include("i0stddev")
      end
    end
  end

  describe "clean_packet_log_entries" do
    it "removes PacketLogEntry rows where ready == false" do
      target = Target.create(:name => "test")
      packet = Packet.create(:target_id => target.id, :name => "test", :is_tlm => true)
      packet_log = PacketLog.create(:filename => "filename", :is_tlm => true)
      ple = PacketLogEntry.new
      ple.target_id = target.id
      ple.packet_id = packet.id
      ple.time = Time.now
      ple.packet_log_id = packet_log.id
      ple.data_offset = 1
      ple.meta_id = 1
      ple.is_tlm = true
      ple.ready = false
      ple.save!
      expect(PacketLogEntry.all.length).to eq 1
      @cleaner.clean_packet_log_entries
      expect(PacketLogEntry.all.length).to eq 0
    end
  end

  describe "clean_decommutation_tables" do
    it "removes decommutation rows which are in progress" do
      writer = DartPacketLogWriter.new(
        :TLM,    # Log telemetry
        'clean_decom_', # File name suffix
        true,    # Enable logging
        nil,     # Don't cycle on time
        2_000_000_000, # Cycle the log at 2GB
        Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir

      hs_packet = Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS")
      # Write three packets. The first packet is always SYSTEM META.
      3.times do
        hs_packet.received_time = Time.now
        writer.write(hs_packet)
        sleep 0.01
      end
      writer.shutdown
      sleep 0.1

      # Create a valid SystemConfig in order to create a valid PacketConfig
      meta = Cosmos::System.telemetry.packet("SYSTEM", "META")
      system_config = SystemConfig.create(:name => meta.read("CONFIG"))
      target_id, packet_id = writer.lookup_target_and_packet_id("INST", "HEALTH_STATUS", true)
      packet_config = PacketConfig.create(:packet_id => packet_id, :name => hs_packet.config_name, :first_system_config_id => system_config.id)
      writer.setup_packet_config(hs_packet, packet_id, packet_config)

      decom = writer.get_decom_table_model(packet_config.id, 0)
      PacketLogEntry.all.each do |ple|
        # By default all PacketLogEntries should be marked NOT_STARTED
        expect(ple.decom_state).to eq PacketLogEntry::NOT_STARTED
        case ple.target.name
        when 'SYSTEM'
          ple.decom_state = PacketLogEntry::COMPLETE
        when 'INST'
          ple.decom_state = PacketLogEntry::IN_PROGRESS
          row = decom.new
          row.time = Time.now
          row.reduced_state = DartDecommutator::INITIALIZING
          row.ple_id = ple.id
          row.save!
        end
        ple.save!
      end
      expect(decom.all.count).to eq 3

      @cleaner.clean_decommutation_tables # <--- PERFORM THE TEST

      PacketLogEntry.all.each do |ple|
        case ple.target.name
        when 'SYSTEM'
          expect(ple.decom_state).to eq PacketLogEntry::COMPLETE
        when 'INST'
          # All INST should be now marked NOT_STARTED
          expect(ple.decom_state).to eq PacketLogEntry::NOT_STARTED
        end
      end
      # The decommutation table has been cleaned
      decom = writer.get_decom_table_model(packet_config.id, 0)
      expect(decom.all.count).to eq 0
    end
  end

  describe "clean_decommutation_tables" do
    it "removes decommutation rows which are in progress" do
      writer = DartPacketLogWriter.new(
        :TLM,    # Log telemetry
        'clean_decom_', # File name suffix
        true,    # Enable logging
        nil,     # Don't cycle on time
        2_000_000_000, # Cycle the log at 2GB
        Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir

      hs_packet = Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS")
      # Write three packets. The first packet is always SYSTEM META.
      3.times do
        hs_packet.received_time = Time.now
        writer.write(hs_packet)
        sleep 0.01
      end
      writer.shutdown
      sleep 0.1

      # Create a valid SystemConfig in order to create a valid PacketConfig
      meta = Cosmos::System.telemetry.packet("SYSTEM", "META")
      system_config = SystemConfig.create(:name => meta.read("CONFIG"))
      target_id, packet_id = writer.lookup_target_and_packet_id("INST", "HEALTH_STATUS", true)
      packet_config = PacketConfig.create(:packet_id => packet_id, :name => hs_packet.config_name, :first_system_config_id => system_config.id)
      writer.setup_packet_config(hs_packet, packet_id, packet_config)

      decom = writer.get_decom_table_model(packet_config.id, 0)
      PacketLogEntry.all.each do |ple|
        # By default all PacketLogEntries should be marked NOT_STARTED
        expect(ple.decom_state).to eq PacketLogEntry::NOT_STARTED
        case ple.target.name
        when 'SYSTEM'
          ple.decom_state = PacketLogEntry::COMPLETE
        when 'INST'
          ple.decom_state = PacketLogEntry::IN_PROGRESS
          row = decom.new
          row.time = Time.now
          row.reduced_state = DartDecommutator::INITIALIZING
          row.ple_id = ple.id
          row.save!
        end
        ple.save!
      end
      expect(decom.all.count).to eq 3

      @cleaner.clean_decommutation_tables # <--- PERFORM THE TEST

      PacketLogEntry.all.each do |ple|
        case ple.target.name
        when 'SYSTEM'
          expect(ple.decom_state).to eq PacketLogEntry::COMPLETE
        when 'INST'
          # All INST should be now marked NOT_STARTED
          expect(ple.decom_state).to eq PacketLogEntry::NOT_STARTED
        end
      end
      # The decommutation table has been cleaned
      decom = writer.get_decom_table_model(packet_config.id, 0)
      expect(decom.all.count).to eq 0
    end
  end

  describe "clean_reductions" do
    it "removes decommutation rows which are in progress" do
      writer = DartPacketLogWriter.new(
        :TLM,    # Log telemetry
        'clean_reduction_', # File name suffix
        true,    # Enable logging
        nil,     # Don't cycle on time
        2_000_000_000, # Cycle the log at 2GB
        Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir

      hs_packet = Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS")
      # Write three packets. The first packet is always SYSTEM META.
      3.times do
        hs_packet.received_time = Time.now
        writer.write(hs_packet)
        sleep 0.01
      end
      writer.shutdown
      sleep 0.1

      # Create a valid SystemConfig in order to create a valid PacketConfig
      meta = Cosmos::System.telemetry.packet("SYSTEM", "META")
      system_config = SystemConfig.create(:name => meta.read("CONFIG"))
      target_id, packet_id = writer.lookup_target_and_packet_id("INST", "HEALTH_STATUS", true)
      packet_config = PacketConfig.create(:packet_id => packet_id, :name => hs_packet.config_name, :first_system_config_id => system_config.id)
      writer.setup_packet_config(hs_packet, packet_id, packet_config)

      decom = writer.get_decom_table_model(packet_config.id, 0)
      PacketLogEntry.all.each do |ple|
        # By default all PacketLogEntries should be marked NOT_STARTED
        expect(ple.decom_state).to eq PacketLogEntry::NOT_STARTED
        case ple.target.name
        when 'SYSTEM'
          ple.decom_state = PacketLogEntry::COMPLETE
        when 'INST'
          ple.decom_state = PacketLogEntry::IN_PROGRESS
          row = decom.new
          row.time = Time.now
          row.reduced_state = DartDecommutator::INITIALIZING
          row.ple_id = ple.id
          row.save!
        end
        ple.save!
      end
      expect(decom.all.count).to eq 3

      @cleaner.clean_decommutation_tables # <--- PERFORM THE TEST

      PacketLogEntry.all.each do |ple|
        case ple.target.name
        when 'SYSTEM'
          expect(ple.decom_state).to eq PacketLogEntry::COMPLETE
        when 'INST'
          # All INST should be now marked NOT_STARTED
          expect(ple.decom_state).to eq PacketLogEntry::NOT_STARTED
        end
      end
      # The decommutation table has been cleaned
      decom = writer.get_decom_table_model(packet_config.id, 0)
      expect(decom.all.count).to eq 0
    end
  end
end
