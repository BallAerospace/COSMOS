# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/processors/statistics_processor'

module Cosmos

  describe StatisticsProcessor do

    describe "initialize" do
      it "should take an item_name, samples_to_average, and value_type" do
        p = StatisticsProcessor.new('TEST', '5', 'RAW')
        p.value_type.should eql :RAW
        p.instance_variable_get("@item_name").should eql 'TEST'
        p.instance_variable_get("@samples_to_average").should eql 5
      end
    end

    describe "call and reset" do
      it "should generate statistics" do
        p = StatisticsProcessor.new('TEST', '5', 'RAW')
        packet = Packet.new("tgt","pkt")
        packet.append_item("TEST", 8, :UINT)
        packet.buffer= "\x01"
        p.call(packet, packet.buffer)
        p.results[:MAX].should eql 1
        p.results[:MIN].should eql 1
        p.results[:MEAN].should be_within(0.001).of(1.0)
        p.results[:STDDEV].should be_within(0.001).of(0.0)
        packet.buffer= "\x02"
        p.call(packet, packet.buffer)
        p.results[:MAX].should eql 2
        p.results[:MIN].should eql 1
        p.results[:MEAN].should be_within(0.001).of(1.5)
        p.results[:STDDEV].should be_within(0.001).of(0.7071)
        packet.buffer= "\x00"
        p.call(packet, packet.buffer)
        p.results[:MAX].should eql 2
        p.results[:MIN].should eql 0
        p.results[:MEAN].should be_within(0.001).of(1.0)
        p.results[:STDDEV].should be_within(0.001).of(1.0)
        p.reset
        p.results[:MAX].should eql nil
        p.results[:MIN].should eql nil
        p.results[:MEAN].should eql nil
        p.results[:STDDEV].should eql nil
      end
    end
  end
end

