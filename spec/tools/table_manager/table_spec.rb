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
require 'cosmos/tools/table_manager/table'

module Cosmos

  describe Table do

    describe "table_name" do
      it "returns the table name upcased" do
        t = Table.new("table", :BIG_ENDIAN, :ONE_DIMENSIONAL, "description", "filename")
        expect(t.table_name).to eql "TABLE"
      end
    end

    describe "type" do
      it "must be :ONE_DIMENSIONAL or :TWO_DIMENSIONAL" do
        t = Table.new("table", :BIG_ENDIAN, :ONE_DIMENSIONAL, "description", "filename")
        expect(t.type).to eql :ONE_DIMENSIONAL
        t = Table.new("table", :BIG_ENDIAN, :TWO_DIMENSIONAL, "description", "filename")
        expect(t.type).to eql :TWO_DIMENSIONAL
        expect { Table.new("table", :BIG_ENDIAN, :BIG, "description", "filename") }.to raise_error(ArgumentError, /Invalid type 'BIG' for table 'table'/)
      end
    end

    describe "filename" do
      it "stores the filename" do
        t = Table.new("table", :BIG_ENDIAN, :ONE_DIMENSIONAL, "description", File.join(Dir.pwd, "filename"))
        expect(t.filename).to eql File.join(Dir.pwd, "filename")
      end
    end

    describe "num_rows=" do
      it "raises an error for ONE_DIMENTIONAL" do
        t = Table.new("table", :BIG_ENDIAN, :ONE_DIMENSIONAL, "description", "filename")
        expect { t.num_rows = 2 }.to raise_error(/Rows are fixed/)
      end

      it "sets num_rows for TWO_DIMENTIONAL" do
        t = Table.new("table", :BIG_ENDIAN, :TWO_DIMENSIONAL, "description", "filename")
        t.num_rows = 2
        expect(t.num_rows).to eql 2
      end
    end

    describe "num_rows" do
      it "initializes to 0" do
        t = Table.new("table", :BIG_ENDIAN, :ONE_DIMENSIONAL, "description", "filename")
        expect(t.num_rows).to eql 0
      end

      it "equals the number of visible items in ONE_DIMENSIONAL" do
        t = Table.new("table", :BIG_ENDIAN, :ONE_DIMENSIONAL, "description", "filename")
        ti1 = TableItem.new("test1", 0, 32, :UINT, :BIG_ENDIAN, nil)
        ti2 = TableItem.new("test2", 0, 32, :UINT, :BIG_ENDIAN, nil)
        ti2.hidden = true
        ti3 = TableItem.new("test3", 0, 32, :UINT, :BIG_ENDIAN, nil)
        t.append(ti1)
        expect(t.num_rows).to eql 1
        t.append(ti2)
        expect(t.num_rows).to eql 1
        t.append(ti3)
        expect(t.num_rows).to eql 2
      end
    end

    describe "num_columns" do
      it "initializes to 1 for ONE_DIMENSIONAL" do
        t = Table.new("table", :BIG_ENDIAN, :ONE_DIMENSIONAL, "description", "filename")
        expect(t.num_columns).to eql 1
      end
      it "initializes to 0 for TWO_DIMENSIONAL" do
        t = Table.new("table", :BIG_ENDIAN, :TWO_DIMENSIONAL, "description", "filename")
        expect(t.num_columns).to eql 0
      end
    end

  end # describe Table
end

