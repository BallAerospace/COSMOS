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

require 'spec_helper'
require 'cosmos/models/sorted_model'

module Cosmos
  describe SortedModel do
    before(:each) do
      mock_redis()
    end

    describe "as_json, self.from_json" do
      it "round trips the json representation" do
        time = Time.now
        model = SortedModel.new(scope: 'DEFAULT', value: 123, plugin: true, updated_at: time)
        json = model.as_json
        expect(json['name']).to eql '123' # Name is a String rep of the value parameter
        expect(json['value']).to eql 123
        expect(json['scope']).to eql 'DEFAULT'
        expect(json['updated_at']).to eql time
        expect(json['plugin']).to eql true
        model2 = SortedModel.from_json(JSON.generate(json), scope: "DEFAULT")
        expect(model2).to be_a SortedModel
        json2 = model2.as_json
        expect(json['name']).to eql json2['name']
        expect(json['value']).to eql json2['value']
        expect(json['scope']).to eql json2['scope']
        # TODO: Times don't seem to be round tripping
        # expect(json['updated_at']).to eql json2['updated_at']
        expect(json['plugin']).to eql json2['plugin']
      end
    end

    describe "create" do
      it "stores the value" do
        model = SortedModel.new(scope: 'DEFAULT', value: 100)
        model.create
        data = Store.zrange(SortedModel.pk('DEFAULT'), 0, 1)
        result = JSON.parse(data[0]) # zrange returns array
        expect(result['value']).to eql 100
      end

      it "validates the value for overlap" do
        model = SortedModel.new(scope: 'DEFAULT', value: 100)
        model.create
        expect { model.create }.to raise_error(SortedModel::SortedOverlapError)
      end
    end

    describe "self.get" do
      it "returns data" do
        time1 = Time.now
        model = SortedModel.new(scope: 'DEFAULT', value: 100, updated_at: time1)
        model.create()
        time2 = Time.now + 100
        model = SortedModel.new(scope: 'DEFAULT', value: 200, updated_at: time2)
        model.create()
        json = SortedModel.get(scope: 'DEFAULT', value: 100)
        expect(json["value"]).to eql 100
        # TODO: Times don't seem to be round tripping
        # expect(json["updated_at"]).to eql time1
        json = SortedModel.get(scope: 'DEFAULT', value: 200)
        expect(json["value"]).to eql 200
        # TODO: Times don't seem to be round tripping
        # expect(json["updated_at"]).to eql time2
        json = SortedModel.get(scope: 'DEFAULT', value: 300)
        expect(json).to be_nil
      end
    end

    describe "self.all" do
      it "returns all entries" do
        model = SortedModel.new(scope: 'DEFAULT', value: 100)
        model.create()
        model = SortedModel.new(scope: 'DEFAULT', value: 200)
        model.create()
        all = SortedModel.all(scope: 'DEFAULT')
        expect(all.empty?).to eql(false)
        expect(all.length).to eql(2)
        expect(all[0]["value"]).to eql 100
        expect(all[1]["value"]).to eql 200
      end
    end

    describe "self.range" do
      it "validates start and stop" do
        expect { SortedModel.range(scope: 'DEFAULT', start: 100, stop: 99) }.to raise_error(SortedModel::SortedInputError)
      end

      it "returns data between X and Y" do
        model = SortedModel.new(scope: 'DEFAULT', value: 100)
        model.create()
        model = SortedModel.new(scope: 'DEFAULT', value: 200)
        model.create()
        array = SortedModel.range(scope: 'DEFAULT', start: 100, stop: 200)
        expect(array.length).to eql(2)
        expect(array[0]["value"]).to eql 100
        expect(array[1]["value"]).to eql 200

        array = SortedModel.range(scope: 'DEFAULT', start: 101, stop: 199)
        expect(array.empty?).to eql(true)

        array = SortedModel.range(scope: 'DEFAULT', start: 150, stop: 250)
        expect(array.length).to eql(1)
        expect(array[0]["value"]).to eql 200
      end
    end

    describe "self.count" do
      it "returns the count/number of chronicles" do
        10.times do |x|
          model = SortedModel.new(scope: 'DEFAULT', value: x)
          model.create()
        end
        count = SortedModel.count(scope: 'DEFAULT')
        expect(count).to eql(10)
      end
    end

    describe "self.destroy" do
      it "removes the score from the chronicle" do
        model = SortedModel.new(scope: 'DEFAULT', value: 100)
        model.create()
        ret = SortedModel.destroy(scope: 'DEFAULT', value: 100)
        expect(ret).to eql(1)
        count = SortedModel.count(scope: 'DEFAULT')
        expect(count).to eql(0)
        ret = SortedModel.destroy(scope: 'DEFAULT', value: 100)
        expect(ret).to eql(0)
      end
    end

    describe "self.range_destroy" do
      it "removes multiple members form of the timeline" do
        model = SortedModel.new(scope: 'DEFAULT', value: 100)
        model.create
        model = SortedModel.new(scope: 'DEFAULT', value: 200)
        model.create
        ret = SortedModel.range_destroy(
          scope: 'DEFAULT',
          start: 100,
          stop: 200
        )
        expect(ret).to eql(2)
        expect(SortedModel.count(scope: 'DEFAULT')).to eql(0)
      end
    end
  end
end
