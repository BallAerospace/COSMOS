# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/packets/packet_config'
require 'cosmos/packets/parsers/limits_response_parser'
require 'tempfile'

module Cosmos
  describe PacketConfig do
    describe "parse" do
      before(:each) do
        configure_store()
        @pc = PacketConfig.new
      end

      it "complains if a current item is not defined" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  LIMITS_RESPONSE'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /No current item for LIMITS_RESPONSE/)
        tf.unlink
      end

      it "complains if there are not enough parameters" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts 'ITEM myitem 0 8 UINT "Test Item"'
        tf.puts '  LIMITS_RESPONSE'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters for LIMITS_RESPONSE/)
        tf.unlink
      end

      it "complains if applied to a command PARAMETER" do
        tf = Tempfile.new('unittest')
        tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
        tf.puts '    LIMITS_RESPONSE test.rb'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /LIMITS_RESPONSE only applies to telemetry items/)
        tf.unlink
      end

      it "complains about missing response file" do
        filename = File.join(File.dirname(__FILE__), "../../test_only.rb")
        File.delete(filename) if File.exist?(filename)
        @pc = PacketConfig.new

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM item1 0 16 INT "Integer Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 7 3 5'
        tf.puts '    LIMITS_RESPONSE test_only.rb'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /TestOnly class not found/)
        tf.unlink
      end

      it "complains about a non Cosmos::LimitsResponse class" do
        filename = File.join(File.dirname(__FILE__), "../../limits_response1.rb")
        File.open(filename, 'w') do |file|
          file.puts "class LimitsResponse1"
          file.puts "  def call(target_name, packet_name, item, old_limits_state, new_limits_state)"
          file.puts "  end"
          file.puts "end"
        end
        load 'limits_response1.rb'
        File.delete(filename) if File.exist?(filename)

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM item1 0 16 INT "Integer Item"'
        tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 7 3 5'
        tf.puts '    LIMITS_RESPONSE limits_response1.rb'
        tf.close
        expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /response must be a Cosmos::LimitsResponse but is a LimitsResponse1/)
        tf.unlink
      end

      it "sets the response" do
        filename = File.join(File.dirname(__FILE__), "../../limits_response2.rb")
        File.open(filename, 'w') do |file|
          file.puts "require 'cosmos/packets/limits_response'"
          file.puts "class LimitsResponse2 < Cosmos::LimitsResponse"
          file.puts "  def call(target_name, packet_name, item, old_limits_state, new_limits_state)"
          file.puts "    puts \"\#{target_name} \#{packet_name} \#{item.name} \#{old_limits_state} \#{new_limits_state}\""
          file.puts "  end"
          file.puts "end"
        end
        load 'limits_response2.rb'

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM item1 0 16 INT "Integer Item"'
        tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 6 7 3 5'
        tf.puts '    LIMITS_RESPONSE limits_response2.rb'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        pkt = @pc.telemetry["TGT1"]["PKT1"]
        expect(pkt.get_item("ITEM1").limits.response.class).to eql LimitsResponse2

        File.delete(filename) if File.exist?(filename)
        tf.unlink
      end

      it "calls the response with parameters" do
        filename = File.join(File.dirname(__FILE__), "../../limits_response2.rb")
        File.open(filename, 'w') do |file|
          file.puts "require 'cosmos/packets/limits_response'"
          file.puts "class LimitsResponse2 < Cosmos::LimitsResponse"
          file.puts "  def initialize(val)"
          file.puts "    puts \"initialize: \#{val}\""
          file.puts "  end"
          file.puts "  def call(target_name, packet_name, item, old_limits_state, new_limits_state)"
          file.puts "    puts \"\#{target_name} \#{packet_name} \#{item.name} \#{old_limits_state} \#{new_limits_state}\""
          file.puts "  end"
          file.puts "end"
        end
        load 'limits_response2.rb'

        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
        tf.puts '  ITEM item1 0 16 INT "Integer Item"'
        tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 6 7 3 5'
        tf.puts '    LIMITS_RESPONSE limits_response2.rb 2'
        tf.close
        capture_io do |stdout|
          @pc.process_file(tf.path, "TGT1")
          expect(stdout.string).to eql "initialize: 2\n"
        end

        File.delete(filename) if File.exist?(filename)
        tf.unlink
      end
    end
  end
end
