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
require 'tempfile'

module Cosmos

  describe PacketConfig do

    describe "process_file" do
      before(:each) do
        @pc = PacketConfig.new
      end

      it "complains about unknown keywords" do
        tf = Tempfile.new('unittest')
        tf.puts("BLAH")
        tf.close
        expect { @pc.process_file(tf.path, 'SYSTEM') }.to raise_error(ConfigParser::Error, /Unknown keyword 'BLAH'/)
        tf.unlink
      end

      it "outputs parsed definitions back to a file" do
        tf = Tempfile.new('unittest')
        tlm = "TELEMETRY TGT1 PKT1 LITTLE_ENDIAN \"Telemetry\"\n"\
              "  ITEM BYTE 0 8 UINT \"Item\"\n"
        tf.write tlm
        cmd = "COMMAND TGT1 PKT1 LITTLE_ENDIAN \"Command\"\n"\
              "  PARAMETER PARAM 0 16 UINT 0 0 0 \"Param\"\n"
        tf.write cmd
        limits = "LIMITS_GROUP TVAC\n"\
                 "  LIMITS_GROUP_ITEM TGT1 PKT1 ITEM1\n"
        tf.write limits
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.to_config(System.paths["LOGS"])
        @pc.to_xtce(System.paths["LOGS"])
        expect(cmd.strip).to eql File.read(File.join(System.paths["LOGS"], 'TGT1', 'cmd_tlm', 'tgt1_cmd.txt')).strip
        expect(tlm.strip).to eql File.read(File.join(System.paths["LOGS"], 'TGT1', 'cmd_tlm', 'tgt1_tlm.txt')).strip
        expect(limits.strip).to eql File.read(File.join(System.paths["LOGS"], 'SYSTEM', 'cmd_tlm', 'limits_groups.txt')).strip
        tf.unlink
      end

      context "with all telemetry keywords" do
        before(:all) do
          # top level keywords
          @top_keywords = %w(SELECT_COMMAND SELECT_TELEMETRY LIMITS_GROUP LIMITS_GROUP_ITEM)
          # Keywords that require a current packet from TELEMETRY keyword
          @tlm_keywords = %w(SELECT_ITEM ITEM ID_ITEM ARRAY_ITEM APPEND_ITEM APPEND_ID_ITEM APPEND_ARRAY_ITEM PROCESSOR META)
          # Keywords that require both a current packet and current item
          @item_keywords = %w(STATE READ_CONVERSION WRITE_CONVERSION POLY_READ_CONVERSION POLY_WRITE_CONVERSION SEG_POLY_READ_CONVERSION SEG_POLY_WRITE_CONVERSION GENERIC_READ_CONVERSION_START GENERIC_WRITE_CONVERSION_START LIMITS LIMITS_RESPONSE UNITS FORMAT_STRING DESCRIPTION META)
        end

        it "complains if a current packet is not defined" do
          # Check for missing TELEMETRY line
          @tlm_keywords.each do |keyword|
            tf = Tempfile.new('unittest')
            tf.puts(keyword)
            tf.close
            expect { @pc.process_file(tf.path, "SYSTEM") }.to raise_error(ConfigParser::Error, /No current packet for #{keyword}/)
            tf.unlink
          end # end for each tlm_keywords
        end

        it "complains if a current item is not defined" do
          # Check for missing ITEM definitions
          @item_keywords.each do |keyword|
            next if %w(META).include? keyword
            tf = Tempfile.new('unittest')
            tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
            tf.puts keyword
            tf.close
            expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /No current item for #{keyword}/)
            tf.unlink
          end
        end

        it "complains if there are not enough parameters" do
          @top_keywords.each do |keyword|
            tf = Tempfile.new('unittest')
            tf.puts(keyword)
            tf.close
            expect { @pc.process_file(tf.path, "SYSTEM") }.to raise_error(ConfigParser::Error, /Not enough parameters for #{keyword}/)
            tf.unlink
          end

          @tlm_keywords.each do |keyword|
            tf = Tempfile.new('unittest')
            tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
            tf.puts keyword
            tf.close
            expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters for #{keyword}/)
            tf.unlink
          end

          @item_keywords.each do |keyword|
            next if %w(GENERIC_READ_CONVERSION_START GENERIC_WRITE_CONVERSION_START).include? keyword
            tf = Tempfile.new('unittest')
            tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
            tf.puts 'ITEM myitem 0 8 UINT "Test Item"'
            tf.puts keyword
            tf.close
            expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Not enough parameters for #{keyword}/)
            tf.unlink
          end
        end
        
        it "builds the id value hash" do
          @tlm_keywords.each do |keyword|
            next if %w(PROCESSOR META).include? keyword
            tf = Tempfile.new('unittest')
            tf.puts 'TELEMETRY tgt1 pkt1 BIG_ENDIAN "Packet"'
            tf.puts 'ID_ITEM myitem 0 8 UINT 13 "Test Item id=1"'
            tf.puts 'APPEND_ID_ITEM myitem 8 UINT 114 "Test Item id=1"'
            tf.puts 'COMMAND tgt1 pkt1 BIG_ENDIAN "Packet"'
            tf.puts 'ID_PARAMETER myitem 0 8 UINT 12 12 12 "Test Item id=1"'
            tf.puts 'APPEND_ID_PARAMETER myitem 8 UINT 115 115 115 "Test Item id=1"'
            tf.close
            @pc.process_file(tf.path, "TGT1")
            expected_tlm_hash = {}
            expected_tlm_hash["TGT1"] = {}
            expected_tlm_hash["TGT1"][[13, 114]] = @pc.telemetry["TGT1"]["PKT1"]
            expected_cmd_hash = {}
            expected_cmd_hash["TGT1"] = {}
            expected_cmd_hash["TGT1"][[12, 115]] = @pc.commands["TGT1"]["PKT1"]            
            expect(@pc.tlm_id_value_hash).to eql expected_tlm_hash
            expect(@pc.cmd_id_value_hash).to eql expected_cmd_hash
            tf.unlink
          end          
        end

        it "complains if there are too many parameters" do
          @top_keywords.each do |keyword|
            tf = Tempfile.new('unittest')
            case keyword
            when "SELECT_COMMAND"
              tf.puts 'SELECT_COMMAND tgt1 pkt1 extra'
            when "SELECT_TELEMETRY"
              tf.puts 'SELECT_TELEMETRY tgt1 pkt1 extra'
            when 'LIMITS_GROUP'
              tf.puts "LIMITS_GROUP name extra"
            when 'LIMITS_GROUP_ITEM'
              tf.puts "LIMITS_GROUP_ITEM target packet item extra"
            end
            tf.close
            expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Too many parameters for #{keyword}/)
            tf.unlink
          end

          @tlm_keywords.each do |keyword|
            next if %w(PROCESSOR META).include? keyword
            tf = Tempfile.new('unittest')
            tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
            case keyword
            when "ITEM"
              tf.puts 'ITEM myitem 0 8 UINT "Test Item" BIG_ENDIAN extra'
            when "APPEND_ITEM"
              tf.puts 'APPEND_ITEM myitem 8 UINT "Test Item" BIG_ENDIAN extra'
            when "ID_ITEM"
              tf.puts 'ID_ITEM myitem 0 8 UINT 1 "Test Item id=1" LITTLE_ENDIAN extra'
            when "APPEND_ID_ITEM"
              tf.puts 'APPEND_ID_ITEM myitem 8 UINT 1 "Test Item id=1" BIG_ENDIAN extra'
            when "ARRAY_ITEM"
              tf.puts 'ARRAY_ITEM myitem 0 8 UINT 24 "Test Item array" LITTLE_ENDIAN extra'
            when "APPEND_ARRAY_ITEM"
              tf.puts 'APPEND_ARRAY_ITEM myitem 0 8 UINT 24 "Test Item array" BIG_ENDIAN extra'
            when "SELECT_ITEM"
              tf.puts 'ITEM myitem 0 8 UINT'
              tf.puts 'SELECT_ITEM myitem extra'
            end
            tf.close
            expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Too many parameters for #{keyword}/)
            tf.unlink
          end

          @item_keywords.each do |keyword|
            # The following can have an "unlimited" number of arguments
            next if %w(POLY_READ_CONVERSION POLY_WRITE_CONVERSION READ_CONVERSION WRITE_CONVERSION SEG_POLY_READ_CONVERSION SEG_POLY_WRITE_CONVERSION LIMITS_RESPONSE META).include? keyword
            tf = Tempfile.new('unittest')
            tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
            tf.puts 'ITEM myitem 0 8 UINT "Test Item"'
            case keyword
            when "STATE"
              tf.puts 'STATE mystate 0 RED extra'
            when "GENERIC_READ_CONVERSION_START", "GENERIC_WRITE_CONVERSION_START"
              tf.puts "#{keyword} FLOAT 64 extra"
            when "LIMITS"
              tf.puts 'LIMITS mylimits 1 ENABLED 0 10 20 30 12 18 20'
            when "UNITS"
              tf.puts 'UNITS degrees deg extra'
            when "FORMAT_STRING", "DESCRIPTION"
              tf.puts "#{keyword} 'string' extra"
            end
            tf.close
            expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Too many parameters for #{keyword}/)
            tf.unlink
          end
        end
      end

      context "with SELECT_COMMAND or SELECT_TELEMETRY" do
        it "complains if the packet is not found" do
          %w(SELECT_COMMAND SELECT_TELEMETRY).each do |keyword|
            tf = Tempfile.new('unittest')
            tf.puts keyword + ' tgt1 pkt1'
            tf.puts 'SELECT_ITEM ITEM1'
            tf.puts '  DESCRIPTION "New description"'
            tf.close
            expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Packet not found/)
            tf.unlink
          end
        end

        it "selects a packet for modification" do
          %w(SELECT_COMMAND SELECT_TELEMETRY).each do |keyword|
            tf = Tempfile.new('unittest')
            tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
            tf.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
            tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
            tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
            tf.close
            @pc.process_file(tf.path, "TGT1")
            pkt = @pc.commands["TGT1"]["PKT1"] if keyword =~ /COMMAND/
            pkt = @pc.telemetry["TGT1"]["PKT1"] if keyword =~ /TELEMETRY/
            expect(pkt.get_item("ITEM1").description).to eql "Item"
            tf.unlink

            tf = Tempfile.new('unittest')
            tf.puts keyword + ' tgt1 pkt1'
            tf.puts 'SELECT_PARAMETER ITEM1' if keyword =~ /COMMAND/
            tf.puts 'SELECT_ITEM ITEM1' if keyword =~ /TELEMETRY/
            tf.puts '  DESCRIPTION "New description"'
            tf.close
            @pc.process_file(tf.path, "TGT1")
            pkt = @pc.commands["TGT1"]["PKT1"] if keyword =~ /COMMAND/
            pkt = @pc.telemetry["TGT1"]["PKT1"] if keyword =~ /TELEMETRY/
            expect(pkt.get_item("ITEM1").description).to eql "New description"
            tf.unlink
          end
        end

        it "substitutes the target name" do
          %w(SELECT_COMMAND SELECT_TELEMETRY).each do |keyword|
            tf = Tempfile.new('unittest')
            tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
            tf.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
            tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
            tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
            tf.close
            @pc.process_file(tf.path, "NEW")
            pkt = @pc.commands["NEW"]["PKT1"] if keyword =~ /COMMAND/
            pkt = @pc.telemetry["NEW"]["PKT1"] if keyword =~ /TELEMETRY/
            expect(pkt.get_item("ITEM1").description).to eql "Item"
            tf.unlink

            tf = Tempfile.new('unittest')
            tf.puts keyword + ' tgt1 pkt1'
            tf.puts 'SELECT_PARAMETER ITEM1' if keyword =~ /COMMAND/
            tf.puts 'SELECT_ITEM ITEM1' if keyword =~ /TELEMETRY/
            tf.puts '  DESCRIPTION "New description"'
            tf.close
            @pc.process_file(tf.path, "NEW")
            pkt = @pc.commands["NEW"]["PKT1"] if keyword =~ /COMMAND/
            pkt = @pc.telemetry["NEW"]["PKT1"] if keyword =~ /TELEMETRY/
            expect(pkt.get_item("ITEM1").description).to eql "New description"
            tf.unlink
          end
        end
      end

      context "with SELECT_PARAMETER" do
        it "complains if used with SELECT_TELEMETRY" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY TGT PKT LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM ITEM 16 UINT "Item"'
          tf.puts 'SELECT_TELEMETRY TGT PKT'
          tf.puts '  SELECT_PARAMETER ITEM'
          tf.close
          expect { @pc.process_file(tf.path, "TGT") }.to raise_error(ConfigParser::Error, /SELECT_PARAMETER only applies to command packets/)
        end

        it "complains if the parameter is not found" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND TGT PKT LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_PARAMETER PARAM 16 UINT 0 0 0 "Param"'
          tf.close
          @pc.process_file(tf.path, "TGT")
          pkt = @pc.commands["TGT"]["PKT"]
          expect(pkt.get_item("PARAM").description).to eql "Param"
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'SELECT_COMMAND TGT PKT'
          tf.puts '  SELECT_PARAMETER PARAMX'
          tf.puts '    DESCRIPTION "New description"'
          tf.close
          expect { @pc.process_file(tf.path, "TGT") }.to raise_error(ConfigParser::Error, /PARAMX not found in command packet TGT PKT/)
        end
      end

      context "with SELECT_ITEM" do
        it "complains if used with SELECT_COMMAND" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND TGT PKT LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_PARAMETER PARAM 16 UINT 0 0 0 "Param"'
          tf.puts 'SELECT_COMMAND TGT PKT'
          tf.puts '  SELECT_ITEM PARAM'
          tf.close
          expect { @pc.process_file(tf.path, "TGT") }.to raise_error(ConfigParser::Error, /SELECT_ITEM only applies to telemetry packets/)
        end

        it "complains if the item is not found" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY TGT PKT LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM ITEM 16 UINT "Item"'
          tf.close
          @pc.process_file(tf.path, "TGT")
          pkt = @pc.telemetry["TGT"]["PKT"]
          expect(pkt.get_item("ITEM").description).to eql "Item"
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'SELECT_TELEMETRY TGT PKT'
          tf.puts '  SELECT_ITEM ITEMX'
          tf.puts '    DESCRIPTION "New description"'
          tf.close
          expect { @pc.process_file(tf.path, "TGT") }.to raise_error(ConfigParser::Error, /ITEMX not found in telemetry packet TGT PKT/)
        end
      end

      context "with MACRO_APPEND" do
        it "creates a range of items" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'MACRO_APPEND_START 1 3'
          tf.puts '  APPEND_ITEM BYTE 8 UINT "Setting #x"'
          tf.puts 'MACRO_APPEND_END'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          pkt = @pc.telemetry["TGT1"]["PKT1"]
          expect(pkt.items.length).to eql 8 # 3 plus the RECEIVED_XXX and PACKET_TIMExxx items
          expect(pkt.items.keys).to include('BYTE1','BYTE2','BYTE3')
          expect(pkt.sorted_items[5].name).to eql 'BYTE1'
          expect(pkt.sorted_items[6].name).to eql 'BYTE2'
          expect(pkt.sorted_items[7].name).to eql 'BYTE3'
          tf.unlink
        end
      end

      context "with LIMITS_GROUP" do
        it "creates a new limits group" do
          tf = Tempfile.new('unittest')
          tf.puts 'LIMITS_GROUP TVAC'
          tf.puts 'LIMITS_GROUP VIBE'
          tf.close
          expect(@pc.limits_groups).to be_empty
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.limits_groups).to include('TVAC','VIBE')
          tf.unlink
        end
      end

      context "with LIMITS_ITEM" do
        it "adds a new limits item to the group" do
          tf = Tempfile.new('unittest')
          tf.puts 'LIMITS_GROUP TVAC'
          tf.puts 'LIMITS_GROUP_ITEM TGT1 PKT1 ITEM1'
          tf.close
          expect(@pc.limits_groups).to be_empty
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.limits_groups["TVAC"]).to eql [%w(TGT1 PKT1 ITEM1)]
          tf.unlink

          # Show we can 're-open' the group and add items
          tf = Tempfile.new('unittest')
          tf.puts 'LIMITS_GROUP TVAC'
          tf.puts 'LIMITS_GROUP_ITEM TGT1 PKT1 ITEM2'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.limits_groups["TVAC"]).to eql [%w(TGT1 PKT1 ITEM1), %w(TGT1 PKT1 ITEM2)]
          tf.unlink
        end
      end

      context "with ALLOW_SHORT" do
        it "marks the packet as allowing short buffers" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'ALLOW_SHORT'
          tf.puts 'TELEMETRY tgt1 pkt2 LITTLE_ENDIAN "Description"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.telemetry["TGT1"]["PKT1"].short_buffer_allowed).to be true
          expect(@pc.telemetry["TGT1"]["PKT2"].short_buffer_allowed).to be false
          tf.unlink
        end
      end

      context "with META" do
        it "saves metadata" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'META TYPE "struct packet"'
          tf.puts 'TELEMETRY tgt1 pkt2 LITTLE_ENDIAN "Description"'
          tf.puts 'META TYPE "struct packet2"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.telemetry["TGT1"]["PKT1"].meta['TYPE']).to eql ["struct packet"]
          expect(@pc.telemetry["TGT1"]["PKT2"].meta['TYPE']).to eql ["struct packet2"]
          tf.unlink
        end
      end

      context "with DISABLE_MESSAGES" do
        it "marks the packet as messages disabled" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'DISABLE_MESSAGES'
          tf.puts 'COMMAND tgt1 pkt2 LITTLE_ENDIAN "Description"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.commands["TGT1"]["PKT1"].messages_disabled).to be true
          expect(@pc.commands["TGT1"]["PKT2"].messages_disabled).to be false
          tf.unlink
        end
      end

      context "with HIDDEN" do
        it "marks the packet as hidden" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'HIDDEN'
          tf.puts 'COMMAND tgt1 pkt2 LITTLE_ENDIAN "Description"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.commands["TGT1"]["PKT1"].hidden).to be true
          expect(@pc.commands["TGT1"]["PKT1"].disabled).to be false
          expect(@pc.commands["TGT1"]["PKT2"].hidden).to be false
          expect(@pc.commands["TGT1"]["PKT2"].disabled).to be false
          tf.unlink
        end
      end

      context "with DISABLED" do
        it "marks the packet as disabled" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'DISABLED'
          tf.puts 'COMMAND tgt1 pkt2 LITTLE_ENDIAN "Description"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.commands["TGT1"]["PKT1"].hidden).to be true
          expect(@pc.commands["TGT1"]["PKT1"].disabled).to be true
          expect(@pc.commands["TGT1"]["PKT2"].hidden).to be false
          expect(@pc.commands["TGT1"]["PKT2"].disabled).to be false
          tf.unlink
        end
      end

      context "with HAZARDOUS" do
        it "marks the packet as hazardous" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'HAZARDOUS'
          tf.puts 'TELEMETRY tgt1 pkt2 LITTLE_ENDIAN "Description"'
          tf.puts 'COMMAND tgt2 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'HAZARDOUS'
          tf.puts 'COMMAND tgt2 pkt2 LITTLE_ENDIAN "Description"'
          tf.close
          @pc.process_file(tf.path, "SYSTEM")
          expect(@pc.telemetry["TGT1"]["PKT1"].hazardous).to be true
          expect(@pc.telemetry["TGT1"]["PKT2"].hazardous).to be false
          expect(@pc.commands["TGT2"]["PKT1"].hazardous).to be true
          expect(@pc.commands["TGT2"]["PKT2"].hazardous).to be false
          tf.unlink
        end

        it "takes a description" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'HAZARDOUS "Hazardous description"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.commands["TGT1"]["PKT1"].hazardous).to be true
          expect(@pc.commands["TGT1"]["PKT1"].hazardous_description).to eql "Hazardous description"
          tf.unlink
        end
      end

      context "with READ_CONVERSION and WRITE_CONVERSION" do
        it "complains about missing conversion file" do
          filename = File.join(File.dirname(__FILE__), "../test_only.rb")
          File.delete(filename) if File.exist?(filename)
          @pc = PacketConfig.new

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 16 INT "Integer Item"'
          tf.puts '  READ_CONVERSION test_only.rb'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /TestOnly class not found/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  PARAMETER item1 0 16 INT 0 0 0'
          tf.puts '  WRITE_CONVERSION test_only.rb'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /TestOnly class not found/)
          tf.unlink
        end

        it "complains about a non Cosmos::Conversion class" do
          filename = File.join(File.dirname(__FILE__), "../conversion1.rb")
          File.open(filename, 'w') do |file|
            file.puts "class Conversion1"
            file.puts "  def call(value,packet,buffer)"
            file.puts "  end"
            file.puts "end"
          end
          load 'conversion1.rb'
          File.delete(filename) if File.exist?(filename)

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 16 INT "Integer Item"'
          tf.puts '  READ_CONVERSION conversion1.rb'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /read_conversion must be a Cosmos::Conversion but is a Conversion1/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  PARAMETER item1 0 16 INT 0 0 0'
          tf.puts '  WRITE_CONVERSION conversion1.rb'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /write_conversion must be a Cosmos::Conversion but is a Conversion1/)
          tf.unlink
        end

        it "parses the conversion" do
          filename = File.join(File.dirname(__FILE__), "../conversion2.rb")
          File.open(filename, 'w') do |file|
            file.puts "require 'cosmos/conversions/conversion'"
            file.puts "class Conversion2 < Cosmos::Conversion"
            file.puts "  def call(value,packet,buffer)"
            file.puts "    value * 2"
            file.puts "  end"
            file.puts "end"
          end
          load 'conversion2.rb'

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 16 INT "Integer Item"'
          tf.puts '  READ_CONVERSION conversion2.rb'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.telemetry["TGT1"]["PKT1"].buffer = "\x01"
          expect(@pc.telemetry["TGT1"]["PKT1"].read("ITEM1")).to eql 2
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  PARAMETER item1 0 16 INT 0 0 0'
          tf.puts '  WRITE_CONVERSION conversion2.rb'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].write("ITEM1", 3)
          expect(@pc.commands["TGT1"]["PKT1"].read("ITEM1")).to eql 6
          tf.unlink

          File.delete(filename) if File.exist?(filename)
        end
      end

      context "with POLY_READ_CONVERSION and POLY_WRITE_CONVERSION" do
        it "performs a polynomial conversion" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 16 INT "Integer Item"'
          tf.puts '  POLY_READ_CONVERSION 5 2'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.telemetry["TGT1"]["PKT1"].buffer = "\x01"
          expect(@pc.telemetry["TGT1"]["PKT1"].read("ITEM1")).to eql 7.0
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  PARAMETER item1 0 16 INT 0 0 0'
          tf.puts '  POLY_WRITE_CONVERSION 5 2'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].write("ITEM1", 3)
          expect(@pc.commands["TGT1"]["PKT1"].read("ITEM1")).to eql 11
          tf.unlink
        end
      end

      context "with SEG_POLY_READ_CONVERSION and SEG_POLY_WRITE_CONVERSION" do
        it "performs a segmented polynomial conversion" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 16 INT "Integer Item"'
          tf.puts '  SEG_POLY_READ_CONVERSION 0 1 2'
          tf.puts '  SEG_POLY_READ_CONVERSION 5 2 3'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.telemetry["TGT1"]["PKT1"].buffer = "\x01"
          expect(@pc.telemetry["TGT1"]["PKT1"].read("ITEM1")).to eql 3.0
          @pc.telemetry["TGT1"]["PKT1"].buffer = "\x05"
          expect(@pc.telemetry["TGT1"]["PKT1"].read("ITEM1")).to eql 17.0
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  PARAMETER item1 0 16 INT 0 0 0'
          tf.puts '  SEG_POLY_WRITE_CONVERSION 0 1 2'
          tf.puts '  SEG_POLY_WRITE_CONVERSION 5 2 3'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].write("ITEM1", 1)
          expect(@pc.commands["TGT1"]["PKT1"].read("ITEM1")).to eql 3
          @pc.commands["TGT1"]["PKT1"].write("ITEM1", 5)
          expect(@pc.commands["TGT1"]["PKT1"].read("ITEM1")).to eql 17
          tf.unlink
        end
      end

      context "with GENERIC_READ_CONVERSION and GENERIC_WRITE_CONVERSION" do
        it "processes a generic conversion" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    GENERIC_WRITE_CONVERSION_START'
          tf.puts '      2.0 * value'
          tf.puts '    GENERIC_WRITE_CONVERSION_END'
          tf.puts '  APPEND_ITEM item2 8 UINT "Item"'
          tf.puts '    GENERIC_READ_CONVERSION_START'
          tf.puts '      "Number #{value}"'
          tf.puts '    GENERIC_READ_CONVERSION_END'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          pkt = @pc.telemetry["TGT1"]["PKT1"]
          pkt.enable_method_missing
          pkt.item1 = 2
          expect(pkt.item1).to eql 4
          expect(pkt.item2).to eql "Number 0"
          tf.unlink
        end

        it "processes a generic conversion with a defined type" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    GENERIC_WRITE_CONVERSION_START UINT 8'
          tf.puts '      2.0 * value'
          tf.puts '    GENERIC_WRITE_CONVERSION_END'
          tf.puts '  APPEND_ITEM item2 64 FLOAT "Item"'
          tf.puts '    GENERIC_READ_CONVERSION_START FLOAT 32'
          tf.puts '      2.0 * value'
          tf.puts '    GENERIC_READ_CONVERSION_END'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          pkt = @pc.telemetry["TGT1"]["PKT1"]
          pkt.enable_method_missing
          pkt.item1 = 400
          expect(pkt.item1).to eql 800
          pkt.item2 = 400
          expect(pkt.item2).to eql 800.0
          tf.unlink
        end
      end

      context "with LIMITS" do
        it "ensures limits sets have unique names" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 6 7'
          tf.puts '    LIMITS TVAC 1 ENABLED 1 2 6 7'
          tf.puts '    LIMITS DEFAULT 1 ENABLED 8 9 12 13'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          item = @pc.telemetry["TGT1"]["PKT1"].items["ITEM1"]
          expect(item.limits.values.length).to eql 2
          # Verify the last defined DEFAULT limits wins
          @pc.telemetry["TGT1"]["PKT1"].buffer = "\x04"
          @pc.telemetry["TGT1"]["PKT1"].enable_limits("ITEM1")
          @pc.telemetry["TGT1"]["PKT1"].check_limits
          expect(item.limits.state).to eql :RED_LOW
          tf.unlink
        end
      end

      context "with UNITS" do
        it "apply units when read :WITH_UNITS" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 8 UINT'
          tf.puts '    UNITS Volts V'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.telemetry["TGT1"]["PKT1"].read("ITEM1",:WITH_UNITS)).to eql "0 V"
          tf.unlink
        end
      end

      context "with META" do
        it "saves metadata for items" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 8 UINT'
          tf.puts '    META TYPE "unsigned int"'
          tf.puts '    META OTHER'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.telemetry["TGT1"]["PKT1"].get_item('item1').meta['TYPE']).to eql ['unsigned int']
          expect(@pc.telemetry["TGT1"]["PKT1"].get_item('item1').meta['OTHER']).to eql []
          tf.unlink
        end
      end

      context "with OVERFLOW" do
        it "sets the overflow type for items" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 8 UINT'
          tf.puts '    OVERFLOW TRUNCATE'
          tf.puts '  ITEM item2 8 8 UINT'
          tf.puts '    OVERFLOW SATURATE'
          tf.puts '  ITEM item3 16 8 UINT'
          tf.puts '    OVERFLOW ERROR'
          tf.puts '  ITEM item4 24 8 INT'
          tf.puts '    OVERFLOW ERROR_ALLOW_HEX'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.telemetry["TGT1"]["PKT1"].get_item('item1').overflow).to eql :TRUNCATE
          expect(@pc.telemetry["TGT1"]["PKT1"].get_item('item2').overflow).to eql :SATURATE
          expect(@pc.telemetry["TGT1"]["PKT1"].get_item('item3').overflow).to eql :ERROR
          expect(@pc.telemetry["TGT1"]["PKT1"].get_item('item4').overflow).to eql :ERROR_ALLOW_HEX
          tf.unlink
        end
      end

      context "with REQUIRED" do
        it "only applies to a command parameter" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 8 UINT'
          tf.puts '    REQUIRED'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /REQUIRED only applies to command parameters/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  REQUIRED'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /No current item for REQUIRED/)
          tf.unlink
        end

        it "marks a command parameter as required" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  PARAMETER item1 0 8 UINT 0 1 1'
          tf.puts '    REQUIRED'
          tf.puts '  PARAMETER item2 0 8 UINT 0 1 1'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.commands["TGT1"]["PKT1"].items["ITEM1"].required).to be true
          expect(@pc.commands["TGT1"]["PKT1"].items["ITEM2"].required).to be false
          tf.unlink
        end
      end

      context "with MINIMUM_VALUE, MAXIMUM_VALUE, DEFAULT_VALUE" do
        it "complains if used on telemetry items" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT'
          tf.puts '    MINIMUM_VALUE 1'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /MINIMUM_VALUE only applies to command parameters/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT'
          tf.puts '    MAXIMUM_VALUE 3'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /MAXIMUM_VALUE only applies to command parameters/)
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT'
          tf.puts '    DEFAULT_VALUE 2'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /DEFAULT_VALUE only applies to command parameters/)
          tf.unlink
        end

        it "allows overriding the defined value" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_PARAMETER item1 16 UINT 0 1 1'
          tf.puts '  APPEND_PARAMETER item2 16 STRING "HI"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].restore_defaults
          expect(@pc.commands["TGT1"]["PKT1"].read("ITEM1")).to eql 1
          expect(@pc.commands["TGT1"]["PKT1"].items["ITEM1"].range).to eql (0..1)
          expect(@pc.commands["TGT1"]["PKT1"].read("ITEM2")).to eql "HI"
          tf.unlink

          # Now override the values from above
          tf = Tempfile.new('unittest')
          tf.puts 'SELECT_COMMAND tgt1 pkt1'
          tf.puts 'SELECT_PARAMETER item1'
          tf.puts '  MINIMUM_VALUE 1'
          tf.puts '  MAXIMUM_VALUE 3'
          tf.puts '  DEFAULT_VALUE 2'
          tf.puts 'SELECT_PARAMETER item2'
          tf.puts '  DEFAULT_VALUE "NO"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].restore_defaults
          expect(@pc.commands["TGT1"]["PKT1"].read("ITEM1")).to eql 2
          expect(@pc.commands["TGT1"]["PKT1"].items["ITEM1"].range).to eql (1..3)
          expect(@pc.commands["TGT1"]["PKT1"].read("ITEM2")).to eql "NO"
          tf.unlink
        end
      end

      context "with APPEND" do
        it "allows appending derived items" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 0 DERIVED'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          expect(@pc.telemetry["TGT1"]["PKT1"].items["ITEM1"].data_type).to be :DERIVED
          tf.unlink
        end
      end

    end # describe "process_file"
  end
end
