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
require 'cosmos/io/udp_sockets'

module Cosmos
  describe UdpWriteSocket do
    describe "initialize" do
      it "creates a socket" do
        udp = UdpWriteSocket.new('127.0.0.1', 8888)
        expect(udp.peeraddr[2]).to eql '127.0.0.1'
        expect(udp.peeraddr[1]).to eql 8888
        udp.close
        if RUBY_ENGINE == 'ruby' # UDP multicast does not work in Jruby
          udp = UdpWriteSocket.new('224.0.1.1', 8888, 7777, '127.0.0.1', 3)
          expect(udp.local_address.ip_port).to eql 7777
          # Reading this back doesn't appear to work in JRUBY, not sure if it is actually taking
          expect(udp.getsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_TTL).int).to eql 3
          expect(IPAddr.new_ntoh(udp.getsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF).data).to_s).to eql "127.0.0.1"
          udp.close
        end
      end
    end

    describe "write" do
      it "writes data" do
        udp_read  = UdpReadSocket.new(8888)
        udp_write = UdpWriteSocket.new('127.0.0.1', 8888)
        udp_write.write("\x01\x02", 2.0)
        expect(udp_read.read).to eql "\x01\x02"
        udp_read.close
        udp_write.close
      end

      it "handles timeouts" do
        allow_any_instance_of(UDPSocket).to receive(:write_nonblock) { raise Errno::EWOULDBLOCK }
        expect(IO).to receive(:fast_select).at_least(:once).and_return([], nil)
        udp_write = UdpWriteSocket.new('127.0.0.1', 8888)
        expect { udp_write.write("\x01\x02", 2.0) }.to raise_error(Timeout::Error)
        udp_write.close
      end
    end

    describe "multicast" do
      it "determines if a host is multicast" do
        expect(UdpWriteSocket.multicast?(nil, 80)).to be false
        expect(UdpWriteSocket.multicast?('224.0.1.1', nil)).to be false
        expect(UdpWriteSocket.multicast?('127.0.0.1', 80)).to be false
        expect(UdpWriteSocket.multicast?('224.0.1.1', 80)).to be true
      end
    end
  end

  describe UdpReadSocket do
    describe "initialize" do
      it "creates a socket" do
        udp = UdpReadSocket.new(8888)
        expect(udp.local_address.ip_address).to eql '0.0.0.0'
        expect(udp.local_address.ip_port).to eql 8888
        udp.close
        if RUBY_ENGINE == 'ruby' # UDP multicast does not work in Jruby
          udp = UdpReadSocket.new(8888, '224.0.1.1')
          expect(IPAddr.new_ntoh(udp.getsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF).data).to_s).to eql "0.0.0.0"
          udp.close
        end
      end
    end

    describe "read" do
      it "reads data" do
        udp_read  = UdpReadSocket.new(8888)
        udp_write = UdpWriteSocket.new('127.0.0.1', 8888)
        udp_write.write("\x01\x02", 2.0)
        expect(udp_read.read).to eql "\x01\x02"
        udp_read.close
        udp_write.close
      end

      it "handles timeouts" do
        allow_any_instance_of(UDPSocket).to receive(:recvfrom_nonblock) { raise Errno::EWOULDBLOCK }
        expect(IO).to receive(:fast_select).at_least(:once).and_return([], nil)
        udp_read = UdpReadSocket.new(8889)
        expect { udp_read.read(2.0) }.to raise_error(Timeout::Error)
        udp_read.close
      end
    end
  end

  describe UdpReadWriteSocket do
    describe "initialize" do
      it "creates a socket" do
        udp = UdpReadWriteSocket.new(8888)
        expect(udp.local_address.ip_address).to eql '0.0.0.0'
        expect(udp.local_address.ip_port).to eql 8888
        udp.close
        if RUBY_ENGINE == 'ruby' # UDP multicast does not work in Jruby
          udp = UdpReadWriteSocket.new(8888, '0.0.0.0', 1234, '224.0.1.1')
          expect(IPAddr.new_ntoh(udp.getsockopt(Socket::IPPROTO_IP, Socket::IP_MULTICAST_IF).data).to_s).to eql "0.0.0.0"
          udp.close
        end
      end
    end

    describe "read" do
      it "reads data" do
        udp_read  = UdpReadWriteSocket.new(8888)
        udp_write = UdpWriteSocket.new('127.0.0.1', 8888)
        udp_write.write("\x01\x02", 2.0)
        expect(udp_read.read).to eql "\x01\x02"
        udp_read.close
        udp_write.close
      end
    end

    describe "write" do
      it "writes data" do
        udp_read  = UdpReadSocket.new(8888)
        udp_write = UdpReadWriteSocket.new(0, "0.0.0.0", 8888, '127.0.0.1')
        udp_write.write("\x01\x02", 2.0)
        expect(udp_read.read).to eql "\x01\x02"
        udp_read.close
        udp_write.close
      end
    end
  end
end
