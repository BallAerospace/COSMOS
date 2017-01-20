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

module Cosmos

  describe PacketLogWriter do
    before(:each) do
      System.class_eval('@@instance = nil')
      System.load_configuration
      @log_path = System.paths['LOGS']
    end

    after(:each) do
      clean_config()
    end

    describe "initialize" do
      it "complains with an unknown log type" do
        expect { PacketLogWriter.new(:BOTH) }.to raise_error(/must be :CMD or :TLM/)
      end

      it "creates a command log writer" do
        plw = PacketLogWriter.new(:CMD,nil,true,nil,10000000,nil,false)
        plw.write(Packet.new('',''))
        plw.shutdown
        expect(Dir[File.join(@log_path,"*.bin")][-1]).to match("_cmd.bin")
        sleep(0.1)
      end

      it "creates a telemetry log writer" do
        plw = PacketLogWriter.new(:TLM,nil,true,nil,10000000,nil,false)
        plw.write(Packet.new('',''))
        plw.shutdown
        expect(Dir[File.join(@log_path,"*.bin")][-1]).to match("_tlm.bin")
        sleep(0.1)
      end

      it "uses log_name in the filename" do
        plw = PacketLogWriter.new(:TLM,'test',true,nil,10000000,nil,false)

        plw.write(Packet.new('',''))
        plw.shutdown
        expect(Dir[File.join(@log_path,"*.bin")][-1]).to match("testtlm.bin")
        sleep(0.1)
      end

      it "uses the log directory" do
        plw = PacketLogWriter.new(:TLM,'packet_log_writer_spec_',true,nil,10000000,Cosmos::USERPATH,false)
        plw.write(Packet.new('',''))
        plw.shutdown
        expect(Dir[File.join(Cosmos::USERPATH,"*packet_log_writer_spec*")][-1]).to match("_tlm.bin")
        Dir[File.join(Cosmos::USERPATH,"*packet_log_writer_spec*")].each do |file|
          File.delete file
        end
        sleep(0.1)
      end
    end

    describe "write" do
      it "writes synchronously to a log" do
        plw = PacketLogWriter.new(:CMD,nil,true,nil,10000000,nil,false)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x01\x02\x03\x04"
        plw.write(pkt)
        plw.shutdown
        data = nil
        File.open(Dir[File.join(@log_path,"*.bin")][-1],'rb') do |file|
          data = file.read
        end
        expect(data[-4..-1]).to eql "\x01\x02\x03\x04"
        sleep(0.1)
      end

      it "does not write packets if logging is disabled" do
        plw = PacketLogWriter.new(:TLM,nil,false,nil,10000000,nil,false)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x01\x02\x03\x04"
        plw.write(pkt)
        plw.shutdown
        expect(Dir[File.join(@log_path,"*.bin")]).to be_empty
        sleep(0.1)
      end

      it "cycles the log when it a size" do
        plw = PacketLogWriter.new(:TLM,nil,true,nil,200,nil,false)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x01\x02\x03\x04"
        plw.write(pkt) # size 152
        sleep 0.5
        plw.write(pkt) # size 176
        sleep 0.5
        plw.write(pkt) # size 200
        expect(Dir[File.join(@log_path,"*.bin")].length).to eql 1
        # This write pushs us past 200 so we should start a new file
        plw.write(pkt)
        expect(Dir[File.join(@log_path,"*.bin")].length).to eql 2
        plw.shutdown
        sleep(0.1)
      end

      it "cycles the log after a set time" do
        # Monkey patch the constant so the test doesn't take forever
        PacketLogWriter.__send__(:remove_const,:CYCLE_TIME_INTERVAL)
        PacketLogWriter.const_set(:CYCLE_TIME_INTERVAL, 0.5)
        plw = PacketLogWriter.new(:TLM,nil,true,3,10000000,nil,false)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x01\x02\x03\x04"
        plw.write(pkt)
        expect(Dir[File.join(@log_path,"*.bin")].length).to eql 1
        sleep 1
        plw.write(pkt)
        sleep 1
        plw.write(pkt)
        sleep 1
        plw.write(pkt)
        sleep 1
        plw.write(pkt)
        sleep 1
        # Ensure we have two log files
        expect(Dir[File.join(@log_path,"*.bin")].length).to eql 2
        # Check that the log files have timestamps which are 3 (or 4) seconds apart
        files = Dir[File.join(@log_path,"*tlm.bin")].sort
        split1 = files[0].split('_')
        split2 = files[1].split('_')
        log1_time = Time.new(split1[-7].to_i, split1[-6].to_i, split1[-5].to_i, split1[-4].to_i, split1[-3].to_i, split1[-2].to_i)
        log2_time = Time.new(split2[-7].to_i, split2[-6].to_i, split2[-5].to_i, split2[-4].to_i, split2[-3].to_i, split2[-2].to_i)
        expect(log2_time - log1_time).to be_within(2).of(3)
        plw.shutdown
        # Monkey patch the constant back to the default
        PacketLogWriter.__send__(:remove_const,:CYCLE_TIME_INTERVAL)
        PacketLogWriter.const_set(:CYCLE_TIME_INTERVAL, 2)
        sleep(0.1)
      end

      it "writes asynchronously to a log" do
        plw = PacketLogWriter.new(:CMD)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x01\x02\x03\x04"
        plw.write(pkt)
        plw.write(pkt)
        sleep 0.1
        plw.stop
        data = nil
        File.open(Dir[File.join(@log_path,"*.bin")][-1],'rb') do |file|
          data = file.read
        end
        expect(data[-4..-1]).to eql "\x01\x02\x03\x04"
        plw.shutdown
        sleep(0.1)
      end

      it "handles errors creating the log file" do
        capture_io do |stdout|
          allow(File).to receive(:new) { raise "Error" }
          plw = PacketLogWriter.new(:CMD)
          pkt = Packet.new('tgt','pkt')
          pkt.buffer = "\x01\x02\x03\x04"
          plw.write(pkt)
          sleep 0.1
          plw.stop
          expect(stdout.string).to match "Error opening"
          plw.shutdown
          sleep(0.1)
        end
      end

      it "handles errors closing the log file" do
        capture_io do |stdout|
          allow(File).to receive(:chmod ) { raise "Error" }
          plw = PacketLogWriter.new(:CMD)
          pkt = Packet.new('tgt','pkt')
          pkt.buffer = "\x01\x02\x03\x04"
          plw.write(pkt)
          sleep 0.1
          plw.stop
          expect(stdout.string).to match "Error closing"
          plw.shutdown
          sleep(0.1)
        end
      end
    end

    describe "start" do
      it "enables logging" do
        plw = PacketLogWriter.new(:TLM,nil,false,nil,10000000,nil,false)
        plw.start
        plw.write(Packet.new('',''))
        plw.shutdown
        file = Dir[File.join(@log_path,"*.bin")][-1]
        expect(File.size(file)).not_to eql 0
        sleep(0.1)
      end

      it "adds a label to the log file" do
        plw = PacketLogWriter.new(:TLM,nil,false,nil,10000000,nil,false)
        plw.start('test')
        plw.write(Packet.new('',''))
        plw.shutdown
        expect(Dir[File.join(@log_path,"*.bin")][-1]).to match("_tlm_test.bin")
        sleep(0.1)
      end

      it "ignores bad label formats" do
        plw = PacketLogWriter.new(:TLM,nil,false,nil,10000000,nil,false)
        plw.start('my_test')
        plw.write(Packet.new('',''))
        plw.shutdown
        expect(Dir[File.join(@log_path,"*.bin")][-1]).to match("_tlm.bin")
        sleep(0.1)
      end
    end

  end
end

