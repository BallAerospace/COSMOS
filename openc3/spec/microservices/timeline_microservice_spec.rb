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
require 'openc3/topics/timeline_topic'
require 'openc3/models/timeline_model'
require 'openc3/models/activity_model'
require 'openc3/microservices/timeline_microservice'

module OpenC3
  describe TimelineMicroservice do
    # Turn on tests here these test can take up to three minutes so
    # if you want to test them set TEST = true
    TMI_TEST = false

    def generate_timeline()
      timeline = TimelineModel.new(
        name: "TEST",
        scope: "DEFAULT"
      )
      timeline.create()
    end

    def generate_activity(start, kind)
      now = Time.now.to_i
      activity = ActivityModel.new(
        name: "TEST",
        scope: "DEFAULT",
        start: now + start,
        stop: now + start + 120,
        kind: kind,
        data: { kind => "INST ABORT" }
      )
      activity.create()
      return activity
    end

    def generate_json_activity()
      now = Time.now.to_i
      activity = ActivityModel.new(
        name: "TEST",
        scope: "DEFAULT",
        start: now + 500,
        stop: now + 500 + 120,
        kind: "cmd",
        data: { "cmd" => "INST ABORT" }
      )
      return JSON.generate(activity.as_json(:allow_nan => true))
    end

    def valid_events?(events, check)
      ret = false
      events.each do |event|
        ret = (event["event"] == check) ? true : ret
      end
      return ret
    end

    before(:each) do
      @redis = mock_redis()
      setup_system()
      allow(TimelineTopic).to receive(:read_topics) { sleep 5 }.with([]).and_yield(
        "topic",
        "id-1",
        { 'timeline' => 'TEST', 'type' => 'activity', 'kind' => 'create', 'data' => generate_json_activity },
        nil
      ).and_yield(
        "topic",
        "id-1",
        { 'timeline' => 'TEST', 'type' => 'activity', 'kind' => 'delete', 'data' => generate_json_activity },
        nil
      ).and_yield(
        "topic",
        "id-2",
        { 'timeline' => 'FOO', 'type' => 'timeline', 'kind' => 'refresh', 'data' => '{"name":"FOO"}' },
        nil
      ).and_yield(
        "topic",
        "id-3",
        { 'timeline' => 'BAR', 'type' => 'timeline', 'kind' => 'refresh', 'data' => '{"name":"BAR"}' },
        nil
      ).and_yield(
        "topic",
        "id-4",
        { 'timeline' => 'TEST', 'type' => 'timeline', 'kind' => 'refresh', 'data' => '{"name":"TEST"}' },
        nil
      )
      allow(TimelineTopic).to receive(:write_activity) { sleep 2 }
      generate_timeline()
      generate_activity(250, "cmd")
    end

    describe "timeline" do
      it "get the timeline.all" do
        array = ActivityModel.all(name: "TEST", scope: "DEFAULT", limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(1)
        timeline_microservice = TimelineMicroservice.new("DEFAULT__TIMELINE__TEST")
        timeline_thread = Thread.new { timeline_microservice.run }
        sleep 2
        timeline_microservice.shutdown
        sleep 5
      end
    end if TMI_TEST

    describe "timeline manager" do
      it "run the timeline manager and add an expire." do
        name = "TEST"
        scope = "DEFAULT"
        array = ActivityModel.all(name: name, scope: scope, limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(1)
        timeline_schedule = Schedule.new(name)
        timeline_manager = TimelineManager.new(name: name, scope: scope, schedule: timeline_schedule)
        activity = timeline_manager.add_expire_activity()
        manager_thread = Thread.new { timeline_manager.run }
        sleep 5
        timeline_manager.shutdown
        sleep 5
        expect(activity.events.empty?).to eql(false)
        expect(activity.events.length).to eql(1)
        expect(valid_events?(activity.events, "completed")).to eql(true)
      end
    end if TMI_TEST

    describe "timeline manager" do
      it "run the timeline manager and request update" do
        name = "TEST"
        scope = "DEFAULT"
        array = ActivityModel.all(name: name, scope: scope, limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(1)
        timeline_schedule = Schedule.new(name)
        timeline_manager = TimelineManager.new(name: name, scope: scope, schedule: timeline_schedule)
        start = Time.now.to_i
        timeline_manager.request_update(start: start)
        sleep 5
        timeline_manager.shutdown
        sleep 5
      end
    end if TMI_TEST

    describe "timeline" do
      it "add a cmd while microservice is running" do
        allow_any_instance_of(Object).to receive(:cmd_no_hazardous_check) { sleep 2 }
        timeline_microservice = TimelineMicroservice.new("DEFAULT__TIMELINE__TEST")
        Thread.new { timeline_microservice.run }
        model = generate_activity(15, "cmd") # should be 15 seconds in the future
        score = model.start
        array = ActivityModel.all(name: "TEST", scope: "DEFAULT", limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(2)
        sleep 20
        timeline_microservice.shutdown
        sleep 10
        activity = ActivityModel.score(name: "TEST", scope: "DEFAULT", score: score)
        expect(activity).not_to be_nil
        expect(activity.fulfillment).to eql(true)
        expect(activity.events.empty?).to eql(false)
        expect(activity.events.length).to eql(3)
        expect(valid_events?(activity.events, "completed")).to eql(true)
      end
    end if TMI_TEST

    describe "timeline" do
      it "add a cmd activty to run and complete" do
        allow_any_instance_of(Object).to receive(:cmd_no_hazardous_check) { sleep 2 }
        model = generate_activity(15, "cmd") # should be 15 seconds in the future
        score = model.start
        array = ActivityModel.all(name: "TEST", scope: "DEFAULT", limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(2)
        timeline_microservice = TimelineMicroservice.new("DEFAULT__TIMELINE__TEST")
        Thread.new { timeline_microservice.run }
        sleep 20
        timeline_microservice.shutdown
        sleep 10
        activity = ActivityModel.score(name: "TEST", scope: "DEFAULT", score: score)
        expect(activity).not_to be_nil
        expect(activity.fulfillment).to eql(true)
        expect(activity.events.empty?).to eql(false)
        expect(activity.events.length).to eql(3)
        expect(valid_events?(activity.events, "completed")).to eql(true)
      end
    end if TMI_TEST

    describe "timeline" do
      it "add a script activity to run and complete" do
        allow_any_instance_of(Net::HTTP).to receive(:request).with(
          an_instance_of(Net::HTTP::Post)
        ).and_return(Net::HTTPResponse)
        allow(Net::HTTPResponse).to receive(:body).and_return("test")
        allow(Net::HTTPResponse).to receive(:code).and_return(200)
        model = generate_activity(15, "script") # should be 15 seconds in the future
        score = model.start
        array = ActivityModel.all(name: "TEST", scope: "DEFAULT", limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(2)
        timeline_microservice = TimelineMicroservice.new("DEFAULT__TIMELINE__TEST")
        Thread.new { timeline_microservice.run }
        sleep 20
        timeline_microservice.shutdown
        sleep 10
        activity = ActivityModel.score(name: "TEST", scope: "DEFAULT", score: score)
        expect(activity).not_to be_nil
        expect(activity.fulfillment).to eql(true)
        expect(activity.events.empty?).to eql(false)
        expect(activity.events.length).to eql(3)
        expect(valid_events?(activity.events, "completed")).to eql(true)
      end
    end if TMI_TEST

    describe "timeline" do
      it "add a cmd activity to run and fail" do
        allow_any_instance_of(Object).to receive(:cmd_no_hazardous_check).and_raise("ERROR")
        model = generate_activity(15, "cmd") # should be 15 seconds in the future
        score = model.start
        array = ActivityModel.all(name: "TEST", scope: "DEFAULT", limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(2)
        timeline_microservice = TimelineMicroservice.new("DEFAULT__TIMELINE__TEST")
        Thread.new { timeline_microservice.run }
        sleep 20
        timeline_microservice.shutdown
        sleep 10
        activity = ActivityModel.score(name: "TEST", scope: "DEFAULT", score: score)
        expect(activity).not_to be_nil
        expect(activity.fulfillment).to eql(false)
        expect(activity.events.empty?).to eql(false)
        expect(activity.events.length).to eql(3)
        expect(valid_events?(activity.events, "failed")).to eql(true)
      end
    end if TMI_TEST

    describe "timeline" do
      it "add a script activity to run and fail" do
        allow_any_instance_of(Net::HTTP).to receive(:request).with(
          an_instance_of(Net::HTTP::Post)
        ).and_raise("ERROR")
        model = generate_activity(15, "script") # should be 15 seconds in the future
        score = model.start
        array = ActivityModel.all(name: "TEST", scope: "DEFAULT", limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(2)
        timeline_microservice = TimelineMicroservice.new("DEFAULT__TIMELINE__TEST")
        Thread.new { timeline_microservice.run }
        sleep 20
        timeline_microservice.shutdown
        sleep 10
        activity = ActivityModel.score(name: "TEST", scope: "DEFAULT", score: score)
        expect(activity).not_to be_nil
        expect(activity.fulfillment).to eql(false)
        expect(activity.events.empty?).to eql(false)
        expect(activity.events.length).to eql(3)
        expect(valid_events?(activity.events, "failed")).to eql(true)
      end
    end if TMI_TEST
  end
end
