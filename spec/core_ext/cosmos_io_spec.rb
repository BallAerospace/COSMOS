# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/core_ext/cosmos_io'

class StringIO
  include CosmosIO
end

describe StringIO do

  describe "read_length_bytes" do
    it "returns nil if length field is not 1, 2 or 4" do
      io = StringIO.new
      io.write "\x01\x01\x01\x01\x01\x01\x01\x01"
      io.rewind
      io.read_length_bytes(0).should be_nil
      io.rewind
      io.read_length_bytes(3).should be_nil
      io.rewind
      io.read_length_bytes(8).should be_nil
    end

    it "returns nil if there aren't enough bytes to read the length field" do
      io = StringIO.new
      io.write ""
      io.rewind
      io.read_length_bytes(1).should be_nil

      io = StringIO.new
      io.write "\x01"
      io.rewind
      io.read_length_bytes(2).should be_nil

      io = StringIO.new
      io.write "\x01\x01"
      io.rewind
      io.read_length_bytes(4).should be_nil
    end

    it "returns nil if there aren't enough bytes to read the string" do
      io = StringIO.new
      io.write "\x02\x01"
      io.rewind
      io.read_length_bytes(1).should be_nil
    end

    it "reads the bytes with length field size 1" do
      io = StringIO.new
      io.write "\x02\x01\x02"
      io.rewind
      io.read_length_bytes(1).should eql "\x01\x02"
    end

    it "reads the bytes with length field size 2" do
      io = StringIO.new
      io.write "\x00\x03\x01\x02\x03"
      io.rewind
      io.read_length_bytes(2).should eql "\x01\x02\x03"
    end

    it "reads the bytes with length field size 4" do
      io = StringIO.new
      io.write "\x00\x00\x00\x03\x01\x02\x03"
      io.rewind
      io.read_length_bytes(4).should eql "\x01\x02\x03"
    end
  end
end
