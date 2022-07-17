# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'spec_helper'
require 'openc3'
require 'openc3/tools/table_manager/table_item_parser'
require 'openc3/tools/table_manager/table_config'
require 'tempfile'

module OpenC3

  describe TableItemParser do

    describe "process_file" do
      before(:each) do
        @tc = TableConfig.new
      end

      it "handles errors parsing" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE table LITTLE_ENDIAN KEY_VALUE "Table"'
        tf.puts '  APPEND_PARAMETER ITEM1 ZERO UINT 0 2 0 "Description"'
        tf.close
        expect { @tc.process_file(tf.path) }.to raise_error(ConfigParser::Error)
        tf.unlink
      end

      it "renames items in ROW_COLUMN tables by appending their column number" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE table LITTLE_ENDIAN ROW_COLUMN 100 "Table"'
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
