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
require 'openc3/models/sorted_model'

module OpenC3
  describe SortedModel do
    before(:each) do
      mock_redis()
    end

    def create_model(start: Time.now.to_i, scope: 'DEFAULT')
      model = SortedModel.new(
        scope: scope,
        start: start,
      )
      model.create()
      model
    end

    describe "self.pk" do
      it "returns the primary key" do
        expect(SortedModel.pk('DEFAULT')).to eql("DEFAULT__SORTED")
      end
    end

    describe "self.get_current_value" do
      it "get the current sorted entry (latest before Time.now)" do
        now = Time.now.to_i
        create_model(start: now + 10) # future
        create_model(start: now)
        create_model(start: now - 10)
        create_model(start: now - 20)
        json = SortedModel.get_current_value(
          scope: 'DEFAULT'
        )
        hash = JSON.parse(json, :allow_nan => true, :create_additions => true)
        expect(hash['start']).to eql(now)
      end
    end

    describe "self.get" do
      it "returns a sorted item" do
        time1 = Time.now
        model = SortedModel.new(scope: 'DEFAULT', start: 100, updated_at: time1)
        model.create()
        time2 = Time.now + 100
        model = SortedModel.new(scope: 'DEFAULT', start: 200, updated_at: time2)
        model.create()
        json = SortedModel.get(scope: 'DEFAULT', start: 100)
        expect(json["start"]).to eql 100
        # TODO: Times don't seem to be round tripping
        # expect(json["updated_at"]).to eql time1
        json = SortedModel.get(scope: 'DEFAULT', start: 200)
        expect(json["start"]).to eql 200
        # TODO: Times don't seem to be round tripping
        # expect(json["updated_at"]).to eql time2
        json = SortedModel.get(scope: 'DEFAULT', start: 300)
        expect(json).to be_nil
      end
    end

    describe "self.all" do
      it "returns all entries" do
        create_model(start: 100)
        create_model(start: 200)
        create_model(start: 300)
        create_model(start: 400)
        all = SortedModel.all(scope: 'DEFAULT')
        expect(all.length).to eql(4)
        expect(all[3]["start"]).to eql 100
        expect(all[2]["start"]).to eql 200
        expect(all[1]["start"]).to eql 300
        expect(all[0]["start"]).to eql 400
      end

      # TODO: mock_redis currently doesn't implement limit
      # it "limits the results" do
      #   now = Time.now.to_i
      #   create_model(start: 100)
      #   create_model(start: 200)
      #   create_model(start: 300)
      #   create_model(start: 400)
      #   all = SortedModel.all(scope: 'DEFAULT', limit: 2)
      #   expect(all.length).to eql(2)
      #   expect(all[0]["start"]).to eql 100
      #   expect(all[1]["start"]).to eql 200
      # end
    end

    describe "self.range" do
      it "validates start and stop" do
        expect { SortedModel.range(scope: 'DEFAULT', start: 100, stop: 99) }.to raise_error(SortedInputError)
      end

      it "returns items between start and stop" do
        model = SortedModel.new(scope: 'DEFAULT', start: 100)
        model.create()
        model = SortedModel.new(scope: 'DEFAULT', start: 200)
        model.create()
        array = SortedModel.range(scope: 'DEFAULT', start: 100, stop: 200)
        expect(array.length).to eql(2)
        expect(array[0]["start"]).to eql 100
        expect(array[1]["start"]).to eql 200

        array = SortedModel.range(scope: 'DEFAULT', start: 101, stop: 199)
        expect(array.empty?).to eql(true)

        array = SortedModel.range(scope: 'DEFAULT', start: 150, stop: 250)
        expect(array.length).to eql(1)
        expect(array[0]["start"]).to eql 200
      end
    end

    describe "self.count" do
      it "returns the count/number of sorted items" do
        10.times do |x|
          model = SortedModel.new(scope: 'DEFAULT', start: x)
          model.create()
        end
        count = SortedModel.count(scope: 'DEFAULT')
        expect(count).to eql(10)
      end
    end

    describe "self.destroy" do
      it "removes the sorted item" do
        model = SortedModel.new(scope: 'DEFAULT', start: 100)
        model.create()
        ret = SortedModel.destroy(scope: 'DEFAULT', start: 100)
        expect(ret).to eql(1)
        count = SortedModel.count(scope: 'DEFAULT')
        expect(count).to eql(0)
        ret = SortedModel.destroy(scope: 'DEFAULT', start: 100)
        expect(ret).to eql(0)
      end
    end

    describe "self.range_destroy" do
      it "removes multiple sorted items" do
        model = SortedModel.new(scope: 'DEFAULT', start: 100)
        model.create
        model = SortedModel.new(scope: 'DEFAULT', start: 200)
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

    describe "initialize" do
      it "raises error due to invalid start" do
        expect { create_model(start: 'foo') }.to raise_error(SortedInputError)
        expect { create_model(start: 5.5) }.to raise_error(SortedInputError)
        expect { create_model(start: -1) }.to raise_error(SortedInputError)
      end

      it "allows future start times" do
        future = Time.now.to_i + 1000
        create_model(start: future)
      end

      it "raises error due to start overlap" do
        now = Time.now.to_i
        create_model(start: now)
        expect { create_model(start: now) }.to raise_error(SortedOverlapError)
      end
    end

    describe "create" do
      it "stores the start" do
        create_model(start: 100)
        data = Store.zrange(SortedModel.pk('DEFAULT'), 0, 1)
        result = JSON.parse(data[0], :allow_nan => true, :create_additions => true) # zrange returns array
        expect(result['start']).to eql 100
      end

      it "validates the start for overlap" do
        model = create_model(start: 100)
        expect { model.create }.to raise_error(SortedOverlapError)
      end
    end

    describe "update" do
      it "updates the sorted item" do
        now = Time.now.to_i
        model = create_model(start: now)
        expect(SortedModel.count(scope: 'DEFAULT')).to eql(1)
        model.update(
          start: now + 10,
        )
        expect(SortedModel.count(scope: 'DEFAULT')).to eql(1)
        hash = SortedModel.get(scope: 'DEFAULT', start: now + 10)
        expect(hash['start']).to eql(now + 10)
      end
    end

    describe "destroy" do
      it "removes the sorted item" do
        model = create_model()
        expect(SortedModel.count(scope: 'DEFAULT')).to eql(1)
        model.destroy
        expect(SortedModel.count(scope: 'DEFAULT')).to eql(0)
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        now = Time.now.to_i
        model = create_model(start: now)
        json = model.as_json(:allow_nan => true)
        expect(json["start"]).to eql(now)
        expect(json['type']).to eql("sorted")
      end
    end

    describe "from_json" do
      it "encodes all the input parameters" do
        model = create_model()
        hash = model.as_json(:allow_nan => true)
        json = JSON.generate(hash)
        new_model = SortedModel.from_json(json, scope: 'DEFAULT')
        expect(new_model).to be_a SortedModel
        expect(new_model.start).to eql(hash['start'])
      end
    end
  end
end
