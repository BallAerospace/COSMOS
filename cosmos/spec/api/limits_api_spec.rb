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
require 'cosmos/api/limits_api'
require 'cosmos/api/target_api'
require 'cosmos/script/extract'
require 'cosmos/utilities/authorization'
require 'cosmos/microservices/interface_microservice'
require 'cosmos/microservices/decom_microservice'

module Cosmos
  describe Api do
    class ApiTest
      include Extract
      include Api
      include Authorization
    end

    before(:each) do
      @redis = mock_redis()
      setup_system()

      %w(INST SYSTEM).each do |target|
        model = TargetModel.new(folder_name: target, name: target, scope: "DEFAULT")
        model.create
        model.update_store(File.join(SPEC_DIR, 'install', 'config', 'targets'))
      end

      # Mock out some stuff in Microservice initialize()
      dbl = double("AwsS3Client").as_null_object
      allow(Aws::S3::Client).to receive(:new).and_return(dbl)
      allow(Zip::File).to receive(:open).and_return(true)
      allow_any_instance_of(Cosmos::Interface).to receive(:connected?).and_return(true)
      @im_shutdown = false
      allow_any_instance_of(Cosmos::Interface).to receive(:read_interface) { sleep(0.01) until @im_shutdown }

      model = MicroserviceModel.new(name: "DEFAULT__DECOM__INST_INT", scope: "DEFAULT", topics: ["DEFAULT__TELEMETRY__{INST}__HEALTH_STATUS"])
      model.create
      @dm = DecomMicroservice.new("DEFAULT__DECOM__INST_INT")
      @dm_thread = Thread.new { @dm.run }
      sleep(0.01) # Allow the threads to run

      @api = ApiTest.new
    end

    after(:each) do
      @dm.shutdown
      sleep(1.01)
    end

    describe "get_stale" do
      it "complains about non-existant targets" do
        expect { @api.get_stale(target_name: "BLAH") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
      end

      it "gets stale packets for all targets" do
        packets = []
        @api.get_target_list().each do |target_name|
          all = @api.get_all_telemetry(target_name)
          all.each { |item| packets << [item['target_name'], item['packet_name']] }
        end
        stale = @api.get_stale().sort
        # Initially all packets are stale
        expect(stale).to eql packets.sort
      end

      it "gets stale packets for the specified target" do
        inst_packets = []
        all = @api.get_all_telemetry("INST")
        all.each { |item| inst_packets << [item['target_name'], item['packet_name']] }
        stale = @api.get_stale(target_name: "INST").sort
        # Initially all packets are stale
        expect(stale).to eql inst_packets.sort
        # Explitly check for this since we check below that it is NOT there
        expect(stale).to include(["INST", "HEALTH_STATUS"])

        packet = System.telemetry.packet('INST', 'HEALTH_STATUS')
        packet.received_time = Time.now.sys
        TelemetryTopic.write_packet(packet, scope: "DEFAULT")
        sleep(0.1)
        updated = @api.get_stale(target_name: "INST").sort
        expect(updated).to_not include(["INST", "HEALTH_STATUS"])
      end

      it "only gets stale packets with limits items" do
        stale = @api.get_stale(target_name: "INST", with_limits_only: true).sort
        expect(stale).to eq [["INST", "HEALTH_STATUS"]]
      end
    end

    describe "get_limits" do
      it "complains about non-existant targets" do
        expect { @api.get_limits("BLAH", "HEALTH_STATUS", "TEMP1") }.to raise_error(RuntimeError, "Packet 'BLAH HEALTH_STATUS' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_limits("INST", "BLAH", "TEMP1") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.get_limits("INST", "HEALTH_STATUS", "BLAH") }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "gets limits for an item" do
        expect(@api.get_limits("INST", "HEALTH_STATUS", "TEMP1")).to \
          eql({ 'DEFAULT' => [-80.0, -70.0, 60.0, 80.0, -20.0, 20.0], 'TVAC' => [-80.0, -30.0, 30.0, 80.0] })
      end
    end

    describe "set_limits" do
      it "complains about non-existant targets" do
        expect { @api.set_limits("BLAH", "HEALTH_STATUS", "TEMP1", 0.0, 10.0, 20.0, 30.0) }.to raise_error(RuntimeError, "Packet 'BLAH HEALTH_STATUS' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.set_limits("INST", "BLAH", "TEMP1", 0.0, 10.0, 20.0, 30.0) }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.set_limits("INST", "HEALTH_STATUS", "BLAH", 0.0, 10.0, 20.0, 30.0) }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "creates a CUSTOM limits set" do
        @api.set_limits("INST", "HEALTH_STATUS", "TEMP1", 0.0, 10.0, 20.0, 30.0)
        expect(@api.get_limits("INST", "HEALTH_STATUS", "TEMP1")['CUSTOM']).to eql([0.0, 10.0, 20.0, 30.0])
      end

      it "complains about invalid limits" do
        expect { @api.set_limits("INST", "HEALTH_STATUS", "TEMP1", 2.0, 1.0, 4.0, 5.0)  }.to raise_error(RuntimeError, /Invalid limits specified/)
        expect { @api.set_limits("INST", "HEALTH_STATUS", "TEMP1", 0.0, 1.0, 2.0, 3.0, 4.0, 5.0)  }.to raise_error(RuntimeError, /Invalid limits specified/)
      end

      it "overrides existing limits" do
        item = @api.get_item("INST", "HEALTH_STATUS", "TEMP1")
        expect(item['limits']['persistence_setting']).to_not eql(10)
        expect(item['limits']['enabled']).to be true
        @api.set_limits("INST", "HEALTH_STATUS", "TEMP1", 0.0, 1.0, 4.0, 5.0, 2.0, 3.0, 'DEFAULT', 10, false)
        item = @api.get_item("INST", "HEALTH_STATUS", "TEMP1")
        expect(item['limits']['persistence_setting']).to eql(10)
        expect(item['limits']['enabled']).to be_nil
        expect(item['limits']['DEFAULT']).to eql({ 'red_low' => 0.0, 'yellow_low' => 1.0, 'yellow_high' => 4.0,
                                                   'red_high' => 5.0, 'green_low' => 2.0, 'green_high' => 3.0 })
      end
    end

    describe "get_limits_groups" do
      it "returns an empty hash with no groups" do
        # Remove all limits_groups
        @redis.del("DEFAULT__limits_groups")
        expect(@api.get_limits_groups).to eql({})
      end

      it "returns all the limits groups" do
        expect(@api.get_limits_groups).to eql({ "FIRST" => [%w(INST HEALTH_STATUS TEMP1), %w(INST HEALTH_STATUS TEMP3)],
                                                "SECOND" => [%w(INST HEALTH_STATUS TEMP2), %w(INST HEALTH_STATUS TEMP4)] })
      end
    end

    describe "enable_limits_group" do
      it "complains about undefined limits groups" do
        expect { @api.enable_limits_group("MINE") }.to raise_error(RuntimeError, "LIMITS_GROUP MINE undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP MINE")
      end

      it "enables limits for all items in the group" do
        @api.disable_limits("INST", "HEALTH_STATUS", "TEMP1")
        @api.disable_limits("INST", "HEALTH_STATUS", "TEMP3")
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP1")).to be false
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP3")).to be false
        @api.enable_limits_group("FIRST")
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP1")).to be true
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP3")).to be true
      end
    end

    describe "disable_limits_group" do
      it "complains about undefined limits groups" do
        expect { @api.disable_limits_group("MINE") }.to raise_error(RuntimeError, "LIMITS_GROUP MINE undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP MINE")
      end

      it "disables limits for all items in the group" do
        @api.enable_limits("INST", "HEALTH_STATUS", "TEMP1")
        @api.enable_limits("INST", "HEALTH_STATUS", "TEMP3")
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP1")).to be true
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP3")).to be true
        @api.disable_limits_group("FIRST")
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP1")).to be false
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP3")).to be false
      end
    end

    describe "get_limits_sets, get_limits_set, set_limits_set" do
      it "gets and set the active limits set" do
        expect(@api.get_limits_sets).to eql ['DEFAULT', 'TVAC']
        @api.set_limits_set("TVAC")
        expect(@api.get_limits_set).to eql "TVAC"
        @api.set_limits_set("DEFAULT")
        expect(@api.get_limits_set).to eql "DEFAULT"
        @api.set_limits_set("TVAC")
        expect(@api.get_limits_set).to eql "TVAC"
      end
    end

    describe "get_limits_events" do
      it "returns empty array with no events" do
        events = @api.get_limits_events()
        expect(events).to eql([])
      end

      it "returns an offset and limits event hash" do
        # Load the events topic with two events ... only the last should be returned
        event = { type: :LIMITS_CHANGE, target_name: "BLAH", packet_name: "BLAH", item_name: "BLAH",
                  old_limits_state: :RED_LOW, new_limits_state: :RED_HIGH, time_nsec: 0, message: "nope" }
        LimitsEventTopic.write(event, scope: "DEFAULT")
        time = Time.now.to_nsec_from_epoch
        event = { type: :LIMITS_CHANGE, target_name: "TGT", packet_name: "PKT", item_name: "ITEM",
                  old_limits_state: :GREEN, new_limits_state: :YELLOW_LOW, time_nsec: time, message: "message" }
        LimitsEventTopic.write(event, scope: "DEFAULT")
        events = @api.get_limits_events()
        expect(events).to be_a Array
        offset = events[0][0]
        event = events[0][1]
        expect(offset).to match(/\d{13}-\d/)
        expect(event).to be_a Hash
        expect(event['type']).to eql "LIMITS_CHANGE"
        expect(event['target_name']).to eql "TGT"
        expect(event['packet_name']).to eql "PKT"
        expect(event['old_limits_state']).to eql "GREEN"
        expect(event['new_limits_state']).to eql "YELLOW_LOW"
        expect(event['time_nsec']).to eql time.to_s
        expect(event['message']).to eql "message"
      end

      it "returns multiple offsets/events with multiple calls" do
        event = { type: :LIMITS_CHANGE, target_name: "TGT", packet_name: "PKT", item_name: "ITEM",
                  old_limits_state: :GREEN, new_limits_state: :YELLOW_LOW, time_nsec: 0, message: "message" }
        LimitsEventTopic.write(event, scope: "DEFAULT")
        events = @api.get_limits_events()
        expect(events[0][0]).to match(/\d{13}-\d/)
        expect(events[0][1]['time_nsec']).to eql "0"
        last_offset = events[-1][0]

        # Load additional events
        event[:old_limits_state] = :YELLOW_LOW
        event[:new_limits_state] = :RED_LOW
        event[:time_nsec] = 1
        LimitsEventTopic.write(event, scope: "DEFAULT")
        event[:old_limits_state] = :RED_LOW
        event[:new_limits_state] = :YELLOW_LOW
        event[:time_nsec] = 2
        LimitsEventTopic.write(event, scope: "DEFAULT")
        event[:old_limits_state] = :YELLOW_LOW
        event[:new_limits_state] = :GREEN
        event[:time_nsec] = 3
        LimitsEventTopic.write(event, scope: "DEFAULT")
        # Limit the count to 2
        events = @api.get_limits_events(last_offset, count: 2)
        expect(events.length).to eql 2
        expect(events[0][0]).to match(/\d{13}-\d/)
        expect(events[0][1]['time_nsec']).to eql "1"
        expect(events[1][0]).to match(/\d{13}-\d/)
        expect(events[1][1]['time_nsec']).to eql "2"
        last_offset = events[-1][0]

        events = @api.get_limits_events(last_offset)
        expect(events.length).to eql 1
        expect(events[0][0]).to match(/\d{13}-\d/)
        expect(events[0][1]['time_nsec']).to eql "3"
        last_offset = events[-1][0]

        events = @api.get_limits_events(last_offset)
        expect(events).to eql([])
      end
    end

    describe "get_out_of_limits" do
      it "returns all out of limits items" do
        @api.inject_tlm("INST", "HEALTH_STATUS", { TEMP1: 0, TEMP2: 0, TEMP3: 0, TEMP4: 0 }, type: :RAW)
        sleep 1
        items = @api.get_out_of_limits
        (0..3).each do |i|
          expect(items[i][0]).to eql "INST"
          expect(items[i][1]).to eql "HEALTH_STATUS"
          expect(items[i][2]).to eql "TEMP#{i + 1}"
          expect(items[i][3]).to eql "RED_LOW"
        end
      end
    end

    describe "get_overall_limits_state" do
      it "returns the overall system limits state" do
        @api.inject_tlm("INST", "HEALTH_STATUS",
                        { 'TEMP1' => 0, 'TEMP2' => 0, 'TEMP3' => 0, 'TEMP4' => 0, 'GROUND1STATUS' => 1, 'GROUND2STATUS' => 1 })
        sleep 1
        expect(@api.get_overall_limits_state).to eql "GREEN"
        # TEMP1 limits: -80.0 -70.0 60.0 80.0 -20.0 20.0
        # TEMP2 limits: -60.0 -55.0 30.0 35.0
        @api.inject_tlm("INST", "HEALTH_STATUS", { 'TEMP1' => 70, 'TEMP2' => 32, 'TEMP3' => 0, 'TEMP4' => 0 }) # Both YELLOW
        sleep 1
        expect(@api.get_overall_limits_state).to eql "YELLOW"
        @api.inject_tlm("INST", "HEALTH_STATUS", { 'TEMP1' => 0, 'TEMP2' => 40, 'TEMP3' => 0, 'TEMP4' => 0 })
        sleep 1
        expect(@api.get_overall_limits_state).to eql "RED"
        expect(@api.get_overall_limits_state([])).to eql "RED"

        # Ignoring all now yields GREEN
        expect(@api.get_overall_limits_state([["INST", "HEALTH_STATUS", nil]])).to eql "GREEN"
        # Ignoring just TEMP2 yields YELLOW due to TEMP1
        expect(@api.get_overall_limits_state([["INST", "HEALTH_STATUS", "TEMP2"]])).to eql "YELLOW"
      end

      it "raise on invalid ignored_items" do
        expect { @api.get_overall_limits_state(["BLAH"]) }.to raise_error(/Invalid ignored item: BLAH/)
        expect { @api.get_overall_limits_state([["INST", "HEALTH_STATUS"]]) }.to raise_error(/Invalid ignored item: \["INST", "HEALTH_STATUS"\]/)
      end
    end

    describe "limits_enabled?" do
      it "complains about non-existant targets" do
        expect { @api.limits_enabled?("BLAH", "HEALTH_STATUS", "TEMP1") }.to raise_error(RuntimeError, "Packet 'BLAH HEALTH_STATUS' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.limits_enabled?("INST", "BLAH", "TEMP1") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.limits_enabled?("INST", "HEALTH_STATUS", "BLAH") }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "returns whether limits are enable for an item" do
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP1")).to be true
      end
    end

    describe "enable_limits" do
      it "complains about non-existant targets" do
        expect { @api.enable_limits("BLAH", "HEALTH_STATUS", "TEMP1") }.to raise_error(RuntimeError, "Packet 'BLAH HEALTH_STATUS' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.enable_limits("INST", "BLAH", "TEMP1") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.enable_limits("INST", "HEALTH_STATUS", "BLAH") }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "enables limits for an item" do
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP1")).to be true
        @api.disable_limits("INST", "HEALTH_STATUS", "TEMP1")
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP1")).to be false
        @api.enable_limits("INST", "HEALTH_STATUS", "TEMP1")
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP1")).to be true
      end
    end

    describe "disable_limits" do
      it "complains about non-existant targets" do
        expect { @api.disable_limits("BLAH", "HEALTH_STATUS", "TEMP1") }.to raise_error(RuntimeError, "Packet 'BLAH HEALTH_STATUS' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.disable_limits("INST", "BLAH", "TEMP1") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.disable_limits("INST", "HEALTH_STATUS", "BLAH") }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "disables limits for an item" do
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP1")).to be true
        @api.disable_limits("INST", "HEALTH_STATUS", "TEMP1")
        expect(@api.limits_enabled?("INST", "HEALTH_STATUS", "TEMP1")).to be false
        @api.enable_limits("INST", "HEALTH_STATUS", "TEMP1")
      end
    end
  end
end
