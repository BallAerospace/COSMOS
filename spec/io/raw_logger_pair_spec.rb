# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/io/raw_logger_pair'

module Cosmos

  describe RawLoggerPair do

    describe "initialize" do
      it "should set the write logger and read logger" do
        pair = RawLoggerPair.new('MYINT')
        pair.read_logger.should_not be_nil
        pair.write_logger.should_not be_nil
        pair.read_logger.logging_enabled.should be_falsey
        pair.write_logger.logging_enabled.should be_falsey

        pair = RawLoggerPair.new('MYINT2', ['raw_logger.rb', true, 100000, './'])
        pair.read_logger.should_not be_nil
        pair.write_logger.should_not be_nil
        pair.read_logger.logging_enabled.should be_truthy
        pair.write_logger.logging_enabled.should be_truthy
      end
    end

    describe "start" do
      it "should start logging" do
        pair = RawLoggerPair.new('MYINT')
        pair.start
        pair.write_logger.logging_enabled.should be_truthy
        pair.read_logger.logging_enabled.should be_truthy
      end
    end

    describe "stop" do
      it "should stop logging" do
        pair = RawLoggerPair.new('MYINT')
        pair.start
        pair.write_logger.logging_enabled.should be_truthy
        pair.read_logger.logging_enabled.should be_truthy
        pair.stop
        pair.write_logger.logging_enabled.should be_falsey
        pair.read_logger.logging_enabled.should be_falsey
      end
    end

    describe "clone" do
      it "should clone itself including logging state" do
        pair = RawLoggerPair.new('MYINT')
        pair.write_logger.logging_enabled.should be_falsey
        pair.read_logger.logging_enabled.should be_falsey
        pair_clone1 = pair.clone
        pair.start
        pair.write_logger.logging_enabled.should be_truthy
        pair.read_logger.logging_enabled.should be_truthy
        pair_clone1.write_logger.logging_enabled.should be_falsey
        pair_clone1.read_logger.logging_enabled.should be_falsey
        pair_clone2 = pair.clone
        pair_clone1.write_logger.logging_enabled.should be_falsey
        pair_clone1.read_logger.logging_enabled.should be_falsey
        pair_clone2.write_logger.logging_enabled.should be_truthy
        pair_clone2.read_logger.logging_enabled.should be_truthy
      end
    end

  end
end

