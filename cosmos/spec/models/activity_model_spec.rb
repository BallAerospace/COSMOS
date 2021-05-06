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
require 'cosmos/models/activity_model'

module Cosmos

  describe ActivityModel do
    before(:each) do
      mock_redis()
    end

    describe "self.activites" do
      it "returns metrics for the next hour" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        now = DateTime.now.new_offset(0)
        start_time = (now + (30.0/86400.0)).to_s
        end_time = (now + (100.0/86400.0)).to_s
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data)
        model.create()
        new_start_time = (now + (2.0/24.0)).to_s
        new_end_time = (now + (2.1/24.0)).to_s
        model = ActivityModel.new(name: name, scope: scope, start_time: new_start_time, end_time: new_end_time, kind: "cmd", data: data)
        model.create()
        array = ActivityModel.activities(name: name, scope: scope)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(1)
        expect(array[0].kind).to eql("cmd")
        expect(array[0].start_time).to eql(start_time)
        expect(array[0].end_time).to eql(end_time)
      end
    end

    describe "self.get" do
      it "returns all metrics between X and Y" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "error", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T02:02:00+00:00"
        end_time = "2031-04-16T02:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        search_start_time = "2031-04-16T02:01:00+00:00"
        search_end_time = "2031-04-16T02:03:00+00:00"
        array = ActivityModel.get(name: name, scope: scope, start_time: search_start_time, end_time: search_end_time)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(1)
        expect(array[0]["kind"]).to eql("cmd")
        expect(array[0]["start_time"]).to eql(start_time)
        expect(array[0]["end_time"]).to eql(end_time)
      end
    end

    describe "self.all" do
      it "returns all the activities" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T02:02:00+00:00"
        end_time = "2031-04-16T02:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        all = ActivityModel.all(name: name, scope: scope)
        expect(all.empty?).to eql(false)
        expect(all.length).to eql(2)
        expect(all[0]["kind"]).not_to be_nil
        expect(all[0]["score"]).not_to be_nil
        expect(all[0]["end_time"]).not_to be_nil
        expect(all[1]["kind"]).not_to be_nil
        expect(all[1]["score"]).not_to be_nil
        expect(all[1]["end_time"]).not_to be_nil
      end
    end

    describe "self.score" do
      it "returns a ActivityModel at the score" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        score = DateTime.parse(start_time).strftime("%s").to_i
        model = ActivityModel.score(name: name, scope: scope, score: score)
        expect(model.fulfillment).to eql(false)
        expect(model.start_time).to eql(start_time)
        expect(model.end_time).to eql(end_time)
        expect(model.data).to include("path")
        expect(model.events.empty?).to eql(false)
        expect(model.events.length).to eql(1)
      end
    end

    describe "self.count" do
      it "returns the count of the timeline" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T02:02:00+00:00"
        end_time = "2031-04-16T02:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        all = ActivityModel.count(name: name, scope: scope)
        expect(all).to eql(2)
      end
    end

    describe "self.destroy" do
      it "removes the score form of the timeline" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        score = DateTime.parse(start_time).strftime("%s").to_i
        ret = ActivityModel.destroy(name: name, scope: scope, score: score)
        expect(ret).to eql(1)
        count = ActivityModel.count(name: name, scope: scope)
        expect(count).to eql(0)
      end
    end

    describe "self.range_destroy" do
      it "removes multiple members form of the timeline" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T01:10:00+00:00"
        end_time = "2031-04-16T01:20:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        delete_start_time = "2031-04-16T01:01:00+00:00"
        delete_end_time = "2031-04-16T01:15:00+00:00"
        min_score = DateTime.parse(delete_start_time).strftime("%s").to_i
        max_score = DateTime.parse(delete_end_time).strftime("%s").to_i
        ret = ActivityModel.range_destroy(name: name, scope: scope, min: min_score, max: max_score)
        expect(ret).to eql(2)
        all = ActivityModel.count(name: name, scope: scope)
        expect(all).to eql(0)
      end
    end

    describe "model.create" do
      it "raises error due to overlap starts after A and ends inside A" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:30:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T01:10:00+00:00"
        end_time = "2031-04-16T01:45:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        expect{
          model.create()
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "model.create" do
      it "raises error due to overlap starts before A and ends before A" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:30:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T01:00:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        expect{
          model.create()
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "model.create" do
      it "raises error due to overlap starts inside A and ends inside A" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:01:00+00:00"
        end_time = "2031-04-16T01:31:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T01:10:00+00:00"
        end_time = "2031-04-16T01:20:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        expect{
          model.create()
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "model.create" do
      it "raises error due to overlap starts outside A and ends outside A" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:05:00+00:00"
        end_time = "2031-04-16T01:35:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T01:01:00+00:00"
        end_time = "2031-04-16T01:41:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        expect{
          model.create()
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "model.create" do
      it "raises error due to overlap starts outside A and ends outside A with a second activity" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:04:00+00:00"
        end_time = "2031-04-16T01:04:55+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T01:05:00+00:00"
        end_time = "2031-04-16T01:35:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T01:01:00+00:00"
        end_time = "2031-04-16T01:41:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        expect{
          model.create()
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "model.create" do
      it "raises error due to overlap single " do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:01:00+00:00"
        end_time = "2031-04-16T01:02:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:03:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T01:02:30+00:00"
        end_time = "2031-04-16T01:03:30+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        expect{
          model.create()
        }.to raise_error(ActivityOverlapError)
      end
    end

    describe "time parse" do
      it "raises error due to invalid time" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        expect{
          ActivityModel.new(name: name, scope: scope, start_time: "foo", end_time: "bar", kind: "cmd", data: data, events: nil)
        }.to raise_error(ActivityInputError)
      end
    end

    describe "time duration" do
      it "raises error due to event start and end are the same time" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: start_time, kind: "cmd", data: data, events: nil)
        expect{
          model.create()
        }.to raise_error(ActivityInputError)
      end
    end

    describe "time duration" do
      it "raises error due to event longer then 24h" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-17T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        expect{
          model.create()
        }.to raise_error(ActivityInputError)
      end
    end

    describe "time entry" do
      it "raises error due to event start is after end" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2021-04-17T01:10:00+00:00"
        end_time = "2031-04-16T01:02:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        expect{
          model.create()
        }.to raise_error(ActivityInputError)
      end
    end

    describe "update error" do
      it "raises error due to not created yet" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "error", data: data, events: nil)
        expect{
          model.update(start_time: start_time, end_time: end_time, kind: "error", data: data)
        }.to raise_error(ActivityError)
      end
    end

    describe "update error" do
      it "raises error due to update is overlapping time point" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "error", data: data, events: nil)
        model.create()
        start_time = "2031-04-16T00:02:00+00:00"
        end_time = "2031-04-16T00:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        new_start_time = "2031-04-16T00:01:00+00:00"
        new_end_time = "2031-04-16T01:10:00+00:00"
        expect{
          model.update(start_time: new_start_time, end_time: new_end_time, kind: "error", data: data)
        }.to raise_error(ActivityOverlapError)
        search_start_time = "2031-04-16T00:01:00+00:00"
        search_end_time = "2031-04-16T00:03:00+00:00"
        array = ActivityModel.get(name: name, scope: scope, start_time: search_start_time, end_time: search_end_time)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(1)
        expect(array[0]["kind"]).to eql("cmd")
        expect(array[0]["start_time"]).to eql(start_time)
        expect(array[0]["end_time"]).to eql(end_time)
      end
    end

    describe "update end_time" do
      it "update the input parameters" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        end_time = "2031-04-16T01:20:00+00:00"
        model.update(start_time: start_time, end_time: end_time, kind: "foo", data: data)
        expect(model.start_time).to eql(start_time)
        expect(model.end_time).to eql(end_time)
        expect(model.kind).to eql("foo")
        expect(model.data).not_to be_nil
        expect(model.data).to include("path")
        expect(model.events.empty?).to eql(false)
        expect(model.events.length).to eql(2)
      end
    end

    describe "update both start_time and end_time" do
      it "update the input parameters" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        new_start_time = "2031-04-16T01:10:00+00:00"
        new_end_time = "2031-04-16T01:20:00+00:00"
        model.update(start_time: new_start_time, end_time: new_end_time, kind: "foo", data: data)
        expect(model.start_time).to eql(new_start_time)
        expect(model.end_time).to eql(new_end_time)
        expect(model.kind).to eql("foo")
        expect(model.data).not_to be_nil
        score = DateTime.parse(start_time).strftime("%s").to_i
        ret = ActivityModel.score(name: name, scope: scope, score: score)
        expect(ret).to be_nil
      end
    end

    describe "commit" do
      it "update the events and commit them to redis" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        score = DateTime.parse(start_time).strftime("%s").to_i
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create()
        expect(model.fulfillment).to eql(false)
        model.commit(status: "test", message: "message", fulfillment: true)
        expect(model.fulfillment).to eql(true)
        activity = ActivityModel.score(name: name, scope: scope, score: score)
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
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.notify(kind: "new")
      end
    end

    describe "destroy" do
      it "the model to remove it" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        score = DateTime.parse(start_time).strftime("%s").to_i
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model.create
        model.destroy
        activity = ActivityModel.score(name: name, scope: scope, score: score)
        expect(activity).to eql(nil)
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        start_check = DateTime.parse(start_time).strftime("%s").to_i
        end_check = DateTime.parse(end_time).strftime("%s").to_i
        duration = end_check - start_check
        model = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        json = model.as_json
        expect(json["score"]).to eql(start_check)
        expect(json["duration"]).to eql(duration)
        expect(json["start_time"]).to eql(start_time)
        expect(json["end_time"]).to eql(end_time)
        expect(json["kind"]).to eql("cmd")
        expect(json["data"]).not_to be_nil
      end
    end

    describe "from_json" do
      it "encodes all the input parameters" do
        name = "foobar"
        scope = "scope"
        data = {"path" => "/file/path/file.txt"}
        start_time = "2031-04-16T01:02:00+00:00"
        end_time = "2031-04-16T01:10:00+00:00"
        model_obj = ActivityModel.new(name: name, scope: scope, start_time: start_time, end_time: end_time, kind: "cmd", data: data, events: nil)
        model_hash = model_obj.as_json
        json = JSON.generate(model_hash)
        new_model = ActivityModel.from_json(json, name: name, scope: scope)
        expect(model_obj.score).to eql(new_model.score)
        expect(model_obj.duration).to eql(new_model.duration)
        expect(model_obj.start_time).to eql(new_model.start_time)
        expect(model_obj.end_time).to eql(new_model.end_time)
        expect(model_obj.kind).to eql(new_model.kind)
        expect(model_obj.data).to eql(new_model.data)
      end
    end

  end
end
