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
require 'openc3/tools/table_manager/table_item'

module OpenC3

  describe TableItem do
    before(:each) do
      @ti = TableItem.new("test", 0, 32, :UINT, :BIG_ENDIAN, nil)
    end

    describe "editable=" do
      it "sets the editable flag" do
        @ti.editable = true
        expect(@ti.editable).to eql true
        @ti.editable = false
        expect(@ti.editable).to eql false
      end

      it "complains about non boolean values" do
        expect { @ti.editable = 5.1 }.to raise_error(ArgumentError, "#{@ti.name}: editable must be a boolean but is a Float")
      end
    end

    describe "clone" do
      it "duplicates the entire TableItem" do
        pi2 = @ti.clone
        expect(@ti < pi2).to be true
      end
    end

    describe "as_json" do
      it "converts to a Hash" do
        hash = @ti.as_json(:allow_nan => true)
        # Check the values from StructureItem
        expect(hash.keys).to include('editable')
        expect(hash["editable"]).to eql true

        @ti.editable = false

        hash = @ti.as_json(:allow_nan => true)
        expect(hash["editable"]).to eql false
      end
    end
  end
end

