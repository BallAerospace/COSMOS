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
        expect { @ti.editable = 5 }.to raise_error(ArgumentError, "#{@ti.name}: editable must be a boolean but is a Fixnum")
      end
    end

    describe "constraint=" do
      it "sets the constraint" do
        @ti.constraint = Conversion.new
        expect(@ti.constraint).to be_a(Conversion)
        @ti.constraint = nil
        expect(@ti.constraint).to be_nil
      end

      it "complains about non Conversion values" do
        expect { @ti.constraint = 5 }.to raise_error(ArgumentError, "#{@ti.name}: constraint must be a Conversion but is a Fixnum")
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
        expect(hash.keys).to include('editable', 'constraint')
        expect(hash["editable"]).to eql true
        expect(hash["constraint"]).to be_nil

        @ti.editable = false
        @ti.constraint = Conversion.new

        hash = @ti.to_hash
        expect(hash["editable"]).to eql false
        expect(hash["constraint"]).to match "Conversion"
      end
    end

  end
end
