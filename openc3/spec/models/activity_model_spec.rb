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
require 'openc3/models/activity_model'

module OpenC3
  describe ActivityModel do
    before(:each) do
      mock_redis()
    end

    def generate_activity(name:, scope:, start:, kind: "cmd", stop: 1.0)
      dt = DateTime.now.new_offset(0)
      start_time = dt + (start / 24.0)
      end_time = dt + ((start + stop) / 24.0)
      data = { "test" => "test" }
      ActivityModel.new(
        name: name,
        scope: scope,
        start: start_time.strftime("%s").to_i,
        stop: end_time.strftime("%s").to_i,
        kind: kind,
        data: data
      )
    end

    describe "self.activites" do
      it "returns metrics for the next hour" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1)
        activity.create()
        activity = generate_activity(name: name, scope: scope, start: 10)
        activity.create()
        array = ActivityModel.activities(name: name, scope: scope)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(1)
        expect(array[0].kind).to eql("cmd")
        expect(array[0].start).not_to be_nil
        expect(array[0].stop).not_to be_nil
      end
    end

    describe "self.get" do
      it "returns all metrics between X and Y" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.5)
        activity.create()
        activity = generate_activity(name: name, scope: scope, start: 5.0)
        activity.create()
        dt = DateTime.now.new_offset(0)
        start = (dt + (1 / 24.0)).strftime("%s").to_i
        stop = (dt + (3 / 24.0)).strftime("%s").to_i
        array = ActivityModel.get(name: name, scope: scope, start: start, stop: stop)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(1)
        expect(array[0]["kind"]).to eql("cmd")
        expect(array[0]["start"]).not_to be_nil
        expect(array[0]["stop"]).not_to be_nil
      end
    end

    describe "self.all" do
      it "returns all the activities" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 2.0)
        activity.create()
        activity = generate_activity(name: name, scope: scope, start: 4.0)
        activity.create()
        all = ActivityModel.all(name: name, scope: scope)
        expect(all.empty?).to eql(false)
        expect(all.length).to eql(2)
        expect(all[0]["kind"]).not_to be_nil
        expect(all[0]["start"]).not_to be_nil
        expect(all[0]["stop"]).not_to be_nil
        expect(all[1]["kind"]).not_to be_nil
        expect(all[1]["start"]).not_to be_nil
        expect(all[1]["stop"]).not_to be_nil
      end
    end

    describe "self.start" do
      it "returns a ActivityModel at the start" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0)
        activity.create()
        model = ActivityModel.score(name: name, scope: scope, score: activity.start)
        expect(model.fulfillment).to eql(false)
        expect(model.start).to eql(activity.start)
        expect(model.stop).to eql(activity.stop)
        expect(model.data).to include("test")
        expect(model.events.empty?).to eql(false)
        expect(model.events.length).to eql(1)
      end
    end

    describe "self.count" do
      it "returns the count of the timeline" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0)
        activity.create()
        activity = generate_activity(name: name, scope: scope, start: 2.5)
        activity.create()
        count = ActivityModel.count(name: name, scope: scope)
        expect(count).to eql(2)
      end
    end

    describe "self.destroy" do
      it "removes the score form of the timeline" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 2.0)
        activity.create()
        ret = ActivityModel.destroy(name: name, scope: scope, score: activity.start)
        expect(ret).to eql(1)
        count = ActivityModel.count(name: name, scope: scope)
        expect(count).to eql(0)
      end
    end

    describe "self.range_destroy" do
      it "removes multiple members form of the timeline" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 0.5)
        activity.create()
        activity = generate_activity(name: name, scope: scope, start: 2.0)
        activity.create()
        dt = DateTime.now.new_offset(0)
        min_score = (dt + (0.5 / 24.0)).strftime("%s").to_i
        max_score = (dt + (3.0 / 24.0)).strftime("%s").to_i
        ret = ActivityModel.range_destroy(name: name, scope: scope, min: min_score, max: max_score)
        expect(ret).to eql(2)
        count = ActivityModel.count(name: name, scope: scope)
        expect(count).to eql(0)
      end
    end

    describe "model.create" do
      it "raises error due to overlap starts inside A and ends inside A" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0, stop: 1.0)
        activity.create()
        model = generate_activity(name: name, scope: scope, start: 1.1, stop: 0.8)
        expect {
          model.create()
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "model.create" do
      it "raises error due to overlap starts before A and ends before A" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0, stop: 1.0)
        activity.create()
        model = generate_activity(name: name, scope: scope, start: 0.5, stop: 1.0)
        expect {
          model.create()
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "model.create" do
      it "raises error due to overlap starts inside A and ends outside A" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0, stop: 1.0)
        activity.create()
        model = generate_activity(name: name, scope: scope, start: 1.5, stop: 1.5)
        expect {
          model.create()
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "model.create" do
      it "raises error due to overlap starts before A and ends after A" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0, stop: 1.0)
        activity.create()
        model = generate_activity(name: name, scope: scope, start: 0.5, stop: 1.5)
        expect {
          model.create()
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "model.create" do
      it "raises error due to overlap starts before A and ends outside A inside a second activity" do
        name = "foobar"
        scope = "scope"
        foo = generate_activity(name: name, scope: scope, start: 1.0, stop: 0.5)
        foo.create()
        bar = generate_activity(name: name, scope: scope, start: 2.0, stop: 0.5)
        bar.create()
        activity = generate_activity(name: name, scope: scope, start: 0.5, stop: 1.7)
        expect {
          activity.create()
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "model.create" do
      it "raises error due to overlap single " do
        name = "foobar"
        scope = "scope"
        foo = generate_activity(name: name, scope: scope, start: 1.0, stop: 0.5)
        foo.create()
        bar = generate_activity(name: name, scope: scope, start: 2.0, stop: 0.5)
        bar.create()
        activity = generate_activity(name: name, scope: scope, start: 1.0, stop: 0.5)
        expect {
          activity.create()
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "time parse" do
      it "raises error due to invalid time" do
        name = "foobar"
        scope = "scope"
        expect {
          ActivityModel.new(name: name, scope: scope, start: "foo", stop: "bar", kind: "cmd", data: {})
        }.to raise_error(ActivityInputError)
      end
    end

    describe "time duration" do
      it "raises error due to event start and end are the same time" do
        name = "foobar"
        scope = "scope"
        start = Time.now.to_i
        model = ActivityModel.new(name: name, scope: scope, start: start, stop: start, kind: "cmd", data: {})
        expect {
          model.create()
        }.to raise_error(ActivityInputError)
      end
    end

    describe "time duration" do
      it "raises error due to event longer then 24h" do
        name = "foobar"
        scope = "scope"
        dt_now = DateTime.now
        start = (dt_now + (1.0 / 24.0)).strftime("%s").to_i
        stop = (dt_now + (25.0 / 24.0)).strftime("%s").to_i
        activity = ActivityModel.new(name: name, scope: scope, start: start, stop: stop, kind: "cmd", data: {})
        expect {
          activity.create()
        }.to raise_error(ActivityInputError)
      end
    end

    describe "time entry" do
      it "raises error due to event start is after stop" do
        name = "foobar"
        scope = "scope"
        dt_now = DateTime.now
        start = (dt_now + (1.5 / 24.0)).strftime("%s").to_i
        stop = (dt_now + (1.0 / 24.0)).strftime("%s").to_i
        model = ActivityModel.new(name: name, scope: scope, start: start, stop: stop, kind: "cmd", data: {})
        expect {
          model.create()
        }.to raise_error(ActivityInputError)
      end
    end

    describe "update error" do
      it "raises error due to not created yet" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 0.5, stop: 1.0)
        start = activity.start + 10
        stop = activity.stop + 10
        expect {
          activity.update(start: start, stop: stop, kind: "error", data: {})
        }.to raise_error(ActivityError)
      end
    end

    describe "update error" do
      it "raises error due to update is overlapping time point" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 0.5, stop: 1.0)
        activity.create()
        model = generate_activity(name: name, scope: scope, start: 2.0)
        model.create()
        new_start = activity.start + 3600
        new_stop = activity.stop + 3600
        expect {
          activity.update(start: new_start, stop: new_stop, kind: "error", data: {})
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "update stop" do
      it "update the input parameters" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0)
        activity.create()
        stop = activity.stop + 100
        activity.update(start: activity.start, stop: stop, kind: "foo", data: {})
        expect(activity.start).to eql(activity.start)
        expect(activity.stop).to eql(stop)
        expect(activity.kind).to eql("foo")
        expect(activity.data).not_to be_nil
        expect(activity.data).not_to include("test")
        expect(activity.events.empty?).to eql(false)
        expect(activity.events.length).to eql(2)
      end
    end

    describe "update both start and stop" do
      it "update the input parameters" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0)
        activity.create()
        og_start = activity.start
        new_start = activity.start + 100
        new_stop = activity.stop + 100
        activity.update(start: new_start, stop: new_stop, kind: "foo", data: {})
        expect(activity.start).to eql(new_start)
        expect(activity.stop).to eql(new_stop)
        expect(activity.kind).to eql("foo")
        expect(activity.data).not_to include("test")
        ret = ActivityModel.score(name: name, scope: scope, score: og_start)
        expect(ret).to be_nil
      end
    end

    describe "commit" do
      it "update the events and commit them to redis" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0)
        expect(activity.fulfillment).to eql(false)
        activity.commit(status: "test", message: "message", fulfillment: true)
        expect(activity.fulfillment).to eql(true)
        activity = ActivityModel.score(name: name, scope: scope, score: activity.start)
        expect(activity.fulfillment).to eql(true)
        valid_commit = false
        activity.events.each do |event|
          if event["event"] == "test"
            expect(event["message"]).to eql("message")
            expect(event["commit"]).to eql(true)
            valid_commit = true
          end
        end
        expect(valid_commit).to eql(true)
      end
    end

    describe "notify" do
      it "update the top of a change to the timeline" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0)
        activity.notify(kind: "new")
      end
    end

    describe "destroy" do
      it "the model to remove it" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0)
        activity.create
        activity.destroy
        activity = ActivityModel.score(name: name, scope: scope, score: activity.start)
        expect(activity).to eql(nil)
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0)
        json = activity.as_json(:allow_nan => true)
        expect(json["duration"]).to eql(activity.duration)
        expect(json["start"]).to eql(activity.start)
        expect(json["stop"]).to eql(activity.stop)
        expect(json["kind"]).to eql(activity.kind)
        expect(json["data"]).not_to be_nil
      end
    end

    describe "from_json" do
      it "encodes all the input parameters" do
        name = "foobar"
        scope = "scope"
        activity = generate_activity(name: name, scope: scope, start: 1.0)
        model_hash = activity.as_json(:allow_nan => true)
        json = JSON.generate(model_hash)
        new_activity = ActivityModel.from_json(json, name: name, scope: scope)
        expect(activity.duration).to eql(new_activity.duration)
        expect(activity.start).to eql(new_activity.start)
        expect(activity.stop).to eql(new_activity.stop)
        expect(activity.kind).to eql(new_activity.kind)
        expect(activity.data).to eql(new_activity.data)
      end
    end
  end
end
