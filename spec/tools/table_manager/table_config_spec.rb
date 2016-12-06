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
require 'tempfile'

module Cosmos

  describe TableConfig do
    let(:tc) { TableConfig.new }

    describe "tables" do
      it "returns the tables hash" do
        tf = Tempfile.new('unittest')
        tf.puts("TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL")
        tf.puts("TABLE table2 BIG_ENDIAN TWO_DIMENSIONAL")
        tf.puts("TABLE table3 BIG_ENDIAN ONE_DIMENSIONAL")
        tf.close
        tc.process_file(tf.path)
        expect(tc.tables.keys).to eql %w(TABLE1 TABLE2 TABLE3)
        expect(tc.tables.values[0]).to be_a Table
        tf.unlink
      end
    end

    describe "table_names" do
      it "returns the table names" do
        tf = Tempfile.new('unittest')
        tf.puts("TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL")
        tf.puts("TABLE table2 BIG_ENDIAN TWO_DIMENSIONAL")
        tf.puts("TABLE table3 BIG_ENDIAN ONE_DIMENSIONAL")
        tf.close
        tc.process_file(tf.path)
        expect(tc.table_names).to eql %w(TABLE1 TABLE2 TABLE3)
        tf.unlink
      end
    end

    describe "table" do
      it "returns a table" do
        tf = Tempfile.new('unittest')
        tf.puts("TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL")
        tf.puts("TABLE table2 BIG_ENDIAN TWO_DIMENSIONAL")
        tf.puts("TABLE table3 BIG_ENDIAN ONE_DIMENSIONAL")
        tf.close
        tc.process_file(tf.path)
        expect(tc.table("TABLE1").table_name).to eql "TABLE1"
        expect(tc.table("TABLE1").type).to eql :ONE_DIMENSIONAL
        expect(tc.table("TABLE2").table_name).to eql "TABLE2"
        expect(tc.table("TABLE2").type).to eql :TWO_DIMENSIONAL
        expect(tc.table("TABLE3").table_name).to eql "TABLE3"
        expect(tc.table("TABLE3").type).to eql :ONE_DIMENSIONAL
        tf.unlink
      end
    end

    describe "process_file" do
      it "complains about unknown keywords" do
        tf = Tempfile.new('unittest')
        tf.puts("BLAH")
        tf.close
        expect { tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Unknown keyword 'BLAH'/)
        tf.unlink
      end

      context "with SELECT_TABLE" do
        it "complains if the table is not found" do
          tf = Tempfile.new('unittest')
          tf.puts 'SELECT_TABLE table'
          tf.puts 'SELECT_ITEM ITEM1'
          tf.puts '  DESCRIPTION "New description"'
          tf.close
          expect { tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Table TABLE not found/)
          tf.unlink
        end

        it "selects a table for modification" do
          tf = Tempfile.new('unittest')
          tf.puts 'TABLE table LITTLE_ENDIAN ONE_DIMENSIONAL "Table"'
          tf.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
          tf.close
          tc.process_file(tf.path)
          tbl = tc.table("TABLE")
          expect(tbl.get_item("ITEM1").description).to eql "Item"
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'SELECT_TABLE table'
          tf.puts 'SELECT_PARAMETER ITEM1'
          tf.puts '  DESCRIPTION "New description"'
          tf.close
          tc.process_file(tf.path)
          tbl = tc.table("TABLE")
          expect(tbl.get_item("ITEM1").description).to eql "New description"
          tf.unlink
        end
      end

      context "with SELECT_PARAMETER" do
        it "complains if the parameter is not found" do
          tf = Tempfile.new('unittest')
          tf.puts 'TABLE table LITTLE_ENDIAN ONE_DIMENSIONAL "Table"'
          tf.puts '  APPEND_PARAMETER PARAM 16 UINT 0 0 0 "Param"'
          tf.close
          tc.process_file(tf.path)
          tbl = tc.table("TABLE")
          expect(tbl.get_item("PARAM").description).to eql "Param"
          expect(tbl.get_item("PARAM").editable).to eql true
          tf.unlink

          tf = Tempfile.new('unittest')
          tf.puts 'SELECT_TABLE table'
          tf.puts '  SELECT_PARAMETER PARAMX'
          tf.puts '    DESCRIPTION "New description"'
          tf.close
          expect { tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /PARAMX not found in table TABLE/)
          tf.unlink
        end
      end

      context "with UNEDITABLE" do
        it "sets editable to false" do
          tf = Tempfile.new('unittest')
          tf.puts 'TABLE table LITTLE_ENDIAN ONE_DIMENSIONAL "Table"'
          tf.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
          tf.puts '    UNEDITABLE'
          tf.close
          tc.process_file(tf.path)
          tbl = tc.table("TABLE")
          expect(tbl.get_item("ITEM1").editable).to eql false
          tf.unlink
        end
      end

    end # describe "process_file"
  end
end
