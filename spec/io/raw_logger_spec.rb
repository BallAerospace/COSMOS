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
      it "complains with an unknown log type" do
        expect { RawLogger.new('MYINT', :BOTH) }.to raise_error(/must be :READ or :WRITE/)
      end

      it "creates a raw write log" do
        raw_logger = RawLogger.new('MYINT', :WRITE, true, 100000, nil)
        raw_logger.write("\x00\x01\x02\0x3")
        raw_logger.stop
        expect(Dir[File.join(@log_path,"*.bin")][-1]).to match("myint_raw_write")
      end

      it "creates a raw read log" do
        raw_logger = RawLogger.new('MYINT', :READ, true, 100000, nil)
        raw_logger.write("\x00\x01\x02\0x3")
        raw_logger.stop
        expect(Dir[File.join(@log_path,"*.bin")][-1]).to match("myint_raw_read")
      end

      it "uses the log directory" do
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
      it "writes synchronously to a log" do
        raw_logger = RawLogger.new('MYINT', :WRITE, true, 100000, nil)
        raw_logger.write("\x00\x01\x02\x03")
        raw_logger.stop
        data = nil
        File.open(Dir[File.join(@log_path,"*.bin")][-1],'rb') do |file|
          data = file.read
        end
        expect(data).to eql "\x00\x01\x02\x03"
      end

      it "does not write data if logging is disabled" do
        raw_logger = RawLogger.new('MYINT', :WRITE, false, 100000, nil)
        raw_logger.write("\x00\x01\x02\x03")
        expect(Dir[File.join(@log_path,"*.bin")]).to be_empty
      end

      it "cycles the log when it a size" do
        raw_logger = RawLogger.new('MYINT', :WRITE, true, 200000, nil)
        raw_logger.write("\x00\x01\x02\x03" * 25000) # size 100000
        raw_logger.write("\x00\x01\x02\x03" * 25000) # size 200000
        expect(Dir[File.join(@log_path,"*.bin")].length).to eql 1
        sleep(2)
        raw_logger.write("\x00") # size 200001
        raw_logger.stop
        files = Dir[File.join(@log_path,"*.bin")]
        expect(files.length).to eql 2
      end

      it "handles errors creating the log file" do
        capture_io do |stdout|
          allow(File).to receive(:new) { raise "Error" }
          raw_logger = RawLogger.new('MYINT', :WRITE, true, 200, nil)
          raw_logger.write("\x00\x01\x02\x03")
          raw_logger.stop
          expect(stdout.string).to match "Error opening"
        end
      end

      it "handles errors closing the log file" do
        capture_io do |stdout|
          allow(File).to receive(:chmod) { raise "Error" }
          raw_logger = RawLogger.new('MYINT', :WRITE, true, 200, nil)
          raw_logger.write("\x00\x01\x02\x03")
          raw_logger.stop
          expect(stdout.string).to match "Error closing"
        end
      end

      it "handles errors writing the log file" do
        capture_io do |stdout|
          raw_logger = RawLogger.new('MYINT', :WRITE, true, 200, nil)
          raw_logger.write("\x00\x01\x02\x03")
          allow(raw_logger.instance_variable_get(:@file)).to receive(:write) { raise "Error" }
          raw_logger.write("\x00\x01\x02\x03")
          raw_logger.stop
          expect(stdout.string).to match "Error writing"
        end
      end
    end

    describe "start and stop" do
      it "enables and disable logging" do
        raw_logger = RawLogger.new('MYINT', :WRITE, false, 200, nil)
        expect(raw_logger.logging_enabled).to be false
        raw_logger.start
        expect(raw_logger.logging_enabled).to be true
        raw_logger.write("\x00\x01\x02\x03")
        raw_logger.stop
        expect(raw_logger.logging_enabled).to be false
        file = Dir[File.join(@log_path,"*.bin")][-1]
        expect(File.size(file)).not_to eql 0
      end
    end

  end
end

