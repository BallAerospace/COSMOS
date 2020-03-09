# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/packets/telemetry'
require 'tempfile'

module Cosmos

  describe Telemetry do

    describe "initialize" do
      it "has no warnings" do
        expect(Telemetry.new(PacketConfig.new).warnings).to be_empty
      end
    end

    before(:each) do
      tf = Tempfile.new('unittest')
      tf.puts '# This is a comment'
      tf.puts '#'
      tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "TGT1 PKT1 Description"'
      tf.puts '  APPEND_ID_ITEM item1 8 UINT 1 "Item1"'
      tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 4 5'
      tf.puts '  APPEND_ITEM item2 8 UINT "Item2"'
      tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 4 5'
      tf.puts '  APPEND_ITEM item3 8 UINT "Item3"'
      tf.puts '    POLY_READ_CONVERSION 0 2'
      tf.puts '  APPEND_ITEM item4 8 UINT "Item4"'
      tf.puts '    POLY_READ_CONVERSION 0 2'
      tf.puts 'TELEMETRY tgt1 pkt2 LITTLE_ENDIAN "TGT1 PKT2 Description"'
      tf.puts '  APPEND_ID_ITEM item1 8 UINT 2 "Item1"'
      tf.puts '  APPEND_ITEM item2 8 UINT "Item2"'
      tf.puts 'TELEMETRY tgt2 pkt1 LITTLE_ENDIAN "TGT2 PKT1 Description"'
      tf.puts '  APPEND_ID_ITEM item1 8 UINT 3 "Item1"'
      tf.puts '  APPEND_ITEM item2 8 UINT "Item2"'
      tf.close

      pc = PacketConfig.new
      pc.process_file(tf.path, "SYSTEM")
      @tlm = Telemetry.new(pc)
      tf.unlink
    end

    describe "target_names" do
      it "returns an empty array if no targets" do
        expect(Telemetry.new(PacketConfig.new).target_names).to eql []
      end

      it "returns all target names" do
        expect(@tlm.target_names).to eql ["TGT1","TGT2"]
      end
    end

    describe "packets" do
      it "complains about non-existant targets" do
        expect { @tlm.packets("tgtX") }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "returns all packets target TGT1" do
        pkts = @tlm.packets("TGT1")
        expect(pkts.length).to eql 2
        expect(pkts.keys).to include("PKT1")
        expect(pkts.keys).to include("PKT2")
      end

      it "returns all packets target TGT2" do
        pkts = @tlm.packets("TGT2")
        expect(pkts.length).to eql 1
        expect(pkts.keys).to include("PKT1")
      end
    end

    describe "packet" do
      it "complains about non-existant targets" do
        expect { @tlm.packet("tgtX","pkt1") }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @tlm.packet("TGT1","PKTX") }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 PKTX' does not exist")
      end

      it "complains about the 'LATEST' packet" do
        expect { @tlm.packet("TGT1","LATEST") }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 LATEST' does not exist")
      end

      it "returns the specified packet" do
        pkt = @tlm.packet("TGT1","PKT1")
        expect(pkt.target_name).to eql "TGT1"
        expect(pkt.packet_name).to eql "PKT1"
      end
    end

    describe "items" do
      it "complains about non-existant targets" do
        expect { @tlm.items("tgtX","pkt1") }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @tlm.items("TGT1","PKTX") }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 PKTX' does not exist")
      end

      it "complains about the 'LATEST' packet" do
        expect { @tlm.items("TGT1","LATEST") }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 LATEST' does not exist")
      end

      it "returns all items from packet TGT1/PKT1" do
        items = @tlm.items("TGT1","PKT1")
        expect(items.length).to eql 9
        expect(items[0].name).to eql "PACKET_TIMESECONDS"
        expect(items[1].name).to eql "PACKET_TIMEFORMATTED"
        expect(items[2].name).to eql "RECEIVED_TIMESECONDS"
        expect(items[3].name).to eql "RECEIVED_TIMEFORMATTED"
        expect(items[4].name).to eql "RECEIVED_COUNT"
        expect(items[5].name).to eql "ITEM1"
        expect(items[6].name).to eql "ITEM2"
        expect(items[7].name).to eql "ITEM3"
        expect(items[8].name).to eql "ITEM4"
      end
    end

    describe "item_names" do
      it "returns all the items for a given target and packet" do
        items = @tlm.item_names("TGT1","PKT1")
        expect(items).to contain_exactly('PACKET_TIMEFORMATTED', 'PACKET_TIMESECONDS', 'RECEIVED_TIMEFORMATTED','RECEIVED_TIMESECONDS','RECEIVED_COUNT','ITEM1','ITEM2','ITEM3','ITEM4')

        items = @tlm.item_names("TGT1","LATEST")
        expect(items).to contain_exactly('ITEM1','ITEM2','ITEM3','ITEM4')
      end
    end

    describe "packet_and_item" do
      it "complains about non-existant targets" do
        expect { @tlm.packet_and_item("tgtX","pkt1","item1") }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @tlm.packet_and_item("TGT1","PKTX","ITEM1") }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 PKTX' does not exist")
      end

      it "complains about non-existant items" do
        expect { @tlm.packet_and_item("TGT1","PKT1","ITEMX") }.to raise_error(RuntimeError, "Packet item 'TGT1 PKT1 ITEMX' does not exist")
      end

      it "returns the packet and item" do
        _, item = @tlm.packet_and_item("TGT1","PKT1","ITEM1")
        expect(item.name).to eql "ITEM1"
      end

      it "returns the LATEST packet and item if it exists" do
        pkt,item = @tlm.packet_and_item("TGT1","LATEST","ITEM1")
        expect(pkt.packet_name).to eql "PKT2"
        expect(item.name).to eql "ITEM1"
      end
    end

    describe "latest_packets" do
      it "complains about non-existant targets" do
        expect { @tlm.latest_packets("tgtX","item1") }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "complains about non-existant items" do
        expect { @tlm.latest_packets("TGT1","ITEMX") }.to raise_error(RuntimeError, "Telemetry item 'TGT1 LATEST ITEMX' does not exist")
      end

      it "returns the packets that contain the item" do
        pkts = @tlm.latest_packets("TGT1","ITEM1")
        expect(pkts.length).to eql 2
        expect(pkts[0].packet_name).to eql "PKT1"
        expect(pkts[1].packet_name).to eql "PKT2"
      end
    end

    describe "newest_packet" do
      it "complains about non-existant targets" do
        expect { @tlm.newest_packet("tgtX","item1") }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "complains about non-existant items" do
        expect { @tlm.newest_packet("TGT1","ITEMX") }.to raise_error(RuntimeError, "Telemetry item 'TGT1 LATEST ITEMX' does not exist")
      end

      context "with two valid timestamps" do
        it "returns the latest packet (PKT1)" do
          time = Time.now
          @tlm.packet("TGT1","PKT1").received_time = time + 1
          @tlm.packet("TGT1","PKT2").received_time = time
          pkt = @tlm.newest_packet("TGT1","ITEM1")
          expect(pkt.packet_name).to eql "PKT1"
          expect(pkt.received_time).to eql(time + 1)
        end

        it "returns the latest packet (PKT2)" do
          time = Time.now
          @tlm.packet("TGT1","PKT1").received_time = time
          @tlm.packet("TGT1","PKT2").received_time = time + 1
          pkt = @tlm.newest_packet("TGT1","ITEM1")
          expect(pkt.packet_name).to eql "PKT2"
          expect(pkt.received_time).to eql(time + 1)
        end

        it "returns the last packet if timestamps are equal" do
          time = Time.now
          @tlm.packet("TGT1","PKT1").received_time = time
          @tlm.packet("TGT1","PKT2").received_time = time
          pkt = @tlm.newest_packet("TGT1","ITEM1")
          expect(pkt.packet_name).to eql "PKT2"
          expect(pkt.received_time).to eql(time)
        end
      end

      context "with one or more nil timestamps" do
        it "returns the last packet if neither has a timestamp" do
          pkt = @tlm.newest_packet("TGT1","ITEM1")
          expect(pkt.packet_name).to eql "PKT2"
          expect(pkt.received_time).to be_nil
        end

        it "returns the packet with a timestamp (PKT1)" do
          time = Time.now
          @tlm.packet("TGT1","PKT1").received_time = time
          pkt = @tlm.newest_packet("TGT1","ITEM1")
          expect(pkt.packet_name).to eql "PKT1"
          expect(pkt.received_time).to eql time
        end

        it "returns the packet with a timestamp (PKT2)" do
          time = Time.now
          @tlm.packet("TGT1","PKT2").received_time = time
          pkt = @tlm.newest_packet("TGT1","ITEM1")
          expect(pkt.packet_name).to eql "PKT2"
          expect(pkt.received_time).to eql time
        end
      end
    end

    describe "identify!" do
      it "returns nil with a nil buffer" do
        expect(@tlm.identify!(nil)).to be_nil
      end

      it "only checks the targets given" do
        buffer = "\x01\x02\x03\x04"
        @tlm.identify!(buffer,["TGT1"])
        pkt = @tlm.packet("TGT1","PKT1")
        pkt.enable_method_missing
        expect(pkt.item1).to eql 1
        expect(pkt.item2).to eql 2
        expect(pkt.item3).to eql 6.0
        expect(pkt.item4).to eql 8.0
      end
      
      it "works in unique id mode and not" do
        System.targets["TGT1"] = Target.new("TGT1")
        target = System.targets["TGT1"]
        buffer = "\x01\x02\x03\x04"
        target.tlm_unique_id_mode = false
        pkt = @tlm.identify!(buffer,["TGT1"])
        pkt.enable_method_missing
        expect(pkt.item1).to eql 1
        expect(pkt.item2).to eql 2
        expect(pkt.item3).to eql 6.0
        expect(pkt.item4).to eql 8.0
        buffer = "\x01\x02\x01\x02"
        target.tlm_unique_id_mode = true
        @tlm.identify!(buffer,["TGT1"])
        pkt = @tlm.packet("TGT1","PKT1")
        pkt.enable_method_missing
        expect(pkt.item1).to eql 1
        expect(pkt.item2).to eql 2
        expect(pkt.item3).to eql 2.0
        expect(pkt.item4).to eql 4.0        
        target.tlm_unique_id_mode = false
      end      

      it "returns nil with unknown targets given" do
        buffer = "\x01\x02\x03\x04"
        expect(@tlm.identify!(buffer,["TGTX"])).to be_nil
      end

      context "with an unknown buffer" do
        it "logs an invalid sized buffer" do
          capture_io do |stdout|
            buffer = "\x01\x02\x03\x04\x05"
            @tlm.identify!(buffer)
            pkt = @tlm.packet("TGT1","PKT1")
            pkt.enable_method_missing
            expect(pkt.item1).to eql 1
            expect(pkt.item2).to eql 2
            expect(pkt.item3).to eql 6.0
            expect(pkt.item4).to eql 8.0
            expect(stdout.string).to match(/ERROR: TGT1 PKT1 received with actual packet length of 5 but defined length of 4/)
          end
        end

        it "identifies TGT1 PKT1" do
          buffer = "\x01\x02\x03\x04"
          @tlm.identify!(buffer)
          pkt = @tlm.packet("TGT1","PKT1")
          pkt.enable_method_missing
          expect(pkt.item1).to eql 1
          expect(pkt.item2).to eql 2
          expect(pkt.item3).to eql 6.0
          expect(pkt.item4).to eql 8.0
        end

        it "identifies TGT1 PKT2" do
          buffer = "\x02\x02"
          @tlm.identify!(buffer)
          pkt = @tlm.packet("TGT1","PKT2")
          pkt.enable_method_missing
          expect(pkt.item1).to eql 2
          expect(pkt.item2).to eql 2
        end

        it "identifies TGT2 PKT1" do
          buffer = "\x03\x02"
          @tlm.identify!(buffer)
          pkt = @tlm.packet("TGT2","PKT1")
          pkt.enable_method_missing
          expect(pkt.item1).to eql 3
          expect(pkt.item2).to eql 2
        end
      end
    end

    describe "update!" do
      it "complains about non-existant targets" do
        expect { @tlm.update!("TGTX","PKT1","\x00") }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @tlm.update!("TGT1","PKTX","\x00") }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 PKTX' does not exist")
      end

      it "complains about the 'LATEST' packet" do
        expect { @tlm.update!("TGT1","LATEST","\x00") }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 LATEST' does not exist")
      end

      it "complains with a nil buffer" do
        expect { @tlm.update!("TGT1","PKT1",nil) }.to raise_error(ArgumentError, "Buffer class is NilClass but must be String")
      end

      it "logs an invalid sized buffer" do
        capture_io do |stdout|
          buffer = "\x01\x02\x03\x04\x05"
          @tlm.update!("TGT1","PKT1",buffer)
          pkt = @tlm.packet("TGT1","PKT1")
          pkt.enable_method_missing
          expect(pkt.item1).to eql 1
          expect(pkt.item2).to eql 2
          expect(pkt.item3).to eql 6.0
          expect(pkt.item4).to eql 8.0
          expect(stdout.string).to match(/ERROR: TGT1 PKT1 received with actual packet length of 5 but defined length of 4/)
        end
      end

      it "updates a packet with the given data" do
        @tlm.update!("TGT1","PKT1","\x01\x02\x03\x04")
        pkt = @tlm.packet("TGT1","PKT1")
        pkt.enable_method_missing
        expect(pkt.item1).to eql 1
        expect(pkt.item2).to eql 2
        expect(pkt.item3).to eql 6.0
        expect(pkt.item4).to eql 8.0
      end
    end

    describe "limits_change_callback" do
      it "assigns a callback to each packet" do
        callback = Object.new
        expect(callback).to receive(:call).twice
        @tlm.limits_change_callback = callback
        @tlm.update!("TGT1","PKT1","\x01\x02\x03\x04")
        @tlm.update!("TGT1","PKT2","\x05\x06")
        @tlm.update!("TGT2","PKT1","\x07\x08")
        @tlm.packet("TGT1","PKT1").check_limits
        @tlm.packet("TGT1","PKT2").check_limits
        @tlm.packet("TGT2","PKT1").check_limits
      end
    end

    describe "check_stale" do
      it "checks each packet for staleness" do
        @tlm.check_stale
        expect(@tlm.packet("TGT1","PKT1").stale).to be true
        expect(@tlm.packet("TGT1","PKT2").stale).to be true
        expect(@tlm.packet("TGT2","PKT1").stale).to be true

        @tlm.packet("TGT1","PKT1").check_limits
        @tlm.packet("TGT1","PKT2").check_limits
        @tlm.packet("TGT2","PKT1").check_limits
        @tlm.check_stale
        expect(@tlm.packet("TGT1","PKT1").stale).to be false
        expect(@tlm.packet("TGT1","PKT2").stale).to be false
        expect(@tlm.packet("TGT2","PKT1").stale).to be false
      end
    end

    describe "stale" do
      it "complains about a non-existant target" do
        expect { @tlm.stale(false, "TGTX") }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "returns the list of stale packets for a given target" do
        pkt = @tlm.packet("TGT2","PKT1")
        expect(@tlm.stale(false, "TGT2")).to include(pkt)
        @tlm.packet("TGT2","PKT1").check_limits
        expect(@tlm.stale(false, "TGT2").size).to eql 0
        expect(@tlm.stale(false, "TGT1").size).to eql 2
        expect(@tlm.stale.size).to eql 2
      end

      it "returns the list of stale packets" do
        p1 = @tlm.packet("TGT1","PKT1")
        p2 = @tlm.packet("TGT1","PKT2")
        p3 = @tlm.packet("TGT2","PKT1")
        expect(@tlm.stale).to include(p1, p2, p3)
        @tlm.packet("TGT1","PKT1").check_limits
        expect(@tlm.stale).not_to include(p1)
        expect(@tlm.stale).to include(p2, p3)
        @tlm.packet("TGT1","PKT2").check_limits
        expect(@tlm.stale).not_to include(p1, p2)
        expect(@tlm.stale).to include(p3)
        @tlm.packet("TGT2","PKT1").check_limits
        expect(@tlm.stale.size).to eql 0
      end

      it "returns only stale packets which have limits" do
        p1 = @tlm.packet("TGT1","PKT1")
        p2 = @tlm.packet("TGT1","PKT2")
        p3 = @tlm.packet("TGT2","PKT1")
        expect(@tlm.stale(true)).to include(p1)
        expect(@tlm.stale(true)).not_to include(p2,p3)
        @tlm.packet("TGT1","PKT1").check_limits
        expect(@tlm.stale(true).size).to eql 0
        expect(@tlm.stale(false)).to include(p2,p3)
      end
    end

    describe "clear_counters" do
      it "clears each packet's receive count " do
        @tlm.packet("TGT1","PKT1").received_count = 1
        @tlm.packet("TGT1","PKT2").received_count = 2
        @tlm.packet("TGT2","PKT1").received_count = 3
        @tlm.clear_counters
        expect(@tlm.packet("TGT1","PKT1").received_count).to eql 0
        expect(@tlm.packet("TGT1","PKT2").received_count).to eql 0
        expect(@tlm.packet("TGT2","PKT1").received_count).to eql 0
      end
    end

    describe "value" do
      it "complains about non-existant targets" do
        expect { @tlm.value("TGTX","PKT1","ITEM1") }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @tlm.value("TGT1","PKTX","ITEM1") }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 PKTX' does not exist")
      end

      it "complains about non-existant items" do
        expect { @tlm.value("TGT1","PKT1","ITEMX") }.to raise_error(RuntimeError, "Packet item 'TGT1 PKT1 ITEMX' does not exist")
      end

      it "returns the value" do
        expect(@tlm.value("TGT1","PKT1","ITEM1")).to eql 0
      end

      it "returns the value using LATEST" do
        expect(@tlm.value("TGT1","LATEST","ITEM1")).to eql 0
      end
    end

    describe "set_value" do
      it "complains about non-existant targets" do
        expect { @tlm.set_value("TGTX","PKT1","ITEM1", 1) }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @tlm.set_value("TGT1","PKTX","ITEM1", 1) }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 PKTX' does not exist")
      end

      it "complains about non-existant items" do
        expect { @tlm.set_value("TGT1","PKT1","ITEMX", 1) }.to raise_error(RuntimeError, "Packet item 'TGT1 PKT1 ITEMX' does not exist")
      end

      it "sets the value" do
        @tlm.set_value("TGT1","PKT1","ITEM1",1)
        expect(@tlm.value("TGT1","PKT1","ITEM1")).to eql 1
      end

      it "sets the value using LATEST" do
        @tlm.set_value("TGT1","LATEST","ITEM1",1)
        expect(@tlm.value("TGT1","PKT1","ITEM1")).to eql 0
        expect(@tlm.value("TGT1","PKT2","ITEM1")).to eql 1
      end
    end

    describe "values_and_limits_states" do
      it "complains about non-existant targets" do
        expect { @tlm.values_and_limits_states([["TGTX","PKT1","ITEM1"]]) }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @tlm.values_and_limits_states([["TGT1","PKTX","ITEM1"]]) }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 PKTX' does not exist")
      end

      it "complains about non-existant items" do
        expect { @tlm.values_and_limits_states([["TGT1","PKT1","ITEMX"]]) }.to raise_error(RuntimeError, "Packet item 'TGT1 PKT1 ITEMX' does not exist")
      end

      it "complains about non-existant value_types" do
        expect { @tlm.values_and_limits_states([["TGT1","PKT1","ITEM1"]],:MINE) }.to raise_error(ArgumentError, "Unknown value type on read: MINE")
      end

      it "complains if passed a single array" do
        expect { @tlm.values_and_limits_states(["TGT1","PKT1","ITEM1"]) }.to raise_error(ArgumentError, /item_array must be a nested array/)
      end

      it "complains about the wrong number of parameters" do
        expect { @tlm.values_and_limits_states([["TGT1","PKT1","ITEM1"]],:RAW,:RAW) }.to raise_error(ArgumentError, /wrong number of arguments/)
      end

      it "reads all the specified values" do
        @tlm.update!("TGT1","PKT1","\x01\x02\x03\x04")
        @tlm.update!("TGT1","PKT2","\x05\x06")
        @tlm.update!("TGT2","PKT1","\x07\x08")
        @tlm.packet("TGT1","PKT1").check_limits
        @tlm.packet("TGT1","PKT2").check_limits
        @tlm.packet("TGT2","PKT1").check_limits
        items = []
        items << %w(TGT1 PKT1 ITEM1)
        items << %w(TGT1 PKT2 ITEM2)
        items << %w(TGT2 PKT1 ITEM1)
        vals = @tlm.values_and_limits_states(items)
        expect(vals[0][0]).to eql 1
        expect(vals[0][1]).to eql 6
        expect(vals[0][2]).to eql 7
        expect(vals[1][0]).to eql :RED_LOW
        expect(vals[1][1]).to be_nil
        expect(vals[1][2]).to be_nil
        expect(vals[2][0]).to eql [1.0, 2.0, 4.0, 5.0]
        expect(vals[2][1]).to be_nil
        expect(vals[2][2]).to be_nil
      end

      it "reads all the specified values with specified value_types" do
        @tlm.update!("TGT1","PKT1","\x01\x02\x03\x04")
        @tlm.update!("TGT1","PKT2","\x05\x06")
        @tlm.update!("TGT2","PKT1","\x07\x08")
        @tlm.packet("TGT1","PKT1").check_limits
        @tlm.packet("TGT1","PKT2").check_limits
        @tlm.packet("TGT2","PKT1").check_limits
        items = []
        items << %w(TGT1 PKT1 ITEM1)
        items << %w(TGT1 PKT1 ITEM2)
        items << %w(TGT1 PKT1 ITEM3)
        items << %w(TGT1 PKT1 ITEM4)
        items << %w(TGT1 PKT2 ITEM2)
        items << %w(TGT2 PKT1 ITEM1)
        formats = [:CONVERTED, :RAW, :CONVERTED, :RAW, :CONVERTED, :CONVERTED]
        vals = @tlm.values_and_limits_states(items,formats)
        expect(vals[0][0]).to eql 1
        expect(vals[0][1]).to eql 2
        expect(vals[0][2]).to eql 6.0
        expect(vals[0][3]).to eql 4
        expect(vals[0][4]).to eql 6
        expect(vals[0][5]).to eql 7
        expect(vals[1][0]).to eql :RED_LOW
        expect(vals[1][1]).to eql :YELLOW_LOW
        expect(vals[1][2]).to be_nil
        expect(vals[1][3]).to be_nil
        expect(vals[1][4]).to be_nil
        expect(vals[1][5]).to be_nil
        expect(vals[2][0]).to eql [1.0, 2.0, 4.0, 5.0]
        expect(vals[2][1]).to eql [1.0, 2.0, 4.0, 5.0]
        expect(vals[2][2]).to be_nil
        expect(vals[2][3]).to be_nil
        expect(vals[2][4]).to be_nil
        expect(vals[2][5]).to be_nil
      end
    end

    describe "all" do
      it "returns all packets" do
        expect(@tlm.all.keys).to eql %w(UNKNOWN TGT1 TGT2)
      end
    end

    describe "all_item_strings" do
      it "returns hidden TGT,PKT,ITEMs in the system" do
        @tlm.packet("TGT1","PKT1").hidden = true
        @tlm.packet("TGT1","PKT2").disabled = true
        default = @tlm.all_item_strings() # Return only those not hidden or disabled
        strings = @tlm.all_item_strings(true) # Return everything, even hidden & disabled
        expect(default).to_not eq strings
        # Spot check the default
        expect(default).to include("TGT2 PKT1 ITEM1")
        expect(default).to include("TGT2 PKT1 ITEM2")
        expect(default).to_not include("TGT1 PKT1 ITEM1") # hidden
        expect(default).to_not include("TGT1 PKT2 ITEM1") # disabled

        items = {}
        # Built from the before(:each) section
        items['TGT1 PKT1'] = %w(ITEM1 ITEM2 ITEM3 ITEM4)
        items['TGT1 PKT2'] = %w(ITEM1 ITEM2)
        items['TGT2 PKT1'] = %w(ITEM1 ITEM2)
        items.each do |tgt_pkt, items|
          Packet::RESERVED_ITEM_NAMES.each do |item|
            expect(strings).to include("#{tgt_pkt} #{item}")
          end
          items.each do |item|
            expect(strings).to include("#{tgt_pkt} #{item}")
          end
        end
      end
    end

  end
end
