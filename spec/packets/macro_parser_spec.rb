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
require 'cosmos/packets/macro_parser'
require 'tempfile'

module Cosmos

  describe MacroParser do

    describe "process_file" do
      before(:each) do
        @pc = PacketConfig.new
      end

      it "complains if a current packet is not defined" do
        # Check for missing TELEMETRY line
        %w(MACRO_APPEND_START MACRO_APPEND_END).each do |keyword|
          tf = Tempfile.new('unittest')
          tf.puts(keyword)
          tf.close
          expect { @pc.process_file(tf.path, "SYSTEM") }.to raise_error(ConfigParser::Error, "No current packet for #{keyword}")
          tf.unlink
        end
      end

      it "should complain if there are not enough parameters" do
        %w(MACRO_APPEND_START MACRO_APPEND_END).each do |keyword|
          next if %w(MACRO_APPEND_END).include? keyword
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts keyword
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters for #{keyword}/)
          tf.unlink
        end
      end

      it "should complain if there are too many parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts 'MACRO_APPEND_START 0 1 "%s_%d" extra'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Too many parameters for MACRO_APPEND_START/)
        tf.unlink

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts 'MACRO_APPEND_END extra'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Too many parameters for MACRO_APPEND_END/)
        tf.unlink
      end

      context "with MACRO_APPEND_START" do
        it "should add items to the packet" do
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
          pkt.items.keys.should include('BIT1','BIT2','BIT3','BIT4','BIT5')
          limits_items = []
          pkt.items.each do |name, item|
            limits_items << item if name =~ /BIT/
          end
          pkt.limits_items.should eql limits_items
          tf.unlink
        end

        it "should array items to the packet" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'MACRO_APPEND_START 1 5'
          tf.puts 'APPEND_ARRAY_ITEM BIT 16 INT 64 "Int Array Parameter"'
          tf.puts 'MACRO_APPEND_END'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          pkt = @pc.telemetry["TGT1"]["PKT1"]
          pkt.items.keys.should include('BIT1','BIT2','BIT3','BIT4','BIT5')
          pkt.limits_items.should be_empty
          tf.unlink
        end

        it "should work with printf format strings" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'MACRO_APPEND_START 1 5 "%d%s"'
          tf.puts 'APPEND_ID_ITEM BIT 16 UINT 0 "Setting #x"'
          tf.puts 'MACRO_APPEND_END'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          pkt = @pc.telemetry["TGT1"]["PKT1"]
          pkt.items.keys.should include('1BIT','2BIT','3BIT','4BIT','5BIT')
          pkt.limits_items.should be_empty
          tf.unlink
        end
      end

    end
  end
end
