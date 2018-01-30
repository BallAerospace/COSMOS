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
    def check_float(val, expected)
      if val.is_a? Float
        expect(val).to be_within(0.001).of expected
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
      sleep 1 # Allow the decommutator to work
      thread.exit

      PacketLogEntry.all.each do |ple|
        expect(ple.decom_state).to eq PacketLogEntry::COMPLETE
      end

      system_target = Target.where("name = 'SYSTEM'").first
      meta = Packet.where("target_id = ? AND name = 'META'", system_target.id).first
      packet_config = PacketConfig.where("packet_id = ?", meta.id).first
      model = writer.get_decom_table_model(packet_config.id, 0)

      meta_packet = Cosmos::System.telemetry.packet("SYSTEM","META")
      meta_item_names = meta_packet.sorted_items.collect {|item| item.name }
      expect(model.count).to eq 1 # One SYSTEM META packet
      meta_row = model.first
      expect(meta_row.reduced_state).to eq DartDecommutator::READY_TO_REDUCE
      # Grab all the iXX column names which hold the actual data values
      model.column_names.select {|name| name =~ /^i\d+/}.each_with_index do |item, index|
        # RECEIVED_COUNT doesn't match because we receive additional SYSTEM META packets
        # during decommutation that don't match those when writing the packet log entries
        next if meta_item_names[index] == 'RECEIVED_COUNT'
        db_value = meta_row.send(item.intern)
        check_float(db_value, meta_packet.read(meta_item_names[index]))
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
          # RECEIVED_COUNT doesn't match because DB counts while packet says 0
          # TEMP1MIN, TEMP1MAX, TEMP1MEAN don't match because db says -100 while packet says 0
          # Calling packet.process in clone seems to make them match because the packet
          # Processor gets set instead of being uninitialized
          if item.name == 'RECEIVED_COUNT' || item.name == 'TEMP1MAX' || item.name == 'TEMP1MIN' || item.name == 'TEMP1MEAN'
            db_index += 1
            next
          end
          # Database skips DERIVED items that aren't well defined
          if item.data_type == :DERIVED
            next unless item.read_conversion && item.read_conversion.converted_type && item.read_conversion.converted_bit_size
          end
          name = decom_column_names[db_index].intern
          db_value = row.send(name)
          #puts "#{db_index} item:#{item.name} db:#{db_value} raw pkt:#{packet.read_item(item, :RAW)}"
          check_float(db_value, packet.read_item(item, :RAW))
          if writer.separate_raw_con?(item)
            db_index += 1
            name = decom_column_names[db_index].intern
            db_value = row.send(name)
            #puts "#{db_index} citem:#{item.name} db:#{db_value} conv pkt:#{packet.read_item(item)}"
            check_float(db_value, packet.read_item(item))
          end
          db_index += 1
        end
      end
    end
  end
end
