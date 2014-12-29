# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/streams/tcpip_client_stream'

module Cosmos

  describe TcpipClientStream do
    before(:all) do
      addr = Socket.pack_sockaddr_in(8888, Socket::INADDR_ANY)
      @listen_socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      @listen_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1) unless Kernel.is_windows?
      @listen_socket.bind(addr)
      @listen_socket.listen(5)
    end

    after(:all) do
      @listen_socket.close
    end

    describe "initialize" do
      it "should complain if the host is bad" do
        expect { TcpipClientStream.new('asdf',8888,8888,nil,nil) }.to raise_error(/Invalid hostname/)
      end

      it "should use the same socket if read_port == write_port" do
        ss = TcpipClientStream.new('localhost',8888,8888,nil,nil)
        ss.connected?.should be_truthy
        ss.disconnect
      end

      it "should create the write socket" do
        ss = TcpipClientStream.new('localhost',8888,nil,nil,nil)
        ss.connected?.should be_truthy
        ss.disconnect
      end

      it "should create the read socket" do
        ss = TcpipClientStream.new('localhost',nil,8888,nil,nil)
        ss.connected?.should be_truthy
        ss.disconnect
      end
    end
  end
end

