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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require "spec_helper"
require "cosmos/utilities/metric"

module Cosmos
  describe Metric do
    before(:each) do
      @metric = Metric.new(microservice: "foo", scope: "bar")
      @redis = mock_redis()
    end

    describe "initialize" do
      it "sets the scope and microservice" do
        expect(@metric.microservice).to eql("foo")
        expect(@metric.scope).to eql("bar")
      end
    end

    describe "add_sample" do
      it "adds a sample to the metric" do
        @metric.add_sample(name: "test", value: 2, labels: { "is" => true })
        expect(@metric.items.empty?).to eql(false)
        expect(@metric.items.has_key?("test|is=true")).to eql(true)
        expect(@metric.items["test|is=true"]["count"] == 1)
      end

      it "adds two of the same sample to the metric" do
        @metric.add_sample(name: "test", value: 2, labels: { "is" => true })
        @metric.add_sample(name: "test", value: 1, labels: { "is" => true })
        expect(@metric.items.empty?).to eql(false)
        expect(@metric.items.has_key?("test|is=true")).to eql(true)
        expect(@metric.items["test|is=true"]["count"]).to eql(2)
      end

      it "adds two different named samples to the metric" do
        @metric.add_sample(name: "test", value: 2, labels: { "is" => true })
        @metric.add_sample(name: "pest", value: 1, labels: { "is" => true })
        expect(@metric.items.empty?).to eql(false)
        expect(@metric.items.has_key?("test|is=true")).to eql(true)
        expect(@metric.items.has_key?("pest|is=true")).to eql(true)
        expect(@metric.items["test|is=true"]["count"]).to eql(1)
        expect(@metric.items["pest|is=true"]["count"]).to eql(1)
      end

      it "adds four different named samples to the metric" do
        @metric.add_sample(name: "test", value: 1, labels: { "is" => true })
        @metric.add_sample(name: "test", value: 1, labels: { "is" => false })
        @metric.add_sample(name: "test", value: 1, labels: { "is" => true, "not" => 3 })
        @metric.add_sample(name: "test", value: 1, labels: { "is" => true, "cat" => "tacocat" })
        expect(@metric.items.has_key?("test|is=true")).to eql(true)
        expect(@metric.items.has_key?("test|is=false")).to eql(true)
        expect(@metric.items.has_key?("test|is=true,not=3")).to eql(true)
        expect(@metric.items.has_key?("test|is=true,cat=tacocat")).to eql(true)
      end

      it "will add to the end of the item value array" do
        @metric.size = 3
        @metric.add_sample(name: "test", value: 2, labels: { "is" => true })
        expect(@metric.items["test|is=true"]["values"].length).to eql(@metric.size)
        expect(@metric.items.empty?).to eql(false)
        @metric.add_sample(name: "test", value: 3, labels: { "is" => true })
        @metric.add_sample(name: "test", value: 3, labels: { "is" => true })
        @metric.add_sample(name: "test", value: 3, labels: { "is" => true })
        expect(@metric.items["test|is=true"]["values"].length).to eql(@metric.size)
        expect(@metric.items["test|is=true"]["count"]).to eql(1)
      end
    end

    describe "output" do
      it "empty value generate summary metrics based on samples" do
        expect(@metric.items.empty?).to eql(true)
        @metric.output
        expect(@redis.hget("bar__cosmos__metric", "")).to eql(nil)
      end

      it "single value generate summary metrics based on samples" do
        @metric.add_sample(name: "test", value: 2, labels: { "is" => true })
        expect(@metric.items.empty?).to eql(false)
        @metric.output
        expect(@metric.items.empty?).to eql(false)
        expect(@redis.hget("bar__cosmos__metric", "foo")).not_to eql(nil)
      end

      it "multivalue generate summary metrics based on samples" do
        @metric.add_sample(name: "test", value: 2, labels: { "is" => true })
        @metric.add_sample(name: "test", value: 2, labels: { "is" => false })
        expect(@metric.items.empty?).to eql(false)
        @metric.output
        expect(@redis.hget("bar__cosmos__metric", "foo")).not_to eql(nil)
      end
    end
  end
end
