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
require 'cosmos/topics/timeline_topic'
require 'cosmos/models/timeline_model'
require 'cosmos/models/activity_model'
require 'cosmos/microservices/timeline_microservice'

module Cosmos
  describe TimelineMicroservice do

  # Turn on tests here these test can take up to three minutes so
  # if you want to test them set TEST = true
  TEST = false

  def generate_timeline()
    timeline = TimelineModel.new(
      name: "TEST",
      scope: "DEFAULT")
    timeline.create()
  end

  def generate_activity(start, kind)
    now = DateTime.now.new_offset(0)
    activity = ActivityModel.new(
      name: "TEST",
      scope: "DEFAULT",
      start_time: (now + start).to_s,
      end_time: (now + start + 3.0/1440.0).to_s,
      kind: kind,
      data: {kind => "INST ABORT"})
    activity.create()
    return activity
  end

    before(:each) do
      @redis = mock_redis()
      setup_system()
      allow(TimelineTopic).to receive(:read_topics) { sleep 2 }.with([]).and_yield(
        "topic",
        "id-1",
        {"json_data"=>'{"timeline": "TEST"}'},
        nil
      ).and_yield(
        "topic",
        "id-2",
        {"json_data"=>'{"timeline": "FOO"}'},
        nil
      ).and_yield(
        "topic",
        "id-1",
        {"json_data"=>'{"timeline": "BAR"}'},
        nil
      )
      allow(TimelineTopic).to receive(:write_activity) { sleep 2 }
      generate_timeline()
      generate_activity(250.0/86400.0, "cmd")
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
    end if TEST

    describe "timeline manager" do
      it "run the timeline manager and add an expire." do
        array = ActivityModel.all(name: "TEST", scope: "DEFAULT", limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(1)
        name = "DEFAULT__TIMELINE__TEST"
        timeline_schedule = Schedule.new(name)
        timeline_manager = TimelineManager.new(name, timeline_schedule)
        timeline_manager.add_expire_activity()
        manager_thread = Thread.new { timeline_manager.run }
        sleep 5
        timeline_manager.shutdown
        sleep 5
      end
    end if TEST

    describe "timeline" do
      it "add a cmd activty to run" do
        dbl = double("cmd_no_hazardous_check")
        allow(dbl) { sleep 2 }
        model = generate_activity(20.0/86400.0, "cmd") # should be 50 seconds in the future
        score = model.score
        array = ActivityModel.all(name: "TEST", scope: "DEFAULT", limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(2)
        timeline_microservice = TimelineMicroservice.new("DEFAULT__TIMELINE__TEST")
        Thread.new { timeline_microservice.run }
        sleep 60
        timeline_microservice.shutdown
        sleep 10
        activity = ActivityModel.score(name: "TEST", scope: "DEFAULT", score: score)
        expect(activity).not_to be_nil
        expect(activity.fulfillment).to eql(false)
        expect(activity.events.empty?).to eql(false)
        expect(activity.events.length).to eql(3)
      end
    end if TEST

    describe "timeline" do
      it "add a script activity to run" do
        dbl = double("Net::HTTP")
        allow(dbl).to receive(:request) { sleep 2 }
        model = generate_activity(20.0/86400.0, "script") # should be 50 seconds in the future
        score = model.score
        array = ActivityModel.all(name: "TEST", scope: "DEFAULT", limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(2)
        timeline_microservice = TimelineMicroservice.new("DEFAULT__TIMELINE__TEST")
        Thread.new { timeline_microservice.run }
        sleep 60
        timeline_microservice.shutdown
        sleep 10
        activity = ActivityModel.score(name: "TEST", scope: "DEFAULT", score: score)
        expect(activity).not_to be_nil
        expect(activity.fulfillment).to eql(false)
        expect(activity.events.empty?).to eql(false)
        expect(activity.events.length).to eql(3)
      end
    end if TEST

    describe "timeline" do
      it "add a cmd activity to run and fail" do
        model = generate_activity(20.0/86400.0, "cmd") # should be 50 seconds in the future
        score = model.score
        array = ActivityModel.all(name: "TEST", scope: "DEFAULT", limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(2)
        timeline_microservice = TimelineMicroservice.new("DEFAULT__TIMELINE__TEST")
        Thread.new { timeline_microservice.run }
        sleep 60
        timeline_microservice.shutdown
        sleep 10
        activity = ActivityModel.score(name: "TEST", scope: "DEFAULT", score: score)
        expect(activity).not_to be_nil
        expect(activity.fulfillment).to eql(false)
        expect(activity.events.empty?).to eql(false)
        expect(activity.events.length).to eql(3)
      end
    end if TEST

    describe "timeline" do
      it "add a script activity to run and fail" do
        model = generate_activity(20.0/86400.0, "script") # should be 50 seconds in the future
        score = model.score
        array = ActivityModel.all(name: "TEST", scope: "DEFAULT", limit: 10)
        expect(array.empty?).to eql(false)
        expect(array.length).to eql(2)
        timeline_microservice = TimelineMicroservice.new("DEFAULT__TIMELINE__TEST")
        Thread.new { timeline_microservice.run }
        sleep 60
        timeline_microservice.shutdown
        sleep 10
        activity = ActivityModel.score(name: "TEST", scope: "DEFAULT", score: score)
        expect(activity).not_to be_nil
        expect(activity.fulfillment).to eql(false)
        expect(activity.events.empty?).to eql(false)
        expect(activity.events.length).to eql(3)
      end
    end if TEST

  end
end