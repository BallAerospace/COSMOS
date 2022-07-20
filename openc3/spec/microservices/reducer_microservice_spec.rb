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
require 'openc3/microservices/reducer_microservice'
require 'openc3/topics/telemetry_decom_topic'
require 'fileutils'

module OpenC3
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
            ReducerModel.add_file(log_file)
          elsif log_file.include?("minute")
            @minute_files << log_file
            # Add the file to the ReducerModel like we would in the real system
            ReducerModel.add_file(log_file)
          elsif log_file.include?("hour")
            @hour_files << log_file
            # Add the file to the ReducerModel like we would in the real system
            ReducerModel.add_file(log_file)
          elsif log_file.include?("day")
            @day_files << log_file
            # Day files aren't added to ReducerModel because they are fully reduced
          end
          @reduced_files << log_file if log_file.include?("reduced")
        end
      end

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
      seqflag = 0
      @pkt.write("CCSDSSEQFLAGS", seqflag)
      @pkt.write("TEMP1", 0)

      num_pkts.times do
        json_hash = CvtModel.build_json_from_packet(@pkt)
        plw.write(:JSON_PACKET, :TLM, @pkt.target_name, @pkt.packet_name, @pkt.received_time.to_nsec_from_epoch,
          true, JSON.generate(json_hash.as_json(:allow_nan => true)))
        @pkt.received_time += time_delta
        collects += 1
        collects = 1 if collects > 65535
        @pkt.write("COLLECTS", collects)
        seqflag += 1
        seqflag %= 4
        @pkt.write("CCSDSSEQFLAGS", seqflag)
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
        expect(ReducerModel.all_files(type: :DECOM, target: "INST", scope: "DEFAULT")).to be_empty
        files = ReducerModel.all_files(type: :MINUTE, target: "INST", scope: "DEFAULT")
        expect(files.length).to eql 1
        # Start and end times are the same since there is only one entry
        # expect(File.basename(files[0])).to eql "20220101000000000000000__20220101000000000000000__DEFAULT__INST__HEALTH_STATUS__reduced__minute.bin"

        # 60s of data reduces to a single entry
        plr = PacketLogReader.new
        plr.open(@reduced_files[0])
        pkt = plr.read
        # SAMPLES does not have a conversion
        expect(pkt.read("COLLECTS_SAMPLES")).to eql(60)
        expect(pkt.read("COLLECTS_MIN")).to eql(1)
        expect(pkt.read("COLLECTS_MAX")).to eql(60)
        expect(pkt.read("COLLECTS_AVG")).to eql(30.5)
        expect(pkt.read("COLLECTS_STDDEV")).to be_within(0.001).of(17.318)
        # CCSDSSEQFLAGS has states
        expect(pkt.read("CCSDSSEQFLAGS_SAMPLES")).to eql(60)
        expect(pkt.read("CCSDSSEQFLAGS_MIN")).to eql(0)
        expect(pkt.read("CCSDSSEQFLAGS_MAX")).to eql(3)
        expect(pkt.read("CCSDSSEQFLAGS_AVG")).to eql(1.5)
        expect(pkt.read("CCSDSSEQFLAGS_STDDEV")).to be_within(0.001).of(1.118)
        # TEMP1 has a read and write conversion
        expect(pkt.read("TEMP1_SAMPLES")).to eql(60)
        expect(pkt.read("TEMP1_MIN")).to be_within(0.1).of(0)
        expect(pkt.read("TEMP1_MAX")).to be_within(0.1).of(0)
        expect(pkt.read("TEMP1_AVG")).to be_within(0.1).of(0)
        expect(pkt.read("TEMP1_STDDEV")).to be_within(0.1).of(0)
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
        expect(ReducerModel.all_files(type: :DECOM, target: "INST", scope: "DEFAULT")).to be_empty
        expect(ReducerModel.all_files(type: :MINUTE, target: "INST", scope: "DEFAULT").length).to eql 1

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
        # One sample per minute and 62 samples which will overflow into a new log file
        setup_logfile(start_time: start_time, num_pkts: 62, time_delta: 60)
        @reducer.reduce_minute
        @reducer.shutdown
        sleep 0.1

        # All decom files should have been removed since they were processed
        expect(ReducerModel.all_files(type: :DECOM, target: "INST", scope: "DEFAULT")).to be_empty
        files = ReducerModel.all_files(type: :MINUTE, target: "INST", scope: "DEFAULT")
        expect(files.length).to eql 2
        # expect(File.basename(files[0])).to eql "20220101000000000000000__20220101005900000000000__DEFAULT__INST__HEALTH_STATUS__reduced__minute.bin"
        # expect(File.basename(files[1])).to eql "20220101010000000000000__20220101010100000000000__DEFAULT__INST__HEALTH_STATUS__reduced__minute.bin"

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

      it "reduces at 1h packet time deltas" do
        start_time = Time.at(1641020400) # 2022/01/01 00:00:00
        # time delta is 1hr but we should still create the minute files
        setup_logfile(start_time: start_time, num_pkts: 2, time_delta: 3600)
        @reducer.reduce_minute
        @reducer.shutdown
        sleep 0.1

        # All decom files should have been removed since they were processed
        expect(ReducerModel.all_files(type: :DECOM, target: "INST", scope: "DEFAULT")).to be_empty
        files = ReducerModel.all_files(type: :MINUTE, target: "INST", scope: "DEFAULT")
        expect(files.length).to eql 2

        # We should have 2 output files
        index = 0
        files.each do |file|
          plr = PacketLogReader.new
          plr.each(file) do |pkt|
            expect(pkt.packet_time).to eql(start_time + index)
            expect(pkt.read("COLLECTS_SAMPLES")).to eql(1)
            index += 3600
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
        expect(ReducerModel.all_files(type: :DECOM, target: "INST", scope: "DEFAULT").length).to eql 0
        # We rolled over so there is one minute file remaining
        expect(ReducerModel.all_files(type: :MINUTE, target: "INST", scope: "DEFAULT").length).to eql 1
        files = ReducerModel.all_files(type: :HOUR, target: "INST", scope: "DEFAULT")
        expect(files.length).to eql 1 # We create 1 hour file

        plr = PacketLogReader.new
        plr.open(files[0])
        pkt = plr.read
        expect(pkt.read("COLLECTS_SAMPLES")).to eql(60)
        expect(pkt.read("COLLECTS_MIN")).to eql(1)
        expect(pkt.read("COLLECTS_MAX")).to eql(60)
        plr.close
      end

      it "reduces 4hrs of decom data" do
        start_time = Time.at(1641020400) # 2022/01/01 00:00:00
        # Create log data at every 15 min
        setup_logfile(start_time: start_time, num_pkts: 16, time_delta: 900)
        @reducer.reduce_minute
        @reducer.reduce_hour
        @reducer.shutdown
        sleep 0.1

        # All decom files should have been removed since they were processed
        expect(ReducerModel.all_files(type: :DECOM, target: "INST", scope: "DEFAULT").length).to eql 0
        # TODO: Why is there 1 minute file
        #puts "min len:#{ReducerModel.all_files(type: :MINUTE, target: "INST", scope: "DEFAULT").length}"
        files = ReducerModel.all_files(type: :HOUR, target: "INST", scope: "DEFAULT")
        expect(files.length).to eql 1 # We create 1 hour file

        index = 1
        plr = PacketLogReader.new
        plr.each(files[0]) do |pkt|
          # 4 samples since we are at 15 min intervals
          expect(pkt.read("COLLECTS_SAMPLES")).to eql(4)
          expect(pkt.read("COLLECTS_MIN")).to eql(index)
          expect(pkt.read("COLLECTS_MAX")).to eql(index + 3)
          index += 4
        end
      end

      it "creates another reduced file at 1 day" do
        start_time = Time.at(1641020400) # 2022/01/01 00:00:00
        # Create log data at every hour
        setup_logfile(start_time: start_time, num_pkts: 26, time_delta: 3600)
        @reducer.reduce_minute
        @reducer.reduce_hour
        @reducer.shutdown
        sleep 0.1

        # All decom files should have been removed since they were processed
        expect(ReducerModel.all_files(type: :DECOM, target: "INST", scope: "DEFAULT").length).to eql 0
        files = ReducerModel.all_files(type: :HOUR, target: "INST", scope: "DEFAULT")
        expect(files.length).to eql 2 # We create 2 hour files

        index = 1
        plr = PacketLogReader.new
        files.each do |file|
          plr.each(file) do |pkt|
            # 1 sample since we are at hour intervals
            expect(pkt.read("COLLECTS_SAMPLES")).to eql(1)
            expect(pkt.read("COLLECTS_MIN")).to eql(index)
            expect(pkt.read("COLLECTS_MAX")).to eql(index)
            index += 1
          end
        end
        expect(index).to eql 26
      end
    end

    describe "reduce_day" do
      it "reduces 1 day of decom data" do
        start_time = Time.at(1640995200) # 2022/01/01 00:00:00 GMT
        # Create 1 day of log data but force a roll over so we actually create the file
        setup_logfile(start_time: start_time, num_pkts: 50, time_delta: 3600)
        @reducer.reduce_minute
        @reducer.reduce_hour
        @reducer.reduce_day
        @reducer.shutdown
        sleep 0.1

        # All decom files should have been removed since they were processed
        expect(ReducerModel.all_files(type: :DECOM, target: "INST", scope: "DEFAULT").length).to eql 0
        # Rollover on hour so we have a remaining hour file
        expect(ReducerModel.all_files(type: :HOUR, target: "INST", scope: "DEFAULT").length).to eql 1
        # 1 reduced day created
        expect(@day_files.length).to eql 1

        index = 1
        plr = PacketLogReader.new
        plr.each(@day_files[0]) do |pkt|
          expect(pkt.read("COLLECTS_SAMPLES")).to eql(24)
          expect(pkt.read("COLLECTS_MIN")).to eql(index)
          expect(pkt.read("COLLECTS_MAX")).to eql(index + 23)
          index += 24
        end
        expect(index).to eql 49 # Check that we got 2 packets
      end
    end
  end
end
