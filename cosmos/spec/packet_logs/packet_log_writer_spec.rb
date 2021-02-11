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
require 'cosmos/packet_logs/packet_log_writer'
require 'cosmos/packet_logs/packet_log_reader'

module Cosmos
  describe PacketLogWriter do
    before(:all) do
      setup_system()
      @log_dir = File.expand_path(File.join(SPEC_DIR, 'install', 'outputs', 'logs'))
    end

    before(:each) do
      @files = {}
      s3 = double("AwsS3Client").as_null_object
      allow(Aws::S3::Client).to receive(:new).and_return(s3)
      allow(s3).to receive(:put_object) do |args|
        @files[File.basename(args[:key])] = args[:body].read
      end
    end

    describe "initialize" do
      it "raises with a cycle_time < #{PacketLogWriter::CYCLE_TIME_INTERVAL}" do
        expect { PacketLogWriter.new(@log_dir, "test", true, 0, nil) }.to raise_error("cycle_time must be >= #{PacketLogWriter::CYCLE_TIME_INTERVAL}")
        expect { PacketLogWriter.new(@log_dir, "test", true, 1, nil) }.to raise_error("cycle_time must be >= #{PacketLogWriter::CYCLE_TIME_INTERVAL}")
        expect { PacketLogWriter.new(@log_dir, "test", true, 1.5, nil) }.to raise_error("cycle_time must be >= #{PacketLogWriter::CYCLE_TIME_INTERVAL}")
      end
    end

    describe "write" do
      it "raises with invalid type" do
        capture_io do |stdout|
          plw = PacketLogWriter.new(@log_dir, 'test')
          plw.write(:BLAH, :CMD, 'TGT', 'CMD', 0, true, "\x01\x02", nil)
          expect(stdout.string).to match("Unknown entry_type: BLAH")
          plw.shutdown
          sleep 0.1
        end
      end

      it "writes binary data to a binary and index file" do
        first_time = Time.now.to_nsec_from_epoch
        last_time = first_time += 1_000_000_000
        label = 'test'
        plw = PacketLogWriter.new(@log_dir, label)
        expect(plw.instance_variable_get(:@file_size)).to eq 0
        # Mark the first packet as "stored" (true)
        plw.write(:RAW_PACKET, :TLM, 'TGT1', 'PKT1', first_time, true, "\x01\x02", nil)
        expect(plw.instance_variable_get(:@file_size)).to_not eq 0
        plw.write(:RAW_PACKET, :TLM, 'TGT2', 'PKT2', last_time, false, "\x03\x04", nil)
        plw.shutdown
        sleep 0.1 # Allow for shutdown thread "copy" to S3

        # Files copied to S3 are named via the first_time, last_time, label
        expect(@files.keys).to contain_exactly("#{first_time}__#{last_time}__#{label}.bin",
          "#{first_time}__#{last_time}__#{label}.idx")

        # Verify the COSMOS5 header on the binary file
        bin = @files["#{first_time}__#{last_time}__#{label}.bin"]
        results = bin.unpack("Z8")[0]
        expect(results).to eq 'COSMOS5_'
        # puts bin.formatted

        # Verify the COSMOS5 header on the index file
        idx = @files["#{first_time}__#{last_time}__#{label}.idx"]
        results = idx.unpack("Z8")[0]
        expect(results).to eq 'COSIDX5_'
        # puts idx.formatted

        # Verify the packets by using PacketLogReader
        File.open('test_log.bin','wb') { |file| file.write bin }
        reader = PacketLogReader.new
        reader.open('test_log.bin')
        pkt = reader.read
        expect(pkt.target_name).to eq 'TGT1'
        expect(pkt.packet_name).to eq 'PKT1'
        expect(pkt.stored).to be true
        expect(pkt.buffer).to eq "\x01\x02"
        pkt = reader.read
        expect(pkt.target_name).to eq 'TGT2'
        expect(pkt.packet_name).to eq 'PKT2'
        expect(pkt.stored).to be false
        expect(pkt.buffer).to eq "\x03\x04"
        pkt = reader.read
        expect(pkt).to be_nil
        reader.close()
        FileUtils.rm_f 'test_log.bin'
      end

      it "cycles the log when it a size" do
        time = Time.now.to_nsec_from_epoch
        target_name = 'TGT'
        packet_name = 'PKT'
        pkt = Packet.new(target_name, packet_name)
        pkt.buffer = "\x01\x02\x03\x04"
        label = 'test'

        # Figure out the exact size of the file using PacketLogWriter constants
        file_size = PacketLogWriter::COSMOS5_FILE_HEADER.length
        # The target and packet declarations are only repeated once per target / packet
        tmp = Array.new(PacketLogWriter::COSMOS5_TARGET_DECLARATION_PACK_ITEMS, 0)
        data = tmp.pack(PacketLogWriter::COSMOS5_TARGET_DECLARATION_PACK_DIRECTIVE)
        file_size += data.length + target_name.length
        tmp = Array.new(PacketLogWriter::COSMOS5_PACKET_DECLARATION_PACK_ITEMS, 0)
        data = tmp.pack(PacketLogWriter::COSMOS5_PACKET_DECLARATION_PACK_DIRECTIVE)
        file_size += data.length + packet_name.length

        # Set the file size to contain exactly two packets
        tmp = Array.new(PacketLogWriter::COSMOS5_PACKET_PACK_ITEMS, 0)
        data = tmp.pack(PacketLogWriter::COSMOS5_PACKET_PACK_DIRECTIVE)
        file_size += 2 * (data.length + pkt.buffer.length)

        plw = PacketLogWriter.new(@log_dir, label, true, nil, file_size)
        plw.write(:RAW_PACKET, :TLM, target_name, packet_name, time, false, pkt.buffer, nil)
        time += 1_000_000_000
        plw.write(:RAW_PACKET, :TLM, target_name, packet_name, time, false, pkt.buffer, nil)
        time += 1_000_000_000
        sleep 0.1

        # At this point we've written two packets ... our file should be full but not closed
        expect(plw.instance_variable_get(:@file_size)).to eq file_size
        expect(@files.keys.length).to eq 0 # No files have been written out

        # One more write should cause the first file to close and new one to open
        plw.write(:RAW_PACKET, :TLM, target_name, packet_name, time, false, pkt.buffer, nil)
        sleep 0.1
        expect(@files.keys.length).to eq 2 # Initial files (binary and index)

        plw.shutdown
        sleep 0.1
        expect(@files.keys.length).to eq 4
      end

      it "cycles the log after a set amount of time" do
        # Monkey patch the constant so the test doesn't take forever
        PacketLogWriter.__send__(:remove_const,:CYCLE_TIME_INTERVAL)
        PacketLogWriter.const_set(:CYCLE_TIME_INTERVAL, 0.1)

        time = Time.now.to_nsec_from_epoch
        label = 'test'
        plw = PacketLogWriter.new(@log_dir, label, true, 1, nil) # cycle every sec
        15.times do
          plw.write(:RAW_PACKET, :TLM, 'TGT1', 'PKT1', time, true, "\x01\x02", nil)
          time += 200_000_000
          sleep 0.2
        end
        plw.shutdown
        sleep 0.1
        # Since we wrote about 5s we should see 3 separate cycles
        expect(@files.keys.length).to eq 6

        # Monkey patch the constant back to the default
        PacketLogWriter.__send__(:remove_const,:CYCLE_TIME_INTERVAL)
        PacketLogWriter.const_set(:CYCLE_TIME_INTERVAL, 2)
      end

      it "handles errors creating the log file" do
        capture_io do |stdout|
          allow(File).to receive(:new) { raise "Error" }
          plw = PacketLogWriter.new(@log_dir, "test")
          plw.write(:RAW_PACKET, :TLM, 'TGT1', 'PKT1', Time.now.to_nsec_from_epoch, true, "\x01\x02", nil)
          sleep 0.1
          plw.stop
          expect(stdout.string).to match("Error opening")
          plw.shutdown
          sleep 0.1
        end
      end

      it "handles errors closing the log file" do
        capture_io do |stdout|
          allow_any_instance_of(File).to receive(:close).and_raise('Nope')
          plw = PacketLogWriter.new(@log_dir, "test")
          plw.write(:RAW_PACKET, :TLM, 'TGT1', 'PKT1', Time.now.to_nsec_from_epoch, true, "\x01\x02", nil)
          sleep 0.1
          plw.stop
          expect(stdout.string).to match("Error closing")
          plw.shutdown
          sleep 0.1
        end
      end

      it "raises an error after #{PacketLogWriter::COSMOS5_MAX_TARGET_INDEX} targets" do
        capture_io do |stdout|
          plw = PacketLogWriter.new(@log_dir, "test")
          # Plus 2 because 0 to MAX are all valid so +1 is ok and +2 errors
          (PacketLogWriter::COSMOS5_MAX_TARGET_INDEX + 2).times do |i|
            plw.write(:RAW_PACKET, :TLM, "TGT#{i}", "PKT", Time.now.to_nsec_from_epoch, true, "\x01\x02", nil)
          end
          expect(stdout.string).to match("Target Index Overflow")
          plw.shutdown
          sleep 0.1
        end
      end

      it "raises an error after #{PacketLogWriter::COSMOS5_MAX_PACKET_INDEX} packets" do
        capture_io do |stdout|
          plw = PacketLogWriter.new(@log_dir, "test")
          # Plus 2 because 0 to MAX are all valid so +1 is ok and +2 errors
          (PacketLogWriter::COSMOS5_MAX_PACKET_INDEX + 2).times do |i|
            plw.write(:RAW_PACKET, :TLM, "TGT", "PKT#{i}", Time.now.to_nsec_from_epoch, true, "\x01\x02", nil)
          end
          expect(stdout.string).to match("Packet Index Overflow")
          plw.shutdown
          sleep 0.1
        end
      end
    end

    describe "start" do
      it "enables logging" do
        plw = PacketLogWriter.new(@log_dir, 'test', false) # Logging not enabled
        plw.write(:RAW_PACKET, :CMD, 'TGT', 'CMD', Time.now.to_nsec_from_epoch, true, "\x01\x02", nil)
        expect(plw.instance_variable_get(:@file_size)).to eq 0

        plw.start # Enable logging
        plw.write(:RAW_PACKET, :CMD, 'TGT', 'CMD', Time.now.to_nsec_from_epoch, true, "\x01\x02", nil)
        expect(plw.instance_variable_get(:@file_size)).to_not eq 0

        plw.shutdown
        sleep 0.1
        expect(@files.keys.length).to eq 2
      end
    end
  end
end
