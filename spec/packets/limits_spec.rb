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
require 'cosmos/packets/limits'
require 'tempfile'

module Cosmos

  describe Limits do

    before(:each) do
      tf = Tempfile.new('unittest')
      tf.puts '# This is a comment'
      tf.puts '#'
      tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "TGT1 PKT1 Description"'
      tf.puts '  APPEND_ID_ITEM item1 8 UINT 1 "Item1"'
      tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 4 5'
      tf.puts '    LIMITS TVAC 1 ENABLED 6 7 12 13 9 10'
      tf.puts '  APPEND_ITEM item2 8 UINT "Item2"'
      tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 4 5'
      tf.puts '    LIMITS TVAC 1 ENABLED 6 7 12 13 9 10'
      tf.puts '  APPEND_ITEM item3 8 UINT "Item3"'
      tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 4 5'
      tf.puts '    LIMITS TVAC 1 ENABLED 6 7 12 13 9 10'
      tf.puts '  APPEND_ITEM item4 8 UINT "Item4"'
      tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 4 5'
      tf.puts '    LIMITS TVAC 1 ENABLED 6 7 12 13 9 10'
      tf.puts '  APPEND_ITEM item5 8 UINT "Item5"'
      tf.puts 'TELEMETRY tgt1 pkt2 LITTLE_ENDIAN "TGT1 PKT2 Description"'
      tf.puts '  APPEND_ID_ITEM item1 8 UINT 2 "Item1"'
      tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 4 5'
      tf.puts '  APPEND_ITEM item2 8 UINT "Item2"'
      tf.puts 'TELEMETRY tgt2 pkt1 LITTLE_ENDIAN "TGT2 PKT1 Description"'
      tf.puts '  APPEND_ID_ITEM item1 8 UINT 3 "Item1"'
      tf.puts '  APPEND_ITEM item2 8 UINT "Item2"'
      tf.puts 'LIMITS_GROUP GROUP1'
      tf.puts '  LIMITS_GROUP_ITEM TGT1 PKT1 ITEM1'
      tf.puts '  LIMITS_GROUP_ITEM TGT1 PKT1 ITEM2'
      tf.puts 'LIMITS_GROUP GROUP2'
      tf.puts '  LIMITS_GROUP_ITEM TGT1 PKT1 ITEM1'
      tf.puts '  LIMITS_GROUP_ITEM TGT1 PKT1 ITEM2'
      tf.close

      # Verify initially that everything is empty
      pc = PacketConfig.new
      pc.process_file(tf.path, "SYSTEM")
      @tlm = Telemetry.new(pc)
      @limits = Limits.new(pc)
      tf.unlink
    end

    describe "initialize" do
      it "has no warnings" do
        expect(Limits.new(PacketConfig.new).warnings).to be_empty
      end
    end

    describe "sets" do
      it "returns the defined limits set" do
        expect(@limits.sets).to eql [:DEFAULT, :TVAC]
      end
    end

    describe "groups" do
      it "returns the limits groups" do
        expect(@limits.groups).not_to be_empty
      end
    end

    describe "config=" do
      it "sets the underlying configuration" do
        tf = Tempfile.new('unittest')
        tf.puts ''
        tf.close
        pc = PacketConfig.new
        pc.process_file(tf.path, "SYSTEM")
        expect(@limits.sets).to eql [:DEFAULT, :TVAC]
        expect(@limits.groups).not_to be_empty
        @limits.config = pc
        expect(@limits.sets).to eql [:DEFAULT]
        expect(@limits.groups).to eql({})
        tf.unlink
      end
    end

    describe "out_of_limits" do
      it "returns all out of limits telemetry items" do
        @tlm.update!("TGT1","PKT1","\x00\x03\x03\x04\x05")
        @tlm.packet("TGT1","PKT1").check_limits
        items = @limits.out_of_limits
        expect(items[0][0]).to eql "TGT1"
        expect(items[0][1]).to eql "PKT1"
        expect(items[0][2]).to eql "ITEM1"
        expect(items[0][3]).to eql :RED_LOW
      end
    end

    describe "overall_limits_state" do
      it "returns overall limits state of the system" do
        # Cause packet 2 to be green
        @tlm.update!("TGT1","PKT2","\x03\x03")
        @tlm.packet("TGT1","PKT2").check_limits

        @tlm.packet("TGT1","PKT1").set_stale
        expect(@limits.overall_limits_state).to eq :STALE

        # Cause packet 1 to be all BLUE values
        @tlm.update!("TGT1","PKT1","\x0a\x0a\x0a\x0a\x00")
        @tlm.packet("TGT1","PKT1").check_limits(:TVAC)
        expect(@limits.overall_limits_state).to eq :GREEN

        # Cause packet 1 to have a GREEN value
        @tlm.update!("TGT1","PKT1","\x0a\x0a\x0a\x08\x00")
        @tlm.packet("TGT1","PKT1").check_limits(:TVAC)
        expect(@limits.overall_limits_state).to eq :GREEN

        # Cause packet 1 to have a YELLOW value
        @tlm.update!("TGT1","PKT1","\x0a\x0a\x0a\x07\x00")
        @tlm.packet("TGT1","PKT1").check_limits(:TVAC)
        expect(@limits.overall_limits_state).to eq :YELLOW

        # Cause packet 1 to have a YELLOW and a RED value
        @tlm.update!("TGT1","PKT1","\x0a\x0a\x07\x06\x00")
        @tlm.packet("TGT1","PKT1").check_limits(:TVAC)
        expect(@limits.overall_limits_state).to eq :RED
      end

      it "marks a stale packet green if all items are ignored" do
        # Cause packet 2 to be green
        @tlm.update!("TGT1","PKT2","\x03\x03")
        @tlm.packet("TGT1","PKT2").check_limits

        @tlm.packet("TGT1","PKT1").set_stale
        expect(@limits.overall_limits_state).to eq :STALE
        # Ignore several items in pkt1 but leave one off
        expect(@limits.overall_limits_state([%w(TGT1 PKT1 ITEM1),%w(TGT1 PKT1 ITEM2),%w(TGT1 PKT1 ITEM3)])).to eq :STALE
        # Ignore every item in pkt1
        expect(@limits.overall_limits_state([%w(TGT1 PKT1 ITEM1),%w(TGT1 PKT1 ITEM2),%w(TGT1 PKT1 ITEM3),%w(TGT1 PKT1 ITEM4)])).to eq :GREEN

        # ignore the entire PKT1 packet
        expect(@limits.overall_limits_state).to eq :STALE
        expect(@limits.overall_limits_state([%w(TGT1 PKT1)])).to eq :GREEN
      end

      it "handles non-existant ignored telemetry items" do
        # Cause packet 2 to be green
        @tlm.update!("TGT1","PKT2","\x03\x03")
        @tlm.packet("TGT1","PKT2").check_limits

        # Ignore a non-existant value
        @tlm.update!("TGT1","PKT1","\x0a\x0a\x0a\x07\x00")
        @tlm.packet("TGT1","PKT1").check_limits(:TVAC)
        expect(@limits.overall_limits_state([%w(TGT1 PKT1 BLAH)])).to eq :YELLOW
      end

      it "ignores specified telemetry items" do
        # Cause packet 2 to be green
        @tlm.update!("TGT1","PKT2","\x03\x03")
        @tlm.packet("TGT1","PKT2").check_limits

        # Cause packet 1 to have a YELLOW value but ignore it
        @tlm.update!("TGT1","PKT1","\x0a\x0a\x0a\x07\x00")
        @tlm.packet("TGT1","PKT1").check_limits(:TVAC)
        expect(@limits.overall_limits_state([%w(TGT1 PKT1 ITEM4)])).to eq :GREEN

        # Cause packet 1 to have a YELLOW and a RED value but ignore them
        @tlm.update!("TGT1","PKT1","\x0a\x0a\x07\x06\x00")
        @tlm.packet("TGT1","PKT1").check_limits(:TVAC)
        expect(@limits.overall_limits_state([%w(TGT1 PKT1 ITEM4),%w(TGT1 PKT1 ITEM3)])).to eq :GREEN
      end

      it "ignores specified telemetry packets" do
        # Cause packet 2 to be green
        @tlm.update!("TGT1","PKT2","\x03\x03")
        @tlm.packet("TGT1","PKT2").check_limits

        # Cause packet 1 to have a YELLOW and a RED value but ignore the packet
        @tlm.update!("TGT1","PKT1","\x0a\x0a\x07\x06\x00")
        @tlm.packet("TGT1","PKT1").check_limits(:TVAC)
        expect(@limits.overall_limits_state()).to eq :RED
        expect(@limits.overall_limits_state([%w(TGT1 PKT1)])).to eq :GREEN
      end
    end

    describe "enable_group" do
      it "complains about undefined limits groups" do
        expect { @limits.enable_group("MINE") }.to raise_error(RuntimeError, "LIMITS_GROUP MINE undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP MINE")
      end

      it "complains about undefined items" do
        tf = Tempfile.new('unittest')
        tf.puts 'LIMITS_GROUP GROUP1'
        tf.puts '  LIMITS_GROUP_ITEM TGT1 PKT1 ITEM1'
        tf.close
        pc = PacketConfig.new
        pc.process_file(tf.path, "SYSTEM")
        limits = Limits.new(pc)
        expect { limits.enable_group("group1") }.to raise_error(RuntimeError, "Telemetry target 'TGT1' does not exist")
        tf.unlink
      end

      it "enables limits for all items in the group" do
        @limits.enable_group("group1")
        pkt = @tlm.packet("TGT1","PKT1")
        expect(pkt.get_item("ITEM1").limits.enabled).to be true
        expect(pkt.get_item("ITEM2").limits.enabled).to be true
        expect(pkt.get_item("ITEM3").limits.enabled).to be true
        expect(pkt.get_item("ITEM4").limits.enabled).to be true
        expect(pkt.get_item("ITEM5").limits.enabled).to be false
      end
    end

    describe "disable_group" do
      it "complains about undefined limits groups" do
        expect { @limits.disable_group("MINE") }.to raise_error(RuntimeError, "LIMITS_GROUP MINE undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP MINE")
      end

      it "disables limits for all items in the group" do
        pkt = @tlm.packet("TGT1","PKT1")
        pkt.enable_limits("ITEM1")
        pkt.enable_limits("ITEM2")
        expect(pkt.get_item("ITEM1").limits.enabled).to be true
        expect(pkt.get_item("ITEM2").limits.enabled).to be true

        @limits.disable_group("group1")
        expect(pkt.get_item("ITEM1").limits.enabled).to be false
        expect(pkt.get_item("ITEM2").limits.enabled).to be false
      end
    end

    describe "enabled?" do
      it "complains about non-existant targets" do
        expect { @limits.enabled?("TGTX","PKT1","ITEM1") }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @limits.enabled?("TGT1","PKTX","ITEM1") }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 PKTX' does not exist")
      end

      it "complains about non-existant items" do
        expect { @limits.enabled?("TGT1","PKT1","ITEMX") }.to raise_error(RuntimeError, "Packet item 'TGT1 PKT1 ITEMX' does not exist")
      end

      it "returns whether limits are enable for an item" do
        pkt = @tlm.packet("TGT1","PKT1")
        expect(@limits.enabled?("TGT1","PKT1","ITEM5")).to be false
        pkt.enable_limits("ITEM5")
        expect(@limits.enabled?("TGT1","PKT1","ITEM5")).to be true
      end
    end

    describe "enable" do
      it "complains about non-existant targets" do
        expect { @limits.enable("TGTX","PKT1","ITEM1") }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @limits.enable("TGT1","PKTX","ITEM1") }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 PKTX' does not exist")
      end

      it "complains about non-existant items" do
        expect { @limits.enable("TGT1","PKT1","ITEMX") }.to raise_error(RuntimeError, "Packet item 'TGT1 PKT1 ITEMX' does not exist")
      end

      it "enables limits for an item" do
        @tlm.packet("TGT1","PKT1")
        expect(@limits.enabled?("TGT1","PKT1","ITEM5")).to be false
        @limits.enable("TGT1","PKT1","ITEM5")
        expect(@limits.enabled?("TGT1","PKT1","ITEM5")).to be true
      end
    end

    describe "disable" do
      it "complains about non-existant targets" do
        expect { @limits.disable("TGTX","PKT1","ITEM1") }.to raise_error(RuntimeError, "Telemetry target 'TGTX' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @limits.disable("TGT1","PKTX","ITEM1") }.to raise_error(RuntimeError, "Telemetry packet 'TGT1 PKTX' does not exist")
      end

      it "complains about non-existant items" do
        expect { @limits.disable("TGT1","PKT1","ITEMX") }.to raise_error(RuntimeError, "Packet item 'TGT1 PKT1 ITEMX' does not exist")
      end

      it "disables limits for an item" do
        @tlm.packet("TGT1","PKT1")
        @limits.enable("TGT1","PKT1","ITEM1")
        expect(@limits.enabled?("TGT1","PKT1","ITEM1")).to be true
        @limits.disable("TGT1","PKT1","ITEM1")
        expect(@limits.enabled?("TGT1","PKT1","ITEM1")).to be false
      end
    end

    describe "get" do
      it "gets the limits for an item with limits" do
        expect(@limits.get("TGT1", "PKT1", "ITEM1")).to eql [:DEFAULT, 1, true, 1.0, 2.0, 4.0, 5.0, nil, nil]
      end

      it "handles an item without limits" do
        expect(@limits.get("TGT1", "PKT1", "ITEM5")).to eql [nil, nil, nil, nil, nil, nil, nil, nil, nil]
      end

      it "supports a specified limits set" do
        expect(@limits.get("TGT1", "PKT1", "ITEM1", :TVAC)).to eql [:TVAC, 1, true, 6.0, 7.0, 12.0, 13.0, 9.0, 10.0]
      end

      it "handles an item without limits for the given limits set" do
        expect(@limits.get("TGT1", "PKT2", "ITEM1", :TVAC)).to eql [nil, nil, nil, nil, nil, nil, nil, nil, nil]
      end
    end

    describe "set" do
      it "sets limits for an item" do
        expect(@limits.set("TGT1", "PKT1", "ITEM5", 1, 2, 3, 4, nil, nil, :DEFAULT)).to eql [:DEFAULT, 1, true, 1.0, 2.0, 3.0, 4.0, nil, nil]
      end

      it "enforces setting DEFAULT limits first" do
        expect { @limits.set("TGT1", "PKT1", "ITEM5", 1, 2, 3, 4) }.to raise_error(RuntimeError, "DEFAULT limits must be defined for TGT1 PKT1 ITEM5 before setting limits set CUSTOM")
        expect(@limits.set("TGT1", "PKT1", "ITEM5", 5, 6, 7, 8, nil, nil, :DEFAULT)).to eql [:DEFAULT, 1, true, 5.0, 6.0, 7.0, 8.0, nil, nil]
        expect(@limits.set("TGT1", "PKT1", "ITEM5", 1, 2, 3, 4)).to eql [:CUSTOM, 1, true, 1.0, 2.0, 3.0, 4.0, nil, nil]
      end

      it "allows setting other limits sets" do
        expect(@limits.set("TGT1", "PKT1", "ITEM1", 1, 2, 3, 4, nil, nil, :TVAC)).to eql [:TVAC, 1, true, 1.0, 2.0, 3.0, 4.0, nil, nil]
      end

      it "handles green limits" do
        expect(@limits.set("TGT1", "PKT1", "ITEM1", 1, 2, 5, 6, 3, 4, nil)).to eql [:DEFAULT, 1, true, 1.0, 2.0, 5.0, 6.0, 3.0, 4.0]
      end
    end

  end
end

