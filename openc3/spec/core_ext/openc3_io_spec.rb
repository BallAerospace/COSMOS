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

require 'spec_helper'
require 'openc3/core_ext/openc3_io'

class StringIO
  include OpenC3IO
end

describe StringIO do
  describe "read_length_bytes", no_ext: true do
    it "returns nil if length field is not 1, 2 or 4" do
      io = StringIO.new
      io.write "\x01\x01\x01\x01\x01\x01\x01\x01"
      io.rewind
      expect(io.read_length_bytes(0)).to be_nil
      io.rewind
      expect(io.read_length_bytes(3)).to be_nil
      io.rewind
      expect(io.read_length_bytes(8)).to be_nil
    end

    it "returns nil if there aren't enough bytes to read the length field" do
      io = StringIO.new
      io.write ""
      io.rewind
      expect(io.read_length_bytes(1)).to be_nil

      io = StringIO.new
      io.write "\x01"
      io.rewind
      expect(io.read_length_bytes(2)).to be_nil

      io = StringIO.new
      io.write "\x01\x01"
      io.rewind
      expect(io.read_length_bytes(4)).to be_nil
    end

    it "returns nil if there aren't enough bytes to read the string" do
      io = StringIO.new
      io.write "\x02\x01"
      io.rewind
      expect(io.read_length_bytes(1)).to be_nil
    end

    it "reads the bytes with length field size 1" do
      io = StringIO.new
      io.write "\x02\x01\x02"
      io.rewind
      expect(io.read_length_bytes(1)).to eql "\x01\x02"
    end

    it "reads the bytes with length field size 2" do
      io = StringIO.new
      io.write "\x00\x03\x01\x02\x03"
      io.rewind
      expect(io.read_length_bytes(2)).to eql "\x01\x02\x03"
    end

    it "reads the bytes with length field size 4" do
      io = StringIO.new
      io.write "\x00\x00\x00\x03\x01\x02\x03"
      io.rewind
      expect(io.read_length_bytes(4)).to eql "\x01\x02\x03"
    end
  end
end
