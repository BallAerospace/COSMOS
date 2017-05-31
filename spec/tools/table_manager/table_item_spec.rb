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
require 'cosmos/tools/table_manager/table_item'

module Cosmos

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
        expect(@ti == pi2).to be true
      end
    end

    describe "to_hash" do
      it "converts to a Hash" do
        hash = @ti.to_hash
        # Check the values from StructureItem
        expect(hash.keys).to include('editable')
        expect(hash["editable"]).to eql true

        @ti.editable = false

        hash = @ti.to_hash
        expect(hash["editable"]).to eql false
      end
    end
  end
end

