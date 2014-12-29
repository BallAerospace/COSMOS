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

      it "should complain about unknown keywords" do
        tf = Tempfile.new('unittest')
        tf.puts("BLAH")
        tf.close
        expect { @pc.process_file(tf.path, 'SYSTEM') }.to raise_error(ConfigParser::Error, "Unknown keyword 'BLAH'")
        tf.unlink
      end

      it "should complain about overlapping items" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts '  ITEM item1 0 8 UINT'
        tf.puts '  ITEM item2 0 8 UINT'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.warnings[0].should eql "Bit definition overlap at bit offset 0 for Telemetry packet TGT1 PKT1 items ITEM2 and ITEM1"
        tf.unlink
      end

      it "should not complain with non-overlapping negative offsets" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt2 LITTLE_ENDIAN "Description"'
        tf.puts '  ITEM item1 0 8 UINT'
        tf.puts '  ITEM item2 8 -16 BLOCK'
        tf.puts '  ITEM item3 -16 16 UINT'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.warnings[0].should be_nil
        tf.unlink
      end

      it "should complain with overlapping negative offsets" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt2 LITTLE_ENDIAN "Description"'
        tf.puts '  ITEM item1 0 8 UINT'
        tf.puts '  ITEM item2 8 -16 BLOCK'
        tf.puts '  ITEM item3 -17 16 UINT'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.warnings[0].should eql "Bit definition overlap at bit offset -17 for Telemetry packet TGT1 PKT2 items ITEM3 and ITEM2"
        tf.unlink
      end

      it "should complain about intersecting items" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts '  ITEM item1 0 32 UINT'
        tf.puts '  ITEM item2 16 32 UINT'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.warnings[0].should eql "Bit definition overlap at bit offset 16 for Telemetry packet TGT1 PKT1 items ITEM2 and ITEM1"
        tf.unlink
      end

      it "should complain about array overlapping items" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts '  ARRAY_ITEM item1 0 8 UINT 32'
        tf.puts '  ARRAY_ITEM item2 0 8 UINT 32'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.warnings[0].should eql "Bit definition overlap at bit offset 0 for Telemetry packet TGT1 PKT1 items ITEM2 and ITEM1"
        tf.unlink
      end

      it "should not complain with array non-overlapping negative offsets" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt2 LITTLE_ENDIAN "Description"'
        tf.puts '  ITEM item1 0 8 UINT'
        tf.puts '  ARRAY_ITEM item2 8 8 INT -16'
        tf.puts '  ITEM item3 -16 16 UINT'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.warnings[0].should be_nil
        tf.unlink
      end

      it "should complain with array overlapping negative offsets" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt2 LITTLE_ENDIAN "Description"'
        tf.puts '  ITEM item1 0 8 UINT'
        tf.puts '  ARRAY_ITEM item2 8 8 INT -16'
        tf.puts '  ITEM item3 -17 16 UINT'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.warnings[0].should eql "Bit definition overlap at bit offset -17 for Telemetry packet TGT1 PKT2 items ITEM3 and ITEM2"
        tf.unlink
      end

      it "should complain about array intersecting items" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts '  ARRAY_ITEM item1 0 8 UINT 32'
        tf.puts '  ARRAY_ITEM item2 16 8 UINT 32'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.warnings[0].should eql "Bit definition overlap at bit offset 16 for Telemetry packet TGT1 PKT1 items ITEM2 and ITEM1"
        tf.unlink
      end

      it "should not complain about nonoverlapping little endian bitfields" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
        tf.puts '  ITEM item1 12 12 UINT'
        tf.puts '  ITEM item2 16 16 UINT'
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.warnings[0].should be_nil
        tf.unlink
      end

      context "with all telemetry keywords" do
        before(:all) do
          # top level keywords
          @top_keywords = %w(TELEMETRY SELECT_TELEMETRY LIMITS_GROUP LIMITS_GROUP_ITEM)
          # Keywords that require a current packet from TELEMETRY keyword
          @tlm_keywords = %w(SELECT_ITEM ITEM ID_ITEM ARRAY_ITEM APPEND_ITEM APPEND_ID_ITEM APPEND_ARRAY_ITEM MACRO_APPEND_START MACRO_APPEND_END PROCESSOR META)
          # Keywords that require both a current packet and current item
          @item_keywords = %w(STATE READ_CONVERSION WRITE_CONVERSION POLY_READ_CONVERSION POLY_WRITE_CONVERSION SEG_POLY_READ_CONVERSION SEG_POLY_WRITE_CONVERSION GENERIC_READ_CONVERSION_START GENERIC_WRITE_CONVERSION_START LIMITS LIMITS_RESPONSE UNITS FORMAT_STRING DESCRIPTION META)
        end

        it "should complain if a current packet is not defined" do
          # Check for missing TELEMETRY line
          @tlm_keywords.each do |keyword|
            tf = Tempfile.new('unittest')
            tf.puts(keyword)
            tf.close
            expect { @pc.process_file(tf.path, "SYSTEM") }.to raise_error(ConfigParser::Error, "No current packet for #{keyword}")
            tf.unlink
          end # end for each tlm_keywords
        end

        it "should complain if a current item is not defined" do
          # Check for missing ITEM definitions
          @item_keywords.each do |keyword|
            next if %w(META).include? keyword
            tf = Tempfile.new('unittest')
            tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
            tf.puts keyword
            tf.close
            expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "No current item for #{keyword}")
            tf.unlink
          end
        end

        it "should complain if there are not enough parameters" do
          @top_keywords.each do |keyword|
            tf = Tempfile.new('unittest')
            tf.puts(keyword)
            tf.close
            expect { @pc.process_file(tf.path, "SYSTEM") }.to raise_error(ConfigParser::Error, /Not enough parameters for #{keyword}/)
            tf.unlink
          end

          @tlm_keywords.each do |keyword|
            next if %w(MACRO_APPEND_END).include? keyword
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

        it "should complain if there are too many parameters" do
          @top_keywords.each do |keyword|
            tf = Tempfile.new('unittest')
            case keyword
            when "TELEMETRY"
              tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet" extra'
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
            next if %w(MACRO_APPEND_END PROCESSOR META).include? keyword
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
            when "MACRO_APPEND_START"
              tf.puts 'MACRO_APPEND_START 0 1 "%s_%d" extra'
            when "ACRO_APPEND_END"
              tf.puts 'MACRO_APPEND_END extra'
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

      context "with COMMAND or TELEMETRY" do
        it "should complain about invalid endianness" do
          %w(COMMAND TELEMETRY).each do |keyword|
            tf = Tempfile.new('unittest')
            tf.puts keyword + ' tgt1 pkt1 MIDDLE_ENDIAN "Packet"'
            tf.close
            expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid endianness MIDDLE_ENDIAN. Must be BIG_ENDIAN or LITTLE_ENDIAN.")
            tf.unlink
          end
        end

        it "should process target, packet, endianness, description" do
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

        it "should substitute the target name" do
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
      end

      context "with SELECT_COMMAND or SELECT_TELEMETRY" do
        it "should complain if the packet is not found" do
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

        it "should select a packet for modification" do
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
            pkt.get_item("ITEM1").description.should eql "Item"
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
            pkt.get_item("ITEM1").description.should eql "New description"
            tf.unlink
          end
        end

        it "should substitute the target name" do
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
            pkt.get_item("ITEM1").description.should eql "Item"
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
            pkt.get_item("ITEM1").description.should eql "New description"
            tf.unlink
          end
        end
      end

      context "with SELECT_PARAMETER" do
        it "should complain if used with SELECT_TELEMETRY" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY TGT PKT LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM ITEM 16 UINT "Item"'
          tf.puts 'SELECT_TELEMETRY TGT PKT'
          tf.puts '  SELECT_PARAMETER ITEM'
          tf.close
          expect { @pc.process_file(tf.path, "TGT") }.to raise_error(ConfigParser::Error, "SELECT_PARAMETER only applies to command packets")
        end

        it "should complain if the parameter is not found" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND TGT PKT LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_PARAMETER PARAM 16 UINT 0 0 0 "Param"'
          tf.close
          @pc.process_file(tf.path, "TGT")
          pkt = @pc.commands["TGT"]["PKT"]
          pkt.get_item("PARAM").description.should eql "Param"
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'SELECT_COMMAND TGT PKT'
          tf.puts '  SELECT_PARAMETER PARAMX'
          tf.puts '    DESCRIPTION "New description"'
          tf.close
          expect { @pc.process_file(tf.path, "TGT") }.to raise_error(ConfigParser::Error, "PARAMX not found in command packet TGT PKT")
        end
      end

      context "with SELECT_ITEM" do
        it "should complain if used with SELECT_COMMAND" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND TGT PKT LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_PARAMETER PARAM 16 UINT 0 0 0 "Param"'
          tf.puts 'SELECT_COMMAND TGT PKT'
          tf.puts '  SELECT_ITEM PARAM'
          tf.close
          expect { @pc.process_file(tf.path, "TGT") }.to raise_error(ConfigParser::Error, "SELECT_ITEM only applies to telemetry packets")
        end

        it "should complain if the item is not found" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY TGT PKT LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM ITEM 16 UINT "Item"'
          tf.close
          @pc.process_file(tf.path, "TGT")
          pkt = @pc.telemetry["TGT"]["PKT"]
          pkt.get_item("ITEM").description.should eql "Item"
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'SELECT_TELEMETRY TGT PKT'
          tf.puts '  SELECT_ITEM ITEMX'
          tf.puts '    DESCRIPTION "New description"'
          tf.close
          expect { @pc.process_file(tf.path, "TGT") }.to raise_error(ConfigParser::Error, "ITEMX not found in telemetry packet TGT PKT")
        end
      end

      context "with keywords including ITEM" do
        it "should only allow DERIVED items with offset 0 and size 0" do
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
          @pc.telemetry["TGT1"]["PKT1"].items.keys.should include('ITEM1')
          tf.unlink
        end

        it "should accept types INT UINT FLOAT STRING BLOCK" do
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
          @pc.telemetry["TGT1"]["PKT1"].items.keys.should include('ITEM1','ITEM2','ITEM3','ITEM4','ITEM5','ITEM6')
          id_items = []
          id_items << @pc.telemetry["TGT1"]["PKT1"].items["ITEM1"]
          id_items << @pc.telemetry["TGT1"]["PKT1"].items["ITEM4"]
          @pc.telemetry["TGT1"]["PKT1"].id_items.should eql id_items
          tf.unlink
        end

        it "should support arbitrary endianness per item" do
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
          packet.read("ITEM1").should eql 0x01000000
          packet.read("ITEM2").should eql 0x01000000
          packet.read("ITEM3").should eql [0x01000000, 0x01000000]
          packet.read("ITEM4").should eql 0x01000000
          packet.read("ITEM5").should eql 0x01000000
          packet.read("ITEM6").should eql [0x01000000, 0x01000000]
          packet.read("ITEM10").should eql 0x00000001
          packet.read("ITEM20").should eql 0x00000001
          packet.read("ITEM30").should eql [0x00000001, 0x00000001]
          packet.read("ITEM40").should eql 0x00000001
          packet.read("ITEM50").should eql 0x00000001
          packet.read("ITEM60").should eql [0x00000001, 0x00000001]
          tf.unlink
        end
      end

      context "with keywords including PARAMETER" do
        it "should only allow DERIVED items with offset 0 and size 0" do
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
          @pc.commands["TGT1"]["PKT1"].items.keys.should include('ITEM1')
          tf.unlink
        end

        it "should not allow ID_PARAMETER with DERIVED type" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ID_PARAMETER ITEM1 0 0 DERIVED 0 0 0'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /DERIVED data type not allowed/)
          tf.unlink
        end

        it "should not allow APPEND_ID_PARAMETER with DERIVED type" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  APPEND_ID_PARAMETER ITEM1 0 DERIVED 0 0 0'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /DERIVED data type not allowed/)
          tf.unlink
        end

        it "should accept types INT UINT FLOAT STRING BLOCK" do
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
          @pc.commands["TGT1"]["PKT1"].items.keys.should include('ITEM1','ITEM2','ITEM3','ITEM4','ITEM5','ITEM6','ITEM7','ITEM8')
          tf.unlink
        end

        it "should support arbitrary endianness per item" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  ID_PARAMETER ITEM1 0 32 UINT 0 0 0 "" LITTLE_ENDIAN'
          tf.puts '  PARAMETER ITEM2 0 32 UINT 0 0 0 "" LITTLE_ENDIAN'
          tf.puts '  ARRAY_PARAMETER ITEM3 0 32 UINT 64 "" LITTLE_ENDIAN'
          tf.puts '  APPEND_ID_PARAMETER ITEM4 32 UINT 0 0 0 "" LITTLE_ENDIAN'
          tf.puts '  APPEND_PARAMETER ITEM5 32 UINT 0 0 0 "" LITTLE_ENDIAN'
          tf.puts '  APPEND_ARRAY_PARAMETER ITEM6 32 UINT 64 "" LITTLE_ENDIAN'
          tf.puts '  ID_PARAMETER ITEM10 224 32 UINT 0 0 0 "" BIG_ENDIAN'
          tf.puts '  PARAMETER ITEM20 256 32 UINT 0 0 0 "" BIG_ENDIAN'
          tf.puts '  ARRAY_PARAMETER ITEM30 0 32 UINT 64 "" BIG_ENDIAN'
          tf.puts '  APPEND_ID_PARAMETER ITEM40 32 UINT 0 0 0 "" BIG_ENDIAN'
          tf.puts '  APPEND_PARAMETER ITEM50 32 UINT 0 0 0 "" BIG_ENDIAN'
          tf.puts '  APPEND_ARRAY_PARAMETER ITEM60 32 UINT 64 "" BIG_ENDIAN'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          packet = @pc.commands["TGT1"]["PKT1"]
          packet.buffer = "\x00\x00\x00\x01" * 16
          packet.read("ITEM1").should eql 0x01000000
          packet.read("ITEM2").should eql 0x01000000
          packet.read("ITEM3").should eql [0x01000000, 0x01000000]
          packet.read("ITEM4").should eql 0x01000000
          packet.read("ITEM5").should eql 0x01000000
          packet.read("ITEM6").should eql [0x01000000, 0x01000000]
          packet.read("ITEM10").should eql 0x00000001
          packet.read("ITEM20").should eql 0x00000001
          packet.read("ITEM30").should eql [0x00000001, 0x00000001]
          packet.read("ITEM40").should eql 0x00000001
          packet.read("ITEM50").should eql 0x00000001
          packet.read("ITEM60").should eql [0x00000001, 0x00000001]
          tf.unlink
        end
      end

      context "with LIMITS_GROUP" do
        it "should create a new limits group" do
          tf = Tempfile.new('unittest')
          tf.puts 'LIMITS_GROUP TVAC'
          tf.puts 'LIMITS_GROUP VIBE'
          tf.close
          @pc.limits_groups.should be_empty
          @pc.process_file(tf.path, "TGT1")
          @pc.limits_groups.should include('TVAC','VIBE')
          tf.unlink
        end
      end

      context "with LIMITS_ITEM" do
        it "should add a new limits item to the group" do
          tf = Tempfile.new('unittest')
          tf.puts 'LIMITS_GROUP TVAC'
          tf.puts 'LIMITS_GROUP_ITEM TGT1 PKT1 ITEM1'
          tf.close
          @pc.limits_groups.should be_empty
          @pc.process_file(tf.path, "TGT1")
          @pc.limits_groups["TVAC"].should eql [%w(TGT1 PKT1 ITEM1)]
          tf.unlink

          # Show we can 're-open' the group and add items
          tf = Tempfile.new('unittest')
          tf.puts 'LIMITS_GROUP TVAC'
          tf.puts 'LIMITS_GROUP_ITEM TGT1 PKT1 ITEM2'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.limits_groups["TVAC"].should eql [%w(TGT1 PKT1 ITEM1), %w(TGT1 PKT1 ITEM2)]
          tf.unlink
        end
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

      context "with ALLOW_SHORT" do
        it "should mark the packet as allowing short buffers" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'ALLOW_SHORT'
          tf.puts 'TELEMETRY tgt1 pkt2 LITTLE_ENDIAN "Description"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.telemetry["TGT1"]["PKT1"].short_buffer_allowed.should be_truthy
          @pc.telemetry["TGT1"]["PKT2"].short_buffer_allowed.should be_falsey
          tf.unlink
        end
      end

      context "with META" do
        it "should save metadata" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'META TYPE "struct packet"'
          tf.puts 'TELEMETRY tgt1 pkt2 LITTLE_ENDIAN "Description"'
          tf.puts 'META TYPE "struct packet2"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.telemetry["TGT1"]["PKT1"].meta['TYPE'].should eql ["struct packet"]
          @pc.telemetry["TGT1"]["PKT2"].meta['TYPE'].should eql ["struct packet2"]
          tf.unlink
        end
      end

      context "with DISABLE_MESSAGES" do
        it "should mark the packet as messages disabled" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'DISABLE_MESSAGES'
          tf.puts 'COMMAND tgt1 pkt2 LITTLE_ENDIAN "Description"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].messages_disabled.should be_truthy
          @pc.commands["TGT1"]["PKT2"].messages_disabled.should be_falsey
          tf.unlink
        end
      end

      context "with HIDDEN" do
        it "should mark the packet as hidden" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'HIDDEN'
          tf.puts 'COMMAND tgt1 pkt2 LITTLE_ENDIAN "Description"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].hidden.should be_truthy
          @pc.commands["TGT1"]["PKT1"].disabled.should be_falsey
          @pc.commands["TGT1"]["PKT2"].hidden.should be_falsey
          @pc.commands["TGT1"]["PKT2"].disabled.should be_falsey
          tf.unlink
        end
      end

      context "with DISABLED" do
        it "should mark the packet as disabled" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'DISABLED'
          tf.puts 'COMMAND tgt1 pkt2 LITTLE_ENDIAN "Description"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].hidden.should be_truthy
          @pc.commands["TGT1"]["PKT1"].disabled.should be_truthy
          @pc.commands["TGT1"]["PKT2"].hidden.should be_falsey
          @pc.commands["TGT1"]["PKT2"].disabled.should be_falsey
          tf.unlink
        end
      end

      context "with HAZARDOUS" do
        it "should mark the packet as hazardous" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'HAZARDOUS'
          tf.puts 'TELEMETRY tgt1 pkt2 LITTLE_ENDIAN "Description"'
          tf.puts 'COMMAND tgt2 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'HAZARDOUS'
          tf.puts 'COMMAND tgt2 pkt2 LITTLE_ENDIAN "Description"'
          tf.close
          @pc.process_file(tf.path, "SYSTEM")
          @pc.telemetry["TGT1"]["PKT1"].hazardous.should be_truthy
          @pc.telemetry["TGT1"]["PKT2"].hazardous.should be_falsey
          @pc.commands["TGT2"]["PKT1"].hazardous.should be_truthy
          @pc.commands["TGT2"]["PKT2"].hazardous.should be_falsey
          tf.unlink
        end

        it "should take a description" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts 'HAZARDOUS "Hazardous description"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].hazardous.should be_truthy
          @pc.commands["TGT1"]["PKT1"].hazardous_description.should eql "Hazardous description"
          tf.unlink
        end
      end

      context "with STATE" do
        it "should support STRING items" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  APPEND_ITEM item1 128 STRING "state item"'
          tf.puts '    STATE FALSE "FALSE STRING"'
          tf.puts '    STATE TRUE "TRUE STRING"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.telemetry["TGT1"]["PKT1"].write("ITEM1", "TRUE STRING")
          @pc.telemetry["TGT1"]["PKT1"].read("ITEM1").should eql "TRUE"
          @pc.telemetry["TGT1"]["PKT1"].write("ITEM1", "FALSE STRING")
          @pc.telemetry["TGT1"]["PKT1"].read("ITEM1").should eql "FALSE"
          tf.unlink
        end

        it "should warn about duplicate states and replace the duplicate" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
          tf.puts '  APPEND_PARAMETER item1 8 UINT 0 2 0 "state item"'
          tf.puts '    STATE FALSE 0'
          tf.puts '    STATE TRUE 1'
          tf.puts '    STATE FALSE 2'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.warnings.should include("Duplicate state defined on line 5: STATE FALSE 2")
          @pc.commands["TGT1"]["PKT1"].buffer = "\x00"
          @pc.commands["TGT1"]["PKT1"].read("ITEM1").should eql 0
          @pc.commands["TGT1"]["PKT1"].buffer = "\x02"
          @pc.commands["TGT1"]["PKT1"].read("ITEM1").should eql "FALSE"
          tf.unlink
        end

        context "with telemetry" do
          it "should only allow GREEN YELLOW or RED" do
            tf = Tempfile.new('unittest')
            tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Description"'
            tf.puts '  APPEND_ITEM item1 8 UINT "state item"'
            tf.puts '    STATE WORST 1 ORANGE'
            tf.close
            expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Invalid state color ORANGE/)
            tf.unlink
          end

          it "should record the state values and colors" do
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
              name.should eql "STATE#{index}"
              val.should eql index
              @pc.telemetry["TGT1"]["PKT1"].items["ITEM1"].state_colors[name].should eql colors[index - 1]

              index += 1
            end
            @pc.telemetry["TGT1"]["PKT1"].limits_items.should eql [@pc.telemetry["TGT1"]["PKT1"].items["ITEM1"]]
            tf.unlink
          end
        end

        context "with command" do
          it "should only allow HAZARDOUS as the third param" do
            tf = Tempfile.new('unittest')
            tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Description"'
            tf.puts '  APPEND_PARAMETER item1 8 UINT 0 0 0'
            tf.puts '    STATE WORST 0 RED'
            tf.close
            expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /HAZARDOUS expected as third parameter/)
            tf.unlink
          end

          it "should take HAZARDOUS and an optional description" do
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
            @pc.commands["TGT1"]["PKT1"].items["ITEM1"].hazardous["GOOD"].should be_nil
            @pc.commands["TGT1"]["PKT1"].items["ITEM1"].hazardous["BAD"].should_not be_nil
            @pc.commands["TGT1"]["PKT1"].items["ITEM1"].hazardous["WORST"].should_not be_nil
            @pc.commands["TGT1"]["PKT1"].items["ITEM1"].hazardous["WORST"].should eql "Hazardous description"
            @pc.commands["TGT1"]["PKT1"].limits_items.should be_empty
            tf.unlink
          end
        end
      end

      context "with READ_CONVERSION and WRITE_CONVERSION" do
        it "should complain about missing conversion file" do
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

        it "should complain about a non Cosmos::Conversion class" do
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

        it "should parse the conversion" do
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
          @pc.telemetry["TGT1"]["PKT1"].read("ITEM1").should eql 2
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  PARAMETER item1 0 16 INT 0 0 0'
          tf.puts '  WRITE_CONVERSION conversion2.rb'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].write("ITEM1", 3)
          @pc.commands["TGT1"]["PKT1"].read("ITEM1").should eql 6
          tf.unlink

          File.delete(filename) if File.exist?(filename)
        end
      end

      context "with PROCESSOR" do
        it "should complain about missing processor file" do
          filename = File.join(File.dirname(__FILE__), "../test_only.rb")
          File.delete(filename) if File.exist?(filename)
          @pc = PacketConfig.new

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  PROCESSOR TEST test_only.rb'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /TestOnly class not found/)
          tf.unlink
        end

        it "should complain about a non Cosmos::Processor class" do
          filename = File.join(File.dirname(__FILE__), "../processor1.rb")
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

        it "should parse the processor" do
          filename = File.join(File.dirname(__FILE__), "../processor2.rb")
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
          @pc.telemetry["TGT1"]["PKT1"].read("ITEM1").should eql 5
          tf.unlink

          File.delete(filename) if File.exist?(filename)
        end

        it "should complain if applied to a command packet" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  PROCESSOR P1 processor1.rb'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "PROCESSOR only applies to telemetry packets")
          tf.unlink
        end
      end

      context "with POLY_READ_CONVERSION and POLY_WRITE_CONVERSION" do
        it "should perform a polynomial conversion" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 16 INT "Integer Item"'
          tf.puts '  POLY_READ_CONVERSION 5 2'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.telemetry["TGT1"]["PKT1"].buffer = "\x01"
          @pc.telemetry["TGT1"]["PKT1"].read("ITEM1").should eql 7.0
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  PARAMETER item1 0 16 INT 0 0 0'
          tf.puts '  POLY_WRITE_CONVERSION 5 2'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].write("ITEM1", 3)
          @pc.commands["TGT1"]["PKT1"].read("ITEM1").should eql 11
          tf.unlink
        end
      end

      context "with SEG_POLY_READ_CONVERSION and SEG_POLY_WRITE_CONVERSION" do
        it "should perform a segmented polynomial conversion" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 16 INT "Integer Item"'
          tf.puts '  SEG_POLY_READ_CONVERSION 0 1 2'
          tf.puts '  SEG_POLY_READ_CONVERSION 5 2 3'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.telemetry["TGT1"]["PKT1"].buffer = "\x01"
          @pc.telemetry["TGT1"]["PKT1"].read("ITEM1").should eql 3.0
          @pc.telemetry["TGT1"]["PKT1"].buffer = "\x05"
          @pc.telemetry["TGT1"]["PKT1"].read("ITEM1").should eql 17.0
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  PARAMETER item1 0 16 INT 0 0 0'
          tf.puts '  SEG_POLY_WRITE_CONVERSION 0 1 2'
          tf.puts '  SEG_POLY_WRITE_CONVERSION 5 2 3'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].write("ITEM1", 1)
          @pc.commands["TGT1"]["PKT1"].read("ITEM1").should eql 3
          @pc.commands["TGT1"]["PKT1"].write("ITEM1", 5)
          @pc.commands["TGT1"]["PKT1"].read("ITEM1").should eql 17
          tf.unlink
        end
      end

      context "with GENERIC_READ_CONVERSION and GENERIC_WRITE_CONVERSION" do
        it "should process a generic conversion" do
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
          pkt.item1.should eql 4
          pkt.item2.should eql "Number 0"
          tf.unlink
        end

        it "should process a generic conversion with a defined type" do
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
          pkt.item1.should eql 800
          pkt.item2 = 400
          pkt.item2.should eql 800.0
          tf.unlink
        end
      end

      context "with LIMITS" do
        it "should complain if applied to a command PARAMETER" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
          tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 7 3 5'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "LIMITS only applies to telemetry items")
          tf.unlink
        end

        it "should complain if the second parameter isn't a number" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT TRUE ENABLED 1 2 6 7 3 5'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Ensure persistence is an integer/)
          tf.unlink
        end

        it "should complain if the third parameter isn't ENABLED or DISABLED" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 3 TRUE 1 2 6 7 3 5'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, /Initial state must be ENABLED or DISABLED/)
          tf.unlink
        end

        it "should complain if the 4 limits are out of order" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 3 ENABLED 2 1 3 4'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid limits specified. Ensure yellow limits are within red limits.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 3 ENABLED 1 5 3 7'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid limits specified. Ensure yellow limits are within red limits.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 5 4'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid limits specified. Ensure yellow limits are within red limits.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 3 0'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid limits specified. Ensure yellow limits are within red limits.")
          tf.unlink
        end

        it "should complain if the 6 limits are out of order" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 7 0 5'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid limits specified. Ensure green limits are within yellow limits.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 3 ENABLED 1 3 6 7 2 5'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid limits specified. Ensure green limits are within yellow limits.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 8 3 7'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid limits specified. Ensure green limits are within yellow limits.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 8 3 9'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid limits specified. Ensure green limits are within yellow limits.")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 8 4 3'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "Invalid limits specified. Ensure green limits are within yellow limits.")
          tf.unlink
        end

        it "should take 4 limits values" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 7'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          item = @pc.telemetry["TGT1"]["PKT1"].items["ITEM1"]
          item.limits.values[:DEFAULT].should_not be_nil
          @pc.telemetry["TGT1"]["PKT1"].buffer = "\x04"
          @pc.telemetry["TGT1"]["PKT1"].enable_limits("ITEM1")
          @pc.telemetry["TGT1"]["PKT1"].check_limits
          item.limits.state.should eql :GREEN
          @pc.telemetry["TGT1"]["PKT1"].limits_items.should eql [item]
          tf.unlink
        end

        it "should take 6 limits values" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT "Item"'
          tf.puts '    LIMITS DEFAULT 3 ENABLED 1 2 6 7 3 5'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          item = @pc.telemetry["TGT1"]["PKT1"].items["ITEM1"]
          item.limits.values[:DEFAULT].should_not be_nil
          @pc.telemetry["TGT1"]["PKT1"].buffer = "\x04"
          @pc.telemetry["TGT1"]["PKT1"].enable_limits("ITEM1")
          @pc.telemetry["TGT1"]["PKT1"].check_limits
          item.limits.state.should eql :BLUE
          @pc.telemetry["TGT1"]["PKT1"].limits_items.should eql [item]
          tf.unlink
        end
      end

      context "with LIMITS_RESPONSE" do
        it "should complain if applied to a command PARAMETER" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
          tf.puts '    LIMITS_RESPONSE test.rb'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "LIMITS_RESPONSE only applies to telemetry items")
          tf.unlink
        end

        it "should complain about missing response file" do
          filename = File.join(File.dirname(__FILE__), "../test_only.rb")
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

        it "should complain about a non Cosmos::LimitsResponse class" do
          filename = File.join(File.dirname(__FILE__), "../limits_response1.rb")
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

        it "should set the response" do
          filename = File.join(File.dirname(__FILE__), "../limits_response2.rb")
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
          pkt.get_item("ITEM1").limits.response.class.should eql LimitsResponse2

          File.delete(filename) if File.exist?(filename)
          tf.unlink
        end

        it "should call the response with parameters" do
          filename = File.join(File.dirname(__FILE__), "../limits_response2.rb")
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
            stdout.string.should eql "initialize: 2\n"
          end

          File.delete(filename) if File.exist?(filename)
          tf.unlink
        end
      end

      context "with FORMAT_STRING" do
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

      context "with UNITS" do
        it "apply units when read :WITH_UNITS" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 8 UINT'
          tf.puts '    UNITS Volts V'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.telemetry["TGT1"]["PKT1"].read("ITEM1",:WITH_UNITS).should eql "0 V"
          tf.unlink
        end
      end

      context "with META" do
        it "should save metadata for items" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 8 UINT'
          tf.puts '    META TYPE "unsigned int"'
          tf.puts '    META OTHER'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.telemetry["TGT1"]["PKT1"].get_item('item1').meta['TYPE'].should eql ['unsigned int']
          @pc.telemetry["TGT1"]["PKT1"].get_item('item1').meta['OTHER'].should eql []
          tf.unlink
        end
      end

      context "with OVERFLOW" do
        it "should set the overflow type for items" do
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
          @pc.telemetry["TGT1"]["PKT1"].get_item('item1').overflow.should eql :TRUNCATE
          @pc.telemetry["TGT1"]["PKT1"].get_item('item2').overflow.should eql :SATURATE
          @pc.telemetry["TGT1"]["PKT1"].get_item('item3').overflow.should eql :ERROR
          @pc.telemetry["TGT1"]["PKT1"].get_item('item4').overflow.should eql :ERROR_ALLOW_HEX
          tf.unlink
        end
      end

      context "with REQUIRED" do
        it "should only apply to a command parameter" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  ITEM item1 0 8 UINT'
          tf.puts '    REQUIRED'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "REQUIRED only applies to command parameters")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  REQUIRED'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "No current item for REQUIRED")
          tf.unlink
        end

        it "should mark a command parameter as required" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  PARAMETER item1 0 8 UINT 0 1 1'
          tf.puts '    REQUIRED'
          tf.puts '  PARAMETER item2 0 8 UINT 0 1 1'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].items["ITEM1"].required.should be_truthy
          @pc.commands["TGT1"]["PKT1"].items["ITEM2"].required.should be_falsey
          tf.unlink
        end
      end

      context "with MINIMUM_VALUE, MAXIMUM_VALUE, DEFAULT_VALUE" do
        it "should complain if used on telemetry items" do
          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT'
          tf.puts '    MINIMUM_VALUE 1'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "MINIMUM_VALUE only applies to command parameters")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT'
          tf.puts '    MAXIMUM_VALUE 3'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "MAXIMUM_VALUE only applies to command parameters")
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'TELEMETRY tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_ITEM item1 16 UINT'
          tf.puts '    DEFAULT_VALUE 2'
          tf.close
          expect { @pc.process_file(tf.path, "TGT1") }.to raise_error(ConfigParser::Error, "DEFAULT_VALUE only applies to command parameters")
          tf.unlink
        end

        it "should allow overriding the defined value" do
          tf = Tempfile.new('unittest')
          tf.puts 'COMMAND tgt1 pkt1 LITTLE_ENDIAN "Packet"'
          tf.puts '  APPEND_PARAMETER item1 16 UINT 0 1 1'
          tf.puts '  APPEND_PARAMETER item2 16 STRING "HI"'
          tf.close
          @pc.process_file(tf.path, "TGT1")
          @pc.commands["TGT1"]["PKT1"].restore_defaults
          @pc.commands["TGT1"]["PKT1"].read("ITEM1").should eql 1
          @pc.commands["TGT1"]["PKT1"].items["ITEM1"].range.should eql (0..1)
          @pc.commands["TGT1"]["PKT1"].read("ITEM2").should eql "HI"
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
          @pc.commands["TGT1"]["PKT1"].read("ITEM1").should eql 2
          @pc.commands["TGT1"]["PKT1"].items["ITEM1"].range.should eql (1..3)
          @pc.commands["TGT1"]["PKT1"].read("ITEM2").should eql "NO"
          tf.unlink
        end
      end

    end # describe "process_file"
  end
end
