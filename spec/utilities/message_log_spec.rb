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
    describe "initialize" do
      it "accepts a tool name and use the default LOG path" do
        log = MessageLog.new('TEST')
        log.start
        log.stop
        Cosmos.set_working_dir do
          expect(File.exist?(log.filename)).to be true
          expect(log.filename).to match('TEST')
          expect(log.filename).to match('logs')
          File.delete log.filename
        end
      end

      it "accepts a tool name and path" do
        log = MessageLog.new('TEST', File.expand_path(File.dirname(__FILE__)))
        log.start
        log.stop
        expect(File.exist?(log.filename)).to be true
        expect(log.filename).to match(File.expand_path(File.dirname(__FILE__)))
        File.delete log.filename
      end
    end

    describe "write" do
      it "writes a message to the log" do
        log = MessageLog.new('TEST')
        log.write("Test message")
        log.stop
        Cosmos.set_working_dir do
          expect(File.read(log.filename)).to eql "Test message"
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
        expect(log.filename).not_to eql filename
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
        if Kernel.is_windows? or Process.uid != 0
          # writable? is always true for root, so skip this check
          Cosmos.set_working_dir do
            expect(File.stat(log.filename).writable?).to be false
            File.delete log.filename
          end
        end
      end
    end
  end
end

