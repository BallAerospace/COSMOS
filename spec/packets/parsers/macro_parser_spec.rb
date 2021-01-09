# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos'
require 'cosmos/packets/packet_config'
require 'cosmos/packets/parsers/macro_parser'
require 'tempfile'

module Cosmos
  describe MacroParser do
    before(:each) do
      configure_store()
      @pc = PacketConfig.new
    end

    describe "start" do
      it "complains if a current packet is not defined" do
        # Check for missing TELEMETRY line
        tf = Tempfile.new('unittest')
        tf.puts '  MACRO_APPEND_START'
        tf.close
        expect { @pc.process_file(tf.path, "SYSTEM") }.to raise_error(ConfigParser::Error, /No current packet for MACRO_APPEND_START/)
      end

      it "complains if there are not enough parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  MACRO_APPEND_START'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters for MACRO_APPEND_START/)
        tf.unlink
      end

      it "complains if there are too many parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts 'MACRO_APPEND_START 0 1 "%s_%d" extra'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Too many parameters for MACRO_APPEND_START/)
        tf.unlink
      end

      it "complains if a previous START hasn't been closed" do
        # Check for missing TELEMETRY line
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  MACRO_APPEND_START 1 5'
        tf.puts '  MACRO_APPEND_START 1 5'
        tf.close
        expect { @pc.process_file(tf.path, "SYSTEM") }.to raise_error(ConfigParser::Error, /First close the previous/)
      end

      it "supports descending order" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts 'MACRO_APPEND_START 4 1' # <-- Note the reverse order
        tf.puts 'APPEND_ITEM BIT 16 UINT "Setting #x"'
        tf.puts '  STATE BAD 0 RED'
        tf.puts '  STATE GOOD 1 GREEN'
        tf.puts 'MACRO_APPEND_END'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        pkt = @pc.telemetry["TGT1"]["PKT1"]
        expect(pkt.items.length).to eql 9 # 4 plus the RECEIVED_XXX and PACKET_TIMExxx items
        expect(pkt.items.keys).to include('BIT1','BIT2','BIT3','BIT4')
        expect(pkt.sorted_items[5].name).to eql 'BIT4'
        expect(pkt.sorted_items[6].name).to eql 'BIT3'
        expect(pkt.sorted_items[7].name).to eql 'BIT2'
        expect(pkt.sorted_items[8].name).to eql 'BIT1'
        limits_items = []
        pkt.items.each do |name, item|
          limits_items << item if name.include?('BIT')
        end
        expect(pkt.limits_items).to eql limits_items
        tf.unlink
      end
    end

    describe "end" do
      it "complains if there are too many parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts 'MACRO_APPEND_START 0 1 "%s_%d"'
        tf.puts 'MACRO_APPEND_END extra'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Too many parameters for MACRO_APPEND_END/)
        tf.unlink
      end

      it "complains if there are no items in the macro" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts 'MACRO_APPEND_START 0 1 "%s_%d"'
        tf.puts 'MACRO_APPEND_END'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /No items appended/)
        tf.unlink
      end
    end

    describe "add_item" do
      it "adds multiple items to the packet" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts 'MACRO_APPEND_START 1 4'
        tf.puts 'APPEND_ITEM WORD 16 UINT'
        tf.puts 'APPEND_ITEM DWORD 32 UINT'
        tf.puts 'MACRO_APPEND_END'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        pkt = @pc.telemetry["TGT1"]["PKT1"]
        expect(pkt.items.length).to eql 13 # 8 plus the RECEIVED_XXX and PACKET_TIMExxx items
        expect(pkt.items.keys).to include('WORD1','WORD2','WORD3','WORD4','DWORD1','DWORD2','DWORD3','DWORD4')
        expect(pkt.sorted_items[5].name).to eql 'WORD1'
        expect(pkt.sorted_items[5].bit_offset).to eql 0
        expect(pkt.sorted_items[6].name).to eql 'DWORD1'
        expect(pkt.sorted_items[6].bit_offset).to eql 16
        expect(pkt.sorted_items[7].name).to eql 'WORD2'
        expect(pkt.sorted_items[7].bit_offset).to eql 48
        expect(pkt.sorted_items[8].name).to eql 'DWORD2'
        expect(pkt.sorted_items[8].bit_offset).to eql 64
        expect(pkt.sorted_items[9].name).to eql 'WORD3'
        expect(pkt.sorted_items[9].bit_offset).to eql 96
        expect(pkt.sorted_items[10].name).to eql 'DWORD3'
        expect(pkt.sorted_items[10].bit_offset).to eql 112
        expect(pkt.sorted_items[11].name).to eql 'WORD4'
        expect(pkt.sorted_items[11].bit_offset).to eql 144
        expect(pkt.sorted_items[12].name).to eql 'DWORD4'
        expect(pkt.sorted_items[12].bit_offset).to eql 160
        tf.unlink
      end

      it "adds items with states to the packet" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts 'MACRO_APPEND_START 1 5'
        tf.puts 'APPEND_ITEM BIT 16 UINT "Setting #x"'
        tf.puts '  STATE BAD 0 RED'
        tf.puts '  STATE GOOD 1 GREEN'
        tf.puts 'MACRO_APPEND_END'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        pkt = @pc.telemetry["TGT1"]["PKT1"]
        expect(pkt.items.length).to eql 10 # 5 plus the RECEIVED_XXX and PACKET_TIMExxx items
        expect(pkt.items.keys).to include('BIT1','BIT2','BIT3','BIT4','BIT5')
        expect(pkt.sorted_items[5].name).to eql 'BIT1'
        expect(pkt.sorted_items[5].bit_offset).to eql 0
        expect(pkt.sorted_items[6].name).to eql 'BIT2'
        expect(pkt.sorted_items[6].bit_offset).to eql 16
        expect(pkt.sorted_items[7].name).to eql 'BIT3'
        expect(pkt.sorted_items[7].bit_offset).to eql 32
        expect(pkt.sorted_items[8].name).to eql 'BIT4'
        expect(pkt.sorted_items[8].bit_offset).to eql 48
        expect(pkt.sorted_items[9].name).to eql 'BIT5'
        expect(pkt.sorted_items[9].bit_offset).to eql 64
        limits_items = []
        pkt.items.each do |name, item|
          limits_items << item if name.include?('BIT')
        end
        expect(pkt.limits_items).to eql limits_items
        tf.unlink
      end

      it "adds items with limits to the packet" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts 'MACRO_APPEND_START 1 5'
        tf.puts 'APPEND_ITEM BIT 16 UINT "Setting #x"'
        tf.puts '  LIMITS DEFAULT 3 ENABLED 0 1 3 4'
        tf.puts 'MACRO_APPEND_END'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        pkt = @pc.telemetry["TGT1"]["PKT1"]
        expect(pkt.items.length).to eql 10 # 5 plus the RECEIVED_XXX and PACKET_TIMExxx items
        expect(pkt.items.keys).to include('BIT1','BIT2','BIT3','BIT4','BIT5')
        expect(pkt.limits_items.collect{|item| item.name}).to include('BIT1','BIT2','BIT3','BIT4','BIT5')
        tf.unlink
      end

      it "adds array items to the packet" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts 'MACRO_APPEND_START 1 5'
        tf.puts 'APPEND_ARRAY_ITEM BIT 16 INT 64 "Int Array Parameter"'
        tf.puts 'MACRO_APPEND_END'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        pkt = @pc.telemetry["TGT1"]["PKT1"]
        expect(pkt.items.length).to eql 10 # 5 plus the RECEIVED_XXX and PACKET_TIMExxx items
        expect(pkt.items.keys).to include('BIT1','BIT2','BIT3','BIT4','BIT5')
        expect(pkt.limits_items).to be_empty
        tf.unlink
      end

      it "works with printf format strings" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts 'MACRO_APPEND_START 8 12 "%02d_%s"'
        tf.puts 'APPEND_ID_ITEM BIT 16 UINT 0 "Setting #x"'
        tf.puts 'MACRO_APPEND_END'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        pkt = @pc.telemetry["TGT1"]["PKT1"]
        expect(pkt.items.length).to eql 10 # 5 plus the RECEIVED_XXX and PACKET_TIMExxx items
        expect(pkt.items.keys).to include('08_BIT','09_BIT','10_BIT','11_BIT','12_BIT')
        expect(pkt.limits_items).to be_empty
        tf.unlink
      end
    end
  end
end
