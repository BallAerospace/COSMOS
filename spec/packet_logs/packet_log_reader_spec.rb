# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'tempfile'
require 'cosmos/packet_logs/packet_log_reader'

module Cosmos

  describe PacketLogReader do
    before(:all) do
      System.class_eval('@@instance = nil')
      System.load_configuration
      @log_path = System.paths['LOGS']

      plw = PacketLogWriter.new(:CMD,nil,true,nil,10000000,nil,false)
      @cmd_packets = []
      pkt = System.commands.packet("COSMOS","STARTLOGGING").clone
      pkt.received_time = Time.new(2020,1,31,12,30,15)
      pkt.write('label','PKT1')
      plw.write(pkt)
      @cmd_packet_length = pkt.length
      @cmd_packets << pkt
      pkt = pkt.clone
      pkt.received_time += 1
      pkt.write('label','PKT2')
      plw.write(pkt)
      @cmd_packets << pkt
      pkt = pkt.clone
      pkt.received_time += 1
      pkt.write('label','PKT3')
      plw.write(pkt)
      @cmd_packets << pkt
      plw.stop
      plw = PacketLogWriter.new(:TLM,nil,true,nil,10000000,nil,false)

      @tlm_packets = []
      pkt = System.telemetry.packet("COSMOS","VERSION").clone
      pkt.received_time = Time.new(2020,2,1,12,30,15)
      pkt.write('COSMOS','PKT1')
      plw.write(pkt)
      @tlm_packet_length = pkt.length
      @tlm_packets << pkt
      pkt = pkt.clone
      pkt.received_time += 1
      pkt.write('COSMOS','PKT2')
      plw.write(pkt)
      @tlm_packets << pkt
      pkt = pkt.clone
      pkt.received_time += 1
      pkt.write('COSMOS','PKT3')
      plw.write(pkt)
      @tlm_packets << pkt
      plw.stop
    end

    after(:all) do
      clean_config()
    end

    before(:each) do
      @plr = PacketLogReader.new
    end

    describe "initialize" do
      it "should create a command log writer" do
        @plr.log_type.should eql :TLM
        @plr.configuration_name.should be_nil
        @plr.hostname.should be_nil
      end
    end

    describe "open" do
      it "should complain if the log file is too small" do
        tf = Tempfile.new('log_file')
        tf.puts "BLAH"
        tf.close
        expect { @plr.open(tf.path) }.to raise_error(/Failed to read/)
        tf.unlink
      end

      it "should complain if the log does not have a COSMOS header" do
        pkt = System.telemetry.packet("COSMOS","VERSION").clone
        filename = File.join(@log_path,'test.bin')
        File.open(filename,'wb') do |file|
          file.write "OASIS CMD                            TEST"
          file.write [1000,100,4,"TGT1",4,"PKT1"].pack('NNCA4CA4')
          file.write [pkt.buffer.length].pack('N')
          file.write pkt.buffer
        end
        expect { @plr.open(filename) }.to raise_error(/file header not found/)
      end

      it "should complain if the log is not CMD or TLM" do
        pkt = System.telemetry.packet("COSMOS","VERSION").clone
        filename = File.join(@log_path,'test.bin')
        File.open(filename,'wb') do |file|
          file.write "COSMOSBOTH                            TEST"
          file.write [1000,100,4,"TGT1",4,"PKT1"].pack('NNCA4CA4')
          file.write [pkt.buffer.length].pack('N')
          file.write pkt.buffer
        end
        expect { @plr.open(filename) }.to raise_error("Unknown log type BOT")
      end

      it "should open COSMOS1 log files" do
        pkt = System.telemetry.packet("COSMOS","VERSION").clone
        filename = File.join(@log_path,'test.bin')
        File.open(filename,'wb') do |file|
          file.write "COSMOSCMD                             TEST"
          file.write [1000,100,4,"TGT1",4,"PKT1"].pack('NNCA4CA4')
          file.write [pkt.buffer.length].pack('N')
          file.write pkt.buffer
          file.write [1000,100,4,"TGT2",4,"PKT2"].pack('NNCA4CA4')
          file.write [pkt.buffer.length].pack('N')
          file.write pkt.buffer
          file.write [1000,100,4,"TGT3",4,"PKT3"].pack('NNCA4CA4')
          file.write [pkt.buffer.length].pack('N')
          file.write pkt.buffer
        end
        @plr.open(filename)
        pkt1 = @plr.read
        pkt1.target_name.should eql 'TGT1'
        pkt1.packet_name.should eql 'PKT1'
        pkt2 = @plr.read
        pkt2.target_name.should eql 'TGT2'
        pkt2.packet_name.should eql 'PKT2'
        pkt3 = @plr.read
        pkt3.target_name.should eql 'TGT3'
        pkt3.packet_name.should eql 'PKT3'
        @plr.close
      end
    end

    describe "packet_offsets and read_at_offset" do
      it "should return packet offsets CTS-20, CTS-22" do
        packet_offsets = @plr.packet_offsets(Dir[File.join(@log_path,"*.bin")][0])
        @plr.log_type.should eql :CMD
        @plr.configuration_name.should_not be_nil
        @plr.hostname.should eql Socket.gethostname
        header_length = 8 + 1 + 6 + 1 + 12 + 4
        packet_offsets.should eql [PacketLogReader::COSMOS2_HEADER_LENGTH, PacketLogReader::COSMOS2_HEADER_LENGTH + header_length + @cmd_packet_length, PacketLogReader::COSMOS2_HEADER_LENGTH + (header_length + @cmd_packet_length) * 2]

        @plr.open(Dir[File.join(@log_path,"*.bin")][0])
        pkt = @plr.read_at_offset(packet_offsets[1])
        pkt.target_name.should eql "COSMOS"
        pkt.packet_name.should eql "STARTLOGGING"
        pkt.received_time.should eql Time.new(2020,1,31,12,30,16)
        @plr.close
      end

      it "should return telemetry packet information" do
        packet_offsets = @plr.packet_offsets(Dir[File.join(@log_path,"*.bin")][1])
        @plr.log_type.should eql :TLM
        @plr.configuration_name.should_not be_nil
        @plr.hostname.should eql Socket.gethostname
        header_length = 8 + 1 + 6 + 1 + 7 + 4
        packet_offsets.should eql [PacketLogReader::COSMOS2_HEADER_LENGTH, PacketLogReader::COSMOS2_HEADER_LENGTH + header_length + @tlm_packet_length, PacketLogReader::COSMOS2_HEADER_LENGTH + (header_length + @tlm_packet_length) * 2]

        @plr.open(Dir[File.join(@log_path,"*.bin")][1])
        pkt = @plr.read_at_offset(packet_offsets[1])
        pkt.target_name.should eql "COSMOS"
        pkt.packet_name.should eql "VERSION"
        pkt.received_time.should eql Time.new(2020,2,1,12,30,16)
        @plr.close
      end
    end

    describe "each" do
      it "should return packets" do
        index = 0
        bytes_read = 208
        @plr.each(Dir[File.join(@log_path,"*.bin")][0]) do |packet|
          packet.target_name.should eql @cmd_packets[index].target_name
          packet.packet_name.should eql @cmd_packets[index].packet_name
          packet.received_time.should eql @cmd_packets[index].received_time
          packet.read('LABEL').should eql @cmd_packets[index].read('LABEL')
          @plr.bytes_read.should eql bytes_read
          bytes_read += 80
          index += 1
        end
        index = 0
        bytes_read = 276
        @plr.each(Dir[File.join(@log_path,"*.bin")][1]) do |packet|
          packet.target_name.should eql @tlm_packets[index].target_name
          packet.packet_name.should eql @tlm_packets[index].packet_name
          packet.received_time.should eql @tlm_packets[index].received_time
          packet.read('COSMOS').should eql @tlm_packets[index].read('COSMOS')
          @plr.bytes_read.should eql bytes_read
          bytes_read += 148
          index += 1
        end
      end

      it "should optionally not identify and define packets" do
        index = 0
        @plr.each(Dir[File.join(@log_path,"*.bin")][0], false) do |packet|
          packet.target_name.should eql @cmd_packets[index].target_name
          packet.packet_name.should eql @cmd_packets[index].packet_name
          packet.received_time.should eql @cmd_packets[index].received_time
          expect { packet.read('LABEL') }.to raise_error(/does not exist/)
          index += 1
        end
        index = 0
        @plr.each(Dir[File.join(@log_path,"*.bin")][1], false) do |packet|
          packet.target_name.should eql @tlm_packets[index].target_name
          packet.packet_name.should eql @tlm_packets[index].packet_name
          packet.received_time.should eql @tlm_packets[index].received_time
          expect { packet.read('COSMOS') }.to raise_error(/does not exist/)
          index += 1
        end
      end

      it "should return all packets if the start time is before all" do
        time = Time.new(2000,1,31,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*.bin")][0], true, time) do |packet|
          packet.target_name.should eql @cmd_packets[index].target_name
          packet.packet_name.should eql @cmd_packets[index].packet_name
          packet.received_time.should eql @cmd_packets[index].received_time
          packet.read('LABEL').should eql @cmd_packets[index].read('LABEL')
          index += 1
        end
        index.should eql 3
      end

      it "should return no packets if the start time is after all" do
        time = Time.new(2030,2,1,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*.bin")][1], true, time) do |packet|
          index += 1
        end
        index.should eql 0
      end

      it "should return all packets after a start time" do
        time = Time.new(2020,1,31,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*.bin")][0], true, time) do |packet|
          packet.target_name.should eql @cmd_packets[index+1].target_name
          packet.packet_name.should eql @cmd_packets[index+1].packet_name
          packet.received_time.should eql @cmd_packets[index+1].received_time
          packet.read('LABEL').should eql @cmd_packets[index+1].read('LABEL')
          index += 1
        end
        index.should eql 2

        time = Time.new(2020,2,1,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*.bin")][1], true, time) do |packet|
          packet.target_name.should eql @tlm_packets[index+1].target_name
          packet.packet_name.should eql @tlm_packets[index+1].packet_name
          packet.received_time.should eql @tlm_packets[index+1].received_time
          packet.read('COSMOS').should eql @tlm_packets[index+1].read('COSMOS')
          index += 1
        end
        index.should eql 2
      end

      it "should return no packets if the end time is before all" do
        time = Time.new(2000,1,31,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*.bin")][1], true, nil, time) do |packet|
          index += 1
        end
        index.should eql 0
      end

      it "should return all packets if the end time is after all" do
        time = Time.new(2030,2,1,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*.bin")][0], true, nil, time) do |packet|
          packet.target_name.should eql @cmd_packets[index].target_name
          packet.packet_name.should eql @cmd_packets[index].packet_name
          packet.received_time.should eql @cmd_packets[index].received_time
          packet.read('LABEL').should eql @cmd_packets[index].read('LABEL')
          index += 1
        end
        index.should eql 3
      end

      it "should return all packets before an end time" do
        time = Time.new(2020,1,31,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*.bin")][0], true, nil, time) do |packet|
          packet.target_name.should eql @cmd_packets[index].target_name
          packet.packet_name.should eql @cmd_packets[index].packet_name
          packet.received_time.should eql @cmd_packets[index].received_time
          packet.read('LABEL').should eql @cmd_packets[index].read('LABEL')
          index += 1
        end
        index.should eql 2

        time = Time.new(2020,2,1,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*.bin")][1], true, nil, time) do |packet|
          packet.target_name.should eql @tlm_packets[index].target_name
          packet.packet_name.should eql @tlm_packets[index].packet_name
          packet.received_time.should eql @tlm_packets[index].received_time
          packet.read('COSMOS').should eql @tlm_packets[index].read('COSMOS')
          index += 1
        end
        index.should eql 2
      end
   end

    describe "first" do
      it "should return the first command packet and retain the file position" do
        @plr.open(Dir[File.join(@log_path,"*.bin")][0])
        pkt1 = @plr.read
        pkt1.target_name.should eql @cmd_packets[0].target_name
        pkt1.packet_name.should eql @cmd_packets[0].packet_name
        pkt1.received_time.should eql @cmd_packets[0].received_time
        pkt1.read('LABEL').should eql @cmd_packets[0].read('LABEL')

        first = @plr.first
        first.target_name.should eql @cmd_packets[0].target_name
        first.packet_name.should eql @cmd_packets[0].packet_name
        first.received_time.should eql @cmd_packets[0].received_time
        first.read('LABEL').should eql @cmd_packets[0].read('LABEL')

        pkt2 = @plr.read
        pkt2.target_name.should eql @cmd_packets[1].target_name
        pkt2.packet_name.should eql @cmd_packets[1].packet_name
        pkt2.received_time.should eql @cmd_packets[1].received_time
        pkt2.read('LABEL').should eql @cmd_packets[1].read('LABEL')
        @plr.close
      end

      it "should return the first telemetry packet and retain the file position" do
        @plr.open(Dir[File.join(@log_path,"*.bin")][1])
        pkt1 = @plr.read
        pkt1.target_name.should eql @tlm_packets[0].target_name
        pkt1.packet_name.should eql @tlm_packets[0].packet_name
        pkt1.received_time.should eql @tlm_packets[0].received_time
        pkt1.read('COSMOS').should eql @tlm_packets[0].read('COSMOS')

        first = @plr.first
        first.target_name.should eql @tlm_packets[0].target_name
        first.packet_name.should eql @tlm_packets[0].packet_name
        first.received_time.should eql @tlm_packets[0].received_time
        first.read('COSMOS').should eql @tlm_packets[0].read('COSMOS')

        pkt2 = @plr.read
        pkt2.target_name.should eql @tlm_packets[1].target_name
        pkt2.packet_name.should eql @tlm_packets[1].packet_name
        pkt2.received_time.should eql @tlm_packets[1].received_time
        pkt2.read('COSMOS').should eql @tlm_packets[1].read('COSMOS')
        @plr.close
      end
    end

    describe "last" do
      it "should return the last command packet and retain the file position" do
        @plr.open(Dir[File.join(@log_path,"*.bin")][0])
        pkt1 = @plr.read
        pkt1.target_name.should eql @cmd_packets[0].target_name
        pkt1.packet_name.should eql @cmd_packets[0].packet_name
        pkt1.received_time.should eql @cmd_packets[0].received_time
        pkt1.read('LABEL').should eql @cmd_packets[0].read('LABEL')

        last = @plr.last
        last.target_name.should eql @cmd_packets[2].target_name
        last.packet_name.should eql @cmd_packets[2].packet_name
        last.received_time.should eql @cmd_packets[2].received_time
        last.read('LABEL').should eql @cmd_packets[2].read('LABEL')

        pkt2 = @plr.read
        pkt2.target_name.should eql @cmd_packets[1].target_name
        pkt2.packet_name.should eql @cmd_packets[1].packet_name
        pkt2.received_time.should eql @cmd_packets[1].received_time
        pkt2.read('LABEL').should eql @cmd_packets[1].read('LABEL')
        @plr.close
      end

      it "should return the last telemetry packet and retain the file position" do
        @plr.open(Dir[File.join(@log_path,"*.bin")][1])
        pkt1 = @plr.read
        pkt1.target_name.should eql @tlm_packets[0].target_name
        pkt1.packet_name.should eql @tlm_packets[0].packet_name
        pkt1.received_time.should eql @tlm_packets[0].received_time
        pkt1.read('COSMOS').should eql @tlm_packets[0].read('COSMOS')

        last = @plr.last
        last.target_name.should eql @tlm_packets[2].target_name
        last.packet_name.should eql @tlm_packets[2].packet_name
        last.received_time.should eql @tlm_packets[2].received_time
        last.read('COSMOS').should eql @tlm_packets[2].read('COSMOS')

        pkt2 = @plr.read
        pkt2.target_name.should eql @tlm_packets[1].target_name
        pkt2.packet_name.should eql @tlm_packets[1].packet_name
        pkt2.received_time.should eql @tlm_packets[1].received_time
        pkt2.read('COSMOS').should eql @tlm_packets[1].read('COSMOS')
        @plr.close
      end
    end

  end
end

