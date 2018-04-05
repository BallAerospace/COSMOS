# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'rails_helper'
require 'dart_decom_query'
require 'packet_log_entry'
require 'dart_packet_log_writer'
require 'dart_decommutator'

describe DartDecomQuery do
  before(:each) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
    @query = DartDecomQuery.new
    # Put all the known targets and packets into the DB
    @query.sync_targets_and_packets
  end

  def load_db(num_pkts)
    writer = DartPacketLogWriter.new(
      :TLM,    # Log telemetry
      'test_decom_', # File name suffix
      true,    # Enable logging
      nil,     # Don't cycle on time
      2_000_000_000, # Cycle the log at 2GB
      Cosmos::System.paths['DART_DATA']) # Log into the DART_DATA dir

    hs_packet = Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS")
    @hs_packets = []
    # Write packets. The first packet is always SYSTEM META.
    num_pkts.times do |x|
      hs_packet.received_time = Time.now
      hs_packet.write("COLLECT_TYPE", x, :RAW)
      @hs_packets << hs_packet.clone
      writer.write(hs_packet)
      sleep 0.01
    end
    writer.shutdown
    sleep 0.1

    # Decommutate the DB
    thread = Thread.new do
      decom = DartDecommutator.new
      decom.run
    end
    while true
      break if 0 == PacketLogEntry.where("decom_state = #{PacketLogEntry::NOT_STARTED}").count
      sleep 0.1
    end
    thread.kill
  end

  describe "query" do
    it "raises if start time specified incorrectly" do
      query = {"start_time_sec" => "SEC", "start_time_usec" => "USEC"}
      expect { @query.query(query) }.to raise_error(/Query Error: Invalid start time/)
    end

    it "raises if end time specified incorrectly" do
      query = {"end_time_sec" => "SEC", "end_time_usec" => "USEC"}
      expect { @query.query(query) }.to raise_error(/Query Error: Invalid end time/)
    end

    it "raises if item specified incorrectly" do
      expect { @query.query({"item" => []}) }.to raise_error(/Query Error: Item/)
      expect { @query.query({"item" => ["TGT"]}) }.to raise_error(/Query Error: Item/)
      expect { @query.query({"item" => ["TGT", "PKT"]}) }.to raise_error(/Query Error: Item/)
      RSpec::Expectations.configuration.on_potential_false_positives = :nothing
      expect { @query.query({"item" => ["TGT", "PKT", "ITEM"]}) }.not_to raise_error(/Query Error: Item/)
    end

    it "raises if item not found" do
      query = {"item" => ["TGT", "PKT", "ITEM"], "reduction" => "NONE", "value_type" => "RAW"}
      expect { @query.query(query) }.to raise_error(/Query Error: Target: TGT not found/)
      query = {"item" => ["INST", "PKT", "ITEM"], "reduction" => "NONE", "value_type" => "RAW"}
      expect { @query.query(query) }.to raise_error(/Query Error: Packet: PKT not found/)
      query = {"item" => ["INST", "HEALTH_STATUS", "BLAH"], "reduction" => "NONE", "value_type" => "RAW"}
      expect { @query.query(query) }.to raise_error(/Query Error: Item: BLAH not found/)
    end

    it "raises if reduction specified incorrectly" do
      query = {"item" => ["INST", "HEALTH_STATUS", "TEMP1"], "reduction" => "BLAH"}
      expect { @query.query(query) }.to raise_error(/Query Error: Unknown reduction: BLAH/)
    end

    it "raises if value_type specified incorrectly" do
      query = {"item" => ["INST", "HEALTH_STATUS", "TEMP1"], "reduction" => "NONE", "value_type" => "BLAH"}
      expect { @query.query(query) }.to raise_error(/Query Error: Unknown value_type: BLAH/)
    end

    it "raises if RAW value_type with anything but NONE reduction" do
      %w(MINUTE HOUR DAY).each do |reduction|
        query = {"item" => ["INST", "HEALTH_STATUS", "TEMP1"], "reduction" => reduction, "value_type" => "RAW"}
        expect { @query.query(query) }.to raise_error(/Query Error: RAW value_type is only valid with NONE/)
      end
    end

    it "raises if MIN, MAX, AVG value_type with NONE reduction" do
      %w(RAW_MIN RAW_MAX RAW_AVG CONVERTED_MIN CONVERTED_MAX CONVERTED_AVG).each do |type|
        query = {"item" => ["INST", "HEALTH_STATUS", "TEMP1"], "reduction" => "NONE", "value_type" => type}
        expect { @query.query(query) }.to raise_error(/Query Error: #{type} value_type is not valid with NONE/)
      end
    end

    it "raises if CONVERTED value_type with anything but NONE reduction" do
      %w(MINUTE HOUR DAY).each do |reduction|
        query = {"item" => ["INST", "HEALTH_STATUS", "TEMP1"], "reduction" => reduction, "value_type" => "CONVERTED"}
        expect { @query.query(query) }.to raise_error(/Query Error: CONVERTED value_type is only valid with NONE/)
      end
    end

    it "raises if cmd_tlm specified incorrectly" do
      query = {"item" => ["INST", "HEALTH_STATUS", "TEMP1"], "reduction" => "NONE", "value_type" => "RAW"}
      query["cmd_tlm"] = "BLAH"
      expect { @query.query(query) }.to raise_error(/Query Error: Unknown cmd_tlm: BLAH/)
    end

    it "returns the raw values" do
      load_db(3)
      query = {"item" => ["INST", "HEALTH_STATUS", "COLLECT_TYPE"], "reduction" => "NONE", "value_type" => "RAW"}
      query.merge({"cmd_tlm" => "TLM"})
      data = @query.query(query)
      i = 0
      data.each do |val, time_sec, time_usec, samples, meta_id|
        expect(val).to eql @hs_packets[i].read("COLLECT_TYPE", :RAW)
        expect(time_sec).to eq @hs_packets[i].received_time.to_i
        expect(time_usec).to eq ((@hs_packets[i].received_time.to_f - @hs_packets[i].received_time.to_i) * 1000000).round
        i += 1
      end
    end

    it "returns the converted values" do
      load_db(3)
      query = {"item" => ["INST", "HEALTH_STATUS", "COLLECT_TYPE"], "reduction" => "NONE", "value_type" => "CONVERTED"}
      query.merge({"cmd_tlm" => "TLM"})
      data = @query.query(query)
      i = 0
      data.each do |val, time_sec, time_usec, samples, meta_id|
        expect(val).to eql @hs_packets[i].read("COLLECT_TYPE").to_s
        expect(time_sec).to eq @hs_packets[i].received_time.to_i
        expect(time_usec).to eq ((@hs_packets[i].received_time.to_f - @hs_packets[i].received_time.to_i) * 1000000).round
        i += 1
      end
    end
  end
end
