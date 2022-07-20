# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require "spec_helper"
require "openc3/utilities/logger"

module OpenC3
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
      Logger.level = level
      if block
        # Fortify doesn't like this due to Access Specifier Manipulation
        # but this is only test code
        Logger.send(method, "Message1") { "Block1" }
        json = JSON.parse(stdout.string, :allow_nan => true, :create_additions => true)
        expect(json['log']).not_to match("Message1")
        expect(json['severity']).to match(method.upcase)
        expect(json['log']).to match("Block1")
      else
        # Fortify doesn't like this due to Access Specifier Manipulation
        # but this is only test code
        Logger.send(method, "Message1")
        json = JSON.parse(stdout.string, :allow_nan => true, :create_additions => true)
        expect(json['severity']).to match(method.upcase)
        expect(json['log']).to match("Message1")
      end
      $stdout = STDOUT
    end

    def test_no_output(level, method, block = false)
      stdout = StringIO.new('', 'r+')
      $stdout = stdout
      Logger.level = level
      if block
        # Fortify doesn't like this due to Access Specifier Manipulation
        # but this is only test code
        Logger.send(method, "Message2") { "Block2" }
      else
        # Fortify doesn't like this due to Access Specifier Manipulation
        # but this is only test code
        Logger.send(method, "Message2")
      end
      expect(stdout.string).to be_empty
      $stdout = STDOUT
    end

    describe "debug" do
      it "prints if level is DEBUG or higher" do
        test_output(Logger::DEBUG, 'debug')
        test_output(Logger::DEBUG, 'info')
        test_output(Logger::DEBUG, 'warn')
        test_output(Logger::DEBUG, 'error')
        test_output(Logger::DEBUG, 'fatal')
        test_no_output(Logger::INFO, 'debug')
        test_no_output(Logger::WARN, 'debug')
        test_no_output(Logger::ERROR, 'debug')
        test_no_output(Logger::FATAL, 'debug')
      end
      it "takes a block" do
        test_output(Logger::DEBUG, 'debug', true)
        test_output(Logger::DEBUG, 'info', true)
        test_output(Logger::DEBUG, 'warn', true)
        test_output(Logger::DEBUG, 'error', true)
        test_output(Logger::DEBUG, 'fatal', true)
        test_no_output(Logger::INFO, 'debug', true)
        test_no_output(Logger::WARN, 'debug', true)
        test_no_output(Logger::ERROR, 'debug', true)
        test_no_output(Logger::FATAL, 'debug', true)
      end
    end

    describe "info" do
      it "prints if level is INFO or higher" do
        test_output(Logger::INFO, 'info')
        test_output(Logger::INFO, 'warn')
        test_output(Logger::INFO, 'error')
        test_output(Logger::INFO, 'fatal')
        test_no_output(Logger::WARN, 'info')
        test_no_output(Logger::ERROR, 'info')
        test_no_output(Logger::FATAL, 'info')
      end
      it "takes a block" do
        test_output(Logger::INFO, 'info', true)
        test_output(Logger::INFO, 'warn', true)
        test_output(Logger::INFO, 'error', true)
        test_output(Logger::INFO, 'fatal', true)
        test_no_output(Logger::WARN, 'info', true)
        test_no_output(Logger::ERROR, 'info', true)
        test_no_output(Logger::FATAL, 'info', true)
      end
    end

    describe "warn" do
      it "prints if level is WARN or higher" do
        test_output(Logger::WARN, 'warn')
        test_output(Logger::WARN, 'error')
        test_output(Logger::WARN, 'fatal')
        test_no_output(Logger::ERROR, 'warn')
        test_no_output(Logger::FATAL, 'warn')
      end
      it "takes a block" do
        test_output(Logger::WARN, 'warn', true)
        test_output(Logger::WARN, 'error', true)
        test_output(Logger::WARN, 'fatal', true)
        test_no_output(Logger::ERROR, 'warn', true)
        test_no_output(Logger::FATAL, 'warn', true)
      end
    end

    describe "error" do
      it "prints if level is ERROR or higher" do
        test_output(Logger::ERROR, 'error')
        test_output(Logger::ERROR, 'fatal')
        test_no_output(Logger::FATAL, 'info')
      end
      it "takes a block" do
        test_output(Logger::ERROR, 'error', true)
        test_output(Logger::ERROR, 'fatal', true)
        test_no_output(Logger::FATAL, 'info', true)
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
