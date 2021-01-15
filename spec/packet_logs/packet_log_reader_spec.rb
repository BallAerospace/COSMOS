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
require 'tempfile'
require 'cosmos/packet_logs/packet_log_reader'

module Cosmos
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
          file.write "#{PacketLogReader::COSMOS2_MARKER}\x00\x00\000\x00"
        end
        expect { @plr.open(filename) }.to raise_error("COSMOS 2 log file must be converted to COSMOS 5")
      end

      it "complains if the log has a COSMOS4 header" do
        filename = File.join(@log_path, 'test.bin')
        File.open(filename, 'wb') do |file|
          file.write "#{PacketLogReader::COSMOS4_MARKER}\x00\x00\000\x00"
        end
        expect { @plr.open(filename) }.to raise_error("COSMOS 4 log file must be converted to COSMOS 5")
      end

      it "complains if the log has no COSMOS header" do
        filename = File.join(@log_path, 'test.bin')
        File.open(filename, 'wb') do |file|
          10.times do
            file.write "\x00\x00"
          end
        end
        expect { @plr.open(filename) }.to raise_error("COSMOS file header not found")
      end
    end

    describe "each" do
      context "with telemetry" do
        before(:each) do
          allow(Aws::S3::Client).to receive(:new).and_raise("Nope")
          plw = PacketLogWriter.new(@log_path, 'spec')
          time = Time.now.to_nsec_from_epoch
          @times = [time, time + 1, time + 2]
          @pkt = System.telemetry.packet("INST", "HEALTH_STATUS").clone
          @pkt.write("COLLECTS", 100)
          plw.write(:RAW_PACKET, :TLM, @pkt.target_name, @pkt.packet_name, @times[0], true, @pkt.buffer, nil)
          plw.write(:RAW_PACKET, :TLM, @pkt.target_name, @pkt.packet_name, @times[1], true, @pkt.buffer, nil)
          plw.write(:RAW_PACKET, :TLM, @pkt.target_name, @pkt.packet_name, @times[2], true, @pkt.buffer, nil)
          @logfile = plw.filename
          plw.shutdown

          # Calculate the size of a single packet entry
          tmp = Array.new(PacketLogWriter::COSMOS5_PACKET_PACK_ITEMS, 0)
          data = tmp.pack(PacketLogWriter::COSMOS5_PACKET_PACK_DIRECTIVE)
          @pkt_entry_length = data.length + @pkt.length
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

      context "with commands" do
        before(:each) do
          allow(Aws::S3::Client).to receive(:new).and_raise("Nope")
          plw = PacketLogWriter.new(@log_path, 'spec')
          time = Time.now.to_nsec_from_epoch
          @times = [time, time + 1, time + 2]
          @pkt = System.commands.packet("INST", "COLLECT")
          @pkt.write("DURATION", 10.0)
          plw.write(:RAW_PACKET, :TLM, @pkt.target_name, @pkt.packet_name, @times[0], true, @pkt.buffer, nil)
          plw.write(:RAW_PACKET, :TLM, @pkt.target_name, @pkt.packet_name, @times[1], true, @pkt.buffer, nil)
          plw.write(:RAW_PACKET, :TLM, @pkt.target_name, @pkt.packet_name, @times[2], true, @pkt.buffer, nil)
          @logfile = plw.filename
          plw.shutdown

          # Calculate the size of a single packet entry
          tmp = Array.new(PacketLogWriter::COSMOS5_PACKET_PACK_ITEMS, 0)
          data = tmp.pack(PacketLogWriter::COSMOS5_PACKET_PACK_DIRECTIVE)
          @pkt_entry_length = data.length + @pkt.length
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

      xit "returns all packets if the start time is before all" do
        index = 0
        @plr.each(Dir[File.join(@log_path,"*cmd.bin")][0], true, @time) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @cmd_packets[index].target_name
          expect(packet.packet_name).to eql @cmd_packets[index].packet_name
          expect(packet.received_time).to eql @cmd_packets[index].received_time
          expect(packet.read('LABEL')).to eql @cmd_packets[index].read('LABEL')
          index += 1
        end
        expect(index).to eql 3
      end

      xit "returns no packets if the start time is after all" do
        index = 0
        @plr.each(Dir[File.join(@log_path,"*tlm.bin")][0], true, @time + 100) do |packet|
          index += 1
        end
        expect(index).to eql 0
      end

      xit "returns all packets after a start time" do
        index = 0
        @plr.each(Dir[File.join(@log_path,"*cmd.bin")][0], true, @time) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @cmd_packets[index].target_name
          expect(packet.packet_name).to eql @cmd_packets[index].packet_name
          expect(packet.received_time).to eql @cmd_packets[index].received_time
          expect(packet.read('LABEL')).to eql @cmd_packets[index].read('LABEL')
          index += 1
        end
        expect(index).to eql 3

        index = 1 # @time + 1
        @plr.each(Dir[File.join(@log_path,"*tlm.bin")][0], true, @time + 1) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @tlm_packets[index].target_name
          expect(packet.packet_name).to eql @tlm_packets[index].packet_name
          expect(packet.received_time).to eql @tlm_packets[index].received_time
          expect(packet.read('PACKET')).to eql @tlm_packets[index].read('PACKET')
          index += 1
        end
        expect(index).to eql 3
      end

      xit "returns no packets if the end time is before all" do
        index = 0
        @plr.each(Dir[File.join(@log_path,"*tlm.bin")][0], true, nil, @time - 10) do |packet|
          index += 1
        end
        expect(index).to eql 0
      end

      xit "returns all packets if the end time is after all" do
        index = 0
        @plr.each(Dir[File.join(@log_path,"*cmd.bin")][0], true, nil, @time + 10) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @cmd_packets[index].target_name
          expect(packet.packet_name).to eql @cmd_packets[index].packet_name
          expect(packet.received_time).to eql @cmd_packets[index].received_time
          expect(packet.read('LABEL')).to eql @cmd_packets[index].read('LABEL')
          index += 1
        end
        expect(index).to eql 3
      end

      xit "returns all packets before an end time" do
        index = 0
        @plr.each(Dir[File.join(@log_path,"*cmd.bin")][0], true, nil, @time) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @cmd_packets[index].target_name
          expect(packet.packet_name).to eql @cmd_packets[index].packet_name
          expect(packet.received_time).to eql @cmd_packets[index].received_time
          expect(packet.read('LABEL')).to eql @cmd_packets[index].read('LABEL')
          index += 1
        end
        expect(index).to eql 1

        index = 0
        @plr.each(Dir[File.join(@log_path,"*tlm.bin")][0], true, nil, @time + 1) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @tlm_packets[index].target_name
          expect(packet.packet_name).to eql @tlm_packets[index].packet_name
          expect(packet.received_time).to eql @tlm_packets[index].received_time
          expect(packet.read('PACKET')).to eql @tlm_packets[index].read('PACKET')
          index += 1
        end
        expect(index).to eql 2
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
