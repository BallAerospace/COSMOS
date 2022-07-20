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
require 'tempfile'
require 'openc3/logs/packet_log_reader'

module OpenC3
  describe PacketLogReader do
    before(:all) do
      setup_system()
      @log_path = File.expand_path(File.join(SPEC_DIR, 'install', 'outputs', 'logs'))
    end

    before(:each) do
      @plr = PacketLogReader.new
    end

    describe "open" do
      it "complains if the log file is too small" do
        tf = Tempfile.new('log_file')
        tf.puts "BLAH"
        tf.close
        expect { @plr.open(tf.path) }.to raise_error(/Failed to read/)
        tf.unlink
      end

      it "complains if the log has a COSMOS2 header" do
        filename = File.join(@log_path, 'test.bin')
        File.open(filename, 'wb') do |file|
          file.write "#{PacketLogReader::COSMOS2_FILE_HEADER}\x00\x00\000\x00"
        end
        expect { @plr.open(filename) }.to raise_error("COSMOS 2 log file must be converted to OpenC3 5")
      end

      it "complains if the log has a COSMOS4 header" do
        filename = File.join(@log_path, 'test.bin')
        File.open(filename, 'wb') do |file|
          file.write "#{PacketLogReader::COSMOS4_FILE_HEADER}\x00\x00\000\x00"
        end
        expect { @plr.open(filename) }.to raise_error("COSMOS 4 log file must be converted to OpenC3 5")
      end

      it "complains if the log has no OpenC3 header" do
        filename = File.join(@log_path, 'test.bin')
        File.open(filename, 'wb') do |file|
          10.times do
            file.write "\x00\x00"
          end
        end
        expect { @plr.open(filename) }.to raise_error("OpenC3 file header not found")
      end
    end

    describe "each" do
      def setup_logfile(cmd_or_tlm, raw_or_json)
        allow(File).to receive(:delete).and_return(nil)
        s3 = double("Aws::S3::Client").as_null_object
        allow(Aws::S3::Client).to receive(:new).and_return(s3)
        plw = PacketLogWriter.new(@log_path, 'spec')
        @start_time = Time.now
        time = @start_time.to_nsec_from_epoch
        @times = [time, time + Time::NSEC_PER_SECOND, time + 2 * Time::NSEC_PER_SECOND]
        if cmd_or_tlm == :CMD
          @pkt = System.commands.packet("INST", "COLLECT")
          @pkt.write("DURATION", 10.0)
        else
          @pkt = System.telemetry.packet("INST", "HEALTH_STATUS")
          @pkt.write("COLLECTS", 100)
        end
        data = raw_or_json == :RAW_PACKET ? @pkt.buffer : JSON.generate(@pkt.as_json(:allow_nan => true))
        plw.write(raw_or_json, cmd_or_tlm, @pkt.target_name, @pkt.packet_name, @times[0], true, data, nil, '0-0')
        plw.write(raw_or_json, cmd_or_tlm, @pkt.target_name, @pkt.packet_name, @times[1], true, data, nil, '0-0')
        plw.write(raw_or_json, cmd_or_tlm, @pkt.target_name, @pkt.packet_name, @times[2], true, data, nil, '0-0')
        @logfile = plw.filename
        plw.shutdown
        sleep 0.1

        # Calculate the size of a single packet entry
        tmp = Array.new(PacketLogReader::OPENC3_PACKET_PACK_ITEMS, 0)
        raw = tmp.pack(PacketLogReader::OPENC3_PACKET_PACK_DIRECTIVE)
        @pkt_entry_length = raw.length + data.length
      end

      context "with raw telemetry" do
        before(:each) do
          setup_logfile(:TLM, :RAW_PACKET)
        end
        after(:each) do
          FileUtils.rm_f @logfile
        end

        it "returns identified packets" do
          last_bytes_read = 0
          index = 0
          @plr.each(@logfile) do |packet|
            expect(packet.target_name).to eql @pkt.target_name
            expect(packet.packet_name).to eql @pkt.packet_name
            expect(packet.buffer).to eql @pkt.buffer
            expect(packet.read("COLLECTS")).to eql 100
            expect(packet.received_time.to_nsec_from_epoch).to eql @times[index]
            expect(packet.received_count).to eql index + 1
            if last_bytes_read != 0
              # Check the size of single packet entry
              expect(@plr.bytes_read - last_bytes_read).to eql @pkt_entry_length
            end
            last_bytes_read = @plr.bytes_read
            index += 1
          end
        end

        it "optionally does not identify and define packets" do
          index = 0
          @plr.each(@logfile, false) do |packet|
            expect(packet.target_name).to eql @pkt.target_name
            expect(packet.packet_name).to eql @pkt.packet_name
            expect(packet.buffer).to eql @pkt.buffer
            expect { packet.read("COLLECTS") }.to raise_error(/does not exist/)
            expect(packet.received_time.to_nsec_from_epoch).to eql @times[index]
            expect(packet.received_count).to eql 1 # unidentified packets don't increment received_count
            index += 1
          end
        end
      end

      context "with json telemetry" do
        before(:each) do
          setup_logfile(:TLM, :JSON_PACKET)
        end
        after(:each) do
          FileUtils.rm_f @logfile
        end

        it "returns identified packets" do
          last_bytes_read = 0
          index = 0
          @plr.each(@logfile) do |packet|
            expect(packet.target_name).to eql @pkt.target_name
            expect(packet.packet_name).to eql @pkt.packet_name
            # TODO: How do I read an item value ... they don't appear to be set
            # expect(packet.read("COLLECTS")).to eql 100
            expect(packet.packet_time.to_nsec_from_epoch).to eql @times[index]
            # TODO: Should JsonPacket have a received_count?
            # expect(packet.received_count).to eql index + 1
            if last_bytes_read != 0
              # Check the size of single packet entry
              expect(@plr.bytes_read - last_bytes_read).to eql @pkt_entry_length
            end
            last_bytes_read = @plr.bytes_read
            index += 1
          end
        end
      end

      context "with raw commands" do
        before(:each) do
          setup_logfile(:CMD, :RAW_PACKET)
        end
        after(:each) do
          FileUtils.rm_f @logfile
        end

        it "returns identified packets" do
          last_bytes_read = 0
          index = 0
          @plr.each(@logfile) do |packet|
            expect(packet.target_name).to eql @pkt.target_name
            expect(packet.packet_name).to eql @pkt.packet_name
            expect(packet.buffer).to eql @pkt.buffer
            expect(packet.read("DURATION")).to eql 10.0
            expect(packet.received_time.to_nsec_from_epoch).to eql @times[index]
            expect(packet.received_count).to eql index + 1
            if last_bytes_read != 0
              # Check the size of single packet entry
              expect(@plr.bytes_read - last_bytes_read).to eql @pkt_entry_length
            end
            last_bytes_read = @plr.bytes_read
            index += 1
          end
        end

        it "optionally does not identify and define packets" do
          index = 0
          @plr.each(@logfile, false) do |packet|
            expect(packet.target_name).to eql @pkt.target_name
            expect(packet.packet_name).to eql @pkt.packet_name
            expect(packet.buffer).to eql @pkt.buffer
            expect { packet.read("DURATION") }.to raise_error(/does not exist/)
            expect(packet.received_time.to_nsec_from_epoch).to eql @times[index]
            expect(packet.received_count).to eql 1 # unidentified packets don't increment received_count
            index += 1
          end
        end
      end

      context "with json commands" do
        before(:each) do
          setup_logfile(:CMD, :JSON_PACKET)
        end
        after(:each) do
          FileUtils.rm_f @logfile
        end

        it "returns identified packets" do
          last_bytes_read = 0
          index = 0
          @plr.each(@logfile) do |packet|
            expect(packet.target_name).to eql @pkt.target_name
            expect(packet.packet_name).to eql @pkt.packet_name
            # TODO: How do I read an item value ... they don't appear to be set
            # expect(packet.read("DURATION")).to eql 10.0
            expect(packet.packet_time.to_nsec_from_epoch).to eql @times[index]
            # TODO: Should JsonPacket have a received_count?
            # expect(packet.received_count).to eql index + 1
            if last_bytes_read != 0
              # Check the size of single packet entry
              expect(@plr.bytes_read - last_bytes_read).to eql @pkt_entry_length
            end
            last_bytes_read = @plr.bytes_read
            index += 1
          end
        end
      end

      context "with start and end times" do
        before(:each) do
          setup_logfile(:TLM, :RAW_PACKET)
        end
        after(:each) do
          FileUtils.rm_f @logfile
        end

        it "returns all packets if the start time is before all" do
          index = 0
          reached_end_time = @plr.each(@logfile, true, @start_time - 1) do |packet|
            expect(packet.packet_time.to_nsec_from_epoch).to eql @times[index]
            index += 1
          end
          expect(index).to eql 3
          expect(reached_end_time).to be false
        end

        it "returns no packets if the start time is after all" do
          index = 0
          reached_end_time = @plr.each(@logfile, true, @start_time + 10) do |packet|
            index += 1
          end
          expect(index).to eql 0
          expect(reached_end_time).to be false
        end

        it "returns all packets after a start time" do
          index = 1
          reached_end_time = @plr.each(@logfile, true, @start_time + 1) do |packet|
            # puts "i:#{index} time:#{packet.received_time}"
            expect(packet.packet_time.to_nsec_from_epoch).to eql @times[index]
            index += 1
          end
          expect(index).to eql 3
          expect(reached_end_time).to be false

          index = 2
          reached_end_time = @plr.each(@logfile, true, @start_time + 2) do |packet|
            expect(packet.packet_time.to_nsec_from_epoch).to eql @times[index]
            index += 1
          end
          expect(index).to eql 3
          expect(reached_end_time).to be false
        end

        it "returns no packets if the end time is before all" do
          index = 0
          reached_end_time = @plr.each(@logfile, true, nil, @start_time - 1) do |packet|
            index += 1
          end
          expect(index).to eql 0
          expect(reached_end_time).to be true
        end

        it "returns all packets if the end time is after all" do
          index = 0
          reached_end_time = @plr.each(@logfile, true, nil, @start_time + 4) do |packet|
            expect(packet.packet_time.to_nsec_from_epoch).to eql @times[index]
            index += 1
          end
          expect(index).to eql 3
          expect(reached_end_time).to be false
        end

        it "returns all packets before an end time" do
          index = 0
          reached_end_time = @plr.each(@logfile, true, nil, @start_time + 1) do |packet|
            expect(packet.packet_time.to_nsec_from_epoch).to eql @times[index]
            index += 1
          end
          expect(index).to eql 2 # Since we're exactly at the end time we get the packet
          expect(reached_end_time).to be true

          index = 0
          reached_end_time = @plr.each(@logfile, true, nil, @start_time + 1.99) do |packet|
            expect(packet.packet_time.to_nsec_from_epoch).to eql @times[index]
            index += 1
          end
          expect(index).to eql 2 # Still 2 since we didn't go over
          expect(reached_end_time).to be true

          index = 0
          reached_end_time = @plr.each(@logfile, true, nil, @start_time + 2.01) do |packet|
            expect(packet.packet_time.to_nsec_from_epoch).to eql @times[index]
            index += 1
          end
          expect(index).to eql 3 # Got them all
          expect(reached_end_time).to be false # We didn't reach the end time before we ran out of packets
        end
      end
    end

    # describe "packet_offsets and read_at_offset" do
    #   it "returns packet offsets CTS-20, CTS-22" do
    #     packet_offsets = @plr.packet_offsets(Dir[File.join(@log_path,"*cmd.bin")][0])
    #     expect(@plr.log_type).to eql :CMD
    #     expect(@plr.configuration_name).not_to be_nil
    #     expect(@plr.hostname).to eql Socket.gethostname
    #     header_length = 1 + 8 + 1 + 6 + 1 + 12 + 4
    #     meta_header_length = 1 + 8 + 1 + 6 + 1 + 4 + 4
    #     meta_length = System.telemetry.packet('SYSTEM', 'META').length
    #     expect(packet_offsets).to eql [PacketLogReader::COSMOS4_HEADER_LENGTH, PacketLogReader::COSMOS4_HEADER_LENGTH + meta_header_length + meta_length, PacketLogReader::COSMOS4_HEADER_LENGTH + meta_header_length + meta_length + header_length + @cmd_packet_length, PacketLogReader::COSMOS4_HEADER_LENGTH + meta_header_length + meta_length + (header_length + @cmd_packet_length) * 2]

    #     expect(@plr.open(Dir[File.join(@log_path,"*cmd.bin")][0])).to eql [true, nil]
    #     pkt = @plr.read_at_offset(packet_offsets[2]) # Grab the second STARTLOGGING (META is 0)
    #     expect(pkt.target_name).to eql "SYSTEM"
    #     expect(pkt.packet_name).to eql "STARTLOGGING"
    #     expect(pkt.read('LABEL')).to eql "PKT2"
    #     expect(pkt.received_time).to eql @time + 1
    #     @plr.close
    #   end

    #   it "returns telemetry packet information" do
    #     packet_offsets = @plr.packet_offsets(Dir[File.join(@log_path,"*tlm.bin")][0])
    #     expect(@plr.log_type).to eql :TLM
    #     expect(@plr.configuration_name).not_to be_nil
    #     expect(@plr.hostname).to eql Socket.gethostname
    #     header_length = 1 + 8 + 1 + 6 + 1 + 13 + 4
    #     meta_header_length = 1 + 8 + 1 + 6 + 1 + 4 + 4
    #     meta_length = System.telemetry.packet('SYSTEM', 'META').length
    #     expect(packet_offsets).to eql [PacketLogReader::COSMOS4_HEADER_LENGTH, PacketLogReader::COSMOS4_HEADER_LENGTH + meta_header_length + meta_length, PacketLogReader::COSMOS4_HEADER_LENGTH + meta_header_length + meta_length + header_length + @tlm_packet_length, PacketLogReader::COSMOS4_HEADER_LENGTH + meta_header_length + meta_length + (header_length + @tlm_packet_length) * 2]

    #     expect(@plr.open(Dir[File.join(@log_path,"*tlm.bin")][0])).to eql [true, nil]
    #     pkt = @plr.read_at_offset(packet_offsets[2]) # Grab the second LIMITS_CHANGE (META is 0)
    #     expect(pkt.target_name).to eql "SYSTEM"
    #     expect(pkt.packet_name).to eql "LIMITS_CHANGE"
    #     expect(pkt.read('PACKET')).to eql "PKT2"
    #     expect(pkt.received_time).to eql @time + 1
    #     @plr.close
    #   end
    # end

    # describe "first" do
    #   it "returns the first command packet and retain the file position" do
    #     expect(@plr.open(Dir[File.join(@log_path,"*cmd.bin")][0])).to eql [true, nil]
    #     pkt1 = @plr.read
    #     pkt1 = @plr.read
    #     expect(pkt1.target_name).to eql @cmd_packets[0].target_name
    #     expect(pkt1.packet_name).to eql @cmd_packets[0].packet_name
    #     expect(pkt1.received_time).to eql @cmd_packets[0].received_time
    #     expect(pkt1.read('LABEL')).to eql @cmd_packets[0].read('LABEL')

    #     first = @plr.first
    #     expect(first.target_name).to eql 'SYSTEM'
    #     expect(first.packet_name).to eql 'META'

    #     pkt2 = @plr.read
    #     expect(pkt2.target_name).to eql @cmd_packets[1].target_name
    #     expect(pkt2.packet_name).to eql @cmd_packets[1].packet_name
    #     expect(pkt2.received_time).to eql @cmd_packets[1].received_time
    #     expect(pkt2.read('LABEL')).to eql @cmd_packets[1].read('LABEL')
    #     @plr.close
    #   end

    #   it "returns the first telemetry packet and retain the file position" do
    #     expect(@plr.open(Dir[File.join(@log_path,"*tlm.bin")][0])).to eql [true, nil]
    #     pkt1 = @plr.read
    #     pkt1 = @plr.read
    #     expect(pkt1.target_name).to eql @tlm_packets[0].target_name
    #     expect(pkt1.packet_name).to eql @tlm_packets[0].packet_name
    #     expect(pkt1.received_time).to eql @tlm_packets[0].received_time
    #     expect(pkt1.read('PACKET')).to eql @tlm_packets[0].read('PACKET')

    #     first = @plr.first
    #     expect(first.target_name).to eql 'SYSTEM'
    #     expect(first.packet_name).to eql 'META'

    #     pkt2 = @plr.read
    #     expect(pkt2.target_name).to eql @tlm_packets[1].target_name
    #     expect(pkt2.packet_name).to eql @tlm_packets[1].packet_name
    #     expect(pkt2.received_time).to eql @tlm_packets[1].received_time
    #     expect(pkt2.read('PACKET')).to eql @tlm_packets[1].read('PACKET')
    #     @plr.close
    #   end
    # end

    # describe "last" do
    #   it "returns the last command packet and retain the file position" do
    #     expect(@plr.open(Dir[File.join(@log_path,"*cmd.bin")][0])).to eql [true, nil]
    #     pkt1 = @plr.read
    #     pkt1 = @plr.read
    #     expect(pkt1.target_name).to eql @cmd_packets[0].target_name
    #     expect(pkt1.packet_name).to eql @cmd_packets[0].packet_name
    #     expect(pkt1.received_time).to eql @cmd_packets[0].received_time
    #     expect(pkt1.read('LABEL')).to eql @cmd_packets[0].read('LABEL')

    #     last = @plr.last
    #     expect(last.target_name).to eql @cmd_packets[2].target_name
    #     expect(last.packet_name).to eql @cmd_packets[2].packet_name
    #     expect(last.received_time).to eql @cmd_packets[2].received_time
    #     expect(last.read('LABEL')).to eql @cmd_packets[2].read('LABEL')

    #     pkt2 = @plr.read
    #     expect(pkt2.target_name).to eql @cmd_packets[1].target_name
    #     expect(pkt2.packet_name).to eql @cmd_packets[1].packet_name
    #     expect(pkt2.received_time).to eql @cmd_packets[1].received_time
    #     expect(pkt2.read('LABEL')).to eql @cmd_packets[1].read('LABEL')
    #     @plr.close
    #   end

    #   it "returns the last telemetry packet and retain the file position" do
    #     expect(@plr.open(Dir[File.join(@log_path,"*tlm.bin")][0])).to eql [true, nil]
    #     pkt1 = @plr.read
    #     pkt1 = @plr.read
    #     expect(pkt1.target_name).to eql @tlm_packets[0].target_name
    #     expect(pkt1.packet_name).to eql @tlm_packets[0].packet_name
    #     expect(pkt1.received_time).to eql @tlm_packets[0].received_time
    #     expect(pkt1.read('PACKET')).to eql @tlm_packets[0].read('PACKET')

    #     last = @plr.last
    #     expect(last.target_name).to eql @tlm_packets[2].target_name
    #     expect(last.packet_name).to eql @tlm_packets[2].packet_name
    #     expect(last.received_time).to eql @tlm_packets[2].received_time
    #     expect(last.read('PACKET')).to eql @tlm_packets[2].read('PACKET')

    #     pkt2 = @plr.read
    #     expect(pkt2.target_name).to eql @tlm_packets[1].target_name
    #     expect(pkt2.packet_name).to eql @tlm_packets[1].packet_name
    #     expect(pkt2.received_time).to eql @tlm_packets[1].received_time
    #     expect(pkt2.read('PACKET')).to eql @tlm_packets[1].read('PACKET')
    #     @plr.close
    #   end
    # end
  end
end
