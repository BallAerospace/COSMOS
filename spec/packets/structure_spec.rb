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
        Structure.new(:BIG_ENDIAN).default_endianness.should eql :BIG_ENDIAN
      end

      it "creates LITTLE_ENDIAN structures" do
        Structure.new(:LITTLE_ENDIAN).default_endianness.should eql :LITTLE_ENDIAN
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
        s.items["test1"].should be_nil
        s.sorted_items[0].should be_nil
        s.define_item("test1", 0, 8, :UINT)
        s.items["TEST1"].should_not be_nil
        s.sorted_items[0].should_not be_nil
        s.sorted_items[0].name.should eql "TEST1"
        s.rename_item("TEST1", "TEST2")
        s.items["TEST1"].should be_nil
        s.items["TEST2"].should_not be_nil
        s.sorted_items[0].name.should eql "TEST2"
      end
    end

    describe "define_item" do
      before(:each) do
        @s = Structure.new
      end

      it "adds item to items and sorted_items" do
        @s.items["test1"].should be_nil
        @s.sorted_items[0].should be_nil
        @s.define_item("test1", 0, 8, :UINT)
        @s.items["TEST1"].should_not be_nil
        @s.sorted_items[0].should_not be_nil
        @s.sorted_items[0].name.should eql "TEST1"
        @s.defined_length.should eql 1
        @s.fixed_size.should be true
      end

      it "adds items with negative bit offsets" do
        @s.define_item("test1", -8, 8, :UINT)
        @s.defined_length.should eql 1
        @s.define_item("test2", 0, 4, :UINT)
        @s.defined_length.should eql 2
        @s.define_item("test3", 4, 4, :UINT)
        @s.defined_length.should eql 2
        @s.define_item("test4", 16, 0, :BLOCK)
        @s.defined_length.should eql 3
        @s.define_item("test5", -16, 8, :UINT)
        @s.defined_length.should eql 4
        @s.fixed_size.should be false
      end

      it "adds item with negative offset" do
        expect { @s.define_item("test11", -64, 8, :UINT, 128) }.to raise_error(ArgumentError, "TEST11: Can't define an item with array_size 128 greater than negative bit_offset -64")
        expect { @s.define_item("test10", -64, 8, :UINT, -64) }.to raise_error(ArgumentError, "TEST10: Can't define an item with negative array_size -64 and negative bit_offset -64")
        expect { @s.define_item("test9", -64, -64, :BLOCK) }.to raise_error(ArgumentError, "TEST9: Can't define an item with negative bit_size -64 and negative bit_offset -64")
        expect { @s.define_item("test8", 0, -32, :BLOCK, 64) }.to raise_error(ArgumentError, "TEST8: bit_size cannot be negative or zero for array items")
        expect { @s.define_item("test7", 0, 0, :BLOCK, 64) }.to raise_error(ArgumentError, "TEST7: bit_size cannot be negative or zero for array items")
        expect { @s.define_item("test6", -24, 32, :UINT) }.to raise_error(ArgumentError, "TEST6: Can't define an item with bit_size 32 greater than negative bit_offset -24")
        @s.define_item("test5", -16, 8, :UINT)
        @s.defined_length.should eql 2
        @s.define_item("test1", -8, 8, :UINT)
        @s.defined_length.should eql 2
        @s.define_item("test2", 0, 4, :UINT)
        @s.defined_length.should eql 3
        @s.define_item("test3", 4, 4, :UINT)
        @s.defined_length.should eql 3
        @s.define_item("test4", 8, 0, :BLOCK)
        @s.defined_length.should eql 3
        @s.fixed_size.should be false
      end

      it "recalulates sorted_items when adding multiple items" do
        @s.define_item("test1", 8, 32, :UINT)
        @s.sorted_items[0].name.should eql "TEST1"
        @s.defined_length.should eql 5
        @s.define_item("test2", 0, 8, :UINT)
        @s.sorted_items[0].name.should eql "TEST2"
        @s.defined_length.should eql 5
        @s.define_item("test3", 16, 8, :UINT)
        @s.sorted_items[-1].name.should eql "TEST3"
        @s.defined_length.should eql 5
        @s.fixed_size.should be true
      end

      it "overwrites existing items" do
        @s.define_item("test1", 0, 8, :UINT)
        @s.sorted_items[0].name.should eql "TEST1"
        @s.items["TEST1"].bit_size.should eql 8
        @s.items["TEST1"].data_type.should eql :UINT
        @s.defined_length.should eql 1
        @s.define_item("test1", 0, 16, :INT)
        @s.sorted_items[0].name.should eql "TEST1"
        @s.items["TEST1"].bit_size.should eql 16
        @s.items["TEST1"].data_type.should eql :INT
        @s.defined_length.should eql 2
        @s.fixed_size.should be true
      end
    end # describe "define_item"

    describe "define" do
      before(:each) do
        @s = Structure.new
      end

      it "adds the item to items and sorted_items" do
        @s.items["test1"].should be_nil
        @s.sorted_items[0].should be_nil
        si = StructureItem.new("test1",0,8,:UINT,:BIG_ENDIAN)
        @s.define(si)
        @s.items["TEST1"].should_not be_nil
        @s.sorted_items[0].should_not be_nil
        @s.sorted_items[0].name.should eql "TEST1"
        @s.defined_length.should eql 1
        @s.fixed_size.should be true
      end

      it "allows items to be defined on top of each other" do
        @s.items["test1"].should be_nil
        @s.sorted_items[0].should be_nil
        si = StructureItem.new("test1",0,8,:UINT,:BIG_ENDIAN)
        @s.define(si)
        @s.sorted_items[0].name.should eql "TEST1"
        @s.items["TEST1"].bit_offset.should eql 0
        @s.items["TEST1"].bit_size.should eql 8
        @s.items["TEST1"].data_type.should eql :UINT
        @s.defined_length.should eql 1
        si = StructureItem.new("test2",0,16,:INT,:BIG_ENDIAN)
        @s.define(si)
        @s.sorted_items[1].name.should eql "TEST2"
        @s.items["TEST2"].bit_offset.should eql 0
        @s.items["TEST2"].bit_size.should eql 16
        @s.items["TEST2"].data_type.should eql :INT
        @s.defined_length.should eql 2
        buffer = "\x01\x02"
        @s.read_item(@s.get_item("test1"), :RAW, buffer).should eql 1
        @s.read_item(@s.get_item("test2"), :RAW, buffer).should eql 258
      end

      it "overwrites existing items" do
        si = StructureItem.new("test1",0,8,:UINT,:BIG_ENDIAN)
        @s.define(si)
        @s.sorted_items[0].name.should eql "TEST1"
        @s.items["TEST1"].bit_size.should eql 8
        @s.items["TEST1"].data_type.should eql :UINT
        @s.defined_length.should eql 1
        si = StructureItem.new("test1",0,16,:INT,:BIG_ENDIAN)
        @s.define(si)
        @s.sorted_items[0].name.should eql "TEST1"
        @s.items["TEST1"].bit_size.should eql 16
        @s.items["TEST1"].data_type.should eql :INT
        @s.defined_length.should eql 2
        @s.fixed_size.should be true
      end
    end

    describe "append_item" do
      before(:each) do
        @s = Structure.new
      end

      it "appends an item to items" do
        @s.define_item("test1", 0, 8, :UINT)
        @s.append_item("test2", 16, :UINT)
        @s.items["TEST2"].bit_size.should eql 16
        @s.sorted_items[0].name.should eql "TEST1"
        @s.sorted_items[1].name.should eql "TEST2"
        @s.defined_length.should eql 3
      end

      it "appends an item after an array item " do
        @s.define_item("test1", 0, 8, :UINT, 16)
        @s.items["TEST1"].bit_size.should eql 8
        @s.sorted_items[0].name.should eql "TEST1"
        @s.sorted_items[1].should be_nil
        @s.defined_length.should eql 2
        @s.append_item("test2", 16, :UINT)
        @s.items["TEST2"].bit_size.should eql 16
        @s.sorted_items[0].name.should eql "TEST1"
        @s.sorted_items[1].name.should eql "TEST2"
        @s.defined_length.should eql 4
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
        @s.items["TEST2"].bit_offset.should eql 8
        @s.sorted_items[0].name.should eql "TEST1"
        @s.sorted_items[1].name.should eql "TEST2"
        @s.defined_length.should eql 3
      end

      it "complains if appending after a variably sized item" do
        @s.define_item("test1", 0, 0, :BLOCK)
        expect { @s.append(@item) }.to raise_error(ArgumentError, "Can't append an item after a variably sized item")
      end
    end

    describe "get_item" do
      before(:each) do
        @s = Structure.new
        @s.define_item("test1", 0, 8, :UINT)
      end

      it "returns a defined item" do
        @s.get_item("test1").should_not be_nil
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
        item.bit_size.should eql 8
        item.bit_size = 16
        @s.set_item(item)
        @s.get_item("test1").bit_size.should eql 16
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
        s.read_item(s.get_item("test1"), :RAW, buffer).should eql 1
      end

      it "reads array data from the buffer" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT, 16)
        buffer = "\x01\x02"
        s.read_item(s.get_item("test1"), :RAW, buffer).should eql [1,2]
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
        s.read_item(s.get_item("test1"), :RAW, buffer).should eql 1
        s.write_item(s.get_item("test1"), 2, :RAW, buffer)
        s.read_item(s.get_item("test1"), :RAW, buffer).should eql 2
      end

      it "writes array data to the buffer" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT, 16)
        buffer = "\x01\x02"
        s.read_item(s.get_item("test1"), :RAW, buffer).should eql [1,2]
        s.write_item(s.get_item("test1"), [3,4], :RAW, buffer)
        s.read_item(s.get_item("test1"), :RAW, buffer).should eql [3,4]
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
        s.read("test1", :RAW, buffer).should eql 1
      end

      it "reads array data from the buffer" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT, 16)
        buffer = "\x01\x02"
        s.read("test1", :RAW, buffer).should eql [1,2]
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
        s.read("test1", :RAW, buffer).should eql 1
        s.write("test1", 2, :RAW, buffer)
        s.read("test1", :RAW, buffer).should eql 2
      end

      it "writes array data to the buffer" do
        s = Structure.new
        s.define_item("test1", 0, 8, :UINT, 16)
        buffer = "\x01\x02"
        s.read("test1", :RAW, buffer).should eql [1,2]
        s.write("test1", [3,4], :RAW, buffer)
        s.read("test1", :RAW, buffer).should eql [3,4]
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
        vals[0][0].should eql "TEST1"
        vals[1][0].should eql "TEST2"
        vals[2][0].should eql "TEST3"
        vals[0][1].should eql [1,2]
        vals[1][1].should eql 0x0304
        vals[2][1].should eql 0x05060708
      end

      it "reads all defined items synchronized" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.append_item("test2", 16, :UINT)
        s.append_item("test3", 32, :UINT)

        buffer = "\x01\x02\x03\x04\x05\x06\x07\x08"
        vals = s.read_all(:RAW, buffer, false)
        vals[0][0].should eql "TEST1"
        vals[1][0].should eql "TEST2"
        vals[2][0].should eql "TEST3"
        vals[0][1].should eql [1,2]
        vals[1][1].should eql 0x0304
        vals[2][1].should eql 0x05060708
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
        s.formatted.should include("TEST1: [1, 2]")
        s.formatted.should include("TEST2: 3456")
        s.formatted.should include("TEST3")
        s.formatted.should include("00000000: 07 08 09 0A")
      end

      it "alters the indentation of the item" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.append_item("test2", 16, :UINT)
        s.write("test2", 3456)
        s.append_item("test3", 32, :BLOCK)
        s.write("test3", "\x07\x08\x09\x0A")
        s.formatted(:CONVERTED, 4).should include("    TEST1: [1, 2]")
        s.formatted(:CONVERTED, 4).should include("    TEST2: 3456")
        s.formatted(:CONVERTED, 4).should include("    TEST3")
        s.formatted(:CONVERTED, 4).should include("    00000000: 07 08 09 0A")
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
        s.buffer.should eql "\x01\x02\x03\x04\x05\x06\x07\x08"
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
        s.read("test1").should eql 1
        s.read("test2").should eql "\x02\x03"
      end

      it "sets the buffer" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.append_item("test2", 16, :UINT)
        s.write("test2", 0x0304)
        s.append_item("test3", 32, :UINT)
        s.write("test3", 0x05060708)
        s.read("test1").should eql [1,2]
        s.read("test2").should eql 0x0304
        s.read("test3").should eql 0x05060708
        s.buffer = "\x00\x01\x02\x03\x04\x05\x06\x07"
        s.read("test1").should eql [0,1]
        s.read("test2").should eql 0x0203
        s.read("test3").should eql 0x04050607
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
        s2.read("test1").should eql [1,2]
        s2.read("test2").should eql 0x0304
        s2.read("test3").should eql 0x05060708
        s2.write("test1", [0,0])
        s2.read("test1").should eql [0,0]
        # Ensure we didn't change the original
        s.read("test1").should eql [1,2]
      end
    end

    describe "enable_method_missing" do
      it "enables reading by name" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.enable_method_missing
        s.test1.should eql [1,2]
      end

      it "enables writing by name" do
        s = Structure.new(:BIG_ENDIAN)
        s.append_item("test1", 8, :UINT, 16)
        s.write("test1", [1,2])
        s.enable_method_missing
        s.test1.should eql [1,2]
        s.test1 = [3,4]
        s.test1.should eql [3,4]
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
