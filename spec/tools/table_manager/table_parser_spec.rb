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
require 'cosmos/tools/table_manager/table_config'
require 'cosmos/tools/table_manager/table_parser'
require 'tempfile'

module Cosmos

  describe TableParser do

    describe "process_file" do
      before(:each) do
        @tc = TableConfig.new
      end

      it "complains if there are not enough parameters" do
        tf = Tempfile.new('unittest')
        tf.puts("TABLE table")
        tf.close
        expect { @tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for TABLE/)
        tf.unlink

        tf = Tempfile.new('unittest')
        tf.puts("TABLE table BIG_ENDIAN TWO_DIMENSIONAL")
        tf.close
        expect { @tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters for TABLE/)
        tf.unlink
      end

      it "complains if there are too many parameters" do
        tf = Tempfile.new('unittest')
        tf.puts "TABLE table LITTLE_ENDIAN ONE_DIMENSIONAL 'Table' extra"
        tf.close
        expect { @tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for TABLE/)
        tf.unlink

        tf = Tempfile.new('unittest')
        tf.puts "TABLE table LITTLE_ENDIAN TWO_DIMENSIONAL 2 'Table' extra"
        tf.close
        expect { @tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters for TABLE/)
        tf.unlink
      end

      it "complains about invalid type" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE table LITTLE_ENDIAN FOUR_DIMENSIONAL "Table"'
        tf.close
        expect { @tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Invalid display type FOUR_DIMENSIONAL/)
        tf.unlink
      end

      it "complains about invalid endianness" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE table MIDDLE_ENDIAN ONE_DIMENSIONAL "Table"'
        tf.close
        expect { @tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Invalid endianness MIDDLE_ENDIAN/)
        tf.unlink
      end

      it "processes table, endianness, type, description" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE table LITTLE_ENDIAN ONE_DIMENSIONAL "Table"'
        tf.close
        @tc.process_file(tf.path)
        tbl = @tc.table("TABLE")
        expect(tbl.table_name).to eql "TABLE"
        expect(tbl.default_endianness).to eql :LITTLE_ENDIAN
        expect(tbl.type).to eql :ONE_DIMENSIONAL
        expect(tbl.description).to eql "Table"
        tf.unlink
      end

      it "complains if a table is redefined" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE table LITTLE_ENDIAN ONE_DIMENSIONAL "Packet 1"'
        tf.puts 'TABLE table LITTLE_ENDIAN ONE_DIMENSIONAL "Packet 2"'
        tf.close
        @tc.process_file(tf.path)
        expect(@tc.warnings).to include("Table TABLE redefined.")
        tf.unlink
      end

    end # describe "process_file"
  end
end

