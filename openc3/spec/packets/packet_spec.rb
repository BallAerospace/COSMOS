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
require 'openc3/packets/packet'
require 'openc3/conversions/generic_conversion'

module OpenC3
  describe Packet do
    describe "buffer=" do
      it "sets the buffer" do
        p = Packet.new("tgt", "pkt")
        p.buffer = "\x00\x01\x02\x03"
        expect(p.buffer).to eql "\x00\x01\x02\x03"
      end

      it "complains if the given buffer is too big" do
        capture_io do |stdout|
          p = Packet.new("tgt", "pkt")
          p.append_item("test1", 16, :UINT)

          p.buffer = "\x00\x00\x00"
          expect(stdout.string).to match(/TGT PKT received with actual packet length of 3 but defined length of 2/)
        end
      end

      it "runs processors if present" do
        p = Packet.new("tgt", "pkt")
        p.processors['processor'] = double("call", :call => true)
        p.buffer = "\x00\x01\x02\x03"
      end
    end

    describe "target_name=", no_ext: true do
      it "sets the target_name to an uppercase String" do
        p = Packet.new("tgt", "pkt")
        expect(p.target_name).to eql "TGT"
      end

      it "sets target_name to nil" do
        p = Packet.new(nil, "pkt")
        expect(p.target_name).to be_nil
      end

      it "complains about non String target_names" do
        expect { Packet.new(5.1, "pkt") }.to raise_error(ArgumentError, "target_name must be a String but is a Float")
      end
    end

    describe "packet_name=", no_ext: true do
      it "sets the packet_name to an uppercase String" do
        p = Packet.new("tgt", "pkt")
        expect(p.packet_name).to eql "PKT"
      end

      it "sets packet_name to nil" do
        p = Packet.new("tgt", nil)
        expect(p.packet_name).to be_nil
      end

      it "complains about non String packet_names" do
        expect { Packet.new("tgt", 5.1) }.to raise_error(ArgumentError, "packet_name must be a String but is a Float")
      end
    end

    describe "description=", no_ext: true do
      it "sets the description to a String" do
        p = Packet.new("tgt", "pkt", :BIG_ENDIAN, "This is a description")
        expect(p.description).to eql "This is a description"
      end

      it "sets description to nil" do
        p = Packet.new("tgt", "pkt")
        p.description = nil
        expect(p.description).to be_nil
      end

      it "complains about non String descriptions" do
        p = Packet.new("tgt", "pkt")
        expect { p.description = 5.1 }.to raise_error(ArgumentError, "description must be a String but is a Float")
      end
    end

    describe "set_received_time_fast" do
      it "sets the received_time to a Time" do
        p = Packet.new("tgt", "pkt")
        t = Time.now
        p.set_received_time_fast(t)
        expect(p.received_time).to eql t
      end

      it "sets received_time to nil" do
        p = Packet.new("tgt", "pkt")
        p.received_time = nil
        expect(p.received_time).to be_nil
      end

      it "complains about non Time received_times" do
        p = Packet.new("tgt", "pkt")
        expect { p.received_time = "1pm" }.to raise_error(ArgumentError, "received_time must be a Time but is a String")
      end
    end

    describe "received_time=", no_ext: true do
      it "sets the received_time to a Time" do
        p = Packet.new("tgt", "pkt")
        t = Time.now
        p.received_time = t
        expect(p.received_time).to eql t
      end

      it "sets received_time to nil" do
        p = Packet.new("tgt", "pkt")
        p.received_time = nil
        expect(p.received_time).to be_nil
      end

      it "complains about non Time received_times" do
        p = Packet.new("tgt", "pkt")
        expect { p.received_time = "1pm" }.to raise_error(ArgumentError, "received_time must be a Time but is a String")
      end
    end

    describe "received_count=", no_ext: true do
      it "sets the received_count to a Fixnum" do
        p = Packet.new("tgt", "pkt")
        p.received_count = 10
        expect(p.received_count).to eql 10
      end

      it "complains about nil received_count" do
        p = Packet.new("tgt", "pkt")
        expect { p.received_count = nil }.to raise_error(ArgumentError, "received_count must be an Integer but is a NilClass")
      end

      it "complains about non Fixnum received_counts" do
        p = Packet.new("tgt", "pkt")
        expect { p.received_count = "5" }.to raise_error(ArgumentError, "received_count must be an Integer but is a String")
      end
    end

    describe "hazardous_description=" do
      it "sets the hazardous_description to a String" do
        p = Packet.new("tgt", "pkt")
        p.hazardous_description = "This is a description"
        expect(p.hazardous_description).to eql "This is a description"
      end

      it "sets hazardous_description to nil" do
        p = Packet.new("tgt", "pkt")
        p.hazardous_description = nil
        expect(p.hazardous_description).to be_nil
      end

      it "complains about non String hazardous_descriptions" do
        p = Packet.new("tgt", "pkt")
        expect { p.hazardous_description = 5.1 }.to raise_error(ArgumentError, "hazardous_description must be a String but is a Float")
      end
    end

    describe "given_values=" do
      it "sets the given_values to a Hash" do
        p = Packet.new("tgt", "pkt")
        gv = {}
        p.given_values = gv
        expect(p.given_values).to eql gv
      end

      it "sets given_values to nil" do
        p = Packet.new("tgt", "pkt")
        p.given_values = nil
        expect(p.given_values).to be_nil
      end

      it "complains about non Hash given_valuess" do
        p = Packet.new("tgt", "pkt")
        expect { p.given_values = [] }.to raise_error(ArgumentError, "given_values must be a Hash but is a Array")
      end
    end

    describe "meta" do
      it "allows adding items to the meta hash" do
        p = Packet.new("tgt", "pkt")
        p.meta['TYPE'] = 'float32'
        expect(p.meta['TYPE']).to eql 'float32'
      end
    end

    describe "limits_change_callback=" do
      it "sets the limits_change_callback to something that responds to call" do
        p = Packet.new("tgt", "pkt")
        callback = Object.new
        allow(callback).to receive(:call)
        expect { p.limits_change_callback = callback }.to_not raise_error
      end

      it "sets limits_change_callback to nil" do
        p = Packet.new("tgt", "pkt")
        expect { p.limits_change_callback = nil }.to_not raise_error
      end

      it "complains about non #call limits_change_callbacks" do
        p = Packet.new("tgt", "pkt")
        expect { p.limits_change_callback = "" }.to raise_error(ArgumentError, "limits_change_callback must respond to call")
      end
    end

    describe "define_item" do
      it "takes a format_string, read_conversion, write_conversion, and id_value" do
        p = Packet.new("tgt", "pkt")
        rc = GenericConversion.new("value / 2")
        wc = GenericConversion.new("value * 2")
        p.define_item("item", 0, 32, :FLOAT, nil, :BIG_ENDIAN, :ERROR, "%5.1f", rc, wc, 5)
        i = p.get_item("ITEM")
        expect(i.format_string).to eql "%5.1f"
        expect(i.read_conversion.to_s).to eql rc.to_s
        expect(i.write_conversion.to_s).to eql wc.to_s
        expect(i.id_value).to eql 5.0
      end

      it "initializes format_string, read_conversion, write_conversion, and id_value to nil" do
        p = Packet.new("tgt", "pkt")
        p.define_item("item", 0, 32, :FLOAT)
        i = p.get_item("ITEM")
        expect(i.format_string).to be_nil
        expect(i.read_conversion).to be_nil
        expect(i.write_conversion).to be_nil
        expect(i.id_value).to be_nil
      end
    end

    describe "define" do
      it "adds a PacketItem to a packet" do
        p = Packet.new("tgt", "pkt")
        rc = GenericConversion.new("value / 2")
        wc = GenericConversion.new("value * 2")
        pi = PacketItem.new("item1", 0, 32, :FLOAT, :BIG_ENDIAN, nil, :ERROR)
        pi.format_string = "%5.1f"
        pi.read_conversion = rc
        pi.write_conversion = wc
        pi.state_colors = { 'RED' => 0 }
        pi.id_value = 5
        p.define(pi)
        i = p.get_item("ITEM1")
        expect(i.format_string).to eql "%5.1f"
        expect(i.read_conversion.to_s).to eql rc.to_s
        expect(i.write_conversion.to_s).to eql wc.to_s
        expect(i.id_value).to eql 5.0
        expect(p.id_items.length).to eq 1
        expect(p.id_items[0].name).to eq 'ITEM1'
        expect(p.limits_items[0].name).to eq 'ITEM1'
        expect(p.defined_length).to eql 4
      end

      it "allows PacketItems to be defined on top of each other" do
        p = Packet.new("tgt", "pkt")
        pi = PacketItem.new("item1", 0, 8, :UINT, :BIG_ENDIAN)
        p.define(pi)
        pi = PacketItem.new("item2", 0, 32, :UINT, :BIG_ENDIAN)
        p.define(pi)
        expect(p.defined_length).to eql 4
        buffer = "\x01\x02\x03\x04"
        expect(p.read_item(p.get_item("item1"), :RAW, buffer)).to eql 1
        expect(p.read_item(p.get_item("item2"), :RAW, buffer)).to eql 0x1020304
      end
    end

    describe "append_item" do
      it "takes a format_string, read_conversion, write_conversion, and id_value" do
        p = Packet.new("tgt", "pkt")
        rc = GenericConversion.new("value / 2")
        wc = GenericConversion.new("value * 2")
        p.append_item("item", 32, :FLOAT, nil, :BIG_ENDIAN, :ERROR, "%5.1f", rc, wc, 5)
        i = p.get_item("ITEM")
        expect(i.format_string).to eql "%5.1f"
        expect(i.read_conversion.to_s).to eql rc.to_s
        expect(i.write_conversion.to_s).to eql wc.to_s
        expect(i.id_value).to eql 5.0
      end

      it "initializes format_string, read_conversion, write_conversion, and id_value to nil" do
        p = Packet.new("tgt", "pkt")
        p.append_item("item", 32, :FLOAT)
        i = p.get_item("ITEM")
        expect(i.format_string).to be_nil
        expect(i.read_conversion).to be_nil
        expect(i.write_conversion).to be_nil
        expect(i.id_value).to be_nil
      end
    end

    describe "append" do
      it "adds a PacketItem to the end of a packet" do
        p = Packet.new("tgt", "pkt")
        rc = GenericConversion.new("value / 2")
        wc = GenericConversion.new("value * 2")
        pi = PacketItem.new("item1", 0, 32, :FLOAT, :BIG_ENDIAN, nil, :ERROR)
        pi.format_string = "%5.1f"
        pi.read_conversion = rc
        pi.write_conversion = wc
        pi.limits.values = { :DEFAULT => [0, 1, 2, 3] }
        pi.id_value = 5
        p.append(pi)
        i = p.get_item("ITEM1")
        expect(i.format_string).to eql "%5.1f"
        expect(i.read_conversion.to_s).to eql rc.to_s
        expect(i.write_conversion.to_s).to eql wc.to_s
        expect(i.id_value).to eql 5.0
        expect(p.id_items.length).to eq 1
        expect(p.id_items[0].name).to eq 'ITEM1'
        expect(p.limits_items[0].name).to eq 'ITEM1'
        expect(p.defined_length).to eql 4

        pi = PacketItem.new("item2", 0, 32, :FLOAT, :BIG_ENDIAN, nil, :ERROR)
        p.append(pi)
        i = p.get_item("ITEM2")
        expect(i.bit_offset).to be 32 # offset updated inside the PacketItem
        expect(i.format_string).to be nil
        expect(i.read_conversion).to be nil
        expect(i.write_conversion).to be nil
        expect(i.id_value).to be nil
        expect(p.id_items.length).to eq 1
        expect(p.defined_length).to eql 8
      end
    end

    describe "get_item" do
      it "complains if an item doesn't exist" do
        p = Packet.new("tgt", "pkt")
        expect { p.get_item("test") }.to raise_error(RuntimeError, "Packet item 'TGT PKT TEST' does not exist")
      end
    end

    describe "read and read_item" do
      before (:each) do
        @p = Packet.new("tgt", "pkt")
      end

      it "complains about unknown value_type" do
        @p.append_item("item", 32, :UINT)
        i = @p.get_item("ITEM")
        expect { @p.read("ITEM", :MINE, "\x01\x02\x03\x04") }.to raise_error(ArgumentError, "Unknown value type on read: MINE")
        expect { @p.read_item(i, :MINE, "\x01\x02\x03\x04") }.to raise_error(ArgumentError, "Unknown value type on read: MINE")
      end

      it "reads the RAW value" do
        @p.append_item("item", 32, :UINT)
        i = @p.get_item("ITEM")
        expect(@p.read("ITEM", :RAW, "\x01\x02\x03\x04")).to eql 0x01020304
        expect(@p.read_item(i, :RAW, "\x01\x02\x03\x04")).to eql 0x01020304
      end

      it "reads the CONVERTED value" do
        @p.append_item("item", 8, :UINT)
        i = @p.get_item("ITEM")
        expect(@p.read("ITEM", :CONVERTED, "\x02")).to eql 2
        expect(@p.read_item(i, :CONVERTED, "\x02")).to eql 2
        i.read_conversion = GenericConversion.new("value / 2")
        expect(@p.read("ITEM", :CONVERTED, "\x02")).to eql 1
        expect(@p.read_item(i, :CONVERTED, "\x02")).to eql 1
      end

      it "clears the read conversion cache on clone" do
        @p.append_item("item", 8, :UINT)
        i = @p.get_item("ITEM")
        i.read_conversion = GenericConversion.new("value / 2")
        @p.buffer = "\x02"
        expect(@p.read("ITEM", :CONVERTED)).to eql 1
        expect(@p.read_item(i, :CONVERTED)).to eql 1
        cloned = @p.clone
        cloned.buffer = "\x04"
        expect(@p.read("ITEM", :CONVERTED)).to eql 1
        expect(@p.read_item(i, :CONVERTED)).to eql 1
        expect(cloned.read("ITEM", :CONVERTED)).to eql 2
        expect(cloned.read_item(i, :CONVERTED)).to eql 2
      end

      it "prevents the read conversion cache from being corrupted" do
        @p.append_item("item", 8, :UINT)
        i = @p.get_item("ITEM")
        i.read_conversion = GenericConversion.new("'A String'")
        i.units = "with units"
        value = @p.read_item(i, :CONVERTED)
        expect(value).to eql 'A String'
        value << 'That got modified'
        value = @p.read_item(i, :WITH_UNITS)
        expect(value).to eql 'A String with units'
        value << 'That got modified'
        expect(@p.read_item(i, :WITH_UNITS)).to eql 'A String with units'
        value = @p.read_item(i, :WITH_UNITS)
        value << ' more things'
        expect(@p.read_item(i, :WITH_UNITS)).to eql 'A String with units'

        @p.buffer = "\x00"
        i.read_conversion = GenericConversion.new("['A', 'B', 'C']")
        value = @p.read_item(i, :CONVERTED)
        expect(value).to eql ['A', 'B', 'C']
        value << 'D'
        value = @p.read_item(i, :WITH_UNITS)
        expect(value).to eql ['A with units', 'B with units', 'C with units']
        value << 'D'
        expect(@p.read_item(i, :WITH_UNITS)).to eql ['A with units', 'B with units', 'C with units']
        value = @p.read_item(i, :WITH_UNITS)
        value << 'D'
        expect(@p.read_item(i, :WITH_UNITS)).to eql ['A with units', 'B with units', 'C with units']
      end

      it "reads the CONVERTED value with states" do
        @p.append_item("item", 8, :UINT)
        i = @p.get_item("ITEM")
        i.states = { "TRUE" => 1, "FALSE" => 2 }
        expect(@p.read("ITEM", :CONVERTED, "\x00")).to eql 0
        expect(@p.read_item(i, :CONVERTED, "\x00")).to eql 0
        expect(@p.read("ITEM", :CONVERTED, "\x01")).to eql "TRUE"
        expect(@p.read_item(i, :CONVERTED, "\x01")).to eql "TRUE"
        i.read_conversion = GenericConversion.new("value / 2")
        expect(@p.read("ITEM", :CONVERTED, "\x04")).to eql "FALSE"
        expect(@p.read_item(i, :CONVERTED, "\x04")).to eql "FALSE"
      end

      it "reads the FORMATTED value" do
        @p.append_item("item", 8, :UINT)
        i = @p.get_item("ITEM")
        expect(@p.read("ITEM", :FORMATTED, "\x02")).to eql "2"
        expect(@p.read_item(i, :FORMATTED, "\x02")).to eql "2"
        i.format_string = "0x%x"
        expect(@p.read("ITEM", :FORMATTED, "\x02")).to eql "0x2"
        expect(@p.read_item(i, :FORMATTED, "\x02")).to eql "0x2"
        i.states = { "TRUE" => 1, "FALSE" => 2 }
        expect(@p.read("ITEM", :FORMATTED, "\x01")).to eql "TRUE"
        expect(@p.read_item(i, :FORMATTED, "\x01")).to eql "TRUE"
        expect(@p.read("ITEM", :FORMATTED, "\x02")).to eql "FALSE"
        expect(@p.read_item(i, :FORMATTED, "\x02")).to eql "FALSE"
        expect(@p.read("ITEM", :FORMATTED, "\x04")).to eql "0x4"
        expect(@p.read_item(i, :FORMATTED, "\x04")).to eql "0x4"
        i.read_conversion = GenericConversion.new("value / 2")
        expect(@p.read("ITEM", :FORMATTED, "\x04")).to eql "FALSE"
        expect(@p.read_item(i, :FORMATTED, "\x04")).to eql "FALSE"
      end

      it "reads the WITH_UNITS value" do
        @p.append_item("item", 8, :UINT)
        i = @p.get_item("ITEM")
        i.units = "V"
        expect(@p.read("ITEM", :WITH_UNITS, "\x02")).to eql "2 V"
        expect(@p.read_item(i, :WITH_UNITS, "\x02")).to eql "2 V"
        i.format_string = "0x%x"
        expect(@p.read("ITEM", :WITH_UNITS, "\x02")).to eql "0x2 V"
        expect(@p.read_item(i, :WITH_UNITS, "\x02")).to eql "0x2 V"
        i.states = { "TRUE" => 1, "FALSE" => 2 }
        expect(@p.read("ITEM", :WITH_UNITS, "\x01")).to eql "TRUE"
        expect(@p.read_item(i, :WITH_UNITS, "\x01")).to eql "TRUE"
        expect(@p.read("ITEM", :WITH_UNITS, "\x02")).to eql "FALSE"
        expect(@p.read_item(i, :WITH_UNITS, "\x02")).to eql "FALSE"
        expect(@p.read("ITEM", :WITH_UNITS, "\x04")).to eql "0x4 V"
        expect(@p.read_item(i, :WITH_UNITS, "\x04")).to eql "0x4 V"
        i.read_conversion = GenericConversion.new("value / 2")
        expect(@p.read("ITEM", :WITH_UNITS, "\x04")).to eql "FALSE"
        expect(@p.read_item(i, :WITH_UNITS, "\x04")).to eql "FALSE"
      end

      it "reads the WITH_UNITS array value" do
        @p.append_item("item", 8, :UINT, 16)
        i = @p.get_item("ITEM")
        i.units = "V"
        expect(@p.read("ITEM", :WITH_UNITS, "\x01\x02")).to eql ["1 V", "2 V"]
        expect(@p.read_item(i, :WITH_UNITS, "\x01\x02")).to eql ["1 V", "2 V"]
        i.format_string = "0x%x"
        expect(@p.read("ITEM", :WITH_UNITS, "\x01\x02")).to eql ["0x1 V", "0x2 V"]
        expect(@p.read_item(i, :WITH_UNITS, "\x01\x02")).to eql ["0x1 V", "0x2 V"]
        i.states = { "TRUE" => 1, "FALSE" => 2 }
        expect(@p.read("ITEM", :WITH_UNITS, "\x01\x02")).to eql ["TRUE", "FALSE"]
        expect(@p.read_item(i, :WITH_UNITS, "\x01\x02")).to eql ["TRUE", "FALSE"]
        expect(@p.read("ITEM", :WITH_UNITS, "\x00\x01")).to eql ["0x0 V", "TRUE"]
        expect(@p.read_item(i, :WITH_UNITS, "\x00\x01")).to eql ["0x0 V", "TRUE"]
        expect(@p.read("ITEM", :WITH_UNITS, "\x02\x03")).to eql ["FALSE", "0x3 V"]
        expect(@p.read_item(i, :WITH_UNITS, "\x02\x03")).to eql ["FALSE", "0x3 V"]
        expect(@p.read("ITEM", :WITH_UNITS, "\x04")).to eql ["0x4 V"]
        expect(@p.read_item(i, :WITH_UNITS, "\x04")).to eql ["0x4 V"]
        expect(@p.read("ITEM", :WITH_UNITS, "\x04")).to eql ["0x4 V"]
        expect(@p.read_item(i, :WITH_UNITS, "\x04")).to eql ["0x4 V"]
        i.read_conversion = GenericConversion.new("value / 2")
        expect(@p.read("ITEM", :WITH_UNITS, "\x02\x04")).to eql ["TRUE", "FALSE"]
        expect(@p.read_item(i, :WITH_UNITS, "\x02\x04")).to eql ["TRUE", "FALSE"]
        expect(@p.read("ITEM", :WITH_UNITS, "\x08")).to eql ["0x4 V"]
        expect(@p.read_item(i, :WITH_UNITS, "\x08")).to eql ["0x4 V"]
        @p.define_item("item2", 0, 0, :DERIVED)
        i = @p.get_item("ITEM2")
        i.units = "V"
        i.read_conversion = GenericConversion.new("[1,2,3,4,5]")
        expect(@p.read("ITEM2", :FORMATTED, "")).to eql ["1", "2", "3", "4", "5"]
        expect(@p.read("ITEM2", :WITH_UNITS, "")).to eql ["1 V", "2 V", "3 V", "4 V", "5 V"]
      end

      context "with :DERIVED items" do
        it "returns nil if no read_conversion defined" do
          @p.append_item("item", 0, :DERIVED)
          i = @p.get_item("ITEM")
          i.format_string = "0x%x"
          i.states = { "TRUE" => 1, "FALSE" => 0 }
          i.units = "V"
          expect(@p.read("ITEM", :RAW, "")).to be_nil
          expect(@p.read_item(i, :RAW, "")).to be_nil
        end

        it "reads the RAW value" do
          @p.append_item("item", 0, :DERIVED)
          i = @p.get_item("ITEM")
          i.format_string = "0x%x"
          i.states = { "TRUE" => 1, "FALSE" => 0 }
          i.units = "V"
          i.read_conversion = GenericConversion.new("0")
          expect(@p.read("ITEM", :RAW, "")).to eql 0
          expect(@p.read_item(i, :RAW, "")).to eql 0
          i.read_conversion = GenericConversion.new("1")
          expect(@p.read("ITEM", :RAW, "")).to eql 1
          expect(@p.read_item(i, :RAW, "")).to eql 1
        end

        it "reads the CONVERTED value" do
          @p.append_item("item", 0, :DERIVED)
          i = @p.get_item("ITEM")
          i.format_string = "0x%x"
          i.states = { "TRUE" => 1, "FALSE" => 0 }
          i.units = "V"
          i.read_conversion = GenericConversion.new("0")
          expect(@p.read("ITEM", :CONVERTED, "")).to eql "FALSE"
          expect(@p.read_item(i, :CONVERTED, "")).to eql "FALSE"
          i.read_conversion = GenericConversion.new("1")
          expect(@p.read("ITEM", :CONVERTED, "")).to eql "TRUE"
          expect(@p.read_item(i, :CONVERTED, "")).to eql "TRUE"
        end

        it "reads the FORMATTED value" do
          @p.append_item("item", 0, :DERIVED)
          i = @p.get_item("ITEM")
          i.format_string = "0x%x"
          i.states = { "TRUE" => 1, "FALSE" => 0 }
          i.units = "V"
          i.read_conversion = GenericConversion.new("3")
          expect(@p.read("ITEM", :FORMATTED, "")).to eql "0x3"
          expect(@p.read_item(i, :FORMATTED, "")).to eql "0x3"
        end

        it "reads the WITH_UNITS value" do
          @p.append_item("item", 0, :DERIVED)
          i = @p.get_item("ITEM")
          i.format_string = "0x%x"
          i.states = { "TRUE" => 1, "FALSE" => 0 }
          i.units = "V"
          i.read_conversion = GenericConversion.new("3")
          expect(@p.read("ITEM", :WITH_UNITS, "")).to eql "0x3 V"
          expect(@p.read_item(i, :WITH_UNITS, "")).to eql "0x3 V"
        end
      end
    end

    describe "write and write_item" do
      before (:each) do
        @p = Packet.new("tgt", "pkt")
        @buffer = "\x00\x00\x00\x00"
      end

      it "complains about unknown value_type" do
        @p.append_item("item", 32, :UINT)
        i = @p.get_item("ITEM")
        expect { @p.write("ITEM", 0, :MINE) }.to raise_error(ArgumentError, "Unknown value type on write: MINE")
        expect { @p.write_item(i, 0, :MINE) }.to raise_error(ArgumentError, "Unknown value type on write: MINE")
      end

      it "writes the RAW value" do
        @p.append_item("item", 32, :UINT)
        i = @p.get_item("ITEM")
        @p.write("ITEM", 0x01020304, :RAW, @buffer)
        expect(@buffer).to eql "\x01\x02\x03\x04"
        @p.write_item(i, 0x05060708, :RAW, @buffer)
        expect(@buffer).to eql "\x05\x06\x07\x08"
      end

      it "clears the read cache" do
        @p.append_item("item", 8, :UINT)
        i = @p.get_item("ITEM")
        @p.buffer = "\x04"
        cache = @p.instance_variable_get(:@read_conversion_cache)
        i.read_conversion = GenericConversion.new("value / 2")
        expect(cache).to be nil
        expect(@p.read("ITEM")).to be 2
        cache = @p.instance_variable_get(:@read_conversion_cache)
        expect(cache[i]).to be 2
        @p.write("ITEM", 0x08, :RAW)
        expect(@p.buffer).to eql "\x08"
        expect(cache[i]).to be nil
        expect(@p.read("ITEM")).to be 4
        expect(cache[i]).to be 4
      end

      it "writes the CONVERTED value" do
        @p.append_item("item", 8, :UINT)
        i = @p.get_item("ITEM")
        @p.write("ITEM", 1, :CONVERTED, @buffer)
        expect(@buffer).to eql "\x01\x00\x00\x00"
        @p.write_item(i, 2, :CONVERTED, @buffer)
        expect(@buffer).to eql "\x02\x00\x00\x00"
        i.write_conversion = GenericConversion.new("value / 2")
        @p.write("ITEM", 1, :CONVERTED, @buffer)
        expect(@buffer).to eql "\x00\x00\x00\x00"
        @p.write_item(i, 2, :CONVERTED, @buffer)
        expect(@buffer).to eql "\x01\x00\x00\x00"
      end

      it "writes the CONVERTED value with states" do
        @p.append_item("item", 8, :UINT)
        i = @p.get_item("ITEM")
        i.states = { "TRUE" => 1, "FALSE" => 2 }
        @p.write("ITEM", 3, :CONVERTED, @buffer)
        expect(@buffer).to eql "\x03\x00\x00\x00"
        @p.write_item(i, 4, :CONVERTED, @buffer)
        expect(@buffer).to eql "\x04\x00\x00\x00"
        @p.write("ITEM", "TRUE", :CONVERTED, @buffer)
        expect(@buffer).to eql "\x01\x00\x00\x00"
        @p.write_item(i, "FALSE", :CONVERTED, @buffer)
        expect(@buffer).to eql "\x02\x00\x00\x00"
        expect { @p.write_item(i, "BLAH", :CONVERTED, @buffer) }.to raise_error(RuntimeError, "Unknown state BLAH for ITEM")
        i.write_conversion = GenericConversion.new("value / 2")
        @p.write("ITEM", 4, :CONVERTED, @buffer)
        expect(@buffer).to eql "\x02\x00\x00\x00"
        @p.write("ITEM", "TRUE", :CONVERTED, @buffer)
        expect(@buffer).to eql "\x00\x00\x00\x00"
        @p.write_item(i, "FALSE", :CONVERTED, @buffer)
        expect(@buffer).to eql "\x01\x00\x00\x00"
      end

      it "complains about the FORMATTED value_type" do
        @p.append_item("item", 8, :UINT)
        i = @p.get_item("ITEM")
        expect { @p.write("ITEM", 3, :FORMATTED, @buffer) }.to raise_error(ArgumentError, "Invalid value type on write: FORMATTED")
        expect { @p.write_item(i, 3, :FORMATTED, @buffer) }.to raise_error(ArgumentError, "Invalid value type on write: FORMATTED")
      end

      it "complains about the WITH_UNITS value_type" do
        @p.append_item("item", 8, :UINT)
        i = @p.get_item("ITEM")
        expect { @p.write("ITEM", 3, :WITH_UNITS, @buffer) }.to raise_error(ArgumentError, "Invalid value type on write: WITH_UNITS")
        expect { @p.write_item(i, 3, :WITH_UNITS, @buffer) }.to raise_error(ArgumentError, "Invalid value type on write: WITH_UNITS")
      end
    end

    describe "read_all" do
      it "defaults to read all CONVERTED items" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT, 16)
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.states = { "TRUE" => 0x0304 }
        p.append_item("test3", 32, :UINT)
        i = p.get_item("TEST3")
        i.read_conversion = GenericConversion.new("value / 2")

        buffer = "\x01\x02\x03\x04\x04\x06\x08\x0A"
        p.buffer = buffer
        vals = p.read_all
        expect(vals[0][0]).to eql "TEST1"
        expect(vals[1][0]).to eql "TEST2"
        expect(vals[2][0]).to eql "TEST3"
        expect(vals[0][1]).to eql [1, 2]
        expect(vals[1][1]).to eql "TRUE"
        expect(vals[2][1]).to eql 0x02030405
      end
    end

    describe "read_all_with_limits_states" do
      it "returns an array of items with their limit states" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT)
        i = p.get_item("TEST1")
        i.states = { "TRUE" => 1, "FALSE" => 0 }
        i.state_colors = { "TRUE" => :GREEN, "FALSE" => :RED }
        p.update_limits_items_cache(i)
        p.write("TEST1", 0)
        p.enable_limits("TEST1")
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.limits.values = { :DEFAULT => [1, 2, 4, 5] }
        p.write("TEST2", 3)
        p.enable_limits("TEST2")
        p.update_limits_items_cache(i)
        p.check_limits

        vals = p.read_all_with_limits_states
        expect(vals[0][0]).to eql "TEST1"
        expect(vals[1][0]).to eql "TEST2"
        expect(vals[0][1]).to eql "FALSE"
        expect(vals[1][1]).to eql 3
        expect(vals[0][2]).to eql :RED
        expect(vals[1][2]).to eql :GREEN
      end
    end

    describe "formatted" do
      it "prints out all the items" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT, 16)
        p.write("test1", [1, 2])
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.states = { "TRUE" => 0x0304 }
        p.write("test2", 0x0304)
        p.append_item("test3", 32, :UINT)
        i = p.get_item("TEST3")
        i.read_conversion = GenericConversion.new("value / 2")
        p.write("test3", 0x0406080A)
        p.append_item("test4", 32, :BLOCK)
        i = p.get_item("TEST4")
        i.read_conversion = GenericConversion.new("value.to_s")
        p.write("test4", "Test")
        expect(p.formatted).to include("TEST1: [1, 2]")
        expect(p.formatted).to include("TEST2: TRUE")
        expect(p.formatted).to include("TEST3: #{0x02030405}")
        expect(p.formatted).to include("TEST4: Test")
        # Test the data_type parameter
        expect(p.formatted(:RAW)).to include("TEST1: [1, 2]")
        expect(p.formatted(:RAW)).to include("TEST2: #{0x0304}")
        expect(p.formatted(:RAW)).to include("TEST3: #{0x0406080A}")
        expect(p.formatted(:RAW)).to include("00000000: 54 65 73 74") # Raw TEST4 block
        # Test the indent parameter
        expect(p.formatted(:CONVERTED, 4)).to include("    TEST1: [1, 2]")
        # Test the buffer parameter
        buffer = "\x02\x03\x04\x05\x00\x00\x00\x02\x44\x45\x41\x44"
        expect(p.formatted(:CONVERTED, 0, buffer)).to include("TEST1: [2, 3]")
        expect(p.formatted(:CONVERTED, 0, buffer)).to include("TEST2: #{0x0405}")
        expect(p.formatted(:CONVERTED, 0, buffer)).to include("TEST3: 1")
        expect(p.formatted(:CONVERTED, 0, buffer)).to include("TEST4: DEAD")
        # Test the ignored parameter
        string = p.formatted(:CONVERTED, 0, p.buffer, %w(TEST1 TEST4))
        expect(string).not_to include("TEST1")
        expect(string).to include("TEST2: TRUE")
        expect(string).to include("TEST3: #{0x02030405}")
        expect(string).not_to include("TEST4")
      end
    end

    describe "check_bit_offsets" do
      it "complains about overlapping items" do
        p = Packet.new("tgt1", "pkt1")
        p.define_item("item1", 0, 8, :UINT)
        p.define_item("item2", 0, 8, :UINT)
        expect(p.check_bit_offsets[0]).to eql "Bit definition overlap at bit offset 0 for packet TGT1 PKT1 items ITEM2 and ITEM1"
      end

      it "does not complain with non-overlapping negative offsets" do
        p = Packet.new("tgt1", "pkt1")
        p.define_item("item1", 0, 8, :UINT)
        p.define_item("item2", 8, -16, :BLOCK)
        p.define_item("item3", -16, 16, :UINT)
        expect(p.check_bit_offsets[0]).to be_nil
      end

      it "complains with overlapping negative offsets" do
        p = Packet.new("tgt1", "pkt1")
        p.define_item("item1", 0, 8, :UINT)
        p.define_item("item2", 8, -16, :BLOCK)
        p.define_item("item3", -17, 16, :UINT)
        expect(p.check_bit_offsets[0]).to eql "Bit definition overlap at bit offset -17 for packet TGT1 PKT1 items ITEM3 and ITEM2"
      end

      it "complains about intersecting items" do
        p = Packet.new("tgt1", "pkt1")
        p.define_item("item1", 0, 32, :UINT)
        p.define_item("item2", 16, 32, :UINT)
        expect(p.check_bit_offsets[0]).to eql "Bit definition overlap at bit offset 16 for packet TGT1 PKT1 items ITEM2 and ITEM1"
      end

      it "complains about array overlapping items" do
        p = Packet.new("tgt1", "pkt1")
        p.define_item("item1", 0, 8, :UINT, 32)
        p.define_item("item2", 0, 8, :UINT, 32)
        expect(p.check_bit_offsets[0]).to eql "Bit definition overlap at bit offset 0 for packet TGT1 PKT1 items ITEM2 and ITEM1"
      end

      it "does not complain with array non-overlapping negative offsets" do
        p = Packet.new("tgt1", "pkt1")
        p.define_item("item1", 0, 8, :UINT)
        p.define_item("item2", 8, 8, :INT, -16)
        p.define_item("item3", -16, 16, :UINT)
        expect(p.check_bit_offsets[0]).to be_nil
      end

      it "complains with array overlapping negative offsets" do
        p = Packet.new("tgt1", "pkt1")
        p.define_item("item1", 0, 8, :UINT)
        p.define_item("item2", 8, 8, :INT, -16)
        p.define_item("item3", -17, 16, :UINT)
        expect(p.check_bit_offsets[0]).to eql "Bit definition overlap at bit offset -17 for packet TGT1 PKT1 items ITEM3 and ITEM2"
      end

      it "complains about array intersecting items" do
        p = Packet.new("tgt1", "pkt1")
        p.define_item("item1", 0, 8, :UINT, 32)
        p.define_item("item2", 16, 8, :UINT, 32)
        expect(p.check_bit_offsets[0]).to eql "Bit definition overlap at bit offset 16 for packet TGT1 PKT1 items ITEM2 and ITEM1"
      end

      it "does not complain about nonoverlapping big endian bitfields" do
        p = Packet.new("tgt1", "pkt1")
        p.define_item("item1", 0, 12, :UINT, nil, :BIG_ENDIAN)
        p.define_item("item2", 12, 4, :UINT, nil, :BIG_ENDIAN)
        p.define_item("item3", 16, 16, :UINT, nil, :BIG_ENDIAN)
        expect(p.check_bit_offsets[0]).to be_nil
      end

      it "complains about overlapping big endian bitfields" do
        p = Packet.new("tgt1", "pkt1")
        p.define_item("item1", 0, 12, :UINT, nil, :BIG_ENDIAN)
        p.define_item("item2", 10, 6, :UINT, nil, :BIG_ENDIAN)
        p.define_item("item3", 16, 16, :UINT, nil, :BIG_ENDIAN)
        expect(p.check_bit_offsets[0]).to eql "Bit definition overlap at bit offset 10 for packet TGT1 PKT1 items ITEM2 and ITEM1"
      end

      it "does not complain about nonoverlapping little endian bitfields" do
        p = Packet.new("tgt1", "pkt1")
        # bit offset in LITTLE_ENDIAN refers to MSB
        p.define_item("item1", 12, 12, :UINT, nil, :LITTLE_ENDIAN)
        p.define_item("item2", 16, 16, :UINT, nil, :LITTLE_ENDIAN)
        expect(p.check_bit_offsets[0]).to be_nil
      end

      it "complains about overlapping little endian bitfields" do
        p = Packet.new("tgt1", "pkt1")
        # bit offset in LITTLE_ENDIAN refers to MSB
        p.define_item("item1", 12, 12, :UINT, nil, :LITTLE_ENDIAN)
        p.define_item("item2", 10, 10, :UINT, nil, :LITTLE_ENDIAN)
        expect(p.check_bit_offsets[0]).to eql "Bit definition overlap at bit offset 12 for packet TGT1 PKT1 items ITEM1 and ITEM2"
      end
    end

    describe "id_items" do
      it "returns an array of the identifying items" do
        p = Packet.new("tgt", "pkt")
        p.define_item("item1", 0, 32, :FLOAT, nil, :BIG_ENDIAN, :ERROR, "%5.1f", nil, nil, nil)
        p.define_item("item2", 64, 32, :FLOAT, nil, :BIG_ENDIAN, :ERROR, "%5.1f", nil, nil, 5)
        p.define_item("item3", 96, 32, :FLOAT, nil, :BIG_ENDIAN, :ERROR, "%5.1f", nil, nil, nil)
        p.define_item("item4", 32, 32, :FLOAT, nil, :BIG_ENDIAN, :ERROR, "%5.1f", nil, nil, 6)
        expect(p.id_items).to be_a Array
        expect(p.id_items[0].name).to eq "ITEM4"
        expect(p.id_items[1].name).to eq "ITEM2"
      end
    end

    describe "read_id_values" do
      it "to read the right values" do
        buffer = "\x00\x00\x00\x04\x00\x00\x00\x03\x00\x00\x00\x02\x00\x00\x00\x01"
        p = Packet.new("tgt", "pkt")
        p.define_item("item1", 0, 32, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, nil, nil, nil)
        p.define_item("item2", 64, 32, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, nil, nil, 5)
        p.define_item("item3", 96, 32, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, nil, nil, nil)
        p.define_item("item4", 32, 32, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, nil, nil, 6)
        values = p.read_id_values(buffer)
        expect(values[0]).to eq 3
        expect(values[1]).to eq 2
      end
    end

    describe "identify?" do
      it "identifies a buffer based on id_items" do
        p = Packet.new("tgt", "pkt")
        p.append_item("item1", 8, :UINT)
        p.append_item("item2", 16, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, nil, nil, 5)
        p.append_item("item3", 32, :UINT)
        expect(p.identify?("\x00\x00\x05\x01\x02\x03\x04")).to be true
        expect(p.identify?("\x00\x00\x04\x01\x02\x03\x04")).to be false
        expect(p.identify?("\x00")).to be false
      end

      it "identifies if the buffer is too short" do
        p = Packet.new("tgt", "pkt")
        p.append_item("item1", 8, :UINT)
        p.append_item("item2", 16, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, nil, nil, 5)
        p.append_item("item3", 32, :UINT)
        expect(p.identify?("\x00\x00\x05\x01\x02\x03")).to be true
      end

      it "identifies if the buffer is too long" do
        p = Packet.new("tgt", "pkt")
        p.append_item("item1", 8, :UINT)
        p.append_item("item2", 16, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, nil, nil, 5)
        p.append_item("item3", 32, :UINT)
        expect(p.identify?("\x00\x00\x05\x01\x02\x03\x04\x05")).to be true
      end
    end

    describe "identified?" do
      it "returns true if the target name and packet name are set" do
        expect(Packet.new('TGT', nil).identified?).to be false
        expect(Packet.new(nil, 'PKT').identified?).to be false
        expect(Packet.new('TGT', 'PKT').identified?).to be true
      end
    end

    describe "restore_defaults" do
      it "writes all the items back to their default values" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT, 16)
        i = p.get_item("TEST1")
        i.default = [3, 4]
        p.write("test1", [1, 2])
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.default = 0x0102
        i.states = { "TRUE" => 0x0304 }
        p.write("test2", 0x0304)
        p.append_item("test3", 32, :UINT)
        i = p.get_item("TEST3")
        i.default = 0x02030405
        i.write_conversion = GenericConversion.new("value * 2")
        p.write("test3", 0x01020304)
        expect(p.buffer).to eql "\x01\x02\x03\x04\x02\x04\x06\x08"
        p.restore_defaults
        expect(p.buffer).to eql "\x03\x04\x01\x02\x04\x06\x08\x0A"
      end

      it "writes all except skipped items back to their default values" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT, 16)
        i = p.get_item("TEST1")
        i.default = [3, 4]
        p.write("test1", [1, 2])
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.default = 0x0102
        i.states = { "TRUE" => 0x0304 }
        p.write("test2", 0x0304)
        p.append_item("test3", 32, :UINT)
        i = p.get_item("TEST3")
        i.default = 0x02030405
        i.write_conversion = GenericConversion.new("value * 2")
        p.write("test3", 0x01020304)
        expect(p.buffer).to eql "\x01\x02\x03\x04\x02\x04\x06\x08"
        p.restore_defaults(p.buffer(false), ["test1", "test2", "test3"])
        expect(p.buffer).to eql "\x01\x02\x03\x04\x02\x04\x06\x08"
        p.restore_defaults(p.buffer(false), ["test1", "test3"])
        expect(p.buffer).to eql "\x01\x02\x01\x02\x02\x04\x06\x08"
        p.restore_defaults(p.buffer(false), ["test3"])
        expect(p.buffer).to eql "\x03\x04\x01\x02\x02\x04\x06\x08"
        p.restore_defaults(p.buffer(false))
        expect(p.buffer).to eql "\x03\x04\x01\x02\x04\x06\x08\x0A"
      end
    end

    describe "enable_limits" do
      it "enables limits on each packet item" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT, 16)
        p.append_item("test2", 16, :UINT)
        expect(p.get_item("TEST1").limits.enabled).to be false
        expect(p.get_item("TEST2").limits.enabled).to be false
        p.enable_limits("TEST1")
        expect(p.get_item("TEST1").limits.enabled).to be true
        expect(p.get_item("TEST2").limits.enabled).to be false
        p.enable_limits("TEST2")
        expect(p.get_item("TEST1").limits.enabled).to be true
        expect(p.get_item("TEST2").limits.enabled).to be true
      end
    end

    describe "disable_limits" do
      it "disables limits on each packet item" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT)
        p.append_item("test2", 16, :UINT)
        p.enable_limits("TEST1")
        p.enable_limits("TEST2")
        expect(p.get_item("TEST1").limits.enabled).to be true
        expect(p.get_item("TEST2").limits.enabled).to be true
        p.disable_limits("TEST1")
        expect(p.get_item("TEST1").limits.enabled).to be false
        expect(p.get_item("TEST2").limits.enabled).to be true
        p.disable_limits("TEST2")
        expect(p.get_item("TEST1").limits.enabled).to be false
        expect(p.get_item("TEST2").limits.enabled).to be false
      end

      it "calls the limits_change_callback for all non STALE items" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT)
        i = p.get_item("TEST1")
        i.limits.values = { :DEFAULT => [1, 2, 4, 5] }
        p.update_limits_items_cache(i)
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.limits.values = { :DEFAULT => [1, 2, 4, 5] }
        p.update_limits_items_cache(i)
        p.write("TEST1", 3)
        p.write("TEST2", 3)
        p.enable_limits("TEST1")
        p.enable_limits("TEST2")

        callback = double("callback", :call => true)
        p.limits_change_callback = callback
        expect(callback).to receive(:call).with(p, p.get_item("TEST1"), :GREEN, nil, false)
        expect(callback).to receive(:call).with(p, p.get_item("TEST2"), :GREEN, nil, false)
        p.check_limits
        p.disable_limits("TEST1")
        p.disable_limits("TEST2")
        expect(p.get_item("TEST1").limits.enabled).to be false
        expect(p.get_item("TEST2").limits.enabled).to be false
      end
    end

    describe "limits_items" do
      it "returns all items with limits" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT)
        p.enable_limits("TEST1")
        p.append_item("test2", 16, :UINT)
        p.enable_limits("TEST2")
        expect(p.limits_items).to eql []

        test1 = p.get_item("TEST1")
        test1.limits.values = { :DEFAULT => [1, 2, 4, 5] }
        p.update_limits_items_cache(test1)
        expect(p.limits_items).to eql [test1]
        test2 = p.get_item("TEST2")
        test2.limits.values = { :DEFAULT => [1, 2, 4, 5] }
        p.update_limits_items_cache(test2)
        expect(p.limits_items).to eql [test1, test2]
      end
    end

    describe "out_of_limits" do
      it "returns an array indicating all items out of limits" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT)
        i = p.get_item("TEST1")
        i.limits.values = { :DEFAULT => [1, 2, 4, 5] }
        p.update_limits_items_cache(i)
        p.enable_limits("TEST1")
        p.write("TEST1", 3)
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.limits.values = { :DEFAULT => [1, 2, 4, 5] }
        p.update_limits_items_cache(i)
        p.write("TEST2", 3)
        p.enable_limits("TEST2")
        p.check_limits
        expect(p.out_of_limits).to eql []

        p.write("TEST1", 6)
        p.check_limits
        expect(p.out_of_limits).to eql [["TGT", "PKT", "TEST1", :RED_HIGH]]
        p.write("TEST2", 2)
        p.check_limits
        expect(p.out_of_limits).to eql [["TGT", "PKT", "TEST1", :RED_HIGH], ["TGT", "PKT", "TEST2", :YELLOW_LOW]]
      end
    end

    describe "set_all_limits_states" do
      it "sets all limits states to the given state" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT)
        i = p.get_item("TEST1")
        i.limits.values = { :DEFAULT => [1, 2, 4, 5] }
        p.update_limits_items_cache(i)
        p.enable_limits("TEST1")
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.limits.values = { :DEFAULT => [1, 2, 4, 5] }
        p.update_limits_items_cache(i)
        p.enable_limits("TEST2")
        expect(p.out_of_limits).to eql []

        PacketItemLimits::OUT_OF_LIMITS_STATES.each do |state|
          p.set_all_limits_states(state)
          expect(p.out_of_limits).to eql [["TGT", "PKT", "TEST1", state], ["TGT", "PKT", "TEST2", state]]
        end
      end
    end

    describe "check_limits" do
      before(:each) do
        @p = Packet.new("tgt", "pkt")
        @p.append_item("test1", 8, :UINT)
        @p.append_item("test2", 16, :UINT)
        @p.append_item("test3", 32, :FLOAT)
      end

      it "sets clear the stale flag" do
        expect(@p.stale).to be true
        @p.check_limits
        expect(@p.stale).to be false
      end

      it "does not call the limits_change_callback if limits are disabled" do
        expect(@p.get_item("TEST1").limits.enabled).to be false
        expect(@p.get_item("TEST2").limits.enabled).to be false
        callback = double("callback")
        allow(callback).to receive(:call)
        @p.limits_change_callback = callback
        @p.check_limits
        expect(callback).to_not receive(:call)
      end

      context "with states" do
        it "calls the limits_change_callback" do
          test1 = @p.get_item("TEST1")
          expect(test1.limits.enabled).to be false
          test1.states = { "TRUE" => 1, "FALSE" => 0 }
          test1.state_colors = { "TRUE" => :GREEN, "FALSE" => :RED }
          @p.update_limits_items_cache(test1)
          @p.write("TEST1", 0)
          @p.enable_limits("TEST1")
          test2 = @p.get_item("TEST2")
          expect(test2.limits.enabled).to be false
          test2.states = { "TRUE" => 1, "FALSE" => 0 }
          test2.state_colors = { "TRUE" => :RED, "FALSE" => :GREEN }
          @p.write("TEST2", 0)
          @p.enable_limits("TEST2")
          @p.update_limits_items_cache(test2)

          # Mock the callback so we can see if it is called properly
          callback = double("callback", :call => true)
          @p.limits_change_callback = callback

          # Check the limits for the first time, TEST1 should be :RED and TEST2
          # should be :GREEN
          expect(callback).to receive(:call).once.with(@p, test1, nil, "FALSE", true)
          @p.check_limits

          # Change the TEST2 state to :RED, we were previously :GREEN
          @p.write("TEST2", 1)
          expect(callback).to receive(:call).once.with(@p, test2, :GREEN, "TRUE", true)
          @p.check_limits

          # Change the TEST2 value to something that doesn't map to a state
          @p.write("TEST2", 2)
          expect(callback).to receive(:call).once.with(@p, test2, :RED, 2, false)
          @p.check_limits
        end
      end

      context "with values" do
        before(:each) do
          @test1 = @p.get_item("TEST1")
          expect(@test1.limits.enabled).to be false
          @test1.limits.values = { :DEFAULT => [1, 2, 4, 5] } # red yellow
          @p.update_limits_items_cache(@test1)
          @p.enable_limits("TEST1")

          @test2 = @p.get_item("TEST2")
          expect(@test2.limits.enabled).to be false
          @test2.limits.values = { :DEFAULT => [1, 2, 6, 7, 3, 5] } # red yellow and blue
          @p.update_limits_items_cache(@test2)
          @p.enable_limits("TEST2")

          @test3 = @p.get_item("TEST3")
          expect(@test3.limits.enabled).to be false
          @test3.limits.values = { :DEFAULT => [1, 1.5, 2.5, 3] } # red yellow
          @p.update_limits_items_cache(@test3)
          @p.enable_limits("TEST3")

          # Mock the callback so we can see if it is called properly
          @callback = double("callback", :call => true)
          @p.limits_change_callback = @callback
        end

        it "detects initial low states" do
          @p.write("TEST1", 0)
          @p.write("TEST2", 3)
          @p.write("TEST3", 1.25)
          @p.check_limits
          expect(@p.get_item("TEST1").limits.state).to eql :RED_LOW
          expect(@p.get_item("TEST2").limits.state).to eql :GREEN_LOW
          expect(@p.get_item("TEST3").limits.state).to eql :YELLOW_LOW
        end

        it "detects initial high states" do
          @p.write("TEST1", 6)
          @p.write("TEST2", 5)
          @p.write("TEST3", 2.75)
          @p.check_limits
          expect(@p.get_item("TEST1").limits.state).to eql :RED_HIGH
          expect(@p.get_item("TEST2").limits.state).to eql :GREEN_HIGH
          expect(@p.get_item("TEST3").limits.state).to eql :YELLOW_HIGH
        end

        it "detects initial middle states" do
          @p.write("TEST1", 3)
          @p.write("TEST2", 4)
          @p.write("TEST3", 2.0)
          @p.check_limits
          expect(@p.get_item("TEST1").limits.state).to eql :GREEN
          expect(@p.get_item("TEST2").limits.state).to eql :BLUE
          expect(@p.get_item("TEST3").limits.state).to eql :GREEN
        end

        it "clears persistence when initial state is nil" do
          @p.get_item("TEST1").limits.persistence_count = 2
          @p.get_item("TEST2").limits.persistence_count = 3
          @p.get_item("TEST3").limits.persistence_count = 4
          @p.check_limits
          expect(@p.get_item("TEST1").limits.persistence_count).to eql 0
          expect(@p.get_item("TEST2").limits.persistence_count).to eql 0
          expect(@p.get_item("TEST3").limits.persistence_count).to eql 0
        end

        context "when calling the limits_change_callback" do
          it "initiallies call only for out of limits" do
            @p.write("TEST1", 0)
            @p.write("TEST2", 4)
            @p.write("TEST3", 1.25)

            # Check the limits for the first time, TEST1 should be :RED_LOW, TEST2
            # should be :BLUE, TEST3 should be YELLOW_LOW
            expect(@callback).to receive(:call).with(@p, @test1, nil, 0, true)
            expect(@callback).to receive(:call).with(@p, @test3, nil, 1.25, true)
            @p.check_limits
          end

          it "calls when limits change states" do
            @p.write("TEST1", 0)
            @p.write("TEST2", 4)
            @p.write("TEST3", 1.25)
            @p.check_limits

            # Make TEST2 be GREEN_LOW, we were previously :BLUE
            @p.write("TEST2", 3)
            expect(@callback).to receive(:call).once.with(@p, @test2, :BLUE, 3, true)
            @p.check_limits
          end

          it "calls only when persistence is achieved" do
            # First establish the green state when coming from nil
            @p.get_item("TEST1").limits.persistence_setting = 1
            @p.get_item("TEST2").limits.persistence_setting = 1
            @p.get_item("TEST3").limits.persistence_setting = 1
            @p.write("TEST1", 3)
            @p.write("TEST2", 4)
            @p.write("TEST3", 2.0)
            expect(@callback).to receive(:call).with(@p, @test1, nil, 3, true)
            expect(@callback).to receive(:call).with(@p, @test2, nil, 4, true)
            expect(@callback).to receive(:call).with(@p, @test3, nil, 2.0, true)
            @p.check_limits
            expect(@test1.limits.state).to eql :GREEN
            expect(@test2.limits.state).to eql :BLUE
            expect(@test3.limits.state).to eql :GREEN

            # Now test the persistence setting by going out of limits
            @p.get_item("TEST1").limits.persistence_setting = 2
            @p.get_item("TEST2").limits.persistence_setting = 3
            @p.get_item("TEST3").limits.persistence_setting = 4

            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            @p.check_limits
            expect(@test1.limits.state).to eql :GREEN
            expect(@test2.limits.state).to eql :BLUE
            expect(@test3.limits.state).to eql :GREEN

            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to receive(:call).with(@p, @test1, :GREEN, 0, true)
            @p.check_limits
            expect(@test1.limits.state).to eql :RED_LOW
            expect(@test2.limits.state).to eql :BLUE
            expect(@test3.limits.state).to eql :GREEN

            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to receive(:call).with(@p, @test2, :BLUE, 8, true)
            @p.check_limits
            expect(@test1.limits.state).to eql :RED_LOW
            expect(@test2.limits.state).to eql :RED_HIGH
            expect(@test3.limits.state).to eql :GREEN

            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to receive(:call).with(@p, @test3, :GREEN, 1.25, true)
            @p.check_limits
            expect(@test1.limits.state).to eql :RED_LOW
            expect(@test2.limits.state).to eql :RED_HIGH
            expect(@test3.limits.state).to eql :YELLOW_LOW

            # Now go back to good on everything and verify persistence still applies
            @p.write("TEST1", 3)
            @p.write("TEST2", 4)
            @p.write("TEST3", 2.0)
            @p.check_limits
            expect(@test1.limits.state).to eql :RED_LOW
            expect(@test2.limits.state).to eql :RED_HIGH
            expect(@test3.limits.state).to eql :YELLOW_LOW

            @p.write("TEST1", 3)
            @p.write("TEST2", 4)
            @p.write("TEST3", 2.0)
            expect(@callback).to receive(:call).with(@p, @test1, :RED_LOW, 3, true)
            @p.check_limits
            expect(@test1.limits.state).to eql :GREEN
            expect(@test2.limits.state).to eql :RED_HIGH
            expect(@test3.limits.state).to eql :YELLOW_LOW

            @p.write("TEST1", 3)
            @p.write("TEST2", 4)
            @p.write("TEST3", 2.0)
            expect(@callback).to receive(:call).with(@p, @test2, :RED_HIGH, 4, true)
            @p.check_limits
            expect(@test1.limits.state).to eql :GREEN
            expect(@test2.limits.state).to eql :BLUE
            expect(@test3.limits.state).to eql :YELLOW_LOW

            @p.write("TEST1", 3)
            @p.write("TEST2", 4)
            @p.write("TEST3", 2.0)
            expect(@callback).to receive(:call).with(@p, @test3, :YELLOW_LOW, 2.0, true)
            @p.check_limits
            expect(@test1.limits.state).to eql :GREEN
            expect(@test2.limits.state).to eql :BLUE
            expect(@test3.limits.state).to eql :GREEN
          end

          it "does not call when state changes before persistence is achieved" do
            # First establish the green state when coming from nil
            @p.get_item("TEST1").limits.persistence_setting = 1
            @p.get_item("TEST2").limits.persistence_setting = 1
            @p.get_item("TEST3").limits.persistence_setting = 1
            @p.write("TEST1", 3)
            @p.write("TEST2", 4)
            @p.write("TEST3", 2.0)
            expect(@callback).to receive(:call).with(@p, @test1, nil, 3, true)
            expect(@callback).to receive(:call).with(@p, @test2, nil, 4, true)
            expect(@callback).to receive(:call).with(@p, @test3, nil, 2.0, true)
            @p.check_limits
            expect(@test1.limits.state).to eql :GREEN
            expect(@test2.limits.state).to eql :BLUE
            expect(@test3.limits.state).to eql :GREEN

            # Set all persistence the same
            @p.get_item("TEST1").limits.persistence_setting = 3
            @p.get_item("TEST2").limits.persistence_setting = 3
            @p.get_item("TEST3").limits.persistence_setting = 3

            # Write bad values twice
            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to_not receive(:call)
            @p.check_limits
            expect(@test1.limits.state).to eql :GREEN
            expect(@test2.limits.state).to eql :BLUE
            expect(@test3.limits.state).to eql :GREEN

            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to_not receive(:call)
            @p.check_limits
            expect(@test1.limits.state).to eql :GREEN
            expect(@test2.limits.state).to eql :BLUE
            expect(@test3.limits.state).to eql :GREEN

            # Set the values back to good
            @p.write("TEST1", 3)
            @p.write("TEST2", 4)
            @p.write("TEST3", 2.0)
            @p.check_limits
            expect(@test1.limits.state).to eql :GREEN
            expect(@test2.limits.state).to eql :BLUE
            expect(@test3.limits.state).to eql :GREEN

            # Write bad values twice
            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to_not receive(:call)
            @p.check_limits
            expect(@test1.limits.state).to eql :GREEN
            expect(@test2.limits.state).to eql :BLUE
            expect(@test3.limits.state).to eql :GREEN

            @p.write("TEST1", 0)
            @p.write("TEST2", 8)
            @p.write("TEST3", 1.25)
            expect(@callback).to_not receive(:call)
            @p.check_limits
            expect(@test1.limits.state).to eql :GREEN
            expect(@test2.limits.state).to eql :BLUE
            expect(@test3.limits.state).to eql :GREEN

            # Set the values back to good
            @p.write("TEST1", 3)
            @p.write("TEST2", 4)
            @p.write("TEST3", 2.0)
            @p.check_limits
            expect(@test1.limits.state).to eql :GREEN
            expect(@test2.limits.state).to eql :BLUE
            expect(@test3.limits.state).to eql :GREEN
          end
        end
      end
    end

    describe "stale" do
      it "sets all limits states to stale" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT)
        i = p.get_item("TEST1")
        i.limits.values = { :DEFAULT => [1, 2, 4, 5] }
        p.update_limits_items_cache(i)
        p.enable_limits("TEST1")
        p.append_item("test2", 16, :UINT)
        i = p.get_item("TEST2")
        i.limits.values = { :DEFAULT => [1, 2, 4, 5] }
        p.update_limits_items_cache(i)
        p.enable_limits("TEST2")
        expect(p.out_of_limits).to eql []

        expect(p.stale).to be true
        expect(p.get_item("TEST1").limits.state).to eql :STALE
        expect(p.get_item("TEST2").limits.state).to eql :STALE
        # Update the limits
        p.check_limits
        expect(p.stale).to be false
        expect(p.get_item("TEST1").limits.state).not_to eql :STALE
        expect(p.get_item("TEST2").limits.state).not_to eql :STALE
        # set them all back to stale
        p.set_stale
        expect(p.get_item("TEST1").limits.state).to eql :STALE
        expect(p.get_item("TEST2").limits.state).to eql :STALE
      end
    end

    describe "clone" do
      it "duplicates the packet" do
        p = Packet.new("tgt", "pkt")
        p.processors['PROCESSOR'] = Processor.new
        p.processors['PROCESSOR'].name = "TestProcessor"
        p2 = p.clone
        # No comparison operator
        # expect(p).to eql p2
        expect(p).to_not be p2
        expect(p2.target_name).to eql "TGT"
        expect(p2.packet_name).to eql "PKT"
        # No comparison operator
        # expect(p2.processors['PROCESSOR']).to eql p.processors['PROCESSOR']
        expect(p2.processors['PROCESSOR']).to_not be p.processors['PROCESSOR']
        expect(p2.processors['PROCESSOR'].name).to eql p.processors['PROCESSOR'].name
      end
    end

    describe "reset" do
      it "does nothing to the SYSTEM META packet" do
        p = Packet.new("SYSTEM", "META")
        time = Time.now
        p.received_time = time
        p.received_count = 50
        p.reset
        expect(p.received_time).to eql time
        expect(p.received_count).to eql 50
      end

      it "resets the received_time and received_count" do
        p = Packet.new("tgt", "pkt")
        p.processors['processor'] = double("reset", :reset => true)
        p.received_time = Time.now
        p.received_count = 50
        p.reset
        expect(p.received_time).to eql nil
        expect(p.received_count).to eql 0
      end

      it "clears the read conversion cache" do
        p = Packet.new("tgt", "pkt")
        p.append_item("item", 8, :UINT)
        i = p.get_item("ITEM")
        p.buffer = "\x04"
        i.read_conversion = GenericConversion.new("value / 2")
        expect(p.read("ITEM")).to be 2
        cache = p.instance_variable_get(:@read_conversion_cache)
        expect(cache[i]).to be 2
        p.reset
        expect(cache).to be_empty
      end
    end

    describe "as_json" do
      it "creates a hash" do
        json = Packet.new("tgt", "pkt").as_json(:allow_nan => true)
        expect(json['target_name']).to eql 'TGT'
        expect(json['packet_name']).to eql 'PKT'
        expect(json['items']).to eql []
      end
    end

    describe "self.from_json" do
      it "creates a Packet from a hash" do
        p = Packet.new("tgt", "pkt")
        p.append_item("test1", 8, :UINT)
        packet = Packet.from_json(p.as_json(:allow_nan => true))
        expect(packet.target_name).to eql p.target_name
        expect(packet.packet_name).to eql p.packet_name
        item = packet.sorted_items[0]
        expect(item.name).to eql "TEST1"
      end
    end
  end
end
