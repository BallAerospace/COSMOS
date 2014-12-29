# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/core_ext/io'

describe IO do

  describe "fast_select" do
    before(:all) do
      @server = TCPServer.open(23456)
    end
    after(:all) do
      @server.close
    end

    it "should select on read sockets" do
      # Three different timeout values cause different code paths

      socket = TCPSocket.open('localhost', 23456)
      expect(IO.fast_read_select([socket], 0.0005)).to be_nil
      socket.close

      socket = TCPSocket.open('localhost', 23456)
      expect(IO.fast_read_select([socket], 0.01)).to be_nil
      socket.close

      socket = TCPSocket.open('localhost', 23456)
      expect(IO.fast_read_select([socket], 0.5)).to be_nil
      socket.close
    end

    it "should select on write sockets" do
      socket = TCPSocket.open('localhost', 23456)
      expect(IO.fast_write_select([socket], 0.5)).not_to be_nil
      socket.close
    end
  end
end
