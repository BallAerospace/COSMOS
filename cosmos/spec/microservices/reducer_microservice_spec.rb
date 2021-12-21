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
require 'fileutils'

module Cosmos
  describe ReducerMicroservice do
    before(:all) do
      setup_system()
      @log_path = File.expand_path(File.join(SPEC_DIR, 'install', 'outputs', 'logs'))
    end

    before(:each) do
      mock_redis()
      @reducer = ReducerMicroservice.new("DEFAULT__REDUCER__INST")

      # Override S3Utilities to save off and store and files destined for S3
      @decom_files = []
      @minute_files = []
      @hour_files = []
      @day_files = []
      @reduced_files = []
      allow(S3Utilities).to receive(:move_log_file_to_s3) do |filename, s3_key|
        # puts "move_log_file_to_s3 filename:#{filename} key:#{s3_key}"
        log_file = File.join(@log_path, s3_key.split('/')[-1])
        # We only care about saving the bin files, not the index files
        if File.extname(log_file) == ".bin"
          FileUtils.move filename, log_file
          if log_file.include?("decom")
            @decom_files << log_file
            # Add the file to the ReducerModel like we would in the real system
            ReducerModel.add_decom(filename: log_file, scope: "DEFAULT")
          elsif log_file.include?("minute")
            @minute_files << log_file
            # Add the file to the ReducerModel like we would in the real system
            ReducerModel.add_minute(filename: log_file, scope: "DEFAULT")
          elsif log_file.include?("hour")
            @hour_files << log_file
            # Add the file to the ReducerModel like we would in the real system
            ReducerModel.add_hour(filename: log_file, scope: "DEFAULT")
          elsif log_file.include?("day")
            @day_files << log_file
          end
          @reduced_files << log_file if log_file.include?("reduced")
        end
      end

      # Allow S3File to simply return the files in @decom_files
      @s3_filename = ''
      @s3_file = double(S3File)
      allow(S3File).to receive(:new) do |filename|
        @s3_filename = filename
        @s3_file
      end
      allow(@s3_file).to receive(:retrieve).and_return(nil)
      allow(@s3_file).to receive(:delete).and_return(nil)
      allow(@s3_file).to receive(:local_path) do
        # return the first file in the appropriate array of files
        case @s3_filename
        when /decom/
          @decom_files.shift
        when /minute/
          @minute_files.shift
        when /hour/
          @hour_files.shift
        end
      end
    end

    after(:each) do
      # Clean up all the bin files we created
      Dir["#{@log_path}/*.bin"].each do |file|
        File.delete(file)
      end
    end

    def setup_logfile(start_time:, num_pkts:, time_delta:)
      # Create a filename that matches what happens when we create a decom packet
      # This is critical since we split on '__' to pull out the scope, target, packet
      plw = PacketLogWriter.new(@log_path, 'DEFAULT__INST__HEALTH_STATUS__rt__decom')
      @pkt = System.telemetry.packet("INST", "HEALTH_STATUS")
      @pkt.received_time = start_time
      collects = 1
      @pkt.write("COLLECTS", collects)

      num_pkts.times do
        json_hash = TelemetryDecomTopic.build_json(@pkt)
        plw.write(:JSON_PACKET, :TLM, @pkt.target_name, @pkt.packet_name, @pkt.received_time.to_nsec_from_epoch,
          true, JSON.generate(json_hash.as_json))
        @pkt.received_time += time_delta
        collects += 1
        @pkt.write("COLLECTS", collects)
      end
      plw.close_file
    end

    describe "reduce_minute" do
      it "reduces 60s of data" do
        start_time = Time.at(1641020400) # 2022/01/01 00:00:00
        setup_logfile(start_time: start_time, num_pkts: 60, time_delta: 1) # 60s of data
        @reducer.reduce_minute
        @reducer.shutdown
        sleep 0.1

        # We should have reduced the data into a single file
        expect(@reduced_files.length).to eql 1

        # All decom files should have been removed since they were processed
        expect(ReducerModel.all_decom(scope: "DEFAULT")).to be_empty
        files = ReducerModel.all_minute(scope: "DEFAULT")
        expect(files.length).to eql 1
        # Start and end times are the same since there is only one entry
        expect(File.basename(files[0])).to eql "20220101000000000000000__20220101000000000000000__DEFAULT__INST__HEALTH_STATUS__reduced__minute.bin"

        # 60s of data reduces to a single entry
        plr = PacketLogReader.new
        plr.open(@reduced_files[0])
        pkt = plr.read
        expect(pkt.read("COLLECTS_SAMPLES")).to eql(60)
        expect(pkt.read("COLLECTS_MIN")).to eql(1)
        expect(pkt.read("COLLECTS_MAX")).to eql(60)
        expect(pkt.read("COLLECTS_AVG")).to eql(30.5)
        expect(pkt.read("COLLECTS_STDDEV")).to be_within(0.001).of(17.318)
        pkt = plr.read
        expect(pkt).to be_nil # no more packets
        plr.close
      end

      it "reduces 60s of data across time boundary" do
        start_time = Time.at(1641020430) # 2022/01/01 00:00:30
        setup_logfile(start_time: start_time, num_pkts: 60, time_delta: 1) # 60s of data
        @reducer.reduce_minute
        @reducer.shutdown
        sleep 0.1

        # All decom files should have been removed since they were processed
        expect(ReducerModel.all_decom(scope: "DEFAULT")).to be_empty
        expect(ReducerModel.all_minute(scope: "DEFAULT").length).to eql 1

        # Since we reduced across time boundaries we should have 2 packets with the data split
        plr = PacketLogReader.new
        plr.open(@reduced_files[0])
        pkt = plr.read
        expect(pkt.read("COLLECTS_SAMPLES")).to eql(30)
        expect(pkt.read("COLLECTS_MIN")).to eql(1)
        expect(pkt.read("COLLECTS_MAX")).to eql(30)
        pkt = plr.read
        expect(pkt.read("COLLECTS_SAMPLES")).to eql(30)
        expect(pkt.read("COLLECTS_MIN")).to eql(31)
        expect(pkt.read("COLLECTS_MAX")).to eql(60)
        plr.close
      end

      it "creates another reduced file at 1hr" do
        start_time = Time.at(1641020400) # 2022/01/01 00:00:00
        # One sample per minute and 61 samples which will overflow into a new log file
        setup_logfile(start_time: start_time, num_pkts: 62, time_delta: 60)
        @reducer.reduce_minute
        @reducer.shutdown
        sleep 0.1

        # All decom files should have been removed since they were processed
        expect(ReducerModel.all_decom(scope: "DEFAULT")).to be_empty
        files = ReducerModel.all_minute(scope: "DEFAULT")
        expect(files.length).to eql 2
        expect(File.basename(files[0])).to eql "20220101000000000000000__20220101005900000000000__DEFAULT__INST__HEALTH_STATUS__reduced__minute.bin"
        expect(File.basename(files[1])).to eql "20220101010000000000000__20220101010100000000000__DEFAULT__INST__HEALTH_STATUS__reduced__minute.bin"

        # Since we rolled over we should have 2 output files
        expect(@reduced_files.length).to eql 2
        index = 0
        @reduced_files.each do |file|
          plr = PacketLogReader.new
          plr.each(file) do |pkt|
            expect(pkt.packet_time).to eql(start_time + index)
            expect(pkt.read("COLLECTS_SAMPLES")).to eql(1)
            index += 60
          end
        end
      end
    end

    describe "reduce_hour" do
      it "reduces 1h of decom data" do
        start_time = Time.at(1641020400) # 2022/01/01 00:00:00
        # Create 1hr of log data but force a roll over so we actually create the file
        setup_logfile(start_time: start_time, num_pkts: 62, time_delta: 60)
        @reducer.reduce_minute
        @reducer.reduce_hour
        @reducer.shutdown
        sleep 0.1

        # All decom files should have been removed since they were processed
        expect(ReducerModel.all_decom(scope: "DEFAULT").length).to eql 0
        # We rolled over so there is one minute file remaining
        expect(ReducerModel.all_minute(scope: "DEFAULT").length).to eql 1
        files = ReducerModel.all_hour(scope: "DEFAULT")
        expect(files.length).to eql 1 # We create 1 hour file

        plr = PacketLogReader.new
        plr.open(files[0])
        pkt = plr.read
        expect(pkt.read("COLLECTS_SAMPLES")).to eql(60)
        expect(pkt.read("COLLECTS_MIN")).to eql(1)
        expect(pkt.read("COLLECTS_MAX")).to eql(60)
        plr.close
      end
    end

    # describe "reduce_day" do
    #   it "reduces 1 day of decom data" do
    #     @reducer.initialize_streams
    #     @reducer.get_initial_offsets

    #     start_time = Time.now.sys
    #     packet = System.telemetry.packet("INST", "HEALTH_STATUS")
    #     offset = 0
    #     370.times do # Initial hour
    #       packet.received_time = start_time + offset
    #       packet.write("COLLECTS", rand(10))
    #       TelemetryDecomTopic.write_packet(packet, id: "#{packet.received_time.to_i}000-0", scope: "DEFAULT")
    #       offset += 10 # seconds
    #     end

    #     # Throw in 24 hours of data
    #     (24 * 360).times do
    #       packet.received_time = start_time + offset
    #       packet.write("COLLECTS", rand(10))
    #       TelemetryDecomTopic.write_packet(packet, id: "#{packet.received_time.to_i}000-0", scope: "DEFAULT")
    #       offset += 10 # seconds
    #     end

    #     @reducer.reduce_minute
    #     @reducer.reduce_hour
    #     @reducer.reduce_day

    #     # 1 day of data should be reduced
    #     expect(Store.xlen("DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS")).to eql 1
    #     result = Store.read_topics(["DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS"], ['0-0'])
    #     data = JSON.parse(result["DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS"][0][1]['json_data'])
    #     expect(data['PACKET_TIMESECONDS__MIN']).to eql start_time.to_f + 70 + 3600 # First min and first hour
    #     expect(data['PACKET_TIMESECONDS__MAX']).to eql start_time.to_f + (3660 + 24 * 3600)
    #     expect(data['COLLECTS__MIN']).to eql 0
    #     expect(data['COLLECTS__MAX']).to eql 9
    #     expect(data['COLLECTS__STDDEV']).to be_within(0.3).of(2.8)

    #     # Throw in another 24 hours of data
    #     (24 * 360).times do
    #       packet.received_time = start_time + offset
    #       packet.write("COLLECTS", rand(10))
    #       TelemetryDecomTopic.write_packet(packet, id: "#{packet.received_time.to_i}000-0", scope: "DEFAULT")
    #       offset += 10 # seconds
    #     end

    #     @reducer.reduce_minute
    #     @reducer.reduce_hour
    #     @reducer.reduce_day

    #     # 2 days of data should be reduced
    #     expect(Store.xlen("DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS")).to eql 2
    #     result = Store.read_topics(["DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS"], ['0-0'])
    #     expect(result["DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS"].length).to eql 2
    #     data = JSON.parse(result["DEFAULT__REDUCED_DAY__{INST}__HEALTH_STATUS"][1][1]['json_data'])
    #     expect(data['PACKET_TIMESECONDS__MIN']).to eql start_time.to_f + 70 + 25 * 3600 # First min and first hour plus 1 day
    #     expect(data['PACKET_TIMESECONDS__MAX']).to eql start_time.to_f + (3660 + 48 * 3600)
    #     expect(data['COLLECTS__MIN']).to eql 0
    #     expect(data['COLLECTS__MAX']).to eql 9
    #     expect(data['COLLECTS__STDDEV']).to be_within(0.3).of(2.8)
    #   end
    # end
  end
end
