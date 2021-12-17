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
    end

    def setup_logfile
      @s3_file = double(S3File)
      allow(S3File).to receive(:new).and_return(@s3_file)

      allow(File).to receive(:delete).and_return(nil)
      s3 = double("Aws::S3::Client").as_null_object
      allow(Aws::S3::Client).to receive(:new).and_return(s3)

      # Create a fake filename that matches what happens when we copy a file to S3
      # This is critical since we split on '__' to pull out the scope, target, packet
      plw = PacketLogWriter.new(@log_path, 'START__END__DEFAULT__INST__HEALTH_STATUS__rt__decom')
      @start_time = Time.now
      @pkt = System.telemetry.packet("INST", "HEALTH_STATUS")
      @pkt.received_time = @start_time
      collects = 0
      @pkt.write("COLLECTS", collects)

      90.times do
        json_hash = TelemetryDecomTopic.build_json(@pkt)
        plw.write(:JSON_PACKET, :TLM, @pkt.target_name, @pkt.packet_name, @pkt.received_time.to_nsec_from_epoch,
          true, JSON.generate(json_hash.as_json))
        @pkt.received_time += 20
        collects += 1
        @pkt.write("COLLECTS", collects)
      end
      @logfile = plw.filename
      # @logfile = File.join(SPEC_DIR, "install/20211215233932929797300__20211215234933511878600__DEFAULT__INST__HEALTH_STATUS__rt__decom.bin")
      allow(@s3_file).to receive(:retrieve).and_return(nil)
      allow(@s3_file).to receive(:local_path).and_return(@logfile)
      allow(@s3_file).to receive(:delete).and_return(nil)

      @output_files = []
      allow(S3Utilities).to receive(:move_log_file_to_s3) do |filename, s3_key|
        # puts "filename:#{filename} s3:#{s3_key}"
        log_file = File.join(@log_path, s3_key.split('/')[-1])
        FileUtils.move filename, log_file
        @output_files << log_file
      end
    end

    describe "reduce_minute" do
      it "reduces data" do
        setup_logfile()
        ReducerModel.add_decom(filename: @logfile, scope: "DEFAULT")
        @reducer.reduce_minute
        @reducer.shutdown
        sleep 0.1
        plr = PacketLogReader.new
        @output_files.each do |file|
          puts "output file:#{file}"
          plr.each(file) do |packet|
            puts "collects min:#{packet.read("COLLECTS__MIN")} max:#{packet.read("COLLECTS__MAX")} avg:#{packet.read("COLLECTS__AVG")} stddev:#{packet.read("COLLECTS__STDDEV")} samples:#{packet.read("COLLECTS__SAMPLES")}"
          end
        end
      end
    end
    #   it "reduces 60s of decom data" do
    #     @reducer.initialize_streams
    #     @reducer.get_initial_offsets

    #     start_time = Time.now.sys
    #     packet = System.telemetry.packet("INST", "HEALTH_STATUS")
    #     offset = 0
    #     6.times do
    #       packet.received_time = start_time + offset
    #       TelemetryDecomTopic.write_packet(packet, id: "#{packet.received_time.to_i * 1000}-0", scope: "DEFAULT")
    #       offset += 10 # seconds
    #     end
    #     @reducer.reduce_minute # Initially shouldn't process due to not enough data
    #     expect(Store.xlen("DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS")).to eql 0

    #     packet.received_time = start_time + offset
    #     offset += 10
    #     TelemetryDecomTopic.write_packet(packet, id: "#{packet.received_time.to_i * 1000}-0", scope: "DEFAULT")
    #     @reducer.reduce_minute # <= Do the work!

    #     # One minute of data should be processed
    #     expect(Store.xlen("DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS")).to eql 1
    #     result = Store.read_topics(["DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS"], ['0-0'])
    #     msg_hash = result["DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS"][0][1]
    #     expect(msg_hash['target_name']).to eql "INST"
    #     expect(msg_hash['packet_name']).to eql "HEALTH_STATUS"
    #     data = JSON.parse(msg_hash['json_data'])
    #     expect(data['PACKET_TIMESECONDS__MIN']).to eql start_time.to_f + 10
    #     expect(data['PACKET_TIMESECONDS__MAX']).to eql start_time.to_f + 60
    #     expect(data['PACKET_TIMESECONDS__STDDEV']).to be_within(0.1).of(17)

    #     # Throw in another minute of data
    #     6.times do
    #       packet.received_time = start_time + offset
    #       TelemetryDecomTopic.write_packet(packet, id: "#{packet.received_time.to_i * 1000}-0", scope: "DEFAULT")
    #       offset += 10 # seconds
    #     end
    #     @reducer.reduce_minute # <= Do the work!

    #     # 2 minutes of data should be processed
    #     expect(Store.xlen("DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS")).to eql 2
    #     result = Store.read_topics(["DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS"], ['0-0'])
    #     msg_hash = result["DEFAULT__REDUCED_MINUTE__{INST}__HEALTH_STATUS"][1][1]
    #     expect(msg_hash['target_name']).to eql "INST"
    #     expect(msg_hash['packet_name']).to eql "HEALTH_STATUS"
    #     data = JSON.parse(msg_hash['json_data'])
    #     expect(data['PACKET_TIMESECONDS__MIN']).to eql start_time.to_f + 70
    #     expect(data['PACKET_TIMESECONDS__MAX']).to eql start_time.to_f + 120
    #     expect(data['PACKET_TIMESECONDS__STDDEV']).to be_within(0.1).of(17)
    #   end
    # end

    # describe "reduce_hour" do
    #   it "reduces 1h of decom data" do
    #     @reducer.initialize_streams
    #     @reducer.get_initial_offsets

    #     start_time = Time.now.sys
    #     packet = System.telemetry.packet("INST", "HEALTH_STATUS")
    #     offset = 0
    #     370.times do |i|
    #       packet.received_time = start_time + offset
    #       packet.write("COLLECTS", rand(10))
    #       TelemetryDecomTopic.write_packet(packet, id: "#{(packet.received_time.to_f * 1000).to_i}-0", scope: "DEFAULT")
    #       offset += 10 # seconds
    #     end

    #     @reducer.reduce_minute
    #     @reducer.reduce_hour

    #     # 1 hour of data should be reduced
    #     expect(Store.xlen("DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS")).to eql 1
    #     result = Store.read_topics(["DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS"], ['0-0'])
    #     expect(result["DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS"].length).to eql 1
    #     data = JSON.parse(result["DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS"][0][1]['json_data'])
    #     expect(data['PACKET_TIMESECONDS__MIN']).to eql start_time.to_f + 70
    #     expect(data['PACKET_TIMESECONDS__MAX']).to eql start_time.to_f + 3660 # 1 hr
    #     expect(data['COLLECTS__MIN']).to eql 0
    #     expect(data['COLLECTS__MAX']).to eql 9
    #     expect(data['COLLECTS__STDDEV']).to be_within(0.3).of(2.8)

    #     # Throw in another hour of data
    #     360.times do |i|
    #       packet.received_time = start_time + offset
    #       packet.write("COLLECTS", rand(10))
    #       packet.write("GROUND1STATUS", 1)
    #       TelemetryDecomTopic.write_packet(packet, id: "#{(packet.received_time.to_f * 1000).to_i}-0", scope: "DEFAULT")
    #       offset += 10 # seconds
    #     end

    #     @reducer.reduce_minute
    #     @reducer.reduce_hour

    #     # 2 hours of data should be reduced
    #     expect(Store.xlen("DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS")).to eql 2
    #     result = Store.read_topics(["DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS"], ['0-0'])
    #     expect(result["DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS"].length).to eql 2
    #     data = JSON.parse(result["DEFAULT__REDUCED_HOUR__{INST}__HEALTH_STATUS"][1][1]['json_data'])
    #     expect(data['PACKET_TIMESECONDS__MIN']).to eql start_time.to_f + 3670 # First hour includes extra minute
    #     expect(data['PACKET_TIMESECONDS__MAX']).to eql start_time.to_f + (3660 + 3600) # 2 hr
    #     expect(data['COLLECTS__MIN']).to eql 0
    #     expect(data['COLLECTS__MAX']).to eql 9
    #     expect(data['COLLECTS__STDDEV']).to be_within(0.3).of(2.8)
    #   end
    # end

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
