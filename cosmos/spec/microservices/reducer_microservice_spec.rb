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
require 'cosmos/microservices/reducer_microservice'
require 'cosmos/topics/telemetry_decom_topic'

module Cosmos
  describe ReducerMicroservice do
    before(:each) do
      mock_redis()
      setup_system()
      allow(System).to receive(:setup_targets).and_return(nil)
      %w(INST SYSTEM).each do |target|
        model = TargetModel.new(folder_name: target, name: target, scope: "DEFAULT")
        model.create
        model.update_store(File.join(SPEC_DIR, 'install', 'config', 'targets'))
      end

      @topics = %w(DEFAULT__DECOM__{INST}__HEALTH_STATUS DEFAULT__DECOM__{INST}__IMAGE DEFAULT__DECOM__{INST}__ADCS)
      model = MicroserviceModel.new(
        name: "DEFAULT__REDUCER__INST",
        folder_name: "INST",
        topics: @topics,
        scope: "DEFAULT")
        model.create
    end

    before(:each) do
      @reducer = ReducerMicroservice.new("DEFAULT__REDUCER__INST")
      @reducer.instance_variable_set("@test", true) # Enable Redis ID overload
    end

    after(:each) do
      @reducer.shutdown
      sleep 0.1
    end

    describe "initialize_streams" do
      it "adds streams to Redis" do
        @reducer.initialize_streams
        ReducerMicroservice::REDUCER_KEYS.each do |key|
          @topics.each do |topic|
            scope, _, tgt, pkt = topic.split("__")
            stream = "#{scope}__#{key}__#{tgt}__#{pkt}"
            expect(Store.exists?(stream)).to be true
            expect(Store.get_last_offset(stream)).to eql "0-0"
            expect(Store.xlen(stream)).to eql 0
          end
        end
      end

      it "leaves streams that exist" do
        Store.initialize_streams(["DEFAULT__REDUCED_MINUTE__{INST}__ADCS"])
        100.times { Store.xadd("DEFAULT__REDUCED_MINUTE__{INST}__ADCS", {'test': 'data'}) }
        @reducer.initialize_streams
        # The stream we've added to should NOT eql 0-0
        expect(Store.get_last_offset("DEFAULT__REDUCED_MINUTE__{INST}__ADCS")).to_not eql "0-0"
        expect(Store.xlen("DEFAULT__REDUCED_MINUTE__{INST}__ADCS")).to eql 100
      end
    end

    describe "reduce_minute" do
      it "reduces 60s of decom data" do
        @reducer.initialize_streams
        @reducer.get_initial_offsets

        start_time = Time.now.sys
        packet = System.telemetry.packet("INST", "HEALTH_STATUS")
        offset = 0
        6.times do
          packet.received_time = start_time + offset
          TelemetryDecomTopic.write_packet(packet, id: "#{packet.received_time.to_i * 1000}-0", scope: "DEFAULT")
          offset += 10 # seconds
        end
        @reducer.reduce_minute # Initially shouldn't process due to not enough data
        expect(Store.xlen("DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS")).to eql 0

        packet.received_time = start_time + offset
        offset += 10
        TelemetryDecomTopic.write_packet(packet, id: "#{packet.received_time.to_i * 1000}-0", scope: "DEFAULT")
        @reducer.reduce_minute # <= Do the work!

        # One minute of data should be processed
        expect(Store.xlen("DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS")).to eql 1
        result = Store.read_topics(["DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS"], ['0-0'])
        msg_hash = result["DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS"][0][1]
        expect(msg_hash['target_name']).to eql "INST"
        expect(msg_hash['packet_name']).to eql "HEALTH_STATUS"
        data = JSON.parse(msg_hash['json_data'])
        expect(data['PACKET_TIMESECONDS__MIN']).to eql start_time.to_f + 10
        expect(data['PACKET_TIMESECONDS__MAX']).to eql start_time.to_f + 60
        expect(data['PACKET_TIMESECONDS__STDDEV']).to be_within(0.1).of(17)

        # Throw in another minute of data
        6.times do
          packet.received_time = start_time + offset
          TelemetryDecomTopic.write_packet(packet, id: "#{packet.received_time.to_i * 1000}-0", scope: "DEFAULT")
          offset += 10 # seconds
        end
        @reducer.reduce_minute # <= Do the work!

        # 2 minutes of data should be processed
        expect(Store.xlen("DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS")).to eql 2
        result = Store.read_topics(["DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS"], ['0-0'])
        msg_hash = result["DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS"][1][1]
        expect(msg_hash['target_name']).to eql "INST"
        expect(msg_hash['packet_name']).to eql "HEALTH_STATUS"
        data = JSON.parse(msg_hash['json_data'])
        expect(data['PACKET_TIMESECONDS__MIN']).to eql start_time.to_f + 70
        expect(data['PACKET_TIMESECONDS__MAX']).to eql start_time.to_f + 120
        expect(data['PACKET_TIMESECONDS__STDDEV']).to be_within(0.1).of(17)
      end
    end

    describe "reduce_hour" do
      it "reduces 1h of decom data" do
        @reducer.initialize_streams
        @reducer.get_initial_offsets

        start_time = Time.now.sys
        packet = System.telemetry.packet("INST", "HEALTH_STATUS")
        offset = 0
        370.times do |i|
          packet.received_time = start_time + offset
          packet.write("COLLECTS", rand(10))
          TelemetryDecomTopic.write_packet(packet, id: "#{(packet.received_time.to_f * 1000).to_i}-0", scope: "DEFAULT")
          offset += 10 # seconds
        end

        @reducer.reduce_minute
        @reducer.reduce_hour

        # 1 hour of data should be reduced
        expect(Store.xlen("DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS")).to eql 1
        result = Store.read_topics(["DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS"], ['0-0'])
        expect(result["DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS"].length).to eql 1
        data = JSON.parse(result["DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS"][0][1]['json_data'])
        expect(data['PACKET_TIMESECONDS__MIN']).to eql start_time.to_f + 70
        expect(data['PACKET_TIMESECONDS__MAX']).to eql start_time.to_f + 3660 # 1 hr
        expect(data['COLLECTS__MIN']).to eql 0
        expect(data['COLLECTS__MAX']).to eql 9
        expect(data['COLLECTS__STDDEV']).to be_within(0.3).of(2.8)

        # Throw in another hour of data
        360.times do |i|
          packet.received_time = start_time + offset
          packet.write("COLLECTS", rand(10))
          packet.write("GROUND1STATUS", 1)
          TelemetryDecomTopic.write_packet(packet, id: "#{(packet.received_time.to_f * 1000).to_i}-0", scope: "DEFAULT")
          offset += 10 # seconds
        end

        @reducer.reduce_minute
        @reducer.reduce_hour

        # 2 hours of data should be reduced
        expect(Store.xlen("DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS")).to eql 2
        result = Store.read_topics(["DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS"], ['0-0'])
        expect(result["DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS"].length).to eql 2
        data = JSON.parse(result["DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS"][1][1]['json_data'])
        expect(data['PACKET_TIMESECONDS__MIN']).to eql start_time.to_f + 3670 # First hour includes extra minute
        expect(data['PACKET_TIMESECONDS__MAX']).to eql start_time.to_f + (3660 + 3600) # 2 hr
        expect(data['COLLECTS__MIN']).to eql 0
        expect(data['COLLECTS__MAX']).to eql 9
        expect(data['COLLECTS__STDDEV']).to be_within(0.3).of(2.8)
      end
    end

    describe "reduce_day" do
      it "reduces 1 day of decom data" do
        @reducer.initialize_streams
        @reducer.get_initial_offsets

        start_time = Time.now.sys
        packet = System.telemetry.packet("INST", "HEALTH_STATUS")
        offset = 0
        370.times do # Initial hour
          packet.received_time = start_time + offset
          packet.write("COLLECTS", rand(10))
          TelemetryDecomTopic.write_packet(packet, id: "#{packet.received_time.to_i}000-0", scope: "DEFAULT")
          offset += 10 # seconds
        end

        # Throw in 24 hours of data
        (24 * 360).times do
          packet.received_time = start_time + offset
          packet.write("COLLECTS", rand(10))
          TelemetryDecomTopic.write_packet(packet, id: "#{packet.received_time.to_i}000-0", scope: "DEFAULT")
          offset += 10 # seconds
        end

        @reducer.reduce_minute
        @reducer.reduce_hour
        @reducer.reduce_day

        # 1 day of data should be reduced
        expect(Store.xlen("DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS")).to eql 1
        result = Store.read_topics(["DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS"], ['0-0'])
        data = JSON.parse(result["DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS"][0][1]['json_data'])
        expect(data['PACKET_TIMESECONDS__MIN']).to eql start_time.to_f + 70 + 3600 # First min and first hour
        expect(data['PACKET_TIMESECONDS__MAX']).to eql start_time.to_f + (3660 + 24 * 3600)
        expect(data['COLLECTS__MIN']).to eql 0
        expect(data['COLLECTS__MAX']).to eql 9
        expect(data['COLLECTS__STDDEV']).to be_within(0.3).of(2.8)

        # Throw in another 24 hours of data
        (24 * 360).times do
          packet.received_time = start_time + offset
          packet.write("COLLECTS", rand(10))
          TelemetryDecomTopic.write_packet(packet, id: "#{packet.received_time.to_i}000-0", scope: "DEFAULT")
          offset += 10 # seconds
        end

        @reducer.reduce_minute
        @reducer.reduce_hour
        @reducer.reduce_day

        # 2 days of data should be reduced
        expect(Store.xlen("DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS")).to eql 2
        result = Store.read_topics(["DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS"], ['0-0'])
        expect(result["DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS"].length).to eql 2
        data = JSON.parse(result["DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS"][1][1]['json_data'])
        expect(data['PACKET_TIMESECONDS__MIN']).to eql start_time.to_f + 70 + 25 * 3600 # First min and first hour plus 1 day
        expect(data['PACKET_TIMESECONDS__MAX']).to eql start_time.to_f + (3660 + 48 * 3600)
        expect(data['COLLECTS__MIN']).to eql 0
        expect(data['COLLECTS__MAX']).to eql 9
        expect(data['COLLECTS__STDDEV']).to be_within(0.3).of(2.8)
      end
    end
  end
end
