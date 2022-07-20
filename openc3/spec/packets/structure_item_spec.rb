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
require 'openc3/packets/structure_item'

module OpenC3
  describe StructureItem do
    describe "name=" do
      it "creates new structure items" do
        expect(StructureItem.new("test", 0, 8, :UINT, :BIG_ENDIAN, nil).name).to eql "TEST"
      end

      it "complains about non String names" do
        expect { StructureItem.new(nil, 0, 8, :UINT, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "name must be a String but is a NilClass")
        expect { StructureItem.new(5.1, 0, 8, :UINT, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "name must be a String but is a Float")
      end

      it "complains about blank names" do
        expect { StructureItem.new("", 0, 8, :UINT, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "name must contain at least one character")
      end
    end

    describe "endianness=" do
      it "accepts BIG_ENDIAN and LITTLE_ENDIAN" do
        expect(StructureItem.new("test", 0, 8, :UINT, :BIG_ENDIAN, nil).endianness).to eql :BIG_ENDIAN
        expect(StructureItem.new("test", 0, 8, :UINT, :LITTLE_ENDIAN, nil).endianness).to eql :LITTLE_ENDIAN
      end

      it "complains about string endianness" do
        expect { StructureItem.new("test", 0, 8, :UINT, 'BIG_ENDIAN', nil) }.to raise_error(ArgumentError, "TEST: endianness must be a Symbol")
      end

      it "complains about bad endianness" do
        expect { StructureItem.new("test", 0, 8, :UINT, :BLAH, nil) }.to raise_error(ArgumentError, "TEST: unknown endianness: BLAH - Must be :BIG_ENDIAN or :LITTLE_ENDIAN")
      end
    end

    describe "data_type=" do
      it "accepts INT, UINT, FLOAT, STRING, BLOCK, and DERIVED data types" do
        %w(INT UINT FLOAT STRING BLOCK).each do |type|
          expect(StructureItem.new("test", 0, 32, type.to_sym, :BIG_ENDIAN, nil).data_type).to eql type.to_sym
        end
        expect(StructureItem.new("test", 0, 0, :DERIVED, :BIG_ENDIAN, nil).data_type).to eql :DERIVED
      end

      it "complains about string data_type" do
        expect { StructureItem.new("test", 0, 0, 'UINT', :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "TEST: data_type must be a Symbol")
      end

      it "complains about bad data types" do
        expect { StructureItem.new("test", 0, 0, :UNKNOWN, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "TEST: unknown data_type: UNKNOWN - Must be :INT, :UINT, :FLOAT, :STRING, :BLOCK, or :DERIVED")
      end
    end

    describe "overflow=" do
      it "accepts ERROR, ERROR_ALLOW_HEX, TRUNCATE and SATURATE overflow types" do
        %w(ERROR ERROR_ALLOW_HEX TRUNCATE SATURATE).each do |type|
          expect(StructureItem.new("test", 0, 32, :INT, :BIG_ENDIAN, nil, type.to_sym).overflow).to eql type.to_sym
        end
      end

      it "complains about string overflow types" do
        expect { StructureItem.new("test", 0, 32, :INT, :BIG_ENDIAN, nil, 'ERROR') }.to raise_error(ArgumentError, "TEST: overflow type must be a Symbol")
      end

      it "complains about bad overflow types" do
        expect { StructureItem.new("test", 0, 32, :INT, :BIG_ENDIAN, nil, :UNKNOWN) }.to raise_error(ArgumentError, "TEST: unknown overflow type: UNKNOWN - Must be :ERROR, :ERROR_ALLOW_HEX, :TRUNCATE, or :SATURATE")
      end
    end

    describe "bit_offset=" do
      it "compains about bad bit offsets types" do
        if 0.class == Integer
          # Ruby version >= 2.4.0
          expect { StructureItem.new("test", nil, 8, :UINT, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "TEST: bit_offset must be an Integer")
        else
          # Ruby version < 2.4.0
          expect { StructureItem.new("test", nil, 8, :UINT, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "TEST: bit_offset must be a Fixnum")
        end
      end

      it "complains about unaligned bit offsets" do
        %w(FLOAT STRING BLOCK).each do |type|
          expect { StructureItem.new("test", 1, 32, type.to_sym, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "TEST: bit_offset for :FLOAT, :STRING, and :BLOCK items must be byte aligned")
        end
      end

      it "complains about non zero DERIVED bit offsets" do
        expect { StructureItem.new("test", 8, 0, :DERIVED, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "TEST: DERIVED items must have bit_offset of zero")
      end
    end

    describe "bit_size=" do
      it "complains about bad bit sizes types" do
        if 0.class == Integer
          # Ruby version >= 2.4.0
          expect { StructureItem.new("test", 0, nil, :UINT, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "TEST: bit_size must be an Integer")
        else
          # Ruby version < 2.4.0
          expect { StructureItem.new("test", 0, nil, :UINT, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "TEST: bit_size must be a Fixnum")
        end
      end

      it "complains about 0 size INT, UINT, and FLOAT" do
        %w(INT UINT FLOAT).each do |type|
          expect { StructureItem.new("test", 0, 0, type.to_sym, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "TEST: bit_size cannot be negative or zero for :INT, :UINT, and :FLOAT items: 0")
        end
      end

      it "complains about bad float bit sizes" do
        expect { StructureItem.new("test", 0, 8, :FLOAT, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "TEST: bit_size for FLOAT items must be 32 or 64. Given: 8")
      end

      it "creates 32 and 64 bit floats" do
        expect(StructureItem.new("test", 0, 32, :FLOAT, :BIG_ENDIAN, nil).bit_size).to eql 32
        expect(StructureItem.new("test", 0, 64, :FLOAT, :BIG_ENDIAN, nil).bit_size).to eql 64
      end

      it "complains about non zero DERIVED bit sizes" do
        expect { StructureItem.new("test", 0, 8, :DERIVED, :BIG_ENDIAN, nil) }.to raise_error(ArgumentError, "TEST: DERIVED items must have bit_size of zero")
      end
    end

    describe "array_size=" do
      it "complains about bad array size types" do
        if 0.class == Integer
          # Ruby version >= 2.4.0
          expect { StructureItem.new("test", 0, 8, :UINT, :BIG_ENDIAN, "") }.to raise_error(ArgumentError, "TEST: array_size must be an Integer")
        else
          # Ruby version < 2.4.0
          expect { StructureItem.new("test", 0, 8, :UINT, :BIG_ENDIAN, "") }.to raise_error(ArgumentError, "TEST: array_size must be a Fixnum")
        end
      end

      it "complains about array size != multiple of bit size" do
        expect { StructureItem.new("test", 0, 8, :UINT, :BIG_ENDIAN, 10) }.to raise_error(ArgumentError, "TEST: array_size must be a multiple of bit_size")
      end

      it "does not complain about array size != multiple of bit size with negative array size" do
        expect { StructureItem.new("test", 0, 32, :UINT, :BIG_ENDIAN, -8) }.not_to raise_error
      end
    end

    describe "<=>", no_ext: true do
      it "sorts items according to positive bit offset" do
        si1 = StructureItem.new("si1", 0, 8, :UINT, :BIG_ENDIAN, nil)
        si2 = StructureItem.new("si2", 8, 8, :UINT, :BIG_ENDIAN, nil)
        expect(si1 < si2).to be true
        expect(si1 == si2).to be false
        expect(si1 > si2).to be false

        si2 = StructureItem.new("si2", 0, 8, :UINT, :BIG_ENDIAN, nil)
        expect(si1 < si2).to be true
        expect(si1 == si2).to be false
        expect(si1 > si2).to be false
      end

      it "sorts items with 0 bit offset according to bit size" do
        si1 = StructureItem.new("si1", 0, 8, :UINT, :BIG_ENDIAN, nil)
        si2 = StructureItem.new("si2", 0, 0, :BLOCK, :BIG_ENDIAN, nil)
        expect(si1 < si2).to be false
        expect(si1 == si2).to be false
        expect(si1 > si2).to be true
      end

      it "sorts items according to negative bit offset" do
        si1 = StructureItem.new("si1", -8, 8, :UINT, :BIG_ENDIAN, nil)
        si2 = StructureItem.new("si2", -16, 8, :UINT, :BIG_ENDIAN, nil)
        expect(si1 < si2).to be false
        expect(si1 == si2).to be false
        expect(si1 > si2).to be true

        si2 = StructureItem.new("si2", -8, 8, :UINT, :BIG_ENDIAN, nil)
        expect(si1 < si2).to be true
        expect(si1 == si2).to be false
        expect(si1 > si2).to be false
      end

      it "sorts items according to mixed bit offset" do
        si1 = StructureItem.new("si1", 16, 8, :UINT, :BIG_ENDIAN, nil)
        si2 = StructureItem.new("si2", -8, 8, :UINT, :BIG_ENDIAN, nil)
        expect(si1 < si2).to be true
        expect(si1 == si2).to be false
        expect(si1 > si2).to be false
      end

      it "doesn't raise errors on comparing incompatible items" do
        si1 = StructureItem.new("si1", 16, 8, :UINT, :BIG_ENDIAN, nil)
        expect { (si1 > 5) }.to raise_error(StandardError)
        expect(si1 <=> 5).to be nil
      end
    end

    describe "clone" do
      it "duplicates the entire structure item " do
        si1 = StructureItem.new("si1", -8, 1, :UINT, :LITTLE_ENDIAN, nil)
        si2 = si1.clone
        expect(si1 < si2).to be true
      end
    end

    describe "as_json" do
      it "creates a Hash" do
        item = StructureItem.new("test", 0, 8, :UINT, :BIG_ENDIAN, 16)
        hash = item.as_json(:allow_nan => true)
        expect(hash.keys.length).to eql 7
        expect(hash.keys).to include('name', 'bit_offset', 'bit_size', 'data_type', 'endianness', 'array_size', 'overflow')
        expect(hash["name"]).to eql "TEST"
        expect(hash["bit_offset"]).to eql 0
        expect(hash["bit_size"]).to eql 8
        expect(hash["data_type"]).to eql :UINT
        expect(hash["endianness"]).to eql :BIG_ENDIAN
        expect(hash["array_size"]).to eql 16
        expect(hash["overflow"]).to eql :ERROR
      end
    end

    describe "self.from_json" do
      it "creates StructureItem from hash" do
        item = StructureItem.new("test", 0, 8, :UINT, :BIG_ENDIAN, 16)
        new_item = StructureItem.from_json(item.as_json(:allow_nan => true))
        expect(new_item.name).to eql item.name
        expect(new_item.bit_offset).to eql item.bit_offset
        expect(new_item.bit_size).to eql item.bit_size
        expect(new_item.data_type).to eql item.data_type
        expect(new_item.endianness).to eql item.endianness
        expect(new_item.array_size).to eql item.array_size
        expect(new_item.overflow).to eql item.overflow
      end
    end
  end
end
