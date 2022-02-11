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
        tf.puts("TABLE table1 BIG_ENDIAN KEY_VALUE")
        tf.puts("TABLE table2 BIG_ENDIAN ROW_COLUMN 2")
        tf.puts("TABLE table3 BIG_ENDIAN KEY_VALUE")
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
        tf.puts("TABLE table1 BIG_ENDIAN KEY_VALUE")
        tf.puts("TABLE table2 BIG_ENDIAN ROW_COLUMN 2")
        tf.puts("TABLE table3 BIG_ENDIAN KEY_VALUE")
        tf.close
        tc.process_file(tf.path)
        expect(tc.table_names).to eql %w(TABLE1 TABLE2 TABLE3)
        tf.unlink
      end

      it "supports deprecated ONE_DIMENSIONAL & TWO_DIMENSIONAL" do
        tf = Tempfile.new('unittest')
        tf.puts("TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL")
        tf.puts("TABLE table2 BIG_ENDIAN TWO_DIMENSIONAL 2")
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
        tf.puts("TABLE table1 BIG_ENDIAN KEY_VALUE")
        tf.puts("TABLE table2 BIG_ENDIAN ROW_COLUMN 2")
        tf.puts("TABLE table3 BIG_ENDIAN KEY_VALUE")
        tf.close
        tc.process_file(tf.path)
        expect(tc.table("TABLE1").table_name).to eql "TABLE1"
        expect(tc.table("TABLE1").type).to eql :KEY_VALUE
        expect(tc.table("TABLE2").table_name).to eql "TABLE2"
        expect(tc.table("TABLE2").type).to eql :ROW_COLUMN
        expect(tc.table("TABLE3").table_name).to eql "TABLE3"
        expect(tc.table("TABLE3").type).to eql :KEY_VALUE
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

      it "handles errors in processing elements" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE table LITTLE_ENDIAN KEY_VALUE "Table"'
        tf.puts '  APPEND_PARAMETER item1'
        tf.close
        expect { tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters/)
        tf.unlink
      end

      context "with TABLEFILE" do
        it "complains if not enough parameters" do
          tf = Tempfile.new('unittest')
          tf.puts 'TABLEFILE'
          tf.close
          expect { tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Not enough parameters/)
          tf.unlink
        end

        it "complains if too many parameters" do
          tf = Tempfile.new('unittest')
          tf.puts 'TABLEFILE table_file table_file'
          tf.close
          expect { tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /Too many parameters/)
          tf.unlink
        end

        it "complains if the table file does not exist" do
          tf = Tempfile.new('unittest')
          tf.puts 'TABLEFILE table_file'
          tf.close
          expect { tc.process_file(tf.path) }.to raise_error(ConfigParser::Error, /not found/)
          tf.unlink
        end

        it "parses the table definition file" do
          tf = Tempfile.new('test_table')
          tf.puts 'TABLE table LITTLE_ENDIAN KEY_VALUE "Table"'
          tf.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
          tf.close
          tf1 = Tempfile.new('unittest')
          tf1.puts "TABLEFILE #{File.basename(tf.path)}"
          tf1.close
          tc.process_file(tf1.path)
          tbl = tc.table("TABLE")
          expect(tbl.get_item("ITEM1").description).to eql "Item"
          tf1.unlink
          tf.unlink
        end
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
          tf.puts 'TABLE table LITTLE_ENDIAN KEY_VALUE "Table"'
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
          tf.puts 'TABLE table LITTLE_ENDIAN KEY_VALUE "Table"'
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

      context "with TWO_DIMESIONAL tables" do
        it "duplicates parameters to create rows" do
          tf = Tempfile.new('unittest')
          tf.puts 'TABLE table LITTLE_ENDIAN ROW_COLUMN 2 "Table"'
          tf.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
          tf.puts '  APPEND_PARAMETER item2 16 UINT 0 0 0 "Item"'
          tf.close
          tc.process_file(tf.path)
          tbl = tc.table("TABLE")
          names = []
          tbl.sorted_items.each {|item| names << item.name }
          expect(names).to eql %w(ITEM10 ITEM20 ITEM11 ITEM21)
          tf.unlink
        end
      end

      context "with UNEDITABLE" do
        it "sets editable to false" do
          tf = Tempfile.new('unittest')
          tf.puts 'TABLE table LITTLE_ENDIAN KEY_VALUE "Table"'
          tf.puts '  PARAMETER item1 0 16 UINT 0 0 0 "Item"'
          tf.puts '    UNEDITABLE'
          tf.close
          tc.process_file(tf.path)
          tbl = tc.table("TABLE")
          expect(tbl.get_item("ITEM1").editable).to eql false
          tf.unlink
        end
      end

      context "with HIDDEN" do
        it "sets hidden to true" do
          tf = Tempfile.new('unittest')
          tf.puts 'TABLE table LITTLE_ENDIAN KEY_VALUE "Table"'
          tf.puts '  PARAMETER item1 0 16 UINT 0 0 0 "Item"'
          tf.puts '    HIDDEN'
          tf.close
          tc.process_file(tf.path)
          tbl = tc.table("TABLE")
          expect(tbl.get_item("ITEM1").hidden).to eql true
          tf.unlink
        end
      end

      context "with DEFAULT" do
        it "sets the default value of a 2D table" do
          tf = Tempfile.new('unittest')
          tf.puts 'TABLE table LITTLE_ENDIAN ROW_COLUMN 2 "Table"'
          tf.puts '  APPEND_PARAMETER item1 16 UINT 0 1 0 "Item"'
          tf.puts '    STATE DISABLE 0'
          tf.puts '    STATE ENABLE 1'
          tf.puts '  APPEND_PARAMETER item2 16 UINT 0 0xFFFF 0 "Item"'
          tf.puts 'DEFAULT ENABLE 0x10' # Test states
          tf.puts 'DEFAULT 0 0'         # Test values
          tf.close
          tc.process_file(tf.path)
          tbl = tc.table("TABLE")
          expect(tbl.get_item("ITEM10").default).to eql 1
          expect(tbl.get_item("ITEM20").default).to eql 0x10
          expect(tbl.get_item("ITEM11").default).to eql 0
          expect(tbl.get_item("ITEM21").default).to eql 0
          tf.unlink
        end
      end

    end # describe "process_file"
  end
end
