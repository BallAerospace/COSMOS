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
require 'cosmos/packets/commands'
require 'tempfile'

module Cosmos

  describe Commands do

    describe "initialize" do
      it "should have no warnings" do
        Commands.new(PacketConfig.new).warnings.should be_empty
      end
    end

    before(:each) do
      tf = Tempfile.new('unittest')
      tf.puts '# This is a comment'
      tf.puts '#'
      tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "TGT1 PKT1 Description"'
      tf.puts '  APPEND_ID_PARAMETER item1 8 UINT 1 1 1 "Item1"'
      tf.puts '  APPEND_PARAMETER item2 8 UINT 0 254 2 "Item2"'
      tf.puts '  APPEND_PARAMETER item3 8 UINT 0 254 3 "Item3"'
      tf.puts '  APPEND_PARAMETER item4 8 UINT 0 254 4 "Item4"'
      tf.puts 'COMMAND tgt1 pkt2 LITTLE_ENDIAN "TGT1 PKT2 Description"'
      tf.puts '  APPEND_ID_PARAMETER item1 8 UINT 2 2 2 "Item1"'
      tf.puts '  APPEND_PARAMETER item2 8 UINT 0 255 2 "Item2"'
      tf.puts '    STATE BAD1 0 HAZARDOUS "Hazardous"'
      tf.puts '    STATE BAD2 1 HAZARDOUS'
      tf.puts '    STATE GOOD 2'
      tf.puts 'COMMAND tgt2 pkt3 LITTLE_ENDIAN "TGT2 PKT3 Description"'
      tf.puts '  HAZARDOUS "Hazardous"'
      tf.puts '  APPEND_ID_PARAMETER item1 8 UINT 3 3 3 "Item1"'
      tf.puts '  APPEND_PARAMETER item2 8 UINT 0 255 2 "Item2"'
      tf.puts '    REQUIRED'
      tf.puts 'COMMAND tgt2 pkt4 LITTLE_ENDIAN "TGT2 PKT4 Description"'
      tf.puts '  APPEND_ID_PARAMETER item1 8 UINT 4 4 4 "Item1"'
      tf.puts '  APPEND_PARAMETER item2 2048 STRING "Item2"'
      tf.puts '    OVERFLOW TRUNCATE'
      tf.puts 'COMMAND tgt2 pkt5 LITTLE_ENDIAN "TGT2 PKT5 Description"'
      tf.puts '  APPEND_ID_PARAMETER item1 8 UINT 5 5 5 "Item1"'
      tf.puts '  APPEND_PARAMETER item2 8 UINT 0 100 0 "Item2"'
      tf.puts '    POLY_WRITE_CONVERSION 0 2'
      tf.close

      pc = PacketConfig.new
      pc.process_file(tf.path, "SYSTEM")
      @cmd = Commands.new(pc)
      tf.unlink
    end

    describe "target_names" do
      it "should return an array with just UNKNOWN if no targets" do
        Commands.new(PacketConfig.new).target_names.should eql ["UNKNOWN"]
      end

      it "should return all target names" do
        @cmd.target_names.should eql ["TGT1","TGT2","UNKNOWN"]
      end
    end

    describe "packets" do
      it "should complain about non-existant targets" do
        expect { @cmd.packets("tgtX") }.to raise_error(RuntimeError, "Command target 'TGTX' does not exist")
      end

      it "should return all packets target TGT1" do
        pkts = @cmd.packets("TGT1")
        pkts.length.should eql 2
        pkts.keys.should include("PKT1")
        pkts.keys.should include("PKT2")
      end

      it "should return all packets target TGT2" do
        pkts = @cmd.packets("TGT2")
        pkts.length.should eql 3
        pkts.keys.should include("PKT3")
        pkts.keys.should include("PKT4")
        pkts.keys.should include("PKT5")
      end
    end

    describe "params" do
      it "should complain about non-existant targets" do
        expect { @cmd.params("TGTX","PKT1") }.to raise_error(RuntimeError, "Command target 'TGTX' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @cmd.params("TGT1","PKTX") }.to raise_error(RuntimeError, "Command packet 'TGT1 PKTX' does not exist")
      end

      it "should return all items from packet TGT1/PKT1" do
        items = @cmd.params("TGT1","PKT1")
        items.length.should eql 4
        items[0].name.should eql "ITEM1"
        items[1].name.should eql "ITEM2"
        items[2].name.should eql "ITEM3"
        items[3].name.should eql "ITEM4"
      end
    end

    describe "packet" do
      it "should complain about non-existant targets" do
        expect { @cmd.packet("tgtX","pkt1") }.to raise_error(RuntimeError, "Command target 'TGTX' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @cmd.packet("TGT1","PKTX") }.to raise_error(RuntimeError, "Command packet 'TGT1 PKTX' does not exist")
      end

      it "should return the specified packet" do
        pkt = @cmd.packet("TGT1","PKT1")
        pkt.target_name.should eql "TGT1"
        pkt.packet_name.should eql "PKT1"
      end
    end

    describe "identify" do
      it "return nil with a nil buffer" do
        @cmd.identify(nil).should be_nil
      end

      it "should only check the targets given" do
        buffer = "\x01\x02\x03\x04"
        pkt = @cmd.identify(buffer,["TGT1"])
        pkt.enable_method_missing
        pkt.item1.should eql 1
        pkt.item2.should eql 2
        pkt.item3.should eql 3
        pkt.item4.should eql 4
      end

      it "should return nil with unknown targets given" do
        buffer = "\x01\x02\x03\x04"
        @cmd.identify(buffer,["TGTX"]).should be_nil
      end

      context "with an unknown buffer" do
        it "should log an invalid sized buffer" do
          capture_io do |stdout|
            buffer = "\x01\x02\x03"
            pkt = @cmd.identify(buffer)
            pkt.enable_method_missing
            pkt.item1.should eql 1
            pkt.item2.should eql 2
            pkt.item3.should eql 3
            pkt.item4.should eql 0
            stdout.string.should match(/ERROR: TGT1 PKT1 received with actual packet length of 3 but defined length of 4/)
          end
        end

        it "should log an invalid sized buffer" do
          capture_io do |stdout|
            buffer = "\x01\x02\x03\x04\x05"
            pkt = @cmd.identify(buffer)
            pkt.enable_method_missing
            pkt.item1.should eql 1
            pkt.item2.should eql 2
            pkt.item3.should eql 3
            pkt.item4.should eql 4
            stdout.string.should match(/ERROR: TGT1 PKT1 received with actual packet length of 5 but defined length of 4/)
          end
        end

        it "should identify TGT1 PKT1 but not affect the latest data table" do
          buffer = "\x01\x02\x03\x04"
          pkt = @cmd.identify(buffer)
          pkt.enable_method_missing
          pkt.item1.should eql 1
          pkt.item2.should eql 2
          pkt.item3.should eql 3
          pkt.item4.should eql 4

          # Now request the packet from the latest data table
          pkt = @cmd.packet("TGT1","PKT1")
          pkt.enable_method_missing
          pkt.item1.should eql 0
          pkt.item2.should eql 0
          pkt.item3.should eql 0
          pkt.item4.should eql 0
        end

        it "should identify TGT1 PKT2" do
          buffer = "\x02\x02"
          pkt = @cmd.identify(buffer)
          pkt.enable_method_missing
          pkt.item1.should eql 2
          pkt.item2.should eql "GOOD"
        end

        it "should identify TGT2 PKT1" do
          buffer = "\x03\x02"
          pkt = @cmd.identify(buffer)
          pkt.enable_method_missing
          pkt.item1.should eql 3
          pkt.item2.should eql 2
        end
      end
    end

    describe "build_cmd" do
      it "should complain about non-existant targets" do
        expect { @cmd.build_cmd("tgtX","pkt1") }.to raise_error(RuntimeError, "Command target 'TGTX' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @cmd.build_cmd("tgt1","pktX") }.to raise_error(RuntimeError, "Command packet 'TGT1 PKTX' does not exist")
      end

      it "should complain about non-existant items" do
        expect { cmd = @cmd.build_cmd("tgt1","pkt1",{"itemX"=>1}) }.to raise_error(RuntimeError, "Packet item 'TGT1 PKT1 ITEMX' does not exist")
      end

      it "should create a populated command packet with default values" do
        cmd = @cmd.build_cmd("TGT1","PKT1")
        cmd.enable_method_missing
        cmd.item1.should eql 1
        cmd.item2.should eql 2
        cmd.item3.should eql 3
        cmd.item4.should eql 4
      end

      it "should complain about out of range item values" do
        expect { @cmd.build_cmd("tgt1","pkt1",{"item2"=>1000}) }.to raise_error(RuntimeError, "Command parameter 'TGT1 PKT1 ITEM2' = 1000 not in valid range of 0 to 254")
      end

      it "should ignore out of range item values if requested" do
        cmd = @cmd.build_cmd("tgt1","pkt1",{"item2"=>255}, false)
        cmd.enable_method_missing
        cmd.item1.should eql 1
        cmd.item2.should eql 255
        cmd.item3.should eql 3
        cmd.item4.should eql 4
      end

      it "should create a command packet with override item values" do
        items = {"ITEM2" => 10, "ITEM4" => 11}
        cmd = @cmd.build_cmd("TGT1","PKT1",items)
        cmd.enable_method_missing
        cmd.item1.should eql 1
        cmd.item2.should eql 10
        cmd.item3.should eql 3
        cmd.item4.should eql 11
      end

      it "should create a command packet with override item value states" do
        items = {"ITEM2" => "GOOD"}
        cmd = @cmd.build_cmd("TGT1","PKT2",items)
        cmd.enable_method_missing
        cmd.item1.should eql 2
        cmd.item2.should eql "GOOD"
        cmd.read("ITEM2",:RAW).should eql 2
      end

      it "should complain about missing required parameters" do
        expect { @cmd.build_cmd("tgt2","pkt3") }.to raise_error(RuntimeError, "Required command parameter 'TGT2 PKT3 ITEM2' not given")
      end

      it "should support building raw commands" do
        items = {"ITEM2" => 10}
        cmd = @cmd.build_cmd("TGT2","PKT5",items,false,false)
        cmd.raw.should eql false
        cmd.read("ITEM2").should eql 20
        items = {"ITEM2" => 10}
        cmd = @cmd.build_cmd("TGT1","PKT1",items,false,true)
        cmd.raw.should eql true
        cmd.read("ITEM2").should eql 10
      end
    end

    describe "format" do
      it "should create a string representation of a command" do
        pkt = @cmd.packet("TGT1","PKT1")
        @cmd.format(pkt).should eql "cmd('TGT1 PKT1 with ITEM1 0, ITEM2 0, ITEM3 0, ITEM4 0')"

        pkt = @cmd.packet("TGT2","PKT4")
        string = ''
        pkt.write("ITEM2","HELLO WORLD")
        @cmd.format(pkt).should eql "cmd('TGT2 PKT4 with ITEM1 0, ITEM2 \"HELLO WORLD\"')"

        pkt = @cmd.packet("TGT2","PKT4")
        string = ''
        pkt.write("ITEM2","HELLO WORLD")
        pkt.raw = true
        @cmd.format(pkt).should eql "cmd_raw('TGT2 PKT4 with ITEM1 0, ITEM2 \"HELLO WORLD\"')"

        # If the string is too big it should truncate it
        (1..2028).each {|i| string << 'A' }
        pkt.write("ITEM2",string)
        pkt.raw = false
        result = @cmd.format(pkt)
        result.should match(/cmd\('TGT2 PKT4 with ITEM1 0, ITEM2 \"AAAAAAAAAAA/)
        result.should match(/AAAAAAAAAAA.../)
      end

      it "should ignore parameters" do
        pkt = @cmd.packet("TGT1","PKT1")
        @cmd.format(pkt,['ITEM3','ITEM4']).should eql "cmd('TGT1 PKT1 with ITEM1 0, ITEM2 0')"
      end
    end

    describe "cmd_hazardous?" do
      it "should complain about non-existant targets" do
        expect { @cmd.cmd_hazardous?("tgtX","pkt1") }.to raise_error(RuntimeError, "Command target 'TGTX' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @cmd.cmd_hazardous?("tgt1","pktX") }.to raise_error(RuntimeError, "Command packet 'TGT1 PKTX' does not exist")
      end

      it "should complain about non-existant items" do
        expect { cmd = @cmd.cmd_hazardous?("tgt1","pkt1",{"itemX"=>1}) }.to raise_error(RuntimeError, "Packet item 'TGT1 PKT1 ITEMX' does not exist")
      end

      it "should return true if the command overall is hazardous" do
        hazardous, description = @cmd.cmd_hazardous?("TGT1","PKT1")
        hazardous.should be_falsey
        description.should be_nil
        hazardous, description = @cmd.cmd_hazardous?("tgt2","pkt3")
        hazardous.should be_truthy
        description.should eql "Hazardous"
      end

      it "should return true if a command parameter is hazardous" do
        hazardous, description = @cmd.cmd_hazardous?("TGT1","PKT2",{"ITEM2"=>0})
        hazardous.should be_truthy
        description.should eql "Hazardous"
        hazardous, description = @cmd.cmd_hazardous?("TGT1","PKT2",{"ITEM2"=>1})
        hazardous.should be_truthy
        description.should eql ""
        hazardous, description = @cmd.cmd_hazardous?("TGT1","PKT2",{"ITEM2"=>2})
        hazardous.should be_falsey
        description.should be_nil
      end
    end

    describe "clear_counters" do
      it "should clear the received counters in all packets" do
        @cmd.packet("TGT1","PKT1").received_count = 1
        @cmd.packet("TGT1","PKT2").received_count = 2
        @cmd.packet("TGT2","PKT3").received_count = 3
        @cmd.packet("TGT2","PKT4").received_count = 4
        @cmd.clear_counters
        @cmd.packet("TGT1","PKT1").received_count.should eql 0
        @cmd.packet("TGT1","PKT2").received_count.should eql 0
        @cmd.packet("TGT2","PKT3").received_count.should eql 0
        @cmd.packet("TGT2","PKT4").received_count.should eql 0
      end
    end

    describe "all" do
      it "should return all packets" do
        @cmd.all.keys.should eql %w(UNKNOWN TGT1 TGT2)
      end
    end

  end
end

