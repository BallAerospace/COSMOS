# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
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
      pkt = System.commands.packet("SYSTEM","STARTLOGGING").clone
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
      pkt = System.telemetry.packet("SYSTEM","LIMITS_CHANGE").clone
      pkt.received_time = Time.new(2020,2,1,12,30,15)
      pkt.write('PACKET','PKT1')
      plw.write(pkt)
      @tlm_packet_length = pkt.length
      @tlm_packets << pkt
      pkt = pkt.clone
      pkt.received_time += 1
      pkt.write('PACKET','PKT2')
      plw.write(pkt)
      @tlm_packets << pkt
      pkt = pkt.clone
      pkt.received_time += 1
      pkt.write('PACKET','PKT3')
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
      it "creates a command log writer" do
        expect(@plr.log_type).to eql :TLM
        expect(@plr.configuration_name).to be_nil
        expect(@plr.hostname).to be_nil
      end
    end

    describe "open" do
      it "complains if the log file is too small" do
        tf = Tempfile.new('log_file')
        tf.puts "BLAH"
        tf.close
        expect { @plr.open(tf.path) }.to raise_error(/Failed to read/)
        tf.unlink
      end

      it "complains if the log does not have a COSMOS header" do
        pkt = System.telemetry.packet("SYSTEM","LIMITS_CHANGE").clone
        filename = File.join(@log_path,'test.bin')
        File.open(filename,'wb') do |file|
          file.write "OASIS CMD                            TEST"
          file.write [1000,100,4,"TGT1",4,"PKT1"].pack('NNCA4CA4')
          file.write [pkt.buffer.length].pack('N')
          file.write pkt.buffer
        end
        expect { @plr.open(filename) }.to raise_error(/file header not found/)
      end

      it "complains if the log is not CMD or TLM" do
        pkt = System.telemetry.packet("SYSTEM","LIMITS_CHANGE").clone
        filename = File.join(@log_path,'test.bin')
        File.open(filename,'wb') do |file|
          file.write "COSMOSBOTH                            TEST"
          file.write [1000,100,4,"TGT1",4,"PKT1"].pack('NNCA4CA4')
          file.write [pkt.buffer.length].pack('N')
          file.write pkt.buffer
        end
        expect { @plr.open(filename) }.to raise_error("Unknown log type BOT")
      end

      it "opens COSMOS1 log files" do
        pkt = System.telemetry.packet("SYSTEM","LIMITS_CHANGE").clone
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
        expect(@plr.open(filename)).to eql [false, nil]
        pkt1 = @plr.read
        expect(pkt1.target_name).to eql 'TGT1'
        expect(pkt1.packet_name).to eql 'PKT1'
        pkt2 = @plr.read
        expect(pkt2.target_name).to eql 'TGT2'
        expect(pkt2.packet_name).to eql 'PKT2'
        pkt3 = @plr.read
        expect(pkt3.target_name).to eql 'TGT3'
        expect(pkt3.packet_name).to eql 'PKT3'
        @plr.close
      end
    end

    it "handles saved configuration with errors" do
      begin
        System.class_eval('@@instance = nil')

        # Save system.txt
        @config_file = File.join(Cosmos::USERPATH,'config','system','system.txt')
        FileUtils.mv @config_file, Cosmos::USERPATH

        # Create a dummy system.txt
        File.open(@config_file,'w') {|file| file.puts "# This is a comment" }
        @config_targets = File.join(Cosmos::USERPATH,'config','targets')

        File.open(@config_file,'w') do |file|
          file.puts "DECLARE_TARGET INST OVERRIDE"
          file.puts "DECLARE_TARGET SYSTEM"
        end

        # Load the original configuration
        original_config_name, err = System.load_configuration
        expect(err).to eql nil
        expect(System.telemetry.target_names).to eql %w(OVERRIDE SYSTEM)
        original_pkts = System.telemetry.packets('SYSTEM').keys

        # Create a new configuration by writing another telemetry file
        File.open(File.join(@config_targets,'SYSTEM','cmd_tlm','test1_tlm.txt'),'w') do |file|
          file.puts "TELEMETRY SYSTEM TEST1 BIG_ENDIAN"
          file.puts "  APPEND_ITEM DATA 240 STRING"
        end
        System.instance.process_file(@config_file)
        # Verify the new telemetry packet is there
        expect(System.telemetry.packets('SYSTEM').keys).to include "TEST1"
        second_config_name = System.configuration_name

        # Create a log file for the second config
        filename = File.join(@log_path,'test.bin')
        File.open(filename,'wb') do |file|
          file.write "COSMOS2_TLM_#{second_config_name}_#{'A' * 83}"
        end

        # Corrupt the second config
        second_config_path = System.instance.send(:find_configuration, second_config_name)
        FileUtils.mv File.join(second_config_path, 'system.txt'), File.join(second_config_path, 'system2.txt')

        # Return to original config
        System.load_configuration

        # Open the file from the second config and expect an error
        success, error = @plr.open(filename)
        expect(success).to eql false
        expect(error).to_not be_nil
        @plr.close
      ensure
        # Restore system.txt
        FileUtils.mv File.join(Cosmos::USERPATH, 'system.txt'),
          File.join(Cosmos::USERPATH,'config','system')

        File.delete(File.join(@config_targets,'SYSTEM','cmd_tlm','test1_tlm.txt'))
      end
    end

    describe "packet_offsets and read_at_offset" do
      it "returns packet offsets CTS-20, CTS-22" do
        packet_offsets = @plr.packet_offsets(Dir[File.join(@log_path,"*cmd.bin")][0])
        expect(@plr.log_type).to eql :CMD
        expect(@plr.configuration_name).not_to be_nil
        expect(@plr.hostname).to eql Socket.gethostname
        header_length = 8 + 1 + 6 + 1 + 12 + 4
        meta_header_length = 8 + 1 + 6 + 1 + 4 + 4
        meta_length = System.telemetry.packet('SYSTEM', 'META').length
        expect(packet_offsets).to eql [PacketLogReader::COSMOS2_HEADER_LENGTH, PacketLogReader::COSMOS2_HEADER_LENGTH + meta_header_length + meta_length, PacketLogReader::COSMOS2_HEADER_LENGTH + meta_header_length + meta_length + header_length + @cmd_packet_length, PacketLogReader::COSMOS2_HEADER_LENGTH + meta_header_length + meta_length + (header_length + @cmd_packet_length) * 2]

        expect(@plr.open(Dir[File.join(@log_path,"*cmd.bin")][0])).to eql [true, nil]
        pkt = @plr.read_at_offset(packet_offsets[2])
        expect(pkt.target_name).to eql "SYSTEM"
        expect(pkt.packet_name).to eql "STARTLOGGING"
        expect(pkt.received_time).to eql Time.new(2020,1,31,12,30,16)
        @plr.close
      end

      it "returns telemetry packet information" do
        packet_offsets = @plr.packet_offsets(Dir[File.join(@log_path,"*tlm.bin")][0])
        expect(@plr.log_type).to eql :TLM
        expect(@plr.configuration_name).not_to be_nil
        expect(@plr.hostname).to eql Socket.gethostname
        header_length = 8 + 1 + 6 + 1 + 13 + 4
        meta_header_length = 8 + 1 + 6 + 1 + 4 + 4
        meta_length = System.telemetry.packet('SYSTEM', 'META').length
        expect(packet_offsets).to eql [PacketLogReader::COSMOS2_HEADER_LENGTH, PacketLogReader::COSMOS2_HEADER_LENGTH + meta_header_length + meta_length, PacketLogReader::COSMOS2_HEADER_LENGTH + meta_header_length + meta_length + header_length + @tlm_packet_length, PacketLogReader::COSMOS2_HEADER_LENGTH + meta_header_length + meta_length + (header_length + @tlm_packet_length) * 2]

        expect(@plr.open(Dir[File.join(@log_path,"*tlm.bin")][0])).to eql [true, nil]
        pkt = @plr.read_at_offset(packet_offsets[2])
        expect(pkt.target_name).to eql "SYSTEM"
        expect(pkt.packet_name).to eql "LIMITS_CHANGE"
        expect(pkt.received_time).to eql Time.new(2020,2,1,12,30,16)
        @plr.close
      end
    end

    describe "each" do
      it "returns packets" do
        index = 0
        meta_header_length = 8 + 1 + 6 + 1 + 4 + 4
        meta_length = System.telemetry.packet('SYSTEM', 'META').length
        packet_length = System.commands.packet('SYSTEM', 'STARTLOGGING').length
        packet_header_length = 8 + 1 + 'SYSTEM'.length + 1 + 'STARTLOGGING'.length + 4
        bytes_read = 128 + packet_header_length + packet_length + meta_header_length + meta_length
        @plr.each(Dir[File.join(@log_path,"*cmd.bin")][0]) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @cmd_packets[index].target_name
          expect(packet.packet_name).to eql @cmd_packets[index].packet_name
          expect(packet.received_time).to eql @cmd_packets[index].received_time
          expect(packet.read('LABEL')).to eql @cmd_packets[index].read('LABEL')
          expect(@plr.bytes_read).to eql bytes_read
          bytes_read += packet_header_length + packet_length
          index += 1
        end
        index = 0
        packet_length = System.telemetry.packet('SYSTEM', 'LIMITS_CHANGE').length
        packet_header_length = 8 + 1 + 'SYSTEM'.length + 1 + 'LIMITS_CHANGE'.length + 4
        bytes_read = 128 + packet_header_length + packet_length + meta_header_length + meta_length
        @plr.each(Dir[File.join(@log_path,"*tlm.bin")][0]) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @tlm_packets[index].target_name
          expect(packet.packet_name).to eql @tlm_packets[index].packet_name
          expect(packet.received_time).to eql @tlm_packets[index].received_time
          expect(packet.read('PACKET')).to eql @tlm_packets[index].read('PACKET')
          expect(@plr.bytes_read).to eql bytes_read
          bytes_read += packet_header_length + packet_length
          index += 1
        end
      end

      it "optionally does not identify and define packets" do
        index = 0
        @plr.each(Dir[File.join(@log_path,"*cmd.bin")][0], false) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @cmd_packets[index].target_name
          expect(packet.packet_name).to eql @cmd_packets[index].packet_name
          expect(packet.received_time).to eql @cmd_packets[index].received_time
          expect { packet.read('LABEL') }.to raise_error(/does not exist/)
          index += 1
        end
        index = 0
        @plr.each(Dir[File.join(@log_path,"*tlm.bin")][0], false) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @tlm_packets[index].target_name
          expect(packet.packet_name).to eql @tlm_packets[index].packet_name
          expect(packet.received_time).to eql @tlm_packets[index].received_time
          expect { packet.read('PACKET') }.to raise_error(/does not exist/)
          index += 1
        end
      end

      it "increments the command received count" do
        plw = PacketLogWriter.new(:CMD,'cnt',true,nil,10000000,nil,false)
        plw.write(System.commands.packet("INST","COLLECT").clone)
        plw.write(System.commands.packet("INST","ABORT").clone)
        plw.write(System.commands.packet("INST","ABORT").clone)
        plw.write(System.commands.packet("INST","COLLECT").clone)
        plw.write(System.commands.packet("SYSTEM","STOPLOGGING").clone)
        plw.write(System.commands.packet("INST","ABORT").clone)
        plw.stop

        cnt = {}
        @plr.each(Dir[File.join(@log_path,"*cntcmd.bin")][0]) do |packet|
          next if packet.packet_name == 'META'
          cnt["#{packet.target_name}_#{packet.packet_name}"] ||= 0
          cnt["#{packet.target_name}_#{packet.packet_name}"] += 1
          expect(packet.received_count).to eql cnt["#{packet.target_name}_#{packet.packet_name}"]
        end

        # Resetting a packet should reset only that packet's received_count
        collect = System.commands.packet("INST","COLLECT")
        collect.reset
        cnt["INST_COLLECT"] = 0
        expect(collect.received_count).to eql 0

        @plr.each(Dir[File.join(@log_path,"*cntcmd.bin")][0]) do |packet|
          next if packet.packet_name == 'META'
          cnt["#{packet.target_name}_#{packet.packet_name}"] ||= 0
          cnt["#{packet.target_name}_#{packet.packet_name}"] += 1
          expect(packet.received_count).to eql cnt["#{packet.target_name}_#{packet.packet_name}"]
        end

        Dir[File.join(@log_path,"*cntcmd.bin")].each {|file| FileUtils.rm file }
      end

      it "increments the telemetry received count" do
        plw = PacketLogWriter.new(:TLM,'cnt',true,nil,10000000,nil,false)
        plw.write(System.telemetry.packet("INST","HEALTH_STATUS").clone)
        plw.write(System.telemetry.packet("INST","ADCS").clone)
        plw.write(System.telemetry.packet("INST","ADCS").clone)
        plw.write(System.telemetry.packet("INST","HEALTH_STATUS").clone)
        plw.write(System.telemetry.packet("INST","ADCS").clone)
        plw.stop

        cnt = {}
        @plr.each(Dir[File.join(@log_path,"*cnttlm.bin")][0]) do |packet|
          next if packet.packet_name == 'META'
          cnt["#{packet.target_name}_#{packet.packet_name}"] ||= 0
          cnt["#{packet.target_name}_#{packet.packet_name}"] += 1
          expect(packet.received_count).to eql cnt["#{packet.target_name}_#{packet.packet_name}"]
        end

        # Resetting a packet should reset only that packet's received_count
        status = System.telemetry.packet("INST","HEALTH_STATUS")
        status.reset
        cnt["INST_HEALTH_STATUS"] = 0
        expect(status.received_count).to eql 0

        @plr.each(Dir[File.join(@log_path,"*cnttlm.bin")][0]) do |packet|
          next if packet.packet_name == 'META'
          cnt["#{packet.target_name}_#{packet.packet_name}"] ||= 0
          cnt["#{packet.target_name}_#{packet.packet_name}"] += 1
          expect(packet.received_count).to eql cnt["#{packet.target_name}_#{packet.packet_name}"]
        end

        Dir[File.join(@log_path,"*cnttlm.bin")].each {|file| FileUtils.rm file }
      end

      it "returns all packets if the start time is before all" do
        time = Time.new(2000,1,31,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*cmd.bin")][0], true, time) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @cmd_packets[index].target_name
          expect(packet.packet_name).to eql @cmd_packets[index].packet_name
          expect(packet.received_time).to eql @cmd_packets[index].received_time
          expect(packet.read('LABEL')).to eql @cmd_packets[index].read('LABEL')
          index += 1
        end
        expect(index).to eql 3
      end

      it "returns no packets if the start time is after all" do
        time = Time.new(2030,2,1,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*tlm.bin")][0], true, time) do |packet|
          index += 1
        end
        expect(index).to eql 0
      end

      it "returns all packets after a start time" do
        time = Time.new(2020,1,31,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*cmd.bin")][0], true, time) do |packet|
          expect(packet.target_name).to eql @cmd_packets[index+1].target_name
          expect(packet.packet_name).to eql @cmd_packets[index+1].packet_name
          expect(packet.received_time).to eql @cmd_packets[index+1].received_time
          expect(packet.read('LABEL')).to eql @cmd_packets[index+1].read('LABEL')
          index += 1
        end
        expect(index).to eql 2

        time = Time.new(2020,2,1,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*tlm.bin")][0], true, time) do |packet|
          expect(packet.target_name).to eql @tlm_packets[index+1].target_name
          expect(packet.packet_name).to eql @tlm_packets[index+1].packet_name
          expect(packet.received_time).to eql @tlm_packets[index+1].received_time
          expect(packet.read('PACKET')).to eql @tlm_packets[index+1].read('PACKET')
          index += 1
        end
        expect(index).to eql 2
      end

      it "returns no packets if the end time is before all" do
        time = Time.new(2000,1,31,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*tlm.bin")][0], true, nil, time) do |packet|
          index += 1
        end
        expect(index).to eql 0
      end

      it "returns all packets if the end time is after all" do
        time = Time.new(2030,2,1,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*cmd.bin")][0], true, nil, time) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @cmd_packets[index].target_name
          expect(packet.packet_name).to eql @cmd_packets[index].packet_name
          expect(packet.received_time).to eql @cmd_packets[index].received_time
          expect(packet.read('LABEL')).to eql @cmd_packets[index].read('LABEL')
          index += 1
        end
        expect(index).to eql 3
      end

      it "returns all packets before an end time" do
        time = Time.new(2020,1,31,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*cmd.bin")][0], true, nil, time) do |packet|
          next if packet.packet_name == 'META'
          expect(packet.target_name).to eql @cmd_packets[index].target_name
          expect(packet.packet_name).to eql @cmd_packets[index].packet_name
          expect(packet.received_time).to eql @cmd_packets[index].received_time
          expect(packet.read('LABEL')).to eql @cmd_packets[index].read('LABEL')
          index += 1
        end
        expect(index).to eql 2

        time = Time.new(2020,2,1,12,30,16)
        index = 0
        @plr.each(Dir[File.join(@log_path,"*tlm.bin")][0], true, nil, time) do |packet|
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

    describe "first" do
      it "returns the first command packet and retain the file position" do
        expect(@plr.open(Dir[File.join(@log_path,"*cmd.bin")][0])).to eql [true, nil]
        pkt1 = @plr.read
        pkt1 = @plr.read
        expect(pkt1.target_name).to eql @cmd_packets[0].target_name
        expect(pkt1.packet_name).to eql @cmd_packets[0].packet_name
        expect(pkt1.received_time).to eql @cmd_packets[0].received_time
        expect(pkt1.read('LABEL')).to eql @cmd_packets[0].read('LABEL')

        first = @plr.first
        expect(first.target_name).to eql 'SYSTEM'
        expect(first.packet_name).to eql 'META'

        pkt2 = @plr.read
        expect(pkt2.target_name).to eql @cmd_packets[1].target_name
        expect(pkt2.packet_name).to eql @cmd_packets[1].packet_name
        expect(pkt2.received_time).to eql @cmd_packets[1].received_time
        expect(pkt2.read('LABEL')).to eql @cmd_packets[1].read('LABEL')
        @plr.close
      end

      it "returns the first telemetry packet and retain the file position" do
        expect(@plr.open(Dir[File.join(@log_path,"*tlm.bin")][0])).to eql [true, nil]
        pkt1 = @plr.read
        pkt1 = @plr.read
        expect(pkt1.target_name).to eql @tlm_packets[0].target_name
        expect(pkt1.packet_name).to eql @tlm_packets[0].packet_name
        expect(pkt1.received_time).to eql @tlm_packets[0].received_time
        expect(pkt1.read('PACKET')).to eql @tlm_packets[0].read('PACKET')

        first = @plr.first
        expect(first.target_name).to eql 'SYSTEM'
        expect(first.packet_name).to eql 'META'

        pkt2 = @plr.read
        expect(pkt2.target_name).to eql @tlm_packets[1].target_name
        expect(pkt2.packet_name).to eql @tlm_packets[1].packet_name
        expect(pkt2.received_time).to eql @tlm_packets[1].received_time
        expect(pkt2.read('PACKET')).to eql @tlm_packets[1].read('PACKET')
        @plr.close
      end
    end

    describe "last" do
      it "returns the last command packet and retain the file position" do
        expect(@plr.open(Dir[File.join(@log_path,"*cmd.bin")][0])).to eql [true, nil]
        pkt1 = @plr.read
        pkt1 = @plr.read
        expect(pkt1.target_name).to eql @cmd_packets[0].target_name
        expect(pkt1.packet_name).to eql @cmd_packets[0].packet_name
        expect(pkt1.received_time).to eql @cmd_packets[0].received_time
        expect(pkt1.read('LABEL')).to eql @cmd_packets[0].read('LABEL')

        last = @plr.last
        expect(last.target_name).to eql @cmd_packets[2].target_name
        expect(last.packet_name).to eql @cmd_packets[2].packet_name
        expect(last.received_time).to eql @cmd_packets[2].received_time
        expect(last.read('LABEL')).to eql @cmd_packets[2].read('LABEL')

        pkt2 = @plr.read
        expect(pkt2.target_name).to eql @cmd_packets[1].target_name
        expect(pkt2.packet_name).to eql @cmd_packets[1].packet_name
        expect(pkt2.received_time).to eql @cmd_packets[1].received_time
        expect(pkt2.read('LABEL')).to eql @cmd_packets[1].read('LABEL')
        @plr.close
      end

      it "returns the last telemetry packet and retain the file position" do
        expect(@plr.open(Dir[File.join(@log_path,"*tlm.bin")][0])).to eql [true, nil]
        pkt1 = @plr.read
        pkt1 = @plr.read
        expect(pkt1.target_name).to eql @tlm_packets[0].target_name
        expect(pkt1.packet_name).to eql @tlm_packets[0].packet_name
        expect(pkt1.received_time).to eql @tlm_packets[0].received_time
        expect(pkt1.read('PACKET')).to eql @tlm_packets[0].read('PACKET')

        last = @plr.last
        expect(last.target_name).to eql @tlm_packets[2].target_name
        expect(last.packet_name).to eql @tlm_packets[2].packet_name
        expect(last.received_time).to eql @tlm_packets[2].received_time
        expect(last.read('PACKET')).to eql @tlm_packets[2].read('PACKET')

        pkt2 = @plr.read
        expect(pkt2.target_name).to eql @tlm_packets[1].target_name
        expect(pkt2.packet_name).to eql @tlm_packets[1].packet_name
        expect(pkt2.received_time).to eql @tlm_packets[1].received_time
        expect(pkt2.read('PACKET')).to eql @tlm_packets[1].read('PACKET')
        @plr.close
      end
    end

  end
end

