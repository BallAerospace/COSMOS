# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/streams/tcpip_socket_stream'

module Cosmos

  describe TcpipSocketStream do
    describe "initialize, connected?" do
      it "is not be connected when initialized" do
        ss = TcpipSocketStream.new(nil,nil,nil,nil)
        expect(ss.connected?).to be_falsy
      end
    end

    describe "read" do
      it "raises an error if no read socket given" do
        ss = TcpipSocketStream.new('write',nil,nil,nil)
        ss.connect
        expect { ss.read }.to raise_error("Attempt to read from write only stream")
      end

      it "calls recv_nonblock from the socket" do
        read = double("read_socket")
        expect(read).to receive(:recv_nonblock).and_return 'test'
        ss = TcpipSocketStream.new(nil,read,nil,nil)
        ss.connect
        expect(ss.read).to eql 'test'
      end

      it "handles socket blocking exceptions" do
        read = double("read_socket")
        allow(read).to receive(:recv_nonblock) do
          case $index
          when 1
            $index += 1
            raise Errno::EWOULDBLOCK
          when 2
            'test'
          end
        end
        expect(IO).to receive(:select).at_least(:once).and_return([])
        $index = 1
        ss = TcpipSocketStream.new(nil,read,nil,nil)
        ss.connect
        expect(ss.read).to eql 'test'
      end

      it "handles socket timeouts" do
        read = double("read_socket")
        allow(read).to receive(:recv_nonblock).and_raise(Errno::EWOULDBLOCK)
        expect(IO).to receive(:select).at_least(:once).and_return(nil)
        ss = TcpipSocketStream.new(nil,read,nil,nil)
        ss.connect
        expect { ss.read }.to raise_error(Timeout::Error)
      end

      it "handles socket connection reset exceptions" do
        read = double("read_socket")
        allow(read).to receive(:recv_nonblock).and_raise(Errno::ECONNRESET)
        ss = TcpipSocketStream.new(nil,read,nil,nil)
        ss.connect
        expect(ss.read).to eql ''
      end
    end

    describe "write" do
      it "raises an error if no write port given" do
        ss = TcpipSocketStream.new(nil,'read',nil,nil)
        ss.connect
        expect { ss.write('test') }.to raise_error("Attempt to write to read only stream")
      end

      it "calls write from the driver" do
        write = double("write_socket")
        # Simulate only writing two bytes at a time
        expect(write).to receive(:write_nonblock).twice.and_return(2)
        ss = TcpipSocketStream.new(write,nil,nil,nil)
        ss.connect
        ss.write('test')
      end

      it "handles socket blocking exceptions" do
        write = double("write_socket")
        allow(write).to receive(:write_nonblock) do
          case $index
          when 1
            $index += 1
            raise Errno::EWOULDBLOCK
          when 2
            4
          end
        end
        expect(IO).to receive(:select).at_least(:once).and_return([])
        $index = 1
        ss = TcpipSocketStream.new(write,nil,nil,nil)
        ss.connect
        ss.write('test')
      end

      it "handles socket timeouts" do
        write = double("write_socket")
        allow(write).to receive(:write_nonblock).and_raise(Errno::EWOULDBLOCK)
        expect(IO).to receive(:select).at_least(:once).and_return(nil)
        ss = TcpipSocketStream.new(write,nil,nil,nil)
        ss.connect
        expect { ss.write('test') }.to raise_error(Timeout::Error)
      end
    end

    describe "disconnect" do
      it "closes the write socket" do
        write = double("write_socket")
        expect(write).to receive(:closed?).and_return(false)
        expect(write).to receive(:close)
        ss = TcpipSocketStream.new(write,nil,nil,nil)
        ss.connect
        expect(ss.connected?).to be_truthy
        ss.disconnect
        expect(ss.connected?).to be_falsey
      end

      it "closes the read socket" do
        read = double("read_socket")
        expect(read).to receive(:closed?).and_return(false)
        expect(read).to receive(:close)
        ss = TcpipSocketStream.new(nil,read,nil,nil)
        ss.connect
        expect(ss.connected?).to be_truthy
        ss.disconnect
        expect(ss.connected?).to be_falsey
      end

      it "does not close the socket twice" do
        socket = double("socket")
        expect(socket).to receive(:closed?).and_return(false, true, true, true)
        expect(socket).to receive(:close).once
        ss = TcpipSocketStream.new(socket,socket,nil,nil)
        ss.connect
        expect(ss.connected?).to be_truthy
        ss.disconnect
        expect(ss.connected?).to be_falsey
        ss.disconnect
        expect(ss.connected?).to be_falsey
      end
    end

  end
end

