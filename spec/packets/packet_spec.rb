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
require 'cosmos/packets/packet'
require 'cosmos/conversions/generic_conversion'

module Cosmos

  describe Packet do

    describe "buffer=" do
      it "should set the buffer" do
        p = Packet.new("tgt", "pkt")
        p.buffer = "\x00\x01\x02\x03"
        p.buffer.should eql "\x00\x01\x02\x03"
      end

      it "should complain if the given buffer is too big" do
        capture_io do |stdout|
          p = Packet.new("tgt", "pkt")
          p.append_item("test1", 16, :UINT)

          p.buffer = "\x00\x00\x00"
          stdout.string.should match(/TGT PKT received with actual packet length of 3 but defined length of 2/)
        end
      end

      it "should run processors if present" do
        p = Packet.new("tgt", "pkt")
        p.processors['processor'] = double("call", :call => true)
        p.buffer = "\x00\x01\x02\x03"
      end
    end

    describe "target_name=" do
      it "should set the target_name to an uppercase String" do
        p = Packet.new("tgt", "pkt")
        p.target_name.should eql "TGT"
      end

      it "should set target_name to nil" do
        p = Packet.new(nil,"pkt")
        p.target_name.should be_nil
      end

      it "should complain about non String target_names" do
        expect { Packet.new(5, "pkt") }.to raise_error(ArgumentError, "target_name must be a String but is a Fixnum")
      end
    end

    describe "packet_name=" do
      it "should set the packet_name to an uppercase String" do
        p = Packet.new("tgt", "pkt")
        p.packet_name.should eql "PKT"
      end

      it "should set packet_name to nil" do
        p = Packet.new("tgt",nil)
        p.packet_name.should be_nil
      end

      it "should complain about non String packet_names" do
        expect { Packet.new("tgt", 5) }.to raise_error(ArgumentError, "packet_name must be a String but is a Fixnum")
      end
    end

    describe "description=" do
      it "should set the description to a String" do
        p = Packet.new("tgt", "pkt", :BIG_ENDIAN, "This is a description")
        p.description.should eql "This is a description"
      end

      it "should set description to nil" do
        p = Packet.new("tgt","pkt")
        p.description = nil
        p.description.should be_nil
      end

      it "should complain about non String descriptions" do
        p = Packet.new("tgt","pkt")
        expect { p.description = 5 }.to raise_error(ArgumentError, "description must be a String but is a Fixnum")
      end
    end

    describe "received_time=" do
      it "should set the received_time to a Time" do
        p = Packet.new("tgt", "pkt")
        t = Time.now
        p.received_time = t
        p.received_time.should eql t
      end

      it "should set received_time to nil" do
        p = Packet.new("tgt","pkt")
        p.received_time = nil
        p.received_time.should be_nil
      end

      it "should complain about non Time received_times" do
        p = Packet.new("tgt","pkt")
        expect {p.received_time = "1pm" }.to raise_error(ArgumentError, "received_time must be a Time but is a String")
      end
    end

    describe "received_count=" do
      it "should set the received_count to a Fixnum" do
        p = Packet.new("tgt", "pkt")
        p.received_count = 10
        p.received_count.should eql 10
      end

      it "should complain about nil received_count" do
        p = Packet.new("tgt","pkt")
        expect {p.received_count = nil }.to raise_error(ArgumentError, "received_count must be a Fixnum but is a NilClass")
      end

      it "should complain about non Fixnum received_counts" do
        p = Packet.new("tgt","pkt")
        expect {p.received_count = "5" }.to raise_error(ArgumentError, "received_count must be a Fixnum but is a String")
      end
    end

    describe "hazardous_description=" do
      it "should set the hazardous_description to a String" do
        p = Packet.new("tgt", "pkt")
        p.hazardous_description = "This is a description"
        p.hazardous_description.should eql "This is a description"
      end

      it "should set hazardous_description to nil" do
        p = Packet.new("tgt","pkt")
        p.hazardous_description = nil
        p.hazardous_description.should be_nil
      end

      it "should complain about non String hazardous_descriptions" do
        p = Packet.new("tgt","pkt")
        expect {p.hazardous_description = 5 }.to raise_error(ArgumentError, "hazardous_description must be a String but is a Fixnum")
      end
    end

    describe "given_values=" do
      it "should set the given_values to a Hash" do
        p = Packet.new("tgt", "pkt")
        gv = {}
        p.given_values = gv
        p.given_values.should eql gv
      end

      it "should set given_values to nil" do
        p = Packet.new("tgt","pkt")
        p.given_values = nil
        p.given_values.should be_nil
      end

      it "should complain about non Hash given_valuess" do
        p = Packet.new("tgt","pkt")
        expect {p.given_values = [] }.to raise_error(ArgumentError, "given_values must be a Hash but is a Array")
      end
    end

    describe "meta" do
      it "should allow adding items to the meta hash" do
        p = Packet.new("tgt","pkt")
        p.meta['TYPE'] = 'float32'
        p.meta['TYPE'].should eql 'float32'
      end
    end

    describe "limits_change_callback=" do
      it "should set the limits_change_callback to something that responds to call" do
        p = Packet.new("tgt", "pkt")
        callback = Object.new
        allow(callback).to receive(:call)
        expect { p.limits_change_callback = callback }.to_not raise_error
      end

      it "should set limits_change_callback to nil" do
        p = Packet.new("tgt","pkt")
        expect { p.limits_change_callback = nil }.to_not raise_error
      end

      it "should complain about non #call limits_change_callbacks" do
        p = Packet.new("tgt","pkt")
        expect {p.limits_change_callback = "" }.to raise_error(ArgumentError, "limits_change_callback must respond to call")
      end
    end

    describe "define_item" do
      it "should take a format_string, read_conversion, write_conversion, and id_value" do
        p = Packet.new("tgt","pkt")
        rc = GenericConversion.new("value / 2")
        wc = GenericConversion.new("value * 2")
        p.define_item("item",0,32,:FLOAT,nil,:BIG_ENDIAN,:ERROR,"%5.1f",rc,wc,5)
        i = p.get_item("ITEM")
        i.format_string.should eql "%5.1f"
        i.read_conversion.to_s.should eql rc.to_s
        i.write_conversion.to_s.should eql wc.to_s
        i.id_value.should eql 5.0
      end

      it "should initialize format_string, read_conversion, write_conversion, and id_value to nil" do
        p = Packet.new("tgt","pkt")
        p.define_item("item",0,32,:FLOAT)
        i = p.get_item("ITEM")
        i.format_string.should be_nil
        i.read_conversion.should be_nil
        i.write_conversion.should be_nil
        i.id_value.should be_nil
      end
    end

    describe "append_item" do
      it "should take a format_string, read_conversion, write_conversion, and id_value" do
        p = Packet.new("tgt","pkt")
        rc = GenericConversion.new("value / 2")
        wc = GenericConversion.new("value * 2")
        p.append_item("item",32,:FLOAT,nil,:BIG_ENDIAN,:ERROR,"%5.1f",rc,wc,5)
        i = p.get_item("ITEM")
        i.format_string.should eql "%5.1f"
        i.read_conversion.to_s.should eql rc.to_s
        i.write_conversion.to_s.should eql wc.to_s
        i.id_value.should eql 5.0
      end

      it "should initialize format_string, read_conversion, write_conversion, and id_value to nil" do
        p = Packet.new("tgt","pkt")
        p.append_item("item",32,:FLOAT)
        i = p.get_item("ITEM")
        i.format_string.should be_nil
        i.read_conversion.should be_nil
        i.write_conversion.should be_nil
        i.id_value.should be_nil
      end
    end

    describe "get_item" do
      it "should complain if an item doesn't exist" do
        p = Packet.new("tgt","pkt")
        expect { p.get_item("test") }.to raise_error(RuntimeError, "Packet item 'TGT PKT TEST' does not exist")
      end
    end

    describe "read and read_item" do
      before (:each) do
        @p = Packet.new("tgt","pkt")
      end

      it "should complain about unknown value_type" do
        @p.append_item("item",32,:UINT)
        i = @p.get_item("ITEM")
        expect { @p.read("ITEM", :MINE, "\x01\x02\x03\x04") }.to raise_error(ArgumentError, "Unknown value type on read: MINE")
        expect { @p.read_item(i, :MINE, "\x01\x02\x03\x04") }.to raise_error(ArgumentError, "Unknown value type on read: MINE")
      end

      it "should read the RAW value" do
        @p.append_item("item",32,:UINT)
        i = @p.get_item("ITEM")
        @p.read("ITEM", :RAW, "\x01\x02\x03\x04").should eql 0x01020304
        @p.read_item(i, :RAW, "\x01\x02\x03\x04").should eql 0x01020304
      end

      it "should read the CONVERTED value" do
        @p.append_item("item",8,:UINT)
        i = @p.get_item("ITEM")
        @p.read("ITEM", :CONVERTED, "\x02").should eql 2
        @p.read_item(i, :CONVERTED, "\x02").should eql 2
        i.read_conversion = GenericConversion.new("value / 2")
        @p.read("ITEM", :CONVERTED, "\x02").should eql 1
        @p.read_item(i, :CONVERTED, "\x02").should eql 1
      end

      it "should read the CONVERTED value with states" do
        @p.append_item("item",8,:UINT)
        i = @p.get_item("ITEM")
        i.states = {"TRUE"=>1, "FALSE"=>2}
        @p.read("ITEM", :CONVERTED, "\x00").should eql 0
        @p.read_item(i, :CONVERTED, "\x00").should eql 0
        @p.read("ITEM", :CONVERTED, "\x01").should eql "TRUE"
        @p.read_item(i, :CONVERTED, "\x01").should eql "TRUE"
        i.read_conversion = GenericConversion.new("value / 2")
        @p.read("ITEM", :CONVERTED, "\x04").should eql "FALSE"
        @p.read_item(i, :CONVERTED, "\x04").should eql "FALSE"
      end

      it "should read the FORMATTED value" do
        @p.append_item("item",8,:UINT)
        i = @p.get_item("ITEM")
        @p.read("ITEM", :FORMATTED, "\x02").should eql "2"
        @p.read_item(i, :FORMATTED, "\x02").should eql "2"
        i.format_string = "0x%x"
        @p.read("ITEM", :FORMATTED, "\x02").should eql "0x2"
        @p.read_item(i, :FORMATTED, "\x02").should eql "0x2"
        i.states = {"TRUE"=>1, "FALSE"=>2}
        @p.read("ITEM", :FORMATTED, "\x01").should eql "TRUE"
        @p.read_item(i, :FORMATTED, "\x01").should eql "TRUE"
        @p.read("ITEM", :FORMATTED, "\x02").should eql "FALSE"
        @p.read_item(i, :FORMATTED, "\x02").should eql "FALSE"
        @p.read("ITEM", :FORMATTED, "\x04").should eql "0x4"
        @p.read_item(i, :FORMATTED, "\x04").should eql "0x4"
        i.read_conversion = GenericConversion.new("value / 2")
        @p.read("ITEM", :FORMATTED, "\x04").should eql "FALSE"
        @p.read_item(i, :FORMATTED, "\x04").should eql "FALSE"
      end

      it "should read the WITH_UNITS value" do
        @p.append_item("item",8,:UINT)
        i = @p.get_item("ITEM")
        i.units = "V"
        @p.read("ITEM", :WITH_UNITS, "\x02").should eql "2 V"
        @p.read_item(i, :WITH_UNITS, "\x02").should eql "2 V"
        i.format_string = "0x%x"
        @p.read("ITEM", :WITH_UNITS, "\x02").should eql "0x2 V"
        @p.read_item(i, :WITH_UNITS, "\x02").should eql "0x2 V"
        i.states = {"TRUE"=>1, "FALSE"=>2}
        @p.read("ITEM", :WITH_UNITS, "\x01").should eql "TRUE"
        @p.read_item(i, :WITH_UNITS, "\x01").should eql "TRUE"
        @p.read("ITEM", :WITH_UNITS, "\x02").should eql "FALSE"
        @p.read_item(i, :WITH_UNITS, "\x02").should eql "FALSE"
        @p.read("ITEM", :WITH_UNITS, "\x04").should eql "0x4 V"
        @p.read_item(i, :WITH_UNITS, "\x04").should eql "0x4 V"
        i.read_conversion = GenericConversion.new("value / 2")
        @p.read("ITEM", :WITH_UNITS, "\x04").should eql "FALSE"
        @p.read_item(i, :WITH_UNITS, "\x04").should eql "FALSE"
      end

      it "should read the WITH_UNITS array value" do
        @p.append_item("item",8,:UINT, 16)
        i = @p.get_item("ITEM")
        i.units = "V"
        @p.read("ITEM", :WITH_UNITS, "\x01\x02").should eql ["1 V", "2 V"]
        @p.read_item(i, :WITH_UNITS, "\x01\x02").should eql ["1 V", "2 V"]
        i.format_string = "0x%x"
        @p.read("ITEM", :WITH_UNITS, "\x01\x02").should eql ["0x1 V", "0x2 V"]
        @p.read_item(i, :WITH_UNITS, "\x01\x02").should eql ["0x1 V", "0x2 V"]
        i.states = {"TRUE"=>1, "FALSE"=>2}
        @p.read("ITEM", :WITH_UNITS, "\x01\x02").should eql ["TRUE", "FALSE"]
        @p.read_item(i, :WITH_UNITS, "\x01\x02").should eql ["TRUE", "FALSE"]
        @p.read("ITEM", :WITH_UNITS, "\x00\x01").should eql ["0x0 V", "TRUE"]
        @p.read_item(i, :WITH_UNITS, "\x00\x01").should eql ["0x0 V", "TRUE"]
        @p.read("ITEM", :WITH_UNITS, "\x02\x03").should eql ["FALSE", "0x3 V"]
        @p.read_item(i, :WITH_UNITS, "\x02\x03").should eql ["FALSE", "0x3 V"]
        @p.read("ITEM", :WITH_UNITS, "\x04").should eql ["0x4 V"]
        @p.read_item(i, :WITH_UNITS, "\x04").should eql ["0x4 V"]
        @p.read("ITEM", :WITH_UNITS, "\x04").should eql ["0x4 V"]
        @p.read_item(i, :WITH_UNITS, "\x04").should eql ["0x4 V"]
        i.read_conversion = GenericConversion.new("value / 2")
        @p.read("ITEM", :WITH_UNITS, "\x02\x04").should eql ["TRUE","FALSE"]
        @p.read_item(i, :WITH_UNITS, "\x02\x04").should eql ["TRUE","FALSE"]
        @p.read("ITEM", :WITH_UNITS, "\x08").should eql ["0x4 V"]
        @p.read_item(i, :WITH_UNITS, "\x08").should eql ["0x4 V"]
      end
    end

    describe "write and write_item" do
      before (:each) do
        @p = Packet.new("tgt","pkt")
        @buffer = "\x00\x00\x00\x00"
      end

      it "should complain about unknown value_type" do
        @p.append_item("item",32,:UINT)
        i = @p.get_item("ITEM")
        expect { @p.write("ITEM", 0, :MINE) }.to raise_error(ArgumentError, "Unknown value type on write: MINE")
        expect { @p.write_item(i, 0, :MINE) }.to raise_error(ArgumentError, "Unknown value type on write: MINE")
      end

      it "should write the RAW value" do
        @p.append_item("item",32,:UINT)
        i = @p.get_item("ITEM")
        @p.write("ITEM", 0x01020304, :RAW, @buffer)
        @buffer.should eql "\x01\x02\x03\x04"
        @p.write_item(i, 0x05060708, :RAW, @buffer)
        @buffer.should eql "\x05\x06\x07\x08"
      end

      it "should write the CONVERTED value" do
        @p.append_item("item",8,:UINT)
        i = @p.get_item("ITEM")
        @p.write("ITEM", 1, :CONVERTED, @buffer)
        @buffer.should eql "\x01\x00\x00\x00"
        @p.write_item(i, 2, :CONVERTED, @buffer)
        @buffer.should eql "\x02\x00\x00\x00"
        i.write_conversion = GenericConversion.new("value / 2")
        @p.write("ITEM", 1, :CONVERTED, @buffer)
        @buffer.should eql "\x00\x00\x00\x00"
        @p.write_item(i, 2, :CONVERTED, @buffer)
        @buffer.should eql "\x01\x00\x00\x00"
      end

      it "should write the CONVERTED value with states" do
        @p.append_item("item",8,:UINT)
        i = @p.get_item("ITEM")
        i.states = {"TRUE"=>1, "FALSE"=>2}
        @p.write("ITEM", 3, :CONVERTED, @buffer)
        @buffer.should eql "\x03\x00\x00\x00"
        @p.write_item(i, 4, :CONVERTED, @buffer)
        @buffer.should eql "\x04\x00\x00\x00"
        @p.write("ITEM", "TRUE", :CONVERTED, @buffer)
        @buffer.should eql "\x01\x00\x00\x00"
        @p.write_item(i, "FALSE", :CONVERTED, @buffer)
        @buffer.should eql "\x02\x00\x00\x00"
        i.write_conversion = GenericConversion.new("value / 2")
        @p.write("ITEM", 4, :CONVERTED, @buffer)
        @buffer.should eql "\x02\x00\x00\x00"
        @p.write("ITEM", "TRUE", :CONVERTED, @buffer)
        @buffer.should eql "\x00\x00\x00\x00"
        @p.write_item(i, "FALSE", :CONVERTED, @buffer)
        @buffer.should eql "\x01\x00\x00\x00"
      end

      it "should complain about the FORMATTED value_type" do
        @p.append_item("item",8,:UINT)
        i = @p.get_item("ITEM")
        expect { @p.write("ITEM", 3, :FORMATTED, @buffer) }.to raise_error(ArgumentError, "Invalid value type on write: FORMATTED")
        expect { @p.write_item(i, 3, :FORMATTED, @buffer) }.to raise_error(ArgumentError, "Invalid value type on write: FORMATTED")
      end

      it "should complain about the WITH_UNITS value_type" do
        @p.append_item("item",8,:UINT)
        i = @p.get_item("ITEM")
        expect { @p.write("ITEM", 3, :WITH_UNITS, @buffer) }.to raise_error(ArgumentError, "Invalid value type on write: WITH_UNITS")
        expect { @p.write_item(i, 3, :WITH_UNITS, @buffer) }.to raise_error(ArgumentError, "Invalid value type on write: WITH_UNITS")
      end
    end

    describe "read_all" do
      it "should default to read all CONVERTED items" do
        p = Packet.new("tgt","pkt")
        p.append_item("test1", 8, :UINT, 16)
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.states = {"TRUE"=>0x0304}
        p.append_item("test3", 32, :UINT)
        i = p.get_item("TEST3")
        i.read_conversion = GenericConversion.new("value / 2")

        buffer = "\x01\x02\x03\x04\x04\x06\x08\x0A"
        p.buffer = buffer
        vals = p.read_all
        vals[0][0].should eql "TEST1"
        vals[1][0].should eql "TEST2"
        vals[2][0].should eql "TEST3"
        vals[0][1].should eql [1,2]
        vals[1][1].should eql "TRUE"
        vals[2][1].should eql 0x02030405
      end
    end

    describe "read_all_with_limits_states" do
      it "should return an array of items with their limit states" do
        p = Packet.new("tgt","pkt")
        p.append_item("test1", 8, :UINT)
        i = p.get_item("TEST1")
        i.states = {"TRUE"=>1,"FALSE"=>0}
        i.state_colors = {"TRUE"=>:GREEN,"FALSE"=>:RED}
        p.write("TEST1",0)
        p.enable_limits("TEST1")
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.limits.values = {:DEFAULT=>[1,2,4,5]}
        p.write("TEST2",3)
        p.enable_limits("TEST2")
        p.update_limits_items_cache
        p.check_limits

        vals = p.read_all_with_limits_states
        vals[0][0].should eql "TEST1"
        vals[1][0].should eql "TEST2"
        vals[0][1].should eql "FALSE"
        vals[1][1].should eql 3
        vals[0][2].should eql :RED
        vals[1][2].should eql :GREEN
      end
    end

    describe "formatted" do
      it "should print out all the items and CONVERTED values" do
        p = Packet.new("tgt","pkt")
        p.append_item("test1", 8, :UINT, 16)
        p.write("test1", [1,2])
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.states = {"TRUE"=>0x0304}
        p.write("test2", 0x0304)
        p.append_item("test3", 32, :UINT)
        i = p.get_item("TEST3")
        i.read_conversion = GenericConversion.new("value / 2")
        p.write("test3", 0x0406080A)
        p.formatted.should include("TEST1: [1, 2]")
        p.formatted.should include("TEST2: TRUE")
        p.formatted.should include("TEST3: #{0x02030405}")
      end
    end

    describe "identify?" do
      it "should identify a buffer based on id_items" do
        p = Packet.new("tgt","pkt")
        p.append_item("item1",8,:UINT)
        p.append_item("item2",16,:UINT,nil,:BIG_ENDIAN,:ERROR,nil,nil,nil,5)
        p.append_item("item3",32,:UINT)
        p.identify?("\x00\x00\x05\x01\x02\x03\x04").should be_truthy
        p.identify?("\x00\x00\x04\x01\x02\x03\x04").should be_falsey
        p.identify?("\x00").should be_falsey
      end

      it "should identify if the buffer is too short" do
        p = Packet.new("tgt","pkt")
        p.append_item("item1",8,:UINT)
        p.append_item("item2",16,:UINT,nil,:BIG_ENDIAN,:ERROR,nil,nil,nil,5)
        p.append_item("item3",32,:UINT)
        p.identify?("\x00\x00\x05\x01\x02\x03").should be_truthy
      end

      it "should identify if the buffer is too long" do
        p = Packet.new("tgt","pkt")
        p.append_item("item1",8,:UINT)
        p.append_item("item2",16,:UINT,nil,:BIG_ENDIAN,:ERROR,nil,nil,nil,5)
        p.append_item("item3",32,:UINT)
        p.identify?("\x00\x00\x05\x01\x02\x03\x04\x05").should be_truthy
      end
    end

    describe "identified?" do
      it "should return true if the target name and packet name are set" do
        Packet.new('TGT',nil).identified?.should be_falsey
        Packet.new(nil,'PKT').identified?.should be_falsey
        Packet.new('TGT','PKT').identified?.should be_truthy
      end
    end

    describe "restore_defaults" do
      it "should write all the items back to their default values" do
        p = Packet.new("tgt","pkt")
        p.append_item("test1", 8, :UINT, 16)
        i = p.get_item("TEST1")
        i.default = [3,4]
        p.write("test1", [1,2])
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.default = 0x0102
        i.states = {"TRUE"=>0x0304}
        p.write("test2", 0x0304)
        p.append_item("test3", 32, :UINT)
        i = p.get_item("TEST3")
        i.default = 0x02030405
        i.write_conversion = GenericConversion.new("value * 2")
        p.write("test3", 0x01020304)
        p.buffer.should eql "\x01\x02\x03\x04\x02\x04\x06\x08"
        p.restore_defaults
        p.buffer.should eql "\x03\x04\x01\x02\x04\x06\x08\x0A"
      end
    end

    describe "enable_limits" do
      it "should enable limits on each packet item" do
        p = Packet.new("tgt","pkt")
        p.append_item("test1", 8, :UINT, 16)
        p.append_item("test2", 16, :UINT)
        p.get_item("TEST1").limits.enabled.should be_falsey
        p.get_item("TEST2").limits.enabled.should be_falsey
        p.enable_limits("TEST1")
        p.get_item("TEST1").limits.enabled.should be_truthy
        p.get_item("TEST2").limits.enabled.should be_falsey
        p.enable_limits("TEST2")
        p.get_item("TEST1").limits.enabled.should be_truthy
        p.get_item("TEST2").limits.enabled.should be_truthy
      end
    end

    describe "disable_limits" do
      it "should disable limits on each packet item" do
        p = Packet.new("tgt","pkt")
        p.append_item("test1", 8, :UINT)
        p.append_item("test2", 16, :UINT)
        p.enable_limits("TEST1")
        p.enable_limits("TEST2")
        p.get_item("TEST1").limits.enabled.should be_truthy
        p.get_item("TEST2").limits.enabled.should be_truthy
        p.disable_limits("TEST1")
        p.get_item("TEST1").limits.enabled.should be_falsey
        p.get_item("TEST2").limits.enabled.should be_truthy
        p.disable_limits("TEST2")
        p.get_item("TEST1").limits.enabled.should be_falsey
        p.get_item("TEST2").limits.enabled.should be_falsey
      end

      it "should call the limits_change_callback for all non STALE items" do
        p = Packet.new("tgt","pkt")
        p.append_item("test1", 8, :UINT)
        p.get_item("TEST1").limits.values = {:DEFAULT=>[1,2,4,5]}
        p.append_item("test2", 16, :UINT)
        p.get_item("TEST2").limits.values = {:DEFAULT=>[1,2,4,5]}
        p.write("TEST1",3)
        p.write("TEST2",3)
        p.enable_limits("TEST1")
        p.enable_limits("TEST2")
        p.update_limits_items_cache

        callback = double("callback", :call => true)
        p.limits_change_callback = callback
        expect(callback).to receive(:call).with(p, p.get_item("TEST1"),:GREEN,nil,false)
        expect(callback).to receive(:call).with(p, p.get_item("TEST2"),:GREEN,nil,false)
        p.check_limits
        p.disable_limits("TEST1")
        p.disable_limits("TEST2")
        p.get_item("TEST1").limits.enabled.should be_falsey
        p.get_item("TEST2").limits.enabled.should be_falsey
      end
    end

    describe "limits_items" do
      it "should return all items with limits" do
        p = Packet.new("tgt","pkt")
        p.append_item("test1", 8, :UINT)
        p.enable_limits("TEST1")
        p.append_item("test2", 16, :UINT)
        p.enable_limits("TEST2")
        p.limits_items.should eql []

        test1 = p.get_item("TEST1")
        test1.limits.values = {:DEFAULT=>[1,2,4,5]}
        p.update_limits_items_cache
        p.limits_items.should eql [test1]
        test2 = p.get_item("TEST2")
        test2.limits.values = {:DEFAULT=>[1,2,4,5]}
        p.update_limits_items_cache
        p.limits_items.should eql [test1, test2]
      end
    end

    describe "out_of_limits" do
      it "should return an array indicating all items out of limits" do
        p = Packet.new("tgt","pkt")
        p.append_item("test1", 8, :UINT)
        p.get_item("TEST1").limits.values = {:DEFAULT=>[1,2,4,5]}
        p.enable_limits("TEST1")
        p.write("TEST1",3)
        p.append_item("test2", 16, :UINT)
        p.get_item("TEST2").limits.values = {:DEFAULT=>[1,2,4,5]}
        p.write("TEST2",3)
        p.enable_limits("TEST2")
        p.update_limits_items_cache
        p.check_limits
        p.out_of_limits.should eql []

        p.write("TEST1",6)
        p.check_limits
        p.out_of_limits.should eql [["TGT","PKT","TEST1",:RED_HIGH]]
        p.write("TEST2",2)
        p.check_limits
        p.out_of_limits.should eql [["TGT","PKT","TEST1",:RED_HIGH],["TGT","PKT","TEST2",:YELLOW_LOW]]
      end
    end

    describe "set_all_limits_states" do
      it "should set all limits states to the given state" do
        p = Packet.new("tgt","pkt")
        p.append_item("test1", 8, :UINT)
        p.get_item("TEST1").limits.values = {:DEFAULT=>[1,2,4,5]}
        p.enable_limits("TEST1")
        p.append_item("test2", 16, :UINT)
        p.get_item("TEST2").limits.values = {:DEFAULT=>[1,2,4,5]}
        p.enable_limits("TEST2")
        p.update_limits_items_cache
        p.out_of_limits.should eql []

        PacketItemLimits::OUT_OF_LIMITS_STATES.each do |state|
          p.set_all_limits_states(state)
          p.out_of_limits.should eql [["TGT","PKT","TEST1",state],["TGT","PKT","TEST2",state]]
        end
      end
    end

    describe "check_limits" do
      before(:each) do
        @p = Packet.new("tgt","pkt")
        @p.append_item("test1", 8, :UINT)
        @p.append_item("test2", 16, :UINT)
        @p.append_item("test3", 32, :FLOAT)
      end

      it "should set clear the stale flag" do
        @p.stale.should be_truthy
        @p.check_limits
        @p.stale.should be_falsey
      end

      it "should not call the limits_change_callback if limits are disabled" do
        @p.get_item("TEST1").limits.enabled.should be_falsey
        @p.get_item("TEST2").limits.enabled.should be_falsey
        callback = double("callback")
        allow(callback).to receive(:call)
        @p.limits_change_callback = callback
        @p.check_limits
        expect(callback).to_not receive(:call)
      end

      context "with states" do
        it "should call the limits_change_callback" do
          test1 = @p.get_item("TEST1")
          test1.limits.enabled.should be_falsey
          test1.states = {"TRUE"=>1,"FALSE"=>0}
          test1.state_colors = {"TRUE"=>:GREEN,"FALSE"=>:RED}
          @p.write("TEST1", 0)
          @p.enable_limits("TEST1")
          test2 = @p.get_item("TEST2")
          test2.limits.enabled.should be_falsey
          test2.states = {"TRUE"=>1,"FALSE"=>0}
          test2.state_colors = {"TRUE"=>:RED,"FALSE"=>:GREEN}
          @p.write("TEST2", 0)
          @p.enable_limits("TEST2")
          @p.update_limits_items_cache

          # Mock the callback so we can see if it is called properly
          callback = double("callback", :call => true)
          @p.limits_change_callback = callback

          # Check the limits for the first time, TEST1 should be :RED and TEST2
          # should be :GREEN
          expect(callback).to receive(:call).once.with(@p, test1,nil,"FALSE",true)
          @p.check_limits

          # Change the TEST2 state to :RED, we were previously :GREEN
          @p.write("TEST2", 1)
          expect(callback).to receive(:call).once.with(@p, test2,:GREEN,"TRUE",true)
          @p.check_limits

          # Change the TEST2 value to something that doesn't map to a state
          @p.write("TEST2", 2)
          expect(callback).to receive(:call).once.with(@p, test2,:RED,2,false)
          @p.check_limits
        end
      end

      context "with values" do
        before(:each) do
          @test1 = @p.get_item("TEST1")
          @test1.limits.enabled.should be_falsey
          @test1.limits.values = {:DEFAULT=>[1,2,4,5]} # red yellow
          @p.enable_limits("TEST1")

          @test2 = @p.get_item("TEST2")
          @test2.limits.enabled.should be_falsey
          @test2.limits.values = {:DEFAULT=>[1,2,6,7,3,5]} # red yellow and blue
          @p.enable_limits("TEST2")

          @test3 = @p.get_item("TEST3")
          @test3.limits.enabled.should be_falsey
          @test3.limits.values = {:DEFAULT=>[1,1.5,2.5,3]} # red yellow
          @p.enable_limits("TEST3")
          @p.update_limits_items_cache

          # Mock the callback so we can see if it is called properly
          @callback = double("callback", :call => true)
          @p.limits_change_callback = @callback
        end

        it "should detect initial low states" do
          @p.write("TEST1", 0)
          @p.write("TEST2", 3)
          @p.write("TEST3", 1.25)
          @p.check_limits
          @p.get_item("TEST1").limits.state.should eql :RED_LOW
          @p.get_item("TEST2").limits.state.should eql :GREEN_LOW
          @p.get_item("TEST3").limits.state.should eql :YELLOW_LOW
        end

        it "should detect initial high states" do
          @p.write("TEST1", 6)
          @p.write("TEST2", 5)
          @p.write("TEST3", 2.75)
          @p.check_limits
          @p.get_item("TEST1").limits.state.should eql :RED_HIGH
          @p.get_item("TEST2").limits.state.should eql :GREEN_HIGH
          @p.get_item("TEST3").limits.state.should eql :YELLOW_HIGH
        end

        it "should detect initial middle states" do
          @p.write("TEST1", 3)
          @p.write("TEST2", 4)
          @p.write("TEST3", 2.0)
          @p.check_limits
          @p.get_item("TEST1").limits.state.should eql :GREEN
          @p.get_item("TEST2").limits.state.should eql :BLUE
          @p.get_item("TEST3").limits.state.should eql :GREEN
        end

        it "should clear persistence when initial state is nil" do
          @p.get_item("TEST1").limits.persistence_count = 2
          @p.get_item("TEST2").limits.persistence_count = 3
          @p.get_item("TEST3").limits.persistence_count = 4
          @p.check_limits
          @p.get_item("TEST1").limits.persistence_count.should eql 0
          @p.get_item("TEST2").limits.persistence_count.should eql 0
          @p.get_item("TEST3").limits.persistence_count.should eql 0
        end

        context "when calling the limits_change_callback" do
          it "should initially call only for out of limits" do
            @p.write("TEST1", 0)
            @p.write("TEST2", 4)
            @p.write("TEST3", 1.25)

            # Check the limits for the first time, TEST1 should be :RED_LOW, TEST2
            # should be :BLUE, TEST3 should be YELLOW_LOW
            expect(@callback).to receive(:call).with(@p, @test1,nil,0,true)
            expect(@callback).to receive(:call).with(@p, @test3,nil,1.25,true)
            @p.check_limits
          end

          it "should call when limits change states" do
            @p.write("TEST1", 0)
            @p.write("TEST2", 4)
            @p.write("TEST3", 1.25)
            @p.check_limits

            # Make TEST2 be GREEN_LOW, we were previously :BLUE
            @p.write("TEST2", 3)
            expect(@callback).to receive(:call).once.with(@p, @test2,:BLUE,3,true)
            @p.check_limits
          end

          it "should call only when persistence is achieved" do
            @p.get_item("TEST1").limits.persistence_setting = 2
            @p.get_item("TEST2").limits.persistence_setting = 3
            @p.get_item("TEST3").limits.persistence_setting = 4

            @p.write("TEST1", 3)
            @p.write("TEST2", 4)
            @p.write("TEST3", 2.0)
            expect(@callback).to receive(:call).with(@p, @test1,nil,3,true)
            expect(@callback).to receive(:call).with(@p, @test2,nil,4,true)
            expect(@callback).to receive(:call).with(@p, @test3,nil,2.0,true)
            @p.check_limits
            @test1.limits.state.should eql :GREEN
            @test2.limits.state.should eql :BLUE
            @test3.limits.state.should eql :GREEN

            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            @p.check_limits
            @test1.limits.state.should eql :GREEN
            @test2.limits.state.should eql :BLUE
            @test3.limits.state.should eql :GREEN

            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to receive(:call).with(@p, @test1,:GREEN,0,true)
            @p.check_limits
            @test1.limits.state.should eql :RED_LOW
            @test2.limits.state.should eql :BLUE
            @test3.limits.state.should eql :GREEN

            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to receive(:call).with(@p, @test2,:BLUE,8,true)
            @p.check_limits
            @test1.limits.state.should eql :RED_LOW
            @test2.limits.state.should eql :RED_HIGH
            @test3.limits.state.should eql :GREEN

            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to receive(:call).with(@p, @test3,:GREEN,1.25,true)
            @p.check_limits
            @test1.limits.state.should eql :RED_LOW
            @test2.limits.state.should eql :RED_HIGH
            @test3.limits.state.should eql :YELLOW_LOW
          end

          it "should not call when state changes before persistence is achieved" do
            @p.get_item("TEST1").limits.persistence_setting = 3
            @p.get_item("TEST2").limits.persistence_setting = 3
            @p.get_item("TEST3").limits.persistence_setting = 3

            @p.write("TEST1", 3)
            @p.write("TEST2", 4)
            @p.write("TEST3", 2.0)
            expect(@callback).to receive(:call).with(@p, @test1,nil,3,true)
            expect(@callback).to receive(:call).with(@p, @test2,nil,4,true)
            expect(@callback).to receive(:call).with(@p, @test3,nil,2.0,true)
            @p.check_limits
            @test1.limits.state.should eql :GREEN
            @test2.limits.state.should eql :BLUE
            @test3.limits.state.should eql :GREEN

            # Write bad values twice
            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to_not receive(:call)
            @p.check_limits
            @test1.limits.state.should eql :GREEN
            @test2.limits.state.should eql :BLUE
            @test3.limits.state.should eql :GREEN

            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to_not receive(:call)
            @p.check_limits
            @test1.limits.state.should eql :GREEN
            @test2.limits.state.should eql :BLUE
            @test3.limits.state.should eql :GREEN

            # Set the values back to good
            @p.write("TEST1", 3)
            @p.write("TEST2", 4)
            @p.write("TEST3", 2.0)
            @p.check_limits
            @test1.limits.state.should eql :GREEN
            @test2.limits.state.should eql :BLUE
            @test3.limits.state.should eql :GREEN

            # Write bad values twice
            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to_not receive(:call)
            @p.check_limits
            @test1.limits.state.should eql :GREEN
            @test2.limits.state.should eql :BLUE
            @test3.limits.state.should eql :GREEN

            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to_not receive(:call)
            @p.check_limits
            @test1.limits.state.should eql :GREEN
            @test2.limits.state.should eql :BLUE
            @test3.limits.state.should eql :GREEN

            # Set the values back to good
            @p.write("TEST1", 3)
            @p.write("TEST2", 4)
            @p.write("TEST3", 2.0)
            @p.check_limits
            @test1.limits.state.should eql :GREEN
            @test2.limits.state.should eql :BLUE
            @test3.limits.state.should eql :GREEN
          end
        end
      end
    end

    describe "stale" do
      it "should set all limits states to stale" do
        p = Packet.new("tgt","pkt")
        p.append_item("test1", 8, :UINT)
        p.get_item("TEST1").limits.values = {:DEFAULT=>[1,2,4,5]}
        p.enable_limits("TEST1")
        p.append_item("test2", 16, :UINT)
        p.get_item("TEST2").limits.values = {:DEFAULT=>[1,2,4,5]}
        p.enable_limits("TEST2")
        p.update_limits_items_cache
        p.out_of_limits.should eql []

        p.stale.should be_truthy
        p.get_item("TEST1").limits.state.should eql :STALE
        p.get_item("TEST2").limits.state.should eql :STALE
        # Update the limits
        p.check_limits
        p.stale.should be_falsey
        p.get_item("TEST1").limits.state.should_not eql :STALE
        p.get_item("TEST2").limits.state.should_not eql :STALE
        # set them all back to stale
        p.set_stale
        p.get_item("TEST1").limits.state.should eql :STALE
        p.get_item("TEST2").limits.state.should eql :STALE
      end
    end

    describe "clone" do
      it "should duplicate the packet" do
        p = Packet.new("tgt","pkt")
        p2 = p.clone
        p2.target_name.should eql "TGT"
        p2.packet_name.should eql "PKT"
      end
    end

    describe "reset" do
      it "should reset the packet" do
        p = Packet.new("tgt","pkt")
        p.processors['processor'] = double("reset", :reset => true)
        p.received_time = Time.now
        p.received_count = 50
        p.reset
        p.received_time.should eql nil
        p.received_count.should eql 0
      end
    end

  end # describe Packet

end
