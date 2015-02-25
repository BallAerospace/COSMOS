# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require "spec_helper"
require "cosmos/utilities/message_log"

module Cosmos
  describe MessageLog do
    before(:all) do
      System.class_eval('@@instance = nil')
    end

    after(:all) do
      clean_config()
    end

    describe "initialize" do
      it "accepts a tool name and use the default LOG path" do
        log = MessageLog.new('TEST')
        log.start
        log.stop
        Cosmos.set_working_dir do
          File.exist?(log.filename).should be_truthy
          log.filename.should match 'TEST'
          log.filename.should match 'logs'
          File.delete log.filename
        end
      end

      it "accepts a tool name and path" do
        log = MessageLog.new('TEST', File.expand_path(File.dirname(__FILE__)))
        log.start
        log.stop
        File.exist?(log.filename).should be_truthy
        log.filename.should match File.expand_path(File.dirname(__FILE__))
        File.delete log.filename
      end
    end

    describe "write" do
      it "writes a message to the log" do
        log = MessageLog.new('TEST')
        log.write("Test message")
        log.stop
        Cosmos.set_working_dir do
          File.read(log.filename).should eql "Test message"
          File.delete log.filename
        end
      end
    end

    describe "start" do
      it "creates a new message log" do
        log = MessageLog.new('TEST')
        log.start
        filename = log.filename
        # Allow a second to tick by so we have a unique filename
        sleep(1.001)
        log.start
        log.filename.should_not eql filename
        log.stop
        Cosmos.set_working_dir do
          File.delete filename
          File.delete log.filename
        end
      end
    end

    describe "stop" do
      it "closes the message log and mark it read-only" do
        log = MessageLog.new('TEST')
        log.start
        log.stop
        Cosmos.set_working_dir do
          File.stat(log.filename).writable?.should be_falsey
          File.delete log.filename
        end
      end
    end
  end
end

