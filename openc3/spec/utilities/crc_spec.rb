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
require "openc3/utilities/crc"

module OpenC3
  # CRC 'answers' were found at
  # http://www.tty1.net/pycrc/crc-models_en.html

  describe Crc16, no_ext: true do
    describe "calc" do
      it "calculates a 16 bit CRC" do
        @crc = Crc16.new()
        expect(@crc.calc('123456789')).to eql 0x29B1
      end
    end
  end

  describe Crc32, no_ext: true do
    describe "calc" do
      it "calculates a 32 bit CRC" do
        @crc = Crc32.new()
        expect(@crc.calc('123456789')).to eql 0xCBF43926
      end
    end
  end

  describe Crc64, no_ext: true do
    describe "calc" do
      it "calculates a 64 bit CRC" do
        @crc = Crc64.new()
        expect(@crc.calc('123456789')).to eql 0x995dc9bbdf1939fa
      end
    end
  end
end
