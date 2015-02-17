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
require 'cosmos/packets/parsers/packet_parser'
require 'tempfile'

module Cosmos

  describe PacketParser do

    describe "process_file" do
      before(:each) do
        @pc = PacketConfig.new
      end

      it "complains if there are not enough parameters" do
        %w(COMMAND TELEMETRY).each do |keyword|
          tf = Tempfile.new('unittest')
          tf.puts(keyword)
          tf.close
          expect { @pc.process_file(tf.path, "SYSTEM") }.to raise_error(ConfigParser::Error, /Not enough parameters for #{keyword}/)
          tf.unlink
        end
      end

      it "complains if there are too many parameters" do
        %w(COMMAND TELEMETRY).each do |keyword|
          tf = Tempfile.new('unittest')
          tf.puts "#{keyword} tgt1 pkt1 LITTLE_ENDIAN 'Packet' extra"
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Too many parameters for #{keyword}/)
          tf.unlink
        end
      end

      it "complains about invalid endianness" do
        %w(COMMAND TELEMETRY).each do |keyword|
          tf = Tempfile.new('unittest')
          tf.puts keyword + ' tgt1 pkt1 MIDDLE_ENDIAN "Packet"'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid endianness MIDDLE_ENDIAN. Must be BIG_ENDIAN or LITTLE_ENDIAN.")
          tf.unlink
        end
      end

      it "processes target, packet, endianness, description" do
        %w(COMMAND TELEMETRY).each do |keyword|
          tf = Tempfile.new('unittest')
          tf.puts keyword + ' tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          pkt = @pc.commands["TGT1"]["PKT1"] if keyword == 'COMMAND'
          pkt = @pc.telemetry["TGT1"]["PKT1"] if keyword == 'TELEMETRY'
          pkt.target_name.should eql "TGT1"
          pkt.packet_name.should eql "PKT1"
          pkt.default_endianness.should eql :LITTLE_ENDIAN
          pkt.description.should eql "Packet"
          tf.unlink
        end
      end

      it "substitutes the target name" do
        %w(COMMAND TELEMETRY).each do |keyword|
          tf = Tempfile.new('unittest')
          tf.puts keyword + ' tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.close
          @pc.process_file(tf.path, "NEW")
          pkt = @pc.commands["NEW"]["PKT1"] if keyword == 'COMMAND'
          pkt = @pc.telemetry["NEW"]["PKT1"] if keyword == 'TELEMETRY'
          pkt.target_name.should eql "NEW"
          tf.unlink
        end
      end

      it "complains if a packet is redefined" do
        %w(COMMAND TELEMETRY).each do |keyword|
          tf = Tempfile.new('unittest')
          tf.puts keyword + ' tgt1 pkt1 LITTLE_ENDIAN "Packet 1"'
          tf.puts keyword + ' tgt1 pkt1 LITTLE_ENDIAN "Packet 2"'
          tf.close
          @pc.process_file(tf.path, "SYSTEM")
          @pc.warnings.should include("#{keyword.capitalize} Packet TGT1 PKT1 redefined.")
          tf.unlink
        end
      end

    end # describe "process_file"
  end
end
