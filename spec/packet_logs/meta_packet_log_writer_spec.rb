# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/packet_logs/packet_log_writer'
require 'cosmos/packet_logs/packet_log_reader'
require 'tempfile'

module Cosmos

  describe MetaPacketLogWriter do
    before(:each) do
      System.class_eval('@@instance = nil')
      System.load_configuration
      @log_path = System.paths['LOGS']
    end

    after(:each) do
      clean_config()
    end

    it "should create a command log writer" do
      meta_packet = System.commands.packet('META', 'DATA')
      meta_packet.write('VERSION', 'Great Version')
      meta_packet.write('NUMBER', 5)

      plw = MetaPacketLogWriter.new(:CMD,'META','DATA',nil,true,false,nil,true,nil,nil,nil,false)
      packet = System.commands.packet('INST', 'ABORT')
      packet.restore_defaults
      plw.write(packet)
      plw.stop

      filename = Dir[File.join(@log_path,"*.bin")][-1]
      expect(filename).to match("_cmd.bin")

      reader = PacketLogReader.new
      count = 0
      reader.each(filename) do |packet|
        if count == 0
          packet.target_name.should eql('META')
          packet.packet_name.should eql('DATA')
          packet.read('VERSION').should eql('Great Version')
          packet.read('NUMBER').should eql(5)
        else
          packet.target_name.should eql('INST')
          packet.packet_name.should eql('ABORT')
        end
        count += 1
      end
    end

    it "should create a telemetry log writer" do
      meta_packet = System.telemetry.packet('META', 'DATA')
      meta_packet.write('VERSION', 'Good Version')
      meta_packet.write('NUMBER', 3)

      plw = MetaPacketLogWriter.new(:TLM,'META','DATA',nil,true,true,nil,true,nil,nil,nil,false)
      packet = System.telemetry.packet('INST', 'ADCS')
      packet.write('CCSDSAPID', 2)
      packet.write('PKTID', 1)
      plw.write(packet)
      plw.write(meta_packet)
      plw.stop

      filename = Dir[File.join(@log_path,"*.bin")][-1]
      expect(filename).to match("_tlm.bin")

      reader = PacketLogReader.new
      count = 0
      reader.each(filename) do |packet|
        if count == 0 or count == 2
          packet.target_name.should eql('META')
          packet.packet_name.should eql('DATA')
          packet.read('VERSION').should eql('Good Version')
          packet.read('NUMBER').should eql(3)
        else
          packet.target_name.should eql('INST')
          packet.packet_name.should eql('ADCS')
        end
        count += 1
      end
      count.should eql 3
    end

    it "should not log metadata packets if configured not to" do
      meta_packet = System.telemetry.packet('META', 'DATA')
      meta_packet.write('VERSION', 'Good Version')
      meta_packet.write('NUMBER', 1)

      plw = MetaPacketLogWriter.new(:TLM,'META','DATA',nil,false,true,nil,true,nil,nil,nil,false)
      plw.write(meta_packet)
      packet = System.telemetry.packet('INST', 'ADCS')
      packet.write('CCSDSAPID', 2)
      packet.write('PKTID', 1)
      plw.write(packet)
      plw.write(meta_packet)
      plw.stop

      filename = Dir[File.join(@log_path,"*.bin")][-1]
      expect(filename).to match("_tlm.bin")

      reader = PacketLogReader.new
      count = 0
      reader.each(filename) do |packet|
        if count == 0
          packet.target_name.should eql('META')
          packet.packet_name.should eql('DATA')
          packet.read('VERSION').should eql('Good Version')
          packet.read('NUMBER').should eql(1)
        else
          packet.target_name.should eql('INST')
          packet.packet_name.should eql('ADCS')
        end
        count += 1
      end
      count.should eql(2)
    end

    it "should initialize the meta packet if configured to" do
      tf = Tempfile.new('unittest')
      tf.puts("VERSION 'Ok Version'")
      tf.puts("NUMBER 11")
      tf.close

      meta_packet = System.telemetry.packet('META', 'DATA')
      meta_packet.write('VERSION', 'Bad Version')
      meta_packet.write('NUMBER', 3)

      plw = MetaPacketLogWriter.new(:TLM,'META','DATA',tf.path,false,true,nil,true,nil,nil,nil,false)
      packet = System.telemetry.packet('INST', 'ADCS')
      packet.write('CCSDSAPID', 2)
      packet.write('PKTID', 1)
      plw.write(packet)
      plw.write(meta_packet)
      plw.stop

      filename = Dir[File.join(@log_path,"*.bin")][-1]
      expect(filename).to match("_tlm.bin")

      reader = PacketLogReader.new
      count = 0
      reader.each(filename) do |packet|
        if count == 0
          packet.target_name.should eql('META')
          packet.packet_name.should eql('DATA')
          packet.read('VERSION').should eql('Ok Version')
          packet.read('NUMBER').should eql(11)
        else
          packet.target_name.should eql('INST')
          packet.packet_name.should eql('ADCS')
        end
        count += 1
      end
      count.should eql(2)
      tf.unlink
    end

    it "should complain if the packet does not exist" do
      expect {plw = MetaPacketLogWriter.new(:CMD,'INST','ADCS',nil,true,true)}.to raise_error(RuntimeError)
      expect {plw = MetaPacketLogWriter.new(:CMD,'INST','ABORT',nil,true,true)}.to raise_error(RuntimeError)
    end
  end
end
