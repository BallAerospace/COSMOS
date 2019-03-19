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
require 'cosmos/packets/parsers/state_parser'
require 'tempfile'

module Cosmos

  describe StateParser do

    describe "process_file" do
      before(:each) do
        @pc = PacketConfig.new
      end

      it "complains if a current item is not defined" do
        # Check for missing ITEM definitions
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts 'STATE'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /No current item for STATE/)
        tf.unlink
      end

      it "complains if there are not enough parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts 'ITEM myitem 0 8 UINT "Test Item"'
        tf.puts 'STATE'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters for STATE/)
        tf.unlink
      end

      it "complains if LIMITS defined" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM myitem 0 8 UINT "Test Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 7 3 5'
        tf.puts '    STATE ONE 1'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Items with LIMITS can't define STATE/)
        tf.unlink
      end

      it "complains if UNITS defined" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM myitem 0 8 UINT "Test Item"'
        tf.puts '    UNITS Kelvin K'
        tf.puts '    STATE ONE 1'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Items with UNITS can't define STATE/)
        tf.unlink
      end

      it "complains if there are too many parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts 'ITEM myitem 0 8 UINT "Test Item"'
        tf.puts 'STATE mystate 0 RED extra'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Too many parameters for STATE/)
        tf.unlink
      end

      it "supports STRING items" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts '  APPEND_ITEM item1 128 STRING "state item"'
        tf.puts '    STATE FALSE "FALSE STRING"'
        tf.puts '    STATE TRUE "TRUE STRING"'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.telemetry["TGT1"]["PKT1"].write("ITEM1", "TRUE STRING")
        expect(@pc.telemetry["TGT1"]["PKT1"].read("ITEM1")).to eql "TRUE"
        @pc.telemetry["TGT1"]["PKT1"].write("ITEM1", "FALSE STRING")
        expect(@pc.telemetry["TGT1"]["PKT1"].read("ITEM1")).to eql "FALSE"
        tf.unlink
      end

      it "warns about duplicate states and replace the duplicate" do
        tf = Tempfile.new('unittest')
        tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts '  APPEND_PARAMETER item1 8 UINT 0 2 0 "state item"'
        tf.puts '    STATE FALSE 0'
        tf.puts '    STATE TRUE 1'
        tf.puts '    STATE FALSE 2'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        expect(@pc.warnings).to include("Duplicate state defined on line 5: STATE FALSE 2")
        @pc.commands["TGT1"]["PKT1"].buffer = "\x00"
        expect(@pc.commands["TGT1"]["PKT1"].read("ITEM1")).to eql 0
        @pc.commands["TGT1"]["PKT1"].buffer = "\x02"
        expect(@pc.commands["TGT1"]["PKT1"].read("ITEM1")).to eql "FALSE"
        tf.unlink
      end

      context "with telemetry" do
        it "defines states on ARRAY items" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  APPEND_ARRAY_ITEM item1 8 UINT 40 "state item"'
          tf.puts '    STATE FALSE 0'
          tf.puts '    STATE TRUE 1'
          tf.puts '    STATE ERROR ANY'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          tlm = Telemetry.new(@pc)
          pkt = tlm.packet("TGT1", "PKT1")
          pkt.write("ITEM1", [0,1,2,1,0])
          expect(pkt.read("ITEM1")).to eql ["FALSE","TRUE","ERROR","TRUE","FALSE"]
          tf.unlink
        end

        it "uses state or FORMAT_STRING if no state" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 8 UINT "Test Item"'
          tf.puts '    FORMAT_STRING "0x%x"'
          tf.puts '    STATE ONE 1'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          tlm = Telemetry.new(@pc)
          pkt = tlm.packet("TGT1", "PKT1")
          pkt.write("ITEM1", 1)
          expect(pkt.read("ITEM1", :FORMATTED)).to eql "ONE"
          pkt.write("ITEM1", 2)
          expect(pkt.read("ITEM1", :FORMATTED)).to eql "0x2"
          tf.unlink

          # Ensure the order of STATE vs FORMAT_STRING doesn't matter
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 8 UINT "Test Item"'
          tf.puts '    STATE ONE 1'
          tf.puts '    FORMAT_STRING "0x%x"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          tlm = Telemetry.new(@pc)
          pkt = tlm.packet("TGT1", "PKT1")
          pkt.write("ITEM1", 1)
          expect(pkt.read("ITEM1", :FORMATTED)).to eql "ONE"
          pkt.write("ITEM1", 2)
          expect(pkt.read("ITEM1", :FORMATTED)).to eql "0x2"
          tf.unlink
        end

        it "allows an 'ANY' state" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  APPEND_ITEM item1 8 UINT "state item"'
          tf.puts '    STATE FALSE 0'
          tf.puts '    STATE TRUE 1'
          tf.puts '    STATE ERROR ANY'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          tlm = Telemetry.new(@pc)
          pkt = tlm.packet("TGT1", "PKT1")
          pkt.write("ITEM1", 0)
          expect(pkt.read("ITEM1")).to eql "FALSE"
          pkt.write("ITEM1", 1)
          expect(pkt.read("ITEM1")).to eql "TRUE"
          pkt.write("ITEM1", 2)
          expect(pkt.read("ITEM1")).to eql "ERROR"
          tf.unlink
        end

        it "only allows GREEN YELLOW or RED" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  APPEND_ITEM item1 8 UINT "state item"'
          tf.puts '    STATE WORST 1 ORANGE'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid state color ORANGE/)
          tf.unlink
        end

        it "records the state values and colors" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  APPEND_ITEM item1 8 UINT "state item"'
          tf.puts '    STATE STATE1 1 RED'
          tf.puts '    STATE STATE2 2 YELLOW'
          tf.puts '    STATE STATE3 3 GREEN'
          tf.puts '    STATE STATE4 4'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          index = 1
          colors = [:RED, :YELLOW, :GREEN]
          @pc.telemetry["TGT1"]["PKT1"].items["ITEM1"].states.each do |name,val|
            expect(name).to eql "STATE#{index}"
            expect(val).to eql index
            expect(@pc.telemetry["TGT1"]["PKT1"].items["ITEM1"].state_colors[name]).to eql colors[index - 1]

            index += 1
          end
          expect(@pc.telemetry["TGT1"]["PKT1"].limits_items).to eql [@pc.telemetry["TGT1"]["PKT1"].items["ITEM1"]]
          tf.unlink
        end
      end

      context "with command" do
        it "only allows HAZARDOUS as the third param" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  APPEND_PARAMETER item1 8 UINT 0 0 0'
          tf.puts '    STATE WORST 0 RED'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /HAZARDOUS expected as third parameter/)
          tf.unlink
        end

        it "takes HAZARDOUS and an optional description" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  APPEND_PARAMETER item1 8 UINT 1 3 1'
          tf.puts '    STATE GOOD 1'
          tf.puts '    STATE BAD 2 HAZARDOUS'
          tf.puts '    STATE WORST 3 HAZARDOUS "Hazardous description"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].buffer = "\x01"
          @pc.commands["TGT1"]["PKT1"].check_limits
          expect(@pc.commands["TGT1"]["PKT1"].items["ITEM1"].hazardous["GOOD"]).to be_nil
          expect(@pc.commands["TGT1"]["PKT1"].items["ITEM1"].hazardous["BAD"]).not_to be_nil
          expect(@pc.commands["TGT1"]["PKT1"].items["ITEM1"].hazardous["WORST"]).not_to be_nil
          expect(@pc.commands["TGT1"]["PKT1"].items["ITEM1"].hazardous["WORST"]).to eql "Hazardous description"
          expect(@pc.commands["TGT1"]["PKT1"].limits_items).to be_empty
          tf.unlink
        end
      end

    end
  end
end
