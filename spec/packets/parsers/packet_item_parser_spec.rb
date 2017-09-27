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
require 'cosmos/packets/packet_config'
require 'cosmos/packets/parsers/packet_item_parser'
require 'tempfile'

module Cosmos

  describe PacketItemParser do

    describe "process_file" do
      before(:each) do
        @pc = PacketConfig.new
      end

      context "with keywords including ITEM" do
        it "only allows ITEM after TELEMETRY" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ITEM ITEM1 8 0 DERIVED'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /ITEM types are only valid with TELEMETRY/)
          tf.unlink
        end

        it "complains if given an incomplete definition" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ITEM ITEM1 8 0'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ITEM ITEM1 8'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ITEM ITEM1'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ITEM'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters/)
          tf.unlink
        end

        it "complains if given a bad bit offset" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ITEM ITEM1 EIGHT 0 DERIVED'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /invalid value for Integer/)
          tf.unlink
        end

        it "complains if given a bad bit size" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ITEM ITEM1 8 ZERO DERIVED'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /invalid value for Integer/)
          tf.unlink
        end

        it "complains if given a bad array size" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ARRAY_ITEM ITEM3 0 32 FLOAT EIGHT'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /invalid value for Integer/)
          tf.unlink
        end

        it "only allows DERIVED items with offset 0 and size 0" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ITEM ITEM1 8 0 DERIVED'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /DERIVED items must have bit_offset of zero/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ITEM ITEM1 0 8 DERIVED'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /DERIVED items must have bit_size of zero/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ITEM ITEM1 0 0 DERIVED'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.telemetry["TGT1"]["PKT1"].items.keys).to include('ITEM1')
          tf.unlink
        end

        it "accepts types INT UINT FLOAT STRING BLOCK" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ID_ITEM ITEM1 0 32 INT 0'
          tf.puts '  ITEM ITEM2 0 32 UINT'
          tf.puts '  ARRAY_ITEM ITEM3 0 32 FLOAT 64'
          tf.puts '  APPEND_ID_ITEM ITEM4 32 STRING "ABCD"'
          tf.puts '  APPEND_ITEM ITEM5 32 BLOCK'
          tf.puts '  APPEND_ARRAY_ITEM ITEM6 32 BLOCK 64'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.telemetry["TGT1"]["PKT1"].items.keys).to include('ITEM1','ITEM2','ITEM3','ITEM4','ITEM5','ITEM6')
          id_items = []
          id_items << @pc.telemetry["TGT1"]["PKT1"].items["ITEM1"]
          id_items << @pc.telemetry["TGT1"]["PKT1"].items["ITEM4"]
          expect(@pc.telemetry["TGT1"]["PKT1"].id_items).to eql id_items
          tf.unlink
        end

        it "supports arbitrary endianness per item" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ID_ITEM ITEM1 0 32 UINT 0 "" LITTLE_ENDIAN'
          tf.puts '  ITEM ITEM2 0 32 UINT "" LITTLE_ENDIAN'
          tf.puts '  ARRAY_ITEM ITEM3 0 32 UINT 64 "" LITTLE_ENDIAN'
          tf.puts '  APPEND_ID_ITEM ITEM4 32 UINT 1 "" LITTLE_ENDIAN'
          tf.puts '  APPEND_ITEM ITEM5 32 UINT "" LITTLE_ENDIAN'
          tf.puts '  APPEND_ARRAY_ITEM ITEM6 32 UINT 64 "" LITTLE_ENDIAN'
          tf.puts '  ID_ITEM ITEM10 224 32 UINT 0 "" BIG_ENDIAN'
          tf.puts '  ITEM ITEM20 256 32 UINT "" BIG_ENDIAN'
          tf.puts '  ARRAY_ITEM ITEM30 0 32 UINT 64 "" BIG_ENDIAN'
          tf.puts '  APPEND_ID_ITEM ITEM40 32 UINT 1 "" BIG_ENDIAN'
          tf.puts '  APPEND_ITEM ITEM50 32 UINT "" BIG_ENDIAN'
          tf.puts '  APPEND_ARRAY_ITEM ITEM60 32 UINT 64 "" BIG_ENDIAN'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          packet = @pc.telemetry["TGT1"]["PKT1"]
          packet.buffer = "\x00\x00\x00\x01" * 16
          expect(packet.read("ITEM1")).to eql 0x01000000
          expect(packet.read("ITEM2")).to eql 0x01000000
          expect(packet.read("ITEM3")).to eql [0x01000000, 0x01000000]
          expect(packet.read("ITEM4")).to eql 0x01000000
          expect(packet.read("ITEM5")).to eql 0x01000000
          expect(packet.read("ITEM6")).to eql [0x01000000, 0x01000000]
          expect(packet.read("ITEM10")).to eql 0x00000001
          expect(packet.read("ITEM20")).to eql 0x00000001
          expect(packet.read("ITEM30")).to eql [0x00000001, 0x00000001]
          expect(packet.read("ITEM40")).to eql 0x00000001
          expect(packet.read("ITEM50")).to eql 0x00000001
          expect(packet.read("ITEM60")).to eql [0x00000001, 0x00000001]
          tf.unlink
        end
      end

      context "with keywords including PARAMETER" do
        it "only allows PARAMETER after COMMAND" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  PARAMETER ITEM1 8 0 DERIVED 0 0 0'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /PARAMETER types are only valid with COMMAND/)
          tf.unlink
        end

        it "complains if given an incomplete definition" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  PARAMETER ITEM1 8 0'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  PARAMETER ITEM1 8'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  PARAMETER ITEM1'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  PARAMETER'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters/)
          tf.unlink
        end

        it "only allows DERIVED items with offset 0 and size 0" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  PARAMETER ITEM1 8 0 DERIVED 0 0 0'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /DERIVED items must have bit_offset of zero/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  PARAMETER ITEM1 0 8 DERIVED 0 0 0'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /DERIVED items must have bit_size of zero/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  PARAMETER ITEM1 0 0 DERIVED 0 0 0'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.commands["TGT1"]["PKT1"].items.keys).to include('ITEM1')
          tf.unlink
        end

        it "doesn't allow ID_PARAMETER with DERIVED type" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ID_PARAMETER ITEM1 0 0 DERIVED 0 0 0'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /DERIVED data type not allowed/)
          tf.unlink
        end

        it "doesn't allow APPEND_ID_PARAMETER with DERIVED type" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  APPEND_ID_PARAMETER ITEM1 0 DERIVED 0 0 0'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /DERIVED data type not allowed/)
          tf.unlink
        end

        it "accepts types INT UINT FLOAT STRING BLOCK" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ID_PARAMETER ITEM1 0 32 INT 0 0 0'
          tf.puts '  ID_PARAMETER ITEM2 32 32 STRING "ABCD"'
          tf.puts '  PARAMETER ITEM3 64 32 UINT 0 0 0'
          tf.puts '  ARRAY_PARAMETER ITEM4 96 32 FLOAT 64'
          tf.puts '  APPEND_ID_PARAMETER ITEM5 32 UINT 0 0 0'
          tf.puts '  APPEND_ID_PARAMETER ITEM6 32 STRING "ABCD"'
          tf.puts '  APPEND_PARAMETER ITEM7 32 BLOCK "1234"'
          tf.puts '  APPEND_ARRAY_PARAMETER ITEM8 32 BLOCK 64'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.commands["TGT1"]["PKT1"].items.keys).to include('ITEM1','ITEM2','ITEM3','ITEM4','ITEM5','ITEM6','ITEM7','ITEM8')
          tf.unlink
        end

        it "supports arbitrary range, default and endianness per item" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ID_PARAMETER ITEM1 0 32 UINT 1 2 3 "" LITTLE_ENDIAN'
          tf.puts '  PARAMETER ITEM2 0 32 UINT 4 5 6 "" LITTLE_ENDIAN'
          tf.puts '  ARRAY_PARAMETER ITEM3 0 32 UINT 64 "" LITTLE_ENDIAN'
          tf.puts '  APPEND_ID_PARAMETER ITEM4 32 UINT 7 8 9 "" LITTLE_ENDIAN'
          tf.puts '  APPEND_PARAMETER ITEM5 32 UINT 10 11 12 "" LITTLE_ENDIAN'
          tf.puts '  APPEND_ARRAY_PARAMETER ITEM6 32 UINT 64 "" LITTLE_ENDIAN'
          tf.puts '  ID_PARAMETER ITEM10 224 32 UINT 13 14 15 "" BIG_ENDIAN'
          tf.puts '  PARAMETER ITEM20 256 32 UINT 16 17 18 "" BIG_ENDIAN'
          tf.puts '  ARRAY_PARAMETER ITEM30 0 32 UINT 64 "" BIG_ENDIAN'
          tf.puts '  APPEND_ID_PARAMETER ITEM40 32 UINT 19 20 21 "" BIG_ENDIAN'
          tf.puts '  APPEND_PARAMETER ITEM50 32 UINT 22 23 24 "" BIG_ENDIAN'
          tf.puts '  APPEND_ARRAY_PARAMETER ITEM60 32 UINT 64 "" BIG_ENDIAN'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          packet = @pc.commands["TGT1"]["PKT1"]
          packet.buffer = "\x00\x00\x00\x01" * 16
          expect(packet.get_item("ITEM1").range).to eql (1..2)
          expect(packet.get_item("ITEM1").default).to eql 3
          expect(packet.read("ITEM1")).to eql 0x01000000
          expect(packet.get_item("ITEM2").range).to eql (4..5)
          expect(packet.get_item("ITEM2").default).to eql 6
          expect(packet.read("ITEM2")).to eql 0x01000000
          expect(packet.get_item("ITEM3").range).to be_nil
          expect(packet.get_item("ITEM3").default).to eql []
          expect(packet.read("ITEM3")).to eql [0x01000000, 0x01000000]
          expect(packet.get_item("ITEM4").range).to eql (7..8)
          expect(packet.get_item("ITEM4").default).to eql 9
          expect(packet.read("ITEM4")).to eql 0x01000000
          expect(packet.get_item("ITEM5").range).to eql (10..11)
          expect(packet.get_item("ITEM5").default).to eql 12
          expect(packet.read("ITEM5")).to eql 0x01000000
          expect(packet.get_item("ITEM6").range).to be_nil
          expect(packet.get_item("ITEM6").default).to eql []
          expect(packet.read("ITEM6")).to eql [0x01000000, 0x01000000]
          expect(packet.get_item("ITEM10").range).to eql (13..14)
          expect(packet.get_item("ITEM10").default).to eql 15
          expect(packet.read("ITEM10")).to eql 0x00000001
          expect(packet.get_item("ITEM20").range).to eql (16..17)
          expect(packet.get_item("ITEM20").default).to eql 18
          expect(packet.read("ITEM20")).to eql 0x00000001
          expect(packet.get_item("ITEM30").range).to be_nil
          expect(packet.get_item("ITEM30").default).to eql []
          expect(packet.read("ITEM30")).to eql [0x00000001, 0x00000001]
          expect(packet.get_item("ITEM40").range).to eql (19..20)
          expect(packet.get_item("ITEM40").default).to eql 21
          expect(packet.read("ITEM40")).to eql 0x00000001
          expect(packet.get_item("ITEM50").range).to eql (22..23)
          expect(packet.get_item("ITEM50").default).to eql 24
          expect(packet.read("ITEM50")).to eql 0x00000001
          expect(packet.get_item("ITEM60").range).to be_nil
          expect(packet.get_item("ITEM60").default).to eql []
          expect(packet.read("ITEM60")).to eql [0x00000001, 0x00000001]
          tf.unlink
        end

        it "only supports BIG_ENDIAN and LITTLE_ENDIAN" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ID_PARAMETER ITEM1 0 32 UINT 0 0 0 "" MIDDLE_ENDIAN'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid endianness MIDDLE_ENDIAN/)
          tf.unlink
        end

        context "with a conversion" do
          it "allows for different default type than the data type" do
            tf = Tempfile.new('unittest')
            tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
            tf.puts '  PARAMETER ITEM1 0 32 UINT 4.5 5.5 6.5 "" LITTLE_ENDIAN'
            tf.puts '    GENERIC_WRITE_CONVERSION_START'
            tf.puts '      value / 2.0'
            tf.puts '    GENERIC_WRITE_CONVERSION_END'
            tf.close
            @pc.process_file(tf.path, "TGT1")
            tf.unlink
          end
        end

        context "without a conversion" do
          it "requires the default type matches the data type" do
            tf = Tempfile.new('unittest')
            tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
            tf.puts '  PARAMETER ITEM1 0 32 UINT 4.5 5.5 6.5 "" LITTLE_ENDIAN'
            tf.close
            expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ArgumentError, /TGT1 PKT1 ITEM1: default must be a Integer but is a Float/)
            tf.unlink
          end
        end

      end

    end # describe "process_file"
  end
end
