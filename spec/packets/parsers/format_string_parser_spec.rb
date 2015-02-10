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
require 'cosmos/packets/parsers/format_string_parser'
require 'tempfile'

module Cosmos

  describe PacketConfig do

    describe "process_file" do
      before(:each) do
        @pc = PacketConfig.new
      end

      it "should complain if a current item is not defined" do
        # Check for missing ITEM definitions
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  FORMAT_STRING'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "No current item for FORMAT_STRING")
        tf.unlink
      end

      it "should complain if there are not enough parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts 'ITEM myitem 0 8 UINT "Test Item"'
        tf.puts '  FORMAT_STRING'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters for FORMAT_STRING/)
        tf.unlink
      end

      it "should complain if there are too many parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts 'ITEM myitem 0 8 UINT "Test Item"'
        tf.puts "FORMAT_STRING '0x%x' extra"
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Too many parameters for FORMAT_STRING/)
        tf.unlink
      end

      it "should complain about invalid format strings" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM item1 0 8 INT'
        tf.puts '    FORMAT_STRING "%*s"'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid FORMAT_STRING specified for type INT: %*s")
        tf.unlink

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM item1 0 8 STRING'
        tf.puts '    FORMAT_STRING "%d"'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid FORMAT_STRING specified for type STRING: %d")
        tf.unlink
      end

      it "should format integers" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM item1 0 8 INT'
        tf.puts '    FORMAT_STRING "d%d"'
        tf.puts '  ITEM item2 0 8 UINT'
        tf.puts '    FORMAT_STRING "u%u"'
        tf.puts '  ITEM item3 0 8 UINT'
        tf.puts '    FORMAT_STRING "0x%x"'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.telemetry["TGT1"]["PKT1"].buffer = "\x0a\x0b\x0c"
        @pc.telemetry["TGT1"]["PKT1"].read("ITEM1",:FORMATTED).should eql "d10"
        @pc.telemetry["TGT1"]["PKT1"].read("ITEM2",:FORMATTED).should eql "u10"
        @pc.telemetry["TGT1"]["PKT1"].read("ITEM3",:FORMATTED).should eql "0xa"
        tf.unlink
      end

      it "should format floats" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM item1 0 32 FLOAT'
        tf.puts '    FORMAT_STRING "%3.3f"'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.telemetry["TGT1"]["PKT1"].write("ITEM1",12345.12345)
        @pc.telemetry["TGT1"]["PKT1"].read("ITEM1",:FORMATTED).should eql "12345.123"
        tf.unlink
      end

      it "should format strings and blocks" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM item1 0 32 STRING'
        tf.puts '    FORMAT_STRING "String: %s"'
        tf.puts '  ITEM item2 0 32 BLOCK'
        tf.puts '    FORMAT_STRING "Block: %s"'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.telemetry["TGT1"]["PKT1"].write("ITEM1","HI")
        @pc.telemetry["TGT1"]["PKT1"].read("ITEM1",:FORMATTED).should eql "String: HI"
        @pc.telemetry["TGT1"]["PKT1"].write("ITEM2","\x00\x01\x02\x03")
        @pc.telemetry["TGT1"]["PKT1"].read("ITEM2",:FORMATTED).should eql "Block: \x00\x01\x02\x03"
        tf.unlink
      end
    end

  end
end
