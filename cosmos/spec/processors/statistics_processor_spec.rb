# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos'
require 'cosmos/processors/statistics_processor'

module Cosmos

  describe StatisticsProcessor do
    describe "initialize" do
      it "takes an item_name, samples_to_average, and value_type" do
        p = StatisticsProcessor.new('TEST', '5', 'RAW')
        expect(p.value_type).to eql :RAW
        expect(p.instance_variable_get("@item_name")).to eql 'TEST'
        expect(p.instance_variable_get("@samples_to_average")).to eql 5
      end
    end

    describe "call and reset" do
      it "generates statistics" do
        p = StatisticsProcessor.new('TEST', '5', 'RAW')
        packet = Packet.new("tgt","pkt")
        packet.append_item("TEST", 8, :UINT)
        packet.buffer = "\x01"
        p.call(packet, packet.buffer)
        expect(p.results[:MAX]).to eql 1
        expect(p.results[:MIN]).to eql 1
        expect(p.results[:MEAN]).to be_within(0.001).of(1.0)
        expect(p.results[:STDDEV]).to be_within(0.001).of(0.0)
        packet.buffer = "\x02"
        p.call(packet, packet.buffer)
        expect(p.results[:MAX]).to eql 2
        expect(p.results[:MIN]).to eql 1
        expect(p.results[:MEAN]).to be_within(0.001).of(1.5)
        expect(p.results[:STDDEV]).to be_within(0.001).of(0.7071)
        packet.buffer = "\x00"
        p.call(packet, packet.buffer)
        expect(p.results[:MAX]).to eql 2
        expect(p.results[:MIN]).to eql 0
        expect(p.results[:MEAN]).to be_within(0.001).of(1.0)
        expect(p.results[:STDDEV]).to be_within(0.001).of(1.0)
        p.reset
        expect(p.results[:MAX]).to eql nil
        expect(p.results[:MIN]).to eql nil
        expect(p.results[:MEAN]).to eql nil
        expect(p.results[:STDDEV]).to eql nil
      end

      it "handles nil and infinity" do
        p = StatisticsProcessor.new('TEST', '5')
        packet = Packet.new("tgt","pkt")
        packet.append_item("TEST", 32, :FLOAT)
        packet.write("TEST", 1)
        p.call(packet, packet.buffer)
        expect(p.results[:MAX]).to eql 1.0
        expect(p.results[:MIN]).to eql 1.0
        expect(p.results[:MEAN]).to be_within(0.001).of(1.0)
        expect(p.results[:STDDEV]).to be_within(0.001).of(0.0)
        packet.write("TEST", Float::NAN)
        p.call(packet, packet.buffer)
        expect(p.results[:MAX]).to eql 1.0
        expect(p.results[:MIN]).to eql 1.0
        expect(p.results[:MEAN]).to be_within(0.001).of(1.0)
        expect(p.results[:STDDEV]).to be_within(0.001).of(0.0)
        packet.write("TEST", 2)
        p.call(packet, packet.buffer)
        expect(p.results[:MAX]).to eql 2.0
        expect(p.results[:MIN]).to eql 1.0
        expect(p.results[:MEAN]).to be_within(0.001).of(1.5)
        expect(p.results[:STDDEV]).to be_within(0.001).of(0.7071)
        packet.write("TEST", Float::INFINITY)
        p.call(packet, packet.buffer)
        expect(p.results[:MAX]).to eql 2.0
        expect(p.results[:MIN]).to eql 1.0
        expect(p.results[:MEAN]).to be_within(0.001).of(1.5)
        expect(p.results[:STDDEV]).to be_within(0.001).of(0.7071)
        p.reset
        expect(p.results[:MAX]).to eql nil
        expect(p.results[:MIN]).to eql nil
        expect(p.results[:MEAN]).to eql nil
        expect(p.results[:STDDEV]).to eql nil
      end
    end
  end
end
