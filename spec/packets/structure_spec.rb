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
require 'cosmos/packets/structure'

module Cosmos

  describe Structure do

    describe "initialize" do
      it "complains about non string buffers" do
        expect { Structure.new(:BIG_ENDIAN, Array.new) }.to raise_error(TypeError, "wrong argument type Array (expected String)")
      end

      it "complains about unrecognized data types" do
        expect { Structure.new(:BLAH) }.to raise_error(ArgumentError, "Unrecognized endianness: BLAH - Must be :BIG_ENDIAN or :LITTLE_ENDIAN")
      end

      it "creates BIG_ENDIAN structures" do
        expect(Structure.new(:BIG_ENDIAN).default_endianness).to eql :BIG_ENDIAN
      end

      it "creates LITTLE_ENDIAN structures" do
        expect(Structure.new(:LITTLE_ENDIAN).default_endianness).to eql :LITTLE_ENDIAN
      end
    end # describe "initialize"

    describe "defined?" do
      it "returns true if any items have been defined" do
        s = Structure.new
        expect(s.defined?).to be false
        s.define_item("test1",0,8,:UINT)
        expect(s.defined?).to be true
      end
    end

    describe "rename_item" do
      it "renames a previously defined item" do
        s = Structure.new
        expect(s.items["test1"]).to be_nil
        expect(s.sorted_items[0]).to be_nil
        s.define_item("test1", 0, 8, :UINT)
        expect(s.items["TEST1"]).not_to be_nil
        expect(s.sorted_items[0]).not_to be_nil
        expect(s.sorted_items[0].name).to eql "TEST1"
        s.rename_item("TEST1", "TEST2")
        expect(s.items["TEST1"]).to be_nil
        expect(s.items["TEST2"]).not_to be_nil
        expect(s.sorted_items[0].name).to eql "TEST2"
      end
    end

    describe "define_item" do
      before(:each) do
        @s = Structure.new
      end

      it "adds item to items and sorted_items" do
        expect(@s.items["test1"]).to be_nil
        expect(@s.sorted_items[0]).to be_nil
        @s.define_item("test1", 0, 8, :UINT)
        expect(@s.items["TEST1"]).not_to be_nil
        expect(@s.sorted_items[0]).not_to be_nil
        expect(@s.sorted_items[0].name).to eql "TEST1"
        expect(@s.defined_length).to eql 1
        expect(@s.fixed_size).to be true
      end

      it "adds items with negative bit offsets" do
        @s.define_item("test1", -8, 8, :UINT)
        expect(@s.defined_length).to eql 1
        @s.define_item("test2", 0, 4, :UINT)
        expect(@s.defined_length).to eql 2
        @s.define_item("test3", 4, 4, :UINT)
        expect(@s.defined_length).to eql 2
        @s.define_item("test4", 16, 0, :BLOCK)
        expect(@s.defined_length).to eql 3
        @s.define_item("test5", -16, 8, :UINT)
        expect(@s.defined_length).to eql 4
        expect(@s.fixed_size).to be false
      end

      it "adds item with negative offset" do
        expect { @s.define_item("test11", -64, 8, :UINT, 128) }.to raise_error(ArgumentError, "TEST11: Can't define an item with array_size 128 greater than negative bit_offset -64")
        expect { @s.define_item("test10", -64, 8, :UINT, -64) }.to raise_error(ArgumentError, "TEST10: Can't define an item with negative array_size -64 and negative bit_offset -64")
        expect { @s.define_item("test9", -64, -64, :BLOCK) }.to raise_error(ArgumentError, "TEST9: Can't define an item with negative bit_size -64 and negative bit_offset -64")
        expect { @s.define_item("test8", 0, -32, :BLOCK, 64) }.to raise_error(ArgumentError, "TEST8: bit_size cannot be negative or zero for array items")
        expect { @s.define_item("test7", 0, 0, :BLOCK, 64) }.to raise_error(ArgumentError, "TEST7: bit_size cannot be negative or zero for array items")
        expect { @s.define_item("test6", -24, 32, :UINT) }.to raise_error(ArgumentError, "TEST6: Can't define an item with bit_size 32 greater than negative bit_offset -24")
        @s.define_item("test5", -16, 8, :UINT)
        expect(@s.defined_length).to eql 2
        @s.define_item("test1", -8, 8, :UINT)
        expect(@s.defined_length).to eql 2
        @s.define_item("test2", 0, 4, :UINT)
        expect(@s.defined_length).to eql 3
        @s.define_item("test3", 4, 4, :UINT)
        expect(@s.defined_length).to eql 3
        @s.define_item("test4", 8, 0, :BLOCK)
        expect(@s.defined_length).to eql 3
        expect(@s.fixed_size).to be false
      end

      it "recalulates sorted_items when adding multiple items" do
        @s.define_item("test1", 8, 32, :UINT)
        expect(@s.sorted_items[0].name).to eql "TEST1"
        expect(@s.defined_length).to eql 5
        @s.define_item("test2", 0, 8, :UINT)
        expect(@s.sorted_items[0].name).to eql "TEST2"
        expect(@s.defined_length).to eql 5
        @s.define_item("test3", 16, 8, :UINT)
        expect(@s.sorted_items[-1].name).to eql "TEST3"
        expect(@s.defined_length).to eql 5
        expect(@s.fixed_size).to be true
      end

      it "overwrites existing items" do
        @s.define_item("test1", 0, 8, :UINT)
        expect(@s.sorted_items[0].name).to eql "TEST1"
        expect(@s.items["TEST1"].bit_size).to eql 8
        expect(@s.items["TEST1"].data_type).to eql :UINT
        expect(@s.defined_length).to eql 1
        @s.define_item("test1", 0, 16, :INT)
        expect(@s.sorted_items[0].name).to eql "TEST1"
        expect(@s.items["TEST1"].bit_size).to eql 16
        expect(@s.items["TEST1"].data_type).to eql :INT
        expect(@s.defined_length).to eql 2
        expect(@s.fixed_size).to be true
      end
    end # describe "define_item"

    describe "define" do
      before(:each) do
        @s = Structure.new
      end

      it "adds the item to items and sorted_items" do
        expect(@s.items["test1"]).to be_nil
        expect(@s.sorted_items[0]).to be_nil
        si = StructureItem.new("test1",0,8,:UINT,:BIG_ENDIAN)
        @s.define(si)
        expect(@s.items["TEST1"]).not_to be_nil
        expect(@s.sorted_items[0]).not_to be_nil
        expect(@s.sorted_items[0].name).to eql "TEST1"
        expect(@s.defined_length).to eql 1
        expect(@s.fixed_size).to be true
      end

      it "allows items to be defined on top of each other" do
        expect(@s.items["test1"]).to be_nil
        expect(@s.sorted_items[0]).to be_nil
        si = StructureItem.new("test1",0,8,:UINT,:BIG_ENDIAN)
        @s.define(si)
        expect(@s.sorted_items[0].name).to eql "TEST1"
        expect(@s.items["TEST1"].bit_offset).to eql 0
        expect(@s.items["TEST1"].bit_size).to eql 8
        expect(@s.items["TEST1"].data_type).to eql :UINT
        expect(@s.defined_length).to eql 1
        si = StructureItem.new("test2",0,16,:INT,:BIG_ENDIAN)
        @s.define(si)
        expect(@s.sorted_items[1].name).to eql "TEST2"
        expect(@s.items["TEST2"].bit_offset).to eql 0
        expect(@s.items["TEST2"].bit_size).to eql 16
        expect(@s.items["TEST2"].data_type).to eql :INT
        expect(@s.defined_length).to eql 2
        buffer = "\x01\x02"
        expect(@s.read_item(@s.get_item("test1"), :RAW, buffer)).to eql 1
        expect(@s.read_item(@s.get_item("test2"), :RAW, buffer)).to eql 258
      end

      it "overwrites existing items" do
        si = StructureItem.new("test1",0,8,:UINT,:BIG_ENDIAN)
        @s.define(si)
        expect(@s.sorted_items[0].name).to eql "TEST1"
        expect(@s.items["TEST1"].bit_size).to eql 8
        expect(@s.items["TEST1"].data_type).to eql :UINT
        expect(@s.defined_length).to eql 1
        si = StructureItem.new("test1",0,16,:INT,:BIG_ENDIAN)
        @s.define(si)
        expect(@s.sorted_items[0].name).to eql "TEST1"
        expect(@s.items["TEST1"].bit_size).to eql 16
        expect(@s.items["TEST1"].data_type).to eql :INT
        expect(@s.defined_length).to eql 2
        expect(@s.fixed_size).to be true
      end
    end

    describe "append_item" do
      before(:each) do
        @s = Structure.new
      end

      it "appends an item to items" do
        @s.define_item("test1", 0, 8, :UINT)
        @s.append_item("test2", 16, :UINT)
        expect(@s.items["TEST2"].bit_size).to eql 16
        expect(@s.sorted_items[0].name).to eql "TEST1"
        expect(@s.sorted_items[1].name).to eql "TEST2"
        expect(@s.defined_length).to eql 3
      end

      it "appends an item after an array item " do
        @s.define_item("test1", 0, 8, :UINT, 16)
        expect(@s.items["TEST1"].bit_size).to eql 8
        expect(@s.sorted_items[0].name).to eql "TEST1"
        expect(@s.sorted_items[1]).to be_nil
        expect(@s.defined_length).to eql 2
        @s.append_item("test2", 16, :UINT)
        expect(@s.items["TEST2"].bit_size).to eql 16
        expect(@s.sorted_items[0].name).to eql "TEST1"
        expect(@s.sorted_items[1].name).to eql "TEST2"
        expect(@s.defined_length).to eql 4
      end

      it "complains if appending after a variably sized item" do
        @s.define_item("test1", 0, 0, :BLOCK)
        expect { @s.append_item("test2", 8, :UINT) }.to raise_error(ArgumentError, "Can't append an item after a variably sized item")
      end

      it "complains if appending after a variably sized array" do
        @s.define_item("test1", 0, 8, :UINT, -8)
        expect { @s.append_item("test2", 8, :UINT) }.to raise_error(ArgumentError, "Can't append an item after a variably sized item")
      end
    end

    describe "append" do
      before(:each) do
        @s = Structure.new
      end

      it "appends an item to the structure" do
        @s.define_item("test1", 0, 8, :UINT)
        item = StructureItem.new("test2", 0, 16, :UINT, :BIG_ENDIAN)
        @s.append(item)
        # Bit offset should change because we appended the item
        expect(@s.items["TEST2"].bit_offset).to eql 8
        expect(@s.sorted_items[0].name).to eql "TEST1"
        expect(@s.sorted_items[1].name).to eql "TEST2"
        expect(@s.defined_length).to eql 3
      end

      it "complains if appending after a variably sized item" do
        @s.define_item("test1", 0, 0, :BLOCK)
        item = StructureItem.new("test2", 0, 16, :UINT, :BIG_ENDIAN)
        expect { @s.append(item) }.to raise_error(ArgumentError, "Can't append an item after a variably sized item")
      end
    end

    describe "get_item" do
      before(:each) do
        @s = Structure.new
        @s.define_item("test1", 0, 8, :UINT)
      end

      it "returns a defined item" do
        expect(@s.get_item("test1")).not_to be_nil
      end

      it "complains if an item doesn't exist" do
        expect { @s.get_item("test2") }.to raise_error(ArgumentError, "Unknown item: test2")
      end
    end

    describe "set_item" do
      before(:each) do
        @s = Structure.new
        @s.define_item("test1", 0, 8, :UINT)
      end

      it "sets a defined item" do
        item = @s.get_item("test1")
        expect(item.bit_size).to eql 8
        item.bit_size = 16
        @s.set_item(item)
        expect(@s.get_item("test1").bit_size).to eql 16
      end

      it "complains if an item doesn't exist" do
        item = @s.get_item("test1")
        item.name = "TEST2"
        expect { @s.set_item(item) }.to raise_error(ArgumentError, "Unknown item: TEST2 - Ensure item name is uppercase")
      end
    end

    describe "read_item" do
      it "complains if no buffer given" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT)
        expect { s.read_item(s.get_item("test1"), :RAW, nil) }.to raise_error(RuntimeError, "No buffer given to read_item")
      end

      it "reads data from the buffer" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT)
        buffer = "\x01"
        expect(s.read_item(s.get_item("test1"), :RAW, buffer)).to eql 1
      end

      it "reads array data from the buffer" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT, 16)
        buffer = "\x01\x02"
        expect(s.read_item(s.get_item("test1"), :RAW, buffer)).to eql [1,2]
      end
    end

    describe "write_item" do
      it "complains if no buffer given" do
        expect { Structure.new.write_item(nil, nil, nil, nil) }.to raise_error(RuntimeError, "No buffer given to write_item")
      end

      it "writes data to the buffer" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT)
        buffer = "\x01"
        expect(s.read_item(s.get_item("test1"), :RAW, buffer)).to eql 1
        s.write_item(s.get_item("test1"), 2, :RAW, buffer)
        expect(s.read_item(s.get_item("test1"), :RAW, buffer)).to eql 2
      end

      it "writes array data to the buffer" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT, 16)
        buffer = "\x01\x02"
        expect(s.read_item(s.get_item("test1"), :RAW, buffer)).to eql [1,2]
        s.write_item(s.get_item("test1"), [3,4], :RAW, buffer)
        expect(s.read_item(s.get_item("test1"), :RAW, buffer)).to eql [3,4]
      end
    end

    describe "read" do
      it "complains if item doesn't exist" do
        expect { Structure.new.read("BLAH") }.to raise_error(ArgumentError, "Unknown item: BLAH")
      end

      it "reads data from the buffer" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT)
        buffer = "\x01"
        expect(s.read("test1", :RAW, buffer)).to eql 1
      end

      it "reads until null byte for STRING items" do
        s = Structure.new
        s.define_item("test1", 0, 80, :STRING)
        buffer = "\x4E\x4F\x4F\x50\x00\x4E\x4F\x4F\x50\x0A" # NOOP<NULL>NOOP\n
        expect(s.read("test1", :CONVERTED, buffer)).to eql "NOOP"
      end

      it "reads the entire buffer for BLOCK items" do
        s = Structure.new
        s.define_item("test1", 0, 80, :BLOCK)
        buffer = "\x4E\x4F\x4F\x50\x00\x4E\x4F\x4F\x50\x0A" # NOOP<NULL>NOOP\n
        expect(s.read("test1", :CONVERTED, buffer)).to eql "NOOP\x00NOOP\n"
      end

      it "reads array data from the buffer" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT, 16)
        buffer = "\x01\x02"
        expect(s.read("test1", :RAW, buffer)).to eql [1,2]
      end
    end

    describe "write" do
      it "complains if item doesn't exist" do
        expect { Structure.new.write("BLAH", 0) }.to raise_error(ArgumentError, "Unknown item: BLAH")
      end

      it "writes data to the buffer" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT)
        buffer = "\x01"
        expect(s.read("test1", :RAW, buffer)).to eql 1
        s.write("test1", 2, :RAW, buffer)
        expect(s.read("test1", :RAW, buffer)).to eql 2
      end

      it "writes array data to the buffer" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT, 16)
        buffer = "\x01\x02"
        expect(s.read("test1", :RAW, buffer)).to eql [1,2]
        s.write("test1", [3,4], :RAW, buffer)
        expect(s.read("test1", :RAW, buffer)).to eql [3,4]
      end
    end

    describe "read_all" do
      it "reads all defined items" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.append_item("test2", 16, :UINT)
        s.append_item("test3", 32, :UINT)

        buffer = "\x01\x02\x03\x04\x05\x06\x07\x08"
        vals = s.read_all(:RAW, buffer)
        expect(vals[0][0]).to eql "TEST1"
        expect(vals[1][0]).to eql "TEST2"
        expect(vals[2][0]).to eql "TEST3"
        expect(vals[0][1]).to eql [1,2]
        expect(vals[1][1]).to eql 0x0304
        expect(vals[2][1]).to eql 0x05060708
      end

      it "reads all defined items synchronized" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.append_item("test2", 16, :UINT)
        s.append_item("test3", 32, :UINT)

        buffer = "\x01\x02\x03\x04\x05\x06\x07\x08"
        vals = s.read_all(:RAW, buffer, false)
        expect(vals[0][0]).to eql "TEST1"
        expect(vals[1][0]).to eql "TEST2"
        expect(vals[2][0]).to eql "TEST3"
        expect(vals[0][1]).to eql [1,2]
        expect(vals[1][1]).to eql 0x0304
        expect(vals[2][1]).to eql 0x05060708
      end
    end

    describe "formatted" do
      it "prints out all the items and values" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.append_item("test2", 16, :UINT)
        s.write("test2", 3456)
        s.append_item("test3", 32, :BLOCK)
        s.write("test3", "\x07\x08\x09\x0A")
        expect(s.formatted).to include("TEST1: [1, 2]")
        expect(s.formatted).to include("TEST2: 3456")
        expect(s.formatted).to include("TEST3")
        expect(s.formatted).to include("00000000: 07 08 09 0A")
      end

      it "alters the indentation of the item" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.append_item("test2", 16, :UINT)
        s.write("test2", 3456)
        s.append_item("test3", 32, :BLOCK)
        s.write("test3", "\x07\x08\x09\x0A")
        expect(s.formatted(:CONVERTED, 4)).to include("    TEST1: [1, 2]")
        expect(s.formatted(:CONVERTED, 4)).to include("    TEST2: 3456")
        expect(s.formatted(:CONVERTED, 4)).to include("    TEST3")
        expect(s.formatted(:CONVERTED, 4)).to include("    00000000: 07 08 09 0A")
      end

      it "processes uses a different buffer" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.append_item("test2", 16, :UINT)
        s.write("test2", 3456)
        s.append_item("test3", 32, :BLOCK)
        s.write("test3", "\x07\x08\x09\x0A")
        buffer = "\x0A\x0B\x0C\x0D\xDE\xAD\xBE\xEF"
        expect(s.formatted(:CONVERTED, 0, buffer)).to include("TEST1: [10, 11]")
        expect(s.formatted(:CONVERTED, 0, buffer)).to include("TEST2: #{0x0C0D}")
        expect(s.formatted(:CONVERTED, 0, buffer)).to include("TEST3")
        expect(s.formatted(:CONVERTED, 0, buffer)).to include("00000000: DE AD BE EF")
      end

      it "ignores items" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.append_item("test2", 16, :UINT)
        s.write("test2", 3456)
        s.append_item("test3", 32, :BLOCK)
        s.write("test3", "\x07\x08\x09\x0A")
        expect(s.formatted(:CONVERTED, 0, s.buffer, %w(TEST1 TEST3))).to eq("TEST2: 3456\n")
        expect(s.formatted(:CONVERTED, 0, s.buffer, %w(TEST1 TEST2 TEST3))).to eq("")
      end
    end

    describe "buffer" do
      it "returns the buffer" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.append_item("test2", 16, :UINT)
        s.write("test2", 0x0304)
        s.append_item("test3", 32, :UINT)
        s.write("test3", 0x05060708)
        expect(s.buffer).to eql "\x01\x02\x03\x04\x05\x06\x07\x08"
        expect(s.buffer).to_not be s.buffer
        expect(s.buffer(false)).to be s.buffer(false)
      end
    end

    describe "buffer=" do
      it "complains if the given buffer is too small" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 16, :UINT)
        expect { s.buffer = "\x00" }.to raise_error(RuntimeError, "Buffer length less than defined length")
      end

      it "complains if the given buffer is too big" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 16, :UINT)
        expect { s.buffer = "\x00\x00\x00" }.to raise_error(RuntimeError, "Buffer length greater than defined length")
      end

      it "does not complain if the given buffer is too big and we're not fixed length" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT)
        s.append_item("test2", 0, :BLOCK)
        s.buffer = "\x01\x02\x03"
        expect(s.read("test1")).to eql 1
        expect(s.read("test2")).to eql "\x02\x03"
      end

      it "sets the buffer" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.append_item("test2", 16, :UINT)
        s.write("test2", 0x0304)
        s.append_item("test3", 32, :UINT)
        s.write("test3", 0x05060708)
        expect(s.read("test1")).to eql [1,2]
        expect(s.read("test2")).to eql 0x0304
        expect(s.read("test3")).to eql 0x05060708
        s.buffer = "\x00\x01\x02\x03\x04\x05\x06\x07"
        expect(s.read("test1")).to eql [0,1]
        expect(s.read("test2")).to eql 0x0203
        expect(s.read("test3")).to eql 0x04050607
      end
    end

    describe "clone" do
      it "duplicates the structure with a new buffer" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.append_item("test2", 16, :UINT)
        s.write("test2", 0x0304)
        s.append_item("test3", 32, :UINT)
        s.write("test3", 0x05060708)
        # Get a reference to the original buffer
        old_buffer = s.buffer(false)

        s2 = s.clone
        # Ensure we didn't modify the original buffer object
        expect(s.buffer(false)).to be old_buffer
        # Check that they are equal in value
        expect(s2.buffer(false)).to eql s.buffer(false)
        # But not the same object
        expect(s2.buffer(false)).to_not be s.buffer(false)
        expect(s2.read("test1")).to eql [1,2]
        expect(s2.read("test2")).to eql 0x0304
        expect(s2.read("test3")).to eql 0x05060708
        s2.write("test1", [0,0])
        expect(s2.read("test1")).to eql [0,0]
        # Ensure we didn't change the original
        expect(s.read("test1")).to eql [1,2]
      end
    end

    describe "enable_method_missing" do
      it "enables reading by name" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.enable_method_missing
        expect(s.test1).to eql [1,2]
      end

      it "enables writing by name" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.enable_method_missing
        expect(s.test1).to eql [1,2]
        s.test1 = [3,4]
        expect(s.test1).to eql [3,4]
      end

      it "raises an exception if there is no buffer" do
        s = Structure.new(:BIG_ENDIAN, nil)
        s.append_item("test1", 8, :UINT, 16)
        s.enable_method_missing
        expect { s.test1 }.to raise_error(/No buffer/)
      end

      it "complains if it can't find an item" do
        s = Structure.new(:BIG_ENDIAN)
        s.enable_method_missing
        expect { s.test1 }.to raise_error(ArgumentError, "Unknown item: test1")
      end
    end

  end # describe Structure

end
