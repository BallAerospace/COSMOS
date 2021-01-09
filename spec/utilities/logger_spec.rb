# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require "spec_helper"
require "cosmos/utilities/logger"

module Cosmos
  describe Logger do
    before(:each) do
      Logger.class_variable_set(:@@instance, nil)
    end

    describe "initialize" do
      it "initializes the level to INFO" do
        expect(Logger.new.level).to eql Logger::INFO
      end
    end

    describe "level" do
      it "gets and set the level" do
        Logger.level = Logger::DEBUG
        expect(Logger.level).to eql Logger::DEBUG
      end
    end

    def test_output(level, method, block = false)
      stdout = StringIO.new('', 'r+')
      $stdout = stdout
      Logger.stdout = true
      Logger.level = level
      if block
        Logger.send(method, "Message1") { "Block1" }
        expect(stdout.string).not_to match("Message1")
        expect(stdout.string).to match("#{method.upcase}: Block1")
      else
        Logger.send(method, "Message1")
        expect(stdout.string).to match("#{method.upcase}: Message1")
      end
      Logger::instance.level = level + 1
      if block
        Logger.debug("Message2") { "Block2" }
        expect(stdout.string).not_to match("Message2")
        expect(stdout.string).not_to match("Block2")
      else
        Logger.send(method, "Message2")
        expect(stdout.string).not_to match("Message2")
      end
      $stdout = STDOUT
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
