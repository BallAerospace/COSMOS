# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/interface'
require 'cosmos/interfaces/protocols/override_protocol'

module Cosmos
  describe OverrideProtocol do
    let(:interface) { Interface.new.extend(OverrideProtocol) }

    it "overrides INT values" do
      pkt = Packet.new("TGT","PKT")
      rc = GenericConversion.new("value * 2")
      wc = GenericConversion.new("value * 4")
      pkt.append_item("ITEM", 8, :INT, nil, :BIG_ENDIAN, :ERROR, nil, rc, wc)
      expect(pkt.read("ITEM")).to eql(0)

      interface.override_tlm_raw("TGT","PKT","ITEM",-10)
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(-20)

      interface.override_tlm("TGT","PKT","ITEM",-10) # Write conversion writes -40
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(-80) # Read conversion reads -80
    end

    it "overrides UINT values" do
      pkt = Packet.new("TGT","PKT")
      rc = GenericConversion.new("value * 2")
      wc = GenericConversion.new("value * 4")
      pkt.append_item("ITEM", 8, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, rc, wc)
      expect(pkt.read("ITEM")).to eql(0)

      interface.override_tlm_raw("TGT","PKT","ITEM",10)
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(20)

      interface.override_tlm("TGT","PKT","ITEM",10) # Write conversion writes 40
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(80) # Read conversion reads 80
    end

    it "overrides FLOAT values" do
      pkt = Packet.new("TGT","PKT")
      rc = GenericConversion.new("value * 2")
      wc = GenericConversion.new("value * 4")
      pkt.append_item("ITEM", 32, :FLOAT, nil, :BIG_ENDIAN, :ERROR, nil, rc, wc)
      expect(pkt.read("ITEM")).to eql(0.0)

      interface.override_tlm_raw("TGT","PKT","ITEM",10.5)
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(21.0)

      interface.override_tlm("TGT","PKT","ITEM",10.5) # Write conversion writes 42
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(84.0) # Read conversion reads 84
    end

    it "overrides DOUBLE values" do
      pkt = Packet.new("TGT","PKT")
      rc = GenericConversion.new("value * 2")
      wc = GenericConversion.new("value * 4")
      pkt.append_item("ITEM", 32, :FLOAT, nil, :BIG_ENDIAN, :ERROR, nil, rc, wc)
      expect(pkt.read("ITEM")).to eql(0.0)

      interface.override_tlm_raw("TGT","PKT","ITEM",Float::INFINITY)
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(Float::INFINITY)

      interface.override_tlm("TGT","PKT","ITEM",10.5) # Write conversion writes 42
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(84.0) # Read conversion reads 84
    end

    it "overrides STRING values" do
      pkt = Packet.new("TGT","PKT")
      rc = GenericConversion.new("value * 2")
      wc = GenericConversion.new("value * 4")
      pkt.append_item("ITEM", 1024, :STRING, nil, :BIG_ENDIAN, :ERROR, nil, rc, wc)
      expect(pkt.read("ITEM")).to eql("")

      interface.override_tlm_raw("TGT","PKT","ITEM","HI")
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql("HIHI")

      interface.override_tlm("TGT","PKT","ITEM","X") # Write conversion writes XXXX
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql("XXXXXXXX")
    end

    it "clears overriden values" do
      pkt = Packet.new("TGT","PKT")
      rc = GenericConversion.new("value * 2")
      wc = GenericConversion.new("value * 4")
      pkt.append_item("ITEM", 8, :INT, nil, :BIG_ENDIAN, :ERROR, nil, rc, wc)
      expect(pkt.read("ITEM")).to eql(0)

      interface.override_tlm_raw("TGT","PKT","ITEM",-10)
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(-20)

      interface.normalize_tlm("TGT","PKT","ITEM")
      pkt.write("ITEM", 0, :RAW)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(0)
    end
  end
end
