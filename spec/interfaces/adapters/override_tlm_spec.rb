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
require 'cosmos/interfaces/adapters/override_tlm'

module Cosmos

  describe OverrideTlm do
    let(:interface) { Interface.new.extend(OverrideTlm) }

    it "override_tlm_raws INT values" do
      interface.override_tlm_raw("TGT","PKT","ITEM",10)
      pkt = Packet.new("TGT","PKT")
      pkt.append_item("ITEM", 8, :INT)
      expect(pkt.read("ITEM")).to eql(0)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(10)

      interface.override_tlm_raw("TGT","PKT","ITEM",10)
    end

    it "override_tlm_raws UINT values" do
      interface.override_tlm_raw("TGT","PKT","ITEM",10)
      pkt = Packet.new("TGT","PKT")
      pkt.append_item("ITEM", 16, :UINT)
      expect(pkt.read("ITEM")).to eql(0)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(10)
    end

    it "override_tlm_raws FLOAT values" do
      interface.override_tlm_raw("TGT","PKT","ITEM",12.5)
      pkt = Packet.new("TGT","PKT")
      pkt.append_item("ITEM", 32, :FLOAT)
      expect(pkt.read("ITEM")).to eql(0.0)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(12.5)
    end

    it "override_tlm_raws DOUBLE values" do
      interface.override_tlm_raw("TGT","PKT","ITEM",Float::INFINITY)
      pkt = Packet.new("TGT","PKT")
      pkt.append_item("ITEM", 64, :FLOAT)
      expect(pkt.read("ITEM")).to eql(0.0)
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql(Float::INFINITY)
    end

    it "override_tlm_raws STRING values" do
      interface.override_tlm_raw("TGT","PKT","ITEM","Hi there")
      pkt = Packet.new("TGT","PKT")
      pkt.append_item("ITEM", 1024, :STRING)
      expect(pkt.read("ITEM")).to eql('')
      interface.post_read_packet(pkt)
      expect(pkt.read("ITEM")).to eql("Hi there")
    end
  end
end

