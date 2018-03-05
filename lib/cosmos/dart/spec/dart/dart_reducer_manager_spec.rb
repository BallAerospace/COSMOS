# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'rails_helper'
require 'dart_reducer_manager'
require 'database_cleaner'
require 'dart_packet_log_writer'
require 'dart_decommutator'
require 'dart_common'

describe DartReducerManager do
  let(:common) { Object.new.extend(DartCommon) }

  before(:each) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
  end

  def setup_ples(entries, delta_time)
    time = Time.utc(2018, 1, 1, 0, 0, 0)
    meta = Cosmos::System.telemetry.packet("SYSTEM", "META")
    meta.received_time = time
    hs_packet = Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS")
    # 128 byte file header, SYSTEM META has 14 byte header + length of SYSTEM & META
    # INST HEALTH_STATUS has 14 byte header + length of INST & HEALTH_STATUS
    length = 128 + 24 + meta.length + entries * (31 + hs_packet.length)

    writer = DartPacketLogWriter.new(
      :TLM,    # Log telemetry
      'test_decom_', # File name suffix
      true,    # Enable logging
      nil,     # Don't cycle on time
      length, # Cycle the log after a single INST HEALTH_STATUS packet
      Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir

    entries.times do |x|
      hs_packet.received_time = time
      hs_packet.write("COLLECTS", x)
      writer.write(hs_packet)
      time += delta_time
    end
    ples = 0
    count = 0
    while ples != (entries + 1) # SYSTEM META is the plus 1
      ples = PacketLogEntry.count
      sleep 0.1 # Allow the log writer to work
      count += 1
      break if count == 100 # 10s
    end
    writer.shutdown
    sleep 0.1
    expect(count).to be < 100

    thread = Thread.new do
      decom = DartDecommutator.new
      decom.run
    end
    complete = 0
    count = 0
    while complete != (entries + 1) # SYSTEM META is the plus 1
      complete = PacketLogEntry.where("decom_state = #{PacketLogEntry::COMPLETE}").length
      sleep 0.1 # Allow the decommutator to work
      count += 1
      break if count == 200 # 20s
    end
    expect(count).to be < 200
    thread.kill
  end

  def worker_threads
    count = 0
    Thread.list.each do |t|
      count += 1 if t.inspect.include?("worker_thread")
    end
    count
  end

  def get_mappings(tgt, pkt, item)
    target_model = Target.where("name = ?", tgt).first
    packet_model = Packet.where("target_id = ? and name = ? and is_tlm = ?", target_model.id, pkt, true).first
    item_model = Item.where("packet_id = ? and name = ?", packet_model.id, item).first
    mappings = ItemToDecomTableMapping.where("item_id = ? and value_type != ?", item_model.id, ItemToDecomTableMapping::RAW)
  end

  describe "run" do
    it "starts the specified number of worker threads" do
      drm = DartReducerManager.new(1)
      thread = Thread.new { drm.run }
      sleep 0.1
      expect(worker_threads()).to eq 1
      drm.shutdown
      thread.kill

      drm = DartReducerManager.new(5)
      thread = Thread.new { drm.run }
      sleep 0.1
      expect(worker_threads()).to eq 5
      drm.shutdown
      thread.kill
    end

    it "reduces per minute" do
      setup_ples(11, 6) # 11 entries with a 6s gap
      drm = DartReducerManager.new(1)
      thread = Thread.new { drm.run }
      sleep 0.1
      drm.shutdown
      thread.kill

      get_mappings("INST", "HEALTH_STATUS", "COLLECTS").each do |mapping|
        # Grab the base reduction table
        rows = common.get_decom_table_model(mapping.packet_config_id, mapping.table_index)
        expect(rows.where("reduced_state" => DartCommon::INITIALIZING).count).to eq 0
        # The last one doesn't get reduced
        expect(rows.where("reduced_state" => DartCommon::READY_TO_REDUCE).count).to eq 1
        # Everything else should be reduced
        expect(rows.where("reduced_state" => DartCommon::REDUCED).count).to eq 10
        val = 0
        rows.find_each do |row|
          expect(row.read_attribute("i#{mapping.item_index}")).to eq val
          val += 1
        end

        # Grab the minute reduction table
        rows = common.get_decom_table_model(mapping.packet_config_id, mapping.table_index, "_m")
        expect(rows.where("reduced_state" => DartCommon::INITIALIZING).count).to eq 0
        # We only spanned a single minute so we have a single packet ready to reduce
        expect(rows.where("reduced_state" => DartCommon::READY_TO_REDUCE).count).to eq 1
        # None have been actually reduced
        expect(rows.where("reduced_state" => DartCommon::REDUCED).count).to eq 0
        rows.find_each do |row|
          expect(row.num_samples).to eq 10
          expect(row.read_attribute("i#{mapping.item_index}min")).to eq 0
          expect(row.read_attribute("i#{mapping.item_index}max")).to eq 9
          expect(row.read_attribute("i#{mapping.item_index}avg")).to eq ((0..9).to_a.sum / 10.0)
        end
      end
    end

    it "reduces per hour" do
      # 367 entries at 10s apart creates 3670.367s which is 1hr, 1min and 10s of time
      # The extra 10s is due to the last one not getting reduced. The extra minute is due
      # to the last minute reduction table not getting reduced.
      setup_ples(367, 10.001)
      drm = DartReducerManager.new(1)
      thread = Thread.new { drm.run }
      sleep 1
      drm.shutdown
      thread.kill

      get_mappings("INST", "HEALTH_STATUS", "COLLECTS").each do |mapping|
        # Grab the base reduction table
        rows = common.get_decom_table_model(mapping.packet_config_id, mapping.table_index)
        expect(rows.where("reduced_state" => DartCommon::INITIALIZING).count).to eq 0
        # The last one doesn't get reduced
        expect(rows.where("reduced_state" => DartCommon::READY_TO_REDUCE).count).to eq 1
        # Everything else should be reduced
        expect(rows.where("reduced_state" => DartCommon::REDUCED).count).to eq 366
        val = 0
        rows.find_each do |row|
          expect(row.read_attribute("i#{mapping.item_index}")).to eq val
          val += 1
        end

        # Grab the minute reduction table
        rows = common.get_decom_table_model(mapping.packet_config_id, mapping.table_index, "_m")
        expect(rows.where("reduced_state" => DartCommon::INITIALIZING).count).to eq 0
        # The last one doesn't get reduced
        expect(rows.where("reduced_state" => DartCommon::READY_TO_REDUCE).count).to eq 1
        # We reduced 60 minutes
        expect(rows.where("reduced_state" => DartCommon::REDUCED).count).to eq 60
        row = rows.first
        expect(row.num_samples).to eq 6
        expect(row.read_attribute("i#{mapping.item_index}min")).to eq 0
        expect(row.read_attribute("i#{mapping.item_index}max")).to eq 5
        expect(row.read_attribute("i#{mapping.item_index}avg")).to eq ((0..5).to_a.sum / 6.0)

        # Grab the hour reduction table
        rows = common.get_decom_table_model(mapping.packet_config_id, mapping.table_index, "_h")
        expect(rows.where("reduced_state" => DartCommon::INITIALIZING).count).to eq 0
        # We only spanned a single hour so we have a single packet ready to reduce
        expect(rows.where("reduced_state" => DartCommon::READY_TO_REDUCE).count).to eq 1
        # None have been actually reduced
        expect(rows.where("reduced_state" => DartCommon::REDUCED).count).to eq 0
        row = rows.first
        expect(row.num_samples).to eq 60
        expect(row.read_attribute("i#{mapping.item_index}min")).to eq 0
        expect(row.read_attribute("i#{mapping.item_index}max")).to eq 359
        expect(row.read_attribute("i#{mapping.item_index}avg")).to eq ((0..359).to_a.sum / 360.0)
      end
    end

    it "reduces per day" do
      # 72 is three days plus the extra reduction, minute, and hour
      setup_ples(75, 3600.001)
      drm = DartReducerManager.new(1)
      thread = Thread.new { drm.run }
      sleep 1
      drm.shutdown
      thread.kill

      drm = DartReducerManager.new(1)
      thread = Thread.new { drm.run }
      sleep 1
      drm.shutdown
      thread.kill

      get_mappings("INST", "HEALTH_STATUS", "COLLECTS").each do |mapping|
        # Grab the base reduction table
        rows = common.get_decom_table_model(mapping.packet_config_id, mapping.table_index)
        expect(rows.where("reduced_state" => DartCommon::INITIALIZING).count).to eq 0
        # The last one doesn't get reduced
        expect(rows.where("reduced_state" => DartCommon::READY_TO_REDUCE).count).to eq 1
        # Everything else should be reduced
        expect(rows.where("reduced_state" => DartCommon::REDUCED).count).to eq 74
        val = 0
        rows.find_each do |row|
          expect(row.read_attribute("i#{mapping.item_index}")).to eq val
          val += 1
        end

        # Grab the minute reduction table
        rows = common.get_decom_table_model(mapping.packet_config_id, mapping.table_index, "_m")
        expect(rows.where("reduced_state" => DartCommon::INITIALIZING).count).to eq 0
        # The last one doesn't get reduced
        expect(rows.where("reduced_state" => DartCommon::READY_TO_REDUCE).count).to eq 1
        # The rest is reduced
        expect(rows.where("reduced_state" => DartCommon::REDUCED).count).to eq 73
        val = 0
        rows.find_each do |row|
          # Since our samples were more than 1 min apart there is only 1 sample per row
          expect(row.num_samples).to eq 1
          # Min, max, and avg are all the same since we only have 1 sample
          expect(row.read_attribute("i#{mapping.item_index}min")).to eq val
          expect(row.read_attribute("i#{mapping.item_index}max")).to eq val
          expect(row.read_attribute("i#{mapping.item_index}avg")).to eq val
          val += 1
        end

        # Grab the hour reduction table
        rows = common.get_decom_table_model(mapping.packet_config_id, mapping.table_index, "_h")
        expect(rows.where("reduced_state" => DartCommon::INITIALIZING).count).to eq 0
        # The last one doesn't get reduced
        expect(rows.where("reduced_state" => DartCommon::READY_TO_REDUCE).count).to eq 1
        # The rest is reduced
        expect(rows.where("reduced_state" => DartCommon::REDUCED).count).to eq 72
        val = 0
        rows.find_each do |row|
          # Since our samples were more than 1 hour apart there is only 1 sample per row
          expect(row.num_samples).to eq 1
          # Min, max, and avg are all the same since we only have 1 sample
          expect(row.read_attribute("i#{mapping.item_index}min")).to eq val
          expect(row.read_attribute("i#{mapping.item_index}max")).to eq val
          expect(row.read_attribute("i#{mapping.item_index}avg")).to eq val
          val += 1
        end

        # Grab the day reduction table
        rows = common.get_decom_table_model(mapping.packet_config_id, mapping.table_index, "_d")
        expect(rows.where("reduced_state" => DartCommon::INITIALIZING).count).to eq 0
        # Day values are always "READY" since they don't get further reduced
        expect(rows.where("reduced_state" => DartCommon::READY_TO_REDUCE).count).to eq 3
        # Reduced is always 0
        expect(rows.where("reduced_state" => DartCommon::REDUCED).count).to eq 0
        val = 0
        rows.find_each do |row|
          expect(row.num_samples).to eq 24
          expect(row.read_attribute("i#{mapping.item_index}min")).to eq val
          expect(row.read_attribute("i#{mapping.item_index}max")).to eq val + 23
          expect(row.read_attribute("i#{mapping.item_index}avg")).to eq ((val..(val+23)).to_a.sum / 24.0)
          val += 24
        end
      end
    end
  end
end
