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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos/io/raw_logger_pair'

module Cosmos
  describe RawLoggerPair do
    describe "initialize" do
      it "requires a name" do
        expect { RawLoggerPair.new }.to raise_error(ArgumentError)
      end

      it "requires a log directory" do
        expect { RawLoggerPair.new('MYINT') }.to raise_error(ArgumentError)
      end

      it "sets the write logger and read logger" do
        pair = RawLoggerPair.new('MYINT', '.')
        expect(pair.read_logger).not_to be_nil
        expect(pair.write_logger).not_to be_nil
        expect(pair.read_logger.logging_enabled).to be false
        expect(pair.write_logger.logging_enabled).to be false

        pair = RawLoggerPair.new('MYINT2', '.', ['raw_logger.rb', true, 100000])
        expect(pair.read_logger).not_to be_nil
        expect(pair.write_logger).not_to be_nil
        expect(pair.read_logger.logging_enabled).to be true
        expect(pair.write_logger.logging_enabled).to be true
      end
    end

    describe "start" do
      it "starts logging" do
        pair = RawLoggerPair.new('MYINT', '.')
        pair.start
        expect(pair.write_logger.logging_enabled).to be true
        expect(pair.read_logger.logging_enabled).to be true
      end
    end

    describe "stop" do
      it "stops logging" do
        pair = RawLoggerPair.new('MYINT', '.')
        pair.start
        expect(pair.write_logger.logging_enabled).to be true
        expect(pair.read_logger.logging_enabled).to be true
        pair.stop
        expect(pair.write_logger.logging_enabled).to be false
        expect(pair.read_logger.logging_enabled).to be false
      end
    end

    describe "clone" do
      it "clones itself including logging state" do
        pair = RawLoggerPair.new('MYINT', '.')
        expect(pair.write_logger.logging_enabled).to be false
        expect(pair.read_logger.logging_enabled).to be false
        pair_clone1 = pair.clone
        pair.start
        expect(pair.write_logger.logging_enabled).to be true
        expect(pair.read_logger.logging_enabled).to be true
        expect(pair_clone1.write_logger.logging_enabled).to be false
        expect(pair_clone1.read_logger.logging_enabled).to be false
        pair_clone2 = pair.clone
        expect(pair_clone1.write_logger.logging_enabled).to be false
        expect(pair_clone1.read_logger.logging_enabled).to be false
        expect(pair_clone2.write_logger.logging_enabled).to be true
        expect(pair_clone2.read_logger.logging_enabled).to be true
      end
    end
  end
end
