# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'rails_helper'
require 'dart_common'
require 'database_cleaner'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'
require 'cosmos/tools/cmd_tlm_server/api'

describe DartCommon do
  let(:common) { Object.new.extend(DartCommon) }

  describe "sync_targets_and_packets" do
    it "configures the database" do
      targets = Cosmos::System.telemetry.all.keys.sort
      expect(targets).to eql Cosmos::System.commands.all.keys.sort

      # Put all the known targets and packets into the DB
      common.sync_targets_and_packets

      # Verify the targets
      Target.all.order(:name).each_with_index do |target, i|
        expect(target.name).to eq targets[i]
      end
      # Verify the telemetry packets
      Cosmos::System.telemetry.all.each do |target_name, packets|
        target = Target.find_by_name(target_name)
        expect(target.name).to eq target_name
        packets.each do |name, packet|
          pkt = Packet.where({target: target, name: name, is_tlm: true}).first
          expect(pkt.name).to eq name
          expect(pkt.is_tlm).to eq true
          expect(pkt.target.name).to eq target_name
        end
      end
      # Verify the command packets
      Cosmos::System.commands.all.each do |target_name, packets|
        target = Target.find_by_name(target_name)
        expect(target.name).to eq target_name
        packets.each do |name, packet|
          pkt = Packet.where({target: target, name: name, is_tlm: false}).first
          expect(pkt.name).to eq name
          expect(pkt.is_tlm).to eq false
          expect(pkt.target.name).to eq target_name
        end
      end

      num_tgts = Target.all.length
      tgt_created_at = Target.first.created_at
      num_pkts = Packet.all.length
      pkt_created_at = Packet.first.created_at
      #num_items = Item.all.length
      #item_created_at = Item.first.created_at

      # Try to add the known targets and packets into the DB again
      common.sync_targets_and_packets
      # Verify nothing was added
      expect(Target.all.length).to eq num_tgts
      expect(Packet.all.length).to eq num_pkts
      #expect(Item.all.length).to eq num_items
      expect(Target.first.created_at).to eq tgt_created_at
      expect(Packet.first.created_at).to eq pkt_created_at
      #expect(Item.first.created_at).to eq item_created_at
    end
  end

  describe "setup_packet_config" do
    it "builds the packet configuration in the DB" do
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

      packet = Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS")
      packet_config = PacketConfig.create(:packet_id => packet_id, :name => packet.config_name, :first_system_config_id => 0)
      common.setup_packet_config(packet, packet_id, packet_config)

      model = common.get_decom_table_model(packet_config.id, 0)
      expect(model.column_names).to include("i0")
      model = common.get_decom_table_model(packet_config.id, 0, '_m')
      expect(model.column_names).to include("i0min")
      expect(model.column_names).to include("i0max")
      expect(model.column_names).to include("i0avg")
      expect(model.column_names).to include("i0stddev")
      model = common.get_decom_table_model(packet_config.id, 0, '_h')
      expect(model.column_names).to include("i0min")
      expect(model.column_names).to include("i0max")
      expect(model.column_names).to include("i0avg")
      expect(model.column_names).to include("i0stddev")
      model = common.get_decom_table_model(packet_config.id, 0, '_d')
      expect(model.column_names).to include("i0min")
      expect(model.column_names).to include("i0max")
      expect(model.column_names).to include("i0avg")
      expect(model.column_names).to include("i0stddev")

      # Useful debugging to pring out all the mapping items
      # ItemToDecomTableMapping.all.each do |map|
      #   item = Item.find(map.item_id)
      #   puts "item name:#{item.name} id:#{item.id} val:#{map.value_type} reduced:#{map.reduced} config:#{map.packet_config_id} table_i:#{map.table_index} item_i:#{map.item_index}"
      # end

      ###################################
      # Spot check some interesting items
      ###################################

      item = Item.find_by_name("RECEIVED_TIMESECONDS")
      mapping = ItemToDecomTableMapping.where("item_id = ?", item.id)
      # RECEIVED_TIMESECONDS is derived so it has a single mapping
      expect(mapping.length).to eq 1
      map = mapping.first
      expect(map.value_type).to eq ItemToDecomTableMapping::RAW_CON
      expect(map.reduced).to eq true # Seconds is an integer so it can be reduced
      expect(map.packet_config_id).to eq packet_config.id
      expect(map.table_index).to eq 0 # Not enough values to span multiple tables

      item = Item.find_by_name("RECEIVED_TIMEFORMATTED")
      mapping = ItemToDecomTableMapping.where("item_id = ?", item.id)
      # RECEIVED_TIMEFORMATTED is derived so it has a single mapping
      expect(mapping.length).to eq 1
      map = mapping.first
      expect(map.value_type).to eq ItemToDecomTableMapping::RAW_CON
      expect(map.reduced).to eq false # Formatted is a string so it can't be reduced
      expect(map.packet_config_id).to eq packet_config.id
      expect(map.table_index).to eq 0 # Not enough values to span multiple tables

      item = Item.find_by_name("TEMP1")
      mapping = ItemToDecomTableMapping.where("item_id = ?", item.id)
      # TEMP1 creates a separate RAW and CONVERTED table since it has a conversion
      expect(mapping.length).to eq 2
      map = mapping.where("value_type = ?", ItemToDecomTableMapping::RAW).first
      expect(map.value_type).to eq ItemToDecomTableMapping::RAW
      expect(map.reduced).to eq true # UINT32 can be reduced
      expect(map.packet_config_id).to eq packet_config.id
      expect(map.table_index).to eq 0 # Not enough values to span multiple tables
      map = mapping.where("value_type = ?", ItemToDecomTableMapping::CONVERTED).first
      expect(map.value_type).to eq ItemToDecomTableMapping::CONVERTED
      expect(map.reduced).to eq true # UINT32 can be reduced
      expect(map.packet_config_id).to eq packet_config.id
      expect(map.table_index).to eq 0 # Not enough values to span multiple tables

      item = Item.find_by_name("GROUND1STATUS")
      mapping = ItemToDecomTableMapping.where("item_id = ?", item.id)
      # GROUND1STATUS creates a separate RAW and CONVERTED table since it has states
      expect(mapping.length).to eq 2
      map = mapping.where("value_type = ?", ItemToDecomTableMapping::RAW).first
      expect(map.value_type).to eq ItemToDecomTableMapping::RAW
      expect(map.reduced).to eq true # Raw value can be reduced
      expect(map.packet_config_id).to eq packet_config.id
      expect(map.table_index).to eq 0 # Not enough values to span multiple tables
      map = mapping.where("value_type = ?", ItemToDecomTableMapping::CONVERTED).first
      expect(map.value_type).to eq ItemToDecomTableMapping::CONVERTED
      expect(map.reduced).to eq false # Converted is a string and can't be reduced
      expect(map.packet_config_id).to eq packet_config.id
      expect(map.table_index).to eq 0 # Not enough values to span multiple tables
    end

    it "spans multiple DB tables with big packets" do
      # Create a new packet with a bunch of items
      packet = Cosmos::Packet.new('INST', 'BIGGIE', :BIG_ENDIAN)
      num_items = DartCommon::MAX_COLUMNS_PER_TABLE + 1
      num_items.times do |index|
        packet.append_item("ITEM#{index}", 8, :INT)
      end
      # Push the new packet into the PacketConfig telemetry hash
      Cosmos::System.telemetry.config.telemetry['INST']['BIGGIE'] = packet
      common.sync_targets_and_packets
      target_id, packet_id = common.lookup_target_and_packet_id("INST", "BIGGIE", true)
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

      packet = Cosmos::System.telemetry.packet("INST", "BIGGIE")
      packet_config = PacketConfig.create(:packet_id => packet_id, :name => packet.config_name, :first_system_config_id => 0)
      common.setup_packet_config(packet, packet_id, packet_config)

      # Verify the decommutation and reduction tables were created
      (0..1).each do |table_index|
        model = common.get_decom_table_model(packet_config.id, table_index)
        if table_index == 0
          expect(model.column_names).to include("i0")
          expect(model.column_names).to include("i#{DartCommon::MAX_COLUMNS_PER_TABLE - 1}")
          # The base decommutation table doesn't average
          expect(model.column_names).to_not include("i0avg")
          expect(model.column_names).to_not include("i0stddev")
        else
          expect(model.column_names).to include("i#{DartCommon::MAX_COLUMNS_PER_TABLE}")
          expect(model.column_names).to_not include("i#{DartCommon::MAX_COLUMNS_PER_TABLE + 1}")
        end

        %w(m h d).each do |suffix|
          model = common.get_decom_table_model(packet_config.id, table_index, "_#{suffix}")
          if table_index == 0
            # The decommutation tables have min max avg only
            expect(model.column_names).to_not include("i0")
            expect(model.column_names).to include("i0min")
            expect(model.column_names).to include("i0max")
            expect(model.column_names).to include("i0avg")
            expect(model.column_names).to include("i0stddev")
            expect(model.column_names).to include("i#{DartCommon::MAX_COLUMNS_PER_TABLE - 1}min")
            expect(model.column_names).to include("i#{DartCommon::MAX_COLUMNS_PER_TABLE - 1}max")
            expect(model.column_names).to include("i#{DartCommon::MAX_COLUMNS_PER_TABLE - 1}avg")
            expect(model.column_names).to include("i#{DartCommon::MAX_COLUMNS_PER_TABLE - 1}stddev")
          else
            expect(model.column_names).to include("i#{DartCommon::MAX_COLUMNS_PER_TABLE}min")
            expect(model.column_names).to include("i#{DartCommon::MAX_COLUMNS_PER_TABLE}max")
            expect(model.column_names).to include("i#{DartCommon::MAX_COLUMNS_PER_TABLE}avg")
            expect(model.column_names).to include("i#{DartCommon::MAX_COLUMNS_PER_TABLE}stddev")
          end
        end
      end

      num_items.times do |index|
        item = Item.where("name = ? AND packet_id = ?", "ITEM#{index}", packet_id).first
        map = ItemToDecomTableMapping.where("item_id = ?", item.id).first
        if index < DartCommon::MAX_COLUMNS_PER_TABLE
          expect(map.table_index).to eq 0
        else
          expect(map.table_index).to eq 1 # Mapping spans another table
        end
      end
    end
  end

  describe "switch_and_get_system_config" do
    before(:each) do
      allow_any_instance_of(Cosmos::Interface).to receive(:connected?)
      allow_any_instance_of(Cosmos::Interface).to receive(:connect)
      allow_any_instance_of(Cosmos::Interface).to receive(:disconnect)
      allow_any_instance_of(Cosmos::Interface).to receive(:write_raw)
      allow_any_instance_of(Cosmos::Interface).to receive(:read)
      allow_any_instance_of(Cosmos::Interface).to receive(:write)
      @tlm_file = File.join(Cosmos::USERPATH,'config','targets','SYSTEM','cmd_tlm','test1_tlm.txt')
      FileUtils.rm @tlm_file if File.exist? @tlm_file
    end

    it "raises an error if the configuration can't be found" do
      api = Cosmos::CmdTlmServer.new
      expect { common.switch_and_get_system_config("abcd") }.to raise_error(/No saved config/)
      api.stop
    end

    it "does nothing if loading the current config" do
      api = Cosmos::CmdTlmServer.new
      current = Cosmos::System.configuration_name
      common.switch_and_get_system_config(current)
      expect(Cosmos::System.configuration_name).to eq current
      api.stop
    end

    it "loads new configuration" do
      api = Cosmos::CmdTlmServer.new
      initial_config = Cosmos::System.configuration_name

      # Create a new configuration by writing another telemetry file
      File.open(@tlm_file, 'w') do |file|
        file.puts "TELEMETRY SYSTEM TEST1 BIG_ENDIAN"
        file.puts "  APPEND_ITEM DATA 240 STRING"
      end
      # Reset the instance variable so it will create the new configuration
      Cosmos::System.class_eval('@@instance = nil')
      Cosmos::System.telemetry # Create the new config
      new_config = Cosmos::System.configuration_name
      expect(new_config).to_not eq initial_config

      # Stub find_configuration to first return nil (not found) and then work
      # This allows the switch_and_get_system_config to act like the local copy
      # could not be found and then properly finds it
      allow(Cosmos::System.instance).to receive(:find_configuration).and_return(nil, Cosmos::System.instance.find_configuration(initial_config))
      messages = []
      allow(Cosmos::Logger).to receive(:info) { |msg| messages << msg }

      common.switch_and_get_system_config(initial_config)
      expect(Cosmos::System.configuration_name).to eq initial_config
      messages.each do |msg|
        if msg =~ /Configuration retrieved/
          expect(msg).to match(/#{initial_config}/)
        end
      end

      api.stop
      FileUtils.rm @tlm_file
    end
  end

  describe "read_packet_from_ple" do
    # NOTE: most of read_packet_from_ple is tested in the dart_packet_log_writer_spec
    it "raises an error if the packet can't be found" do
      common.sync_targets_and_packets
      target_id, packet_id = common.lookup_target_and_packet_id("INST", "HEALTH_STATUS", true)
      packet_log = PacketLog.create(:filename => "filename", :is_tlm => true)
      ple = PacketLogEntry.new
      ple.target_id = target_id
      ple.packet_id = packet_id
      ple.time = Time.now
      ple.packet_log_id = packet_log.id
      ple.data_offset = 999
      ple.meta_id = 999
      ple.is_tlm = true
      ple.ready = true
      ple.save!

      expect(Cosmos::Logger).to receive(:error) do |msg|
        expect(msg).to match(/Error Reading Packet/)
      end
      packet = common.read_packet_from_ple(ple)
      expect(packet).to be_nil
    end
  end
end
