# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/io/raw_logger'

module Cosmos

  describe RawLogger do
    before(:each) do
      @log_path = System.paths['LOGS']
    end

    after(:each) do
      clean_config()
    end

    describe "initialize" do
      it "should complain with an unknown log type" do
        expect { RawLogger.new(:BOTH) }.to raise_error
      end

      it "should create a raw write log" do
        raw_logger = RawLogger.new('MYINT', :WRITE, true, 100000, nil)
        raw_logger.write("\x00\x01\x02\0x3")
        raw_logger.stop
        expect(Dir[File.join(@log_path,"*.bin")][-1]).to match("myint_raw_write")
      end

      it "should create a raw read log" do
        raw_logger = RawLogger.new('MYINT', :READ, true, 100000, nil)
        raw_logger.write("\x00\x01\x02\0x3")
        raw_logger.stop
        expect(Dir[File.join(@log_path,"*.bin")][-1]).to match("myint_raw_read")
      end

      it "should use the log directory" do
        raw_logger = RawLogger.new('raw_logger_spec_', :READ, true, 100000, Cosmos::USERPATH)
        raw_logger.write("\x00\x01\x02\0x3")
        raw_logger.stop
        expect(Dir[File.join(Cosmos::USERPATH,"*raw_logger_spec_*")][-1]).to match("raw_logger_spec_")
        Dir[File.join(Cosmos::USERPATH,"*raw_logger_spec_*")].each do |file|
          File.delete file
        end
      end
    end

    describe "write" do
      it "should write synchronously to a log" do
        raw_logger = RawLogger.new('MYINT', :WRITE, true, 100000, nil)
        raw_logger.write("\x00\x01\x02\x03")
        raw_logger.stop
        data = nil
        File.open(Dir[File.join(@log_path,"*.bin")][-1],'rb') do |file|
          data = file.read
        end
        data.should eql "\x00\x01\x02\x03"
      end

      it "should not write data if logging is disabled" do
        raw_logger = RawLogger.new('MYINT', :WRITE, false, 100000, nil)
        raw_logger.write("\x00\x01\x02\x03")
        Dir[File.join(@log_path,"*.bin")].should be_empty
      end

      it "should cycle the log when it a size" do
        raw_logger = RawLogger.new('MYINT', :WRITE, true, 200000, nil)
        raw_logger.write("\x00\x01\x02\x03" * 25000) # size 100000
        raw_logger.write("\x00\x01\x02\x03" * 25000) # size 200000
        Dir[File.join(@log_path,"*.bin")].length.should eql 1
        sleep(2)
        raw_logger.write("\x00") # size 200001
        raw_logger.stop
        files = Dir[File.join(@log_path,"*.bin")]
        files.length.should eql 2
      end

      it "should handle errors creating the log file" do
        capture_io do |stdout|
          allow(File).to receive(:new) { raise "Error" }
          raw_logger = RawLogger.new('MYINT', :WRITE, true, 200, nil)
          raw_logger.write("\x00\x01\x02\x03")
          raw_logger.stop
          stdout.string.should match "Error opening"
        end
      end

      it "should handle errors closing the log file" do
        capture_io do |stdout|
          allow(File).to receive(:chmod) { raise "Error" }
          raw_logger = RawLogger.new('MYINT', :WRITE, true, 200, nil)
          raw_logger.write("\x00\x01\x02\x03")
          raw_logger.stop
          stdout.string.should match "Error closing"
        end
      end

      it "should handle errors writing the log file" do
        capture_io do |stdout|
          raw_logger = RawLogger.new('MYINT', :WRITE, true, 200, nil)
          raw_logger.write("\x00\x01\x02\x03")
          allow(raw_logger.instance_variable_get(:@file)).to receive(:write) { raise "Error" }
          raw_logger.write("\x00\x01\x02\x03")
          raw_logger.stop
          stdout.string.should match "Error writing"
        end
      end
    end

    describe "start and stop" do
      it "should enable and disable logging" do
        raw_logger = RawLogger.new('MYINT', :WRITE, false, 200, nil)
        raw_logger.logging_enabled.should be_falsey
        raw_logger.start
        raw_logger.logging_enabled.should be_truthy
        raw_logger.write("\x00\x01\x02\x03")
        raw_logger.stop
        raw_logger.logging_enabled.should be_falsey
        file = Dir[File.join(@log_path,"*.bin")][-1]
        File.size(file).should_not eql 0
      end
    end

  end
end

