# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require "spec_helper"
require "cosmos/utilities/crc"

module Cosmos
  # CRC 'answers' were found at
  # http://www.tty1.net/pycrc/crc-models_en.html

  describe Crc16 do
    describe "calc" do
      it "calculates a 16 bit CRC" do
        @crc = Crc16.new()
        @crc.calc('123456789').should eql 0x29B1
      end
    end
  end

  describe Crc32 do
    describe "calc" do
      it "calculates a 32 bit CRC" do
        @crc = Crc32.new()
        @crc.calc('123456789').should eql 0xCBF43926
      end
    end
  end

  describe Crc64 do
    describe "calc" do
      it "calculates a 64 bit CRC" do
        @crc = Crc64.new()
        @crc.calc('123456789').should eql 0x995dc9bbdf1939fa
      end
    end
  end
end

