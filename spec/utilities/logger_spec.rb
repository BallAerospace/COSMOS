# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require "spec_helper"
require "cosmos/utilities/logger"

module Cosmos
  describe Logger do
    describe "initialize" do
      it "initializes the level to UNKNOWN" do
        Logger.new.level.should eql Logger::UNKNOWN
        Logger.level = Logger::UNKNOWN
      end
    end

    describe "level" do
      it "gets and set the level" do
        Logger.level = Logger::DEBUG
        Logger.level.should eql Logger::DEBUG
        Logger.level = Logger::UNKNOWN
      end
    end

    def test_output(level, method, block = false)
      stdout = StringIO.new('', 'r+')
      $stdout = stdout
      Logger.level = level
      if block
        Logger.send(method, "Message1") { "Block1" }
        stdout.string.should_not match "Message1"
        stdout.string.should match "#{method.upcase}: Block1"
      else
        Logger.send(method, "Message1")
        stdout.string.should match "#{method.upcase}: Message1"
      end
      Logger::instance.level = level + 1
      if block
        Logger.debug("Message2") { "Block2" }
        stdout.string.should_not match "Message2"
        stdout.string.should_not match "Block2"
      else
        Logger.send(method, "Message2")
        stdout.string.should_not match "Message2"
      end
      $stdout = STDOUT
      Logger.level = Logger::UNKNOWN
    end

    describe "debug" do
      it "only prints if level is DEBUG" do
        test_output(Logger::DEBUG, 'debug')
      end
      it "takes a block" do
        test_output(Logger::DEBUG, 'debug', true)
      end
    end

    describe "info" do
      it "only prints if level is INFO" do
        test_output(Logger::INFO, 'info')
      end
      it "takes a block" do
        test_output(Logger::INFO, 'info', true)
      end
    end

    describe "warn" do
      it "only prints if level is WARN" do
        test_output(Logger::WARN, 'warn')
      end
      it "takes a block" do
        test_output(Logger::WARN, 'warn', true)
      end
    end

    describe "error" do
      it "only prints if level is ERROR" do
        test_output(Logger::ERROR, 'error')
      end
      it "takes a block" do
        test_output(Logger::ERROR, 'error', true)
      end
    end

    describe "fatal" do
      it "only prints if level is FATAL" do
        test_output(Logger::FATAL, 'fatal')
      end
      it "takes a block" do
        test_output(Logger::FATAL, 'fatal', true)
      end
    end
  end
end

