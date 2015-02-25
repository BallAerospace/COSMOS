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
require 'cosmos/packets/parsers/processor_parser'
require 'tempfile'

module Cosmos

  describe ProcessorParser do

    describe "process_file" do
      before(:each) do
        @pc = PacketConfig.new
      end

      it "complains if a current packet is not defined" do
        # Check for missing TELEMETRY line
        tf = Tempfile.new('unittest')
        tf.puts('PROCESSOR')
        tf.close
        expect { @pc.process_file(tf.path, "SYSTEM") }.to raise_error(ConfigParser::Error, "No current packet for PROCESSOR")
        tf.unlink
      end

      it "complains if there are not enough parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  PROCESSOR'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters for PROCESSOR/)
        tf.unlink
      end

      it "complains about missing processor file" do
        filename = File.join(File.dirname(__FILE__), "../../test_only.rb")
        File.delete(filename) if File.exist?(filename)
        @pc = PacketConfig.new

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  PROCESSOR TEST test_only.rb'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /TestOnly class not found/)
        tf.unlink
      end

      it "complains about a non Cosmos::Processor class" do
        filename = File.join(File.dirname(__FILE__), "../../processor1.rb")
        File.open(filename, 'w') do |file|
          file.puts "class Processor1"
          file.puts "  def call(packet,buffer)"
          file.puts "  end"
          file.puts "end"
        end
        load 'processor1.rb'
        File.delete(filename) if File.exist?(filename)

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  PROCESSOR P1 processor1.rb'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /processor must be a Cosmos::Processor but is a Processor1/)
        tf.unlink
      end

      it "parses the processor" do
        filename = File.join(File.dirname(__FILE__), "../../processor2.rb")
        File.open(filename, 'w') do |file|
          file.puts "require 'cosmos/processors/processor'"
          file.puts "class Processor2 < Cosmos::Processor"
          file.puts "  def call(packet,buffer)"
          file.puts "    @results[:TEST] = 5"
          file.puts "  end"
          file.puts "end"
        end
        load 'processor2.rb'

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM item1 0 16 INT "Integer Item"'
        tf.puts '    READ_CONVERSION processor_conversion.rb P2 TEST'
        tf.puts '  PROCESSOR P2 processor2.rb'
        tf.puts '  PROCESSOR P3 processor2.rb RAW'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.telemetry["TGT1"]["PKT1"].buffer = "\x01\x01"
        expect(@pc.telemetry["TGT1"]["PKT1"].read("ITEM1")).to eql 5
        tf.unlink

        File.delete(filename) if File.exist?(filename)
      end

      it "complains if applied to a command packet" do
        tf = Tempfile.new('unittest')
        tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  PROCESSOR P1 processor1.rb'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "PROCESSOR only applies to telemetry packets")
        tf.unlink
      end
    end

  end
end
