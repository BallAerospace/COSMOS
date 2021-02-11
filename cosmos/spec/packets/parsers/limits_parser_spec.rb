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
require 'cosmos/packets/parsers/limits_parser'
require 'tempfile'

module Cosmos
  describe LimitsParser do
    describe "parse" do
      before(:all) do
        setup_system()
      end

      before(:each) do
        @pc = PacketConfig.new
      end

      it "complains if a current item is not defined" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  LIMITS mylimits 1 ENABLED 0 10 20 30 12 18'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /No current item for LIMITS/)
        tf.unlink
      end

      it "complains if there are not enough parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM myitem 0 8 UINT "Test Item"'
        tf.puts '    LIMITS DEFAULT 1 ENABLED 0 10 20 30 12'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Must give both a green low and green high/)
        tf.unlink

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM myitem 0 8 UINT "Test Item"'
        tf.puts '    LIMITS DEFAULT 1 ENABLED 0 10 20'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters for LIMITS/)
        tf.unlink
      end

      it "complains if there are too many parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM myitem 0 8 UINT "Test Item"'
        tf.puts '    LIMITS DEFAULT 1 ENABLED 0 10 20 30 12 18 20'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Too many parameters for LIMITS/)
        tf.unlink
      end

      it "complains if applied to a command PARAMETER" do
        tf = Tempfile.new('unittest')
        tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 7 3 5'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /LIMITS only applies to telemetry items/)
        tf.unlink
      end

      it "complains if a DEFAULT limits set isn't defined" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS TVAC 3 ENABLED 1 2 6 7 3 5'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /DEFAULT limits set must be defined/)
        tf.unlink
      end

      it "complains if STATES are defined" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    STATE ONE 1'
        tf.puts '    LIMITS TVAC 3 ENABLED 1 2 6 7 3 5'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Items with STATE can't define LIMITS/)
        tf.unlink
      end

      it "sets a warning if a new limits set persistence isn't consistent with DEFAULT" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 7 3 5'
        tf.puts '    LIMITS TVAC 1 DISABLED 1 2 6 7 3 5'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        expect(@pc.warnings[-1]).to match(/persistence setting conflict with DEFAULT/)
        tf.unlink
      end

      it "sets a warning if a new limits set enable isn't consistent with DEFAULT" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 7 3 5'
        tf.puts '    LIMITS TVAC 3 DISABLED 1 2 6 7 3 5'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        expect(@pc.warnings[-1]).to match(/enable setting conflict with DEFAULT/)
        tf.unlink
      end

      it "records 2 warnings if a new limits set persistence and enable isn't consistent with DEFAULT" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 7 3 5'
        tf.puts '    LIMITS TVAC 1 DISABLED 1 2 6 7 3 5'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        expect(@pc.warnings.length).to eql 2
        tf.unlink
      end

      it "complains if the second parameter isn't a number" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT TRUE ENABLED 1 2 6 7 3 5'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Persistence must be an integer/)
        tf.unlink
      end

      it "complains if the third parameter isn't ENABLED or DISABLED" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 TRUE 1 2 6 7 3 5'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Initial LIMITS state must be ENABLED or DISABLED/)
        tf.unlink
      end

      it "complains if the fourth through ninth parameter aren't numbers'" do
        msgs = ['','','','','red low','yellow low','yellow high','red high','green low','green high']
        (4..9).each do |index|
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          limits = %w(LIMITS DEFAULT 3 ENABLED 1 2 6 7 3 5)
          limits[index] = 'X'
          tf.puts limits.join(' ')
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid #{msgs[index]} limit value/)
          tf.unlink
        end
      end

      it "complains if the 4 limits are out of order" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 2 1 3 4'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid limits specified. Ensure yellow limits are within red limits./)
        tf.unlink

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 5 3 7'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid limits specified. Ensure yellow limits are within red limits./)
        tf.unlink

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 5 4'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid limits specified. Ensure yellow limits are within red limits./)
        tf.unlink

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 3 0'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid limits specified. Ensure yellow limits are within red limits./)
        tf.unlink
      end

      it "complains if the 6 limits are out of order" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 7 0 5'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid limits specified. Ensure green limits are within yellow limits./)
        tf.unlink

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 3 6 7 2 5'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid limits specified. Ensure green limits are within yellow limits./)
        tf.unlink

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 8 3 7'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid limits specified. Ensure green limits are within yellow limits./)
        tf.unlink

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 8 3 9'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid limits specified. Ensure green limits are within yellow limits./)
        tf.unlink

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 8 4 3'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid limits specified. Ensure green limits are within yellow limits./)
        tf.unlink
      end

      it "takes 4 limits values" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 6 7'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        item = @pc.telemetry["TGT1"]["PKT1"].items["ITEM1"]
        expect(item.limits.values[:DEFAULT]).not_to be_nil
        @pc.telemetry["TGT1"]["PKT1"].buffer = "\x04"
        @pc.telemetry["TGT1"]["PKT1"].enable_limits("ITEM1")
        @pc.telemetry["TGT1"]["PKT1"].check_limits
        expect(item.limits.state).to eql :GREEN
        expect(@pc.telemetry["TGT1"]["PKT1"].limits_items).to eql [item]
        tf.unlink
      end

      it "takes 6 limits values" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 6 7 3 5'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        item = @pc.telemetry["TGT1"]["PKT1"].items["ITEM1"]
        expect(item.limits.values[:DEFAULT]).not_to be_nil
        @pc.telemetry["TGT1"]["PKT1"].buffer = "\x04"
        @pc.telemetry["TGT1"]["PKT1"].enable_limits("ITEM1")
        @pc.telemetry["TGT1"]["PKT1"].check_limits
        expect(item.limits.state).to eql :BLUE
        expect(@pc.telemetry["TGT1"]["PKT1"].limits_items).to eql [item]
        tf.unlink
      end

      it "create multiple limits sets" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
        tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 6 7'
        tf.puts '    LIMITS TVAC 1 ENABLED 1 2 6 7'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        item = @pc.telemetry["TGT1"]["PKT1"].items["ITEM1"]
        expect(item.limits.values.length).to eql 2
        expect(item.limits.values[:DEFAULT]).to_not be_nil
        expect(item.limits.values[:TVAC]).to_not be_nil
        tf.unlink
      end
    end
  end
end
