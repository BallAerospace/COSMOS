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
require 'cosmos/models/narrative_model'

module Cosmos

  describe NarrativeModel do
    before(:each) do
      mock_redis()
    end

    def generate_event(start:, scope: 'scope', description: nil, stop: 1.0)
      dt = DateTime.now.new_offset(0)
      start_time = dt + (start / 24.0)
      end_time = dt + ((start + stop) / 24.0)
      description = "Another test!!!" if description.nil?
      NarrativeModel.new(
        scope: scope,
        start: start_time.strftime("%s").to_i,
        stop: end_time.strftime("%s").to_i,
        color: '#FF0000',
        description: description,
      )
    end

    describe "self.get" do
      it "returns all between X and Y" do
        event = generate_event(start: 1.5)
        event.create()
        event = generate_event(start: 5.0)
        event.create()
        dt = DateTime.now.new_offset(0)
        start = (dt + (1 / 24.0)).strftime("%s").to_i
        stop = (dt + (3 / 24.0)).strftime("%s").to_i
        array = NarrativeModel.get(
          scope: 'scope',
          start: start,
          stop: stop,
        )
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(1)
        expect(array[0]["start"]).not_to be_nil
        expect(array[0]["stop"]).not_to be_nil
      end
    end

    describe "self.all" do
      it "returns all the activities" do
        event = generate_event(start: 2.0)
        event.create()
        event = generate_event(start: 4.0)
        event.create()
        all = NarrativeModel.all(scope: 'scope')
        expect(all.empty?).to eql(false)
        expect(all.length).to eql(2)
        expect(all[0]["start"]).not_to be_nil
        expect(all[0]["stop"]).not_to be_nil
        expect(all[1]["start"]).not_to be_nil
        expect(all[1]["stop"]).not_to be_nil
      end
    end

    describe "self.start" do
      it "returns a NarrativeModel at the start" do
        event = generate_event(start: 1.0)
        event.create()
        model = NarrativeModel.score(score: event.start, scope: 'scope')
        expect(model["start"]).to eql(event.start)
        expect(model["stop"]).to eql(event.stop)
        expect(model["description"]).to include("test")
      end
    end

    describe "self.count" do
      it "returns the count of the timeline" do
        event = generate_event(start: 1.0)
        event.create()
        event = generate_event(start: 2.5)
        event.create()
        count = NarrativeModel.count(scope: 'scope')
        expect(count).to eql(2)
      end
    end

    describe "self.destroy" do
      it "removes the score form of the timeline" do
        event = generate_event(start: 2.0)
        event.create()
        ret = NarrativeModel.destroy(score: event.start, scope: 'scope')
        expect(ret).to eql(1)
        count = NarrativeModel.count(scope: 'scope')
        expect(count).to eql(0)
      end
    end

    describe "self.range_destroy" do
      it "removes multiple members form of the timeline" do
        event = generate_event(start: 0.5)
        event.create()
        event = generate_event(start: 2.0)
        event.create()
        dt = DateTime.now.new_offset(0)
        min_score = (dt + (0.5 / 24.0)).strftime("%s").to_i
        max_score = (dt + (3.0 / 24.0)).strftime("%s").to_i
        ret = NarrativeModel.range_destroy(
          scope: 'scope',
          min: min_score,
          max: max_score
        )
        expect(ret).to eql(2)
        count = NarrativeModel.count(scope: 'scope')
        expect(count).to eql(0)
      end
    end

    describe "time parse" do
      it "raises error due to invalid time" do
        expect {
          NarrativeModel.new(
            scope: 'scope',
            start: "foo",
            stop: "bar",
            color: "#FF0000",
            description: "bad start and stop input"
          )
        }.to raise_error(NarrativeInputError)
      end
    end

    describe "time duration" do
      it "raises error due to event start and end are the same time" do
        start = Time.now.to_i
        model = NarrativeModel.new(
          scope: 'scope',
          start: start,
          stop: start,
          color: "#FF0000",
          description: "incorrect time"
        )
        expect {
          model.create()
        }.to raise_error(NarrativeInputError)
      end
    end

    describe "time entry" do
      it "raises error due to event start is after stop" do
        dt_now = DateTime.now
        start = (dt_now + (1.5 / 24.0)).strftime('%s').to_i
        stop = (dt_now + (1.0 / 24.0)).strftime('%s').to_i
        model = NarrativeModel.new(
          scope: 'scope',
          start: start,
          stop: stop,
          color: '#FF0000',
          description: 'more bad input',
        )
        expect {
          model.create()
        }.to raise_error(NarrativeInputError)
      end
    end

    describe "update stop" do
      it "update the input parameters" do
        event = generate_event(start: 1.0)
        event.create()
        stop = event.stop + 100
        event.update(start: event.start, stop: stop, color: "#00FF00", description: "update")
        expect(event.start).to eql(event.start)
        expect(event.stop).to eql(stop)
        expect(event.description).not_to include("test")
      end
    end

    describe "update both start and stop" do
      it "update the input parameters" do
        event = generate_event(start: 1.0)
        event.create()
        og_start = event.start
        new_start = event.start + 100
        new_stop = event.stop + 100
        event.update(start: new_start, stop: new_stop, color: "#00FF00", description: "update")
        expect(event.start).to eql(new_start)
        expect(event.stop).to eql(new_stop)
        expect(event.description).not_to include("test")
        ret = NarrativeModel.score(score: og_start, scope: 'scope')
        expect(ret).to be_nil
      end
    end

    describe "notify" do
      it "update the top of a change to the timeline" do
        event = generate_event(start: 1.0)
        event.notify(kind: "new")
      end
    end

    describe "destroy" do
      it "the model to remove it" do
        event = generate_event(start: 1.0)
        event.create
        event.destroy
        event = NarrativeModel.score(score: event.start, scope: 'scope')
        expect(event).to eql(nil)
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        event = generate_event(start: 1.0)
        json = event.as_json
        expect(json["start"]).to eql(event.start)
        expect(json["stop"]).to eql(event.stop)
        expect(json["description"]).not_to be_nil
      end
    end

    describe "from_json" do
      it "encodes all the input parameters" do
        event = generate_event(start: 1.0)
        model_hash = event.as_json
        json = JSON.generate(model_hash)
        new_event = NarrativeModel.from_json(json, scope: 'scope')
        expect(event.start).to eql(new_event.start)
        expect(event.stop).to eql(new_event.stop)
        expect(event.color).to eql(new_event.color)
        expect(event.description).to eql(new_event.description)
      end
    end
  end
end
