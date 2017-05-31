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
require 'cosmos/tools/table_manager/table_item_parser'
require 'cosmos/tools/table_manager/table_config'
require 'tempfile'

module Cosmos

  describe TableItemParser do

    describe "process_file" do
      before(:each) do
        @tc = TableConfig.new
      end

      it "handles errors parsing" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE table LITTLE_ENDIAN ONE_DIMENSIONAL "Table"'
        tf.puts '  APPEND_PARAMETER ITEM1 ZERO UINT 0 2 0 "Description"'
        tf.close
        expect { @tc.process_file(tf.path) }.to raise_error(ConfigParser::Error)
        tf.unlink
      end

      it "renames items in TWO_DIMENSIONAL tables by appending their column number" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE table LITTLE_ENDIAN TWO_DIMENSIONAL 100 "Table"'
        tf.puts '  APPEND_PARAMETER FIRST 32 UINT 0 2 0 "Description"'
        tf.puts '  APPEND_PARAMETER SECOND 32 UINT 0 2 0 "Description"'
        tf.puts '  APPEND_PARAMETER THIRD 32 UINT 0 2 0 "Description"'
        tf.close
        @tc.process_file(tf.path)
        items = @tc.table("TABLE").items.collect { |item_name, item| item_name }
        expect(items.length).to eq 300
        first = items.select { |item| item =~ /FIRST/ }
        expect(first.length).to eq 100
        expect(first.sort[0]).to eq 'FIRST0'
        expect(first.sort[-1]).to eq 'FIRST99'
        second = items.select { |item| item =~ /SECOND/ }
        expect(second.length).to eq 100
        expect(second.sort[0]).to eq 'SECOND0'
        expect(second.sort[-1]).to eq 'SECOND99'
        third = items.select { |item| item =~ /THIRD/ }
        expect(third.length).to eq 100
        expect(third.sort[0]).to eq 'THIRD0'
        expect(third.sort[-1]).to eq 'THIRD99'
        tf.unlink
      end
    end
  end
end
