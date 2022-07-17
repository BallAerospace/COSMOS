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
require 'openc3/streams/tcpip_client_stream'

module OpenC3
  describe TcpipClientStream do
    before(:all) do
      addr = Socket.pack_sockaddr_in(8888, "0.0.0.0")
      if RUBY_ENGINE == 'ruby'
        @listen_socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      else
        @listen_socket = ServerSocket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      end
      @listen_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1) unless Kernel.is_windows?
      if RUBY_ENGINE == 'ruby'
        @listen_socket.bind(addr)
        @listen_socket.listen(5)
      else
        @listen_socket.bind(addr, 5)
      end
    end

    after(:all) do
      @listen_socket.close
    end

    describe "initialize" do
      it "complains if the host is bad" do
        expect { TcpipClientStream.new('asdf', 8888, 8888, nil, nil) }.to raise_error(/Invalid hostname/)
      end

      it "uses the same socket if read_port == write_port" do
        ss = TcpipClientStream.new('localhost', 8888, 8888, nil, nil)
        ss.connect
        expect(ss.connected?).to be true
        ss.disconnect
      end

      it "creates the write socket" do
        ss = TcpipClientStream.new('localhost', 8888, nil, nil, nil)
        ss.connect
        expect(ss.connected?).to be true
        ss.disconnect
      end

      it "creates the read socket" do
        ss = TcpipClientStream.new('localhost', nil, 8888, nil, nil)
        ss.connect
        expect(ss.connected?).to be true
        ss.disconnect
      end
    end
  end
end
