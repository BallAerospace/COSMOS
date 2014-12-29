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
      it "should be connected when initialized" do
        ss = TcpipSocketStream.new(nil,nil,nil,nil)
        ss.connected?.should be_truthy
      end
    end

    describe "read" do
      it "should raise an error if no read socket given" do
        ss = TcpipSocketStream.new('write',nil,nil,nil)
        expect { ss.read }.to raise_error("Attempt to read from write only stream")
      end

      it "should call recv_nonblock from the socket" do
        read = double("read_socket")
        expect(read).to receive(:recv_nonblock).and_return 'test'
        ss = TcpipSocketStream.new(nil,read,nil,nil)
        ss.read.should eql 'test'
      end

      it "should handle socket blocking exceptions" do
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
        ss.read.should eql 'test'
      end

      it "should handle socket timeouts" do
        read = double("read_socket")
        allow(read).to receive(:recv_nonblock).and_raise(Errno::EWOULDBLOCK)
        expect(IO).to receive(:select).at_least(:once).and_return(nil)
        ss = TcpipSocketStream.new(nil,read,nil,nil)
        expect { ss.read }.to raise_error(Timeout::Error)
      end

      it "should handle socket connection reset exceptions" do
        read = double("read_socket")
        allow(read).to receive(:recv_nonblock).and_raise(Errno::ECONNRESET)
        ss = TcpipSocketStream.new(nil,read,nil,nil)
        ss.read.should eql ''
      end
    end

    describe "write" do
      it "should raise an error if no write port given" do
        ss = TcpipSocketStream.new(nil,'read',nil,nil)
        expect { ss.write('test') }.to raise_error("Attempt to write to read only stream")
      end

      it "should call write from the driver" do
        write = double("write_socket")
        # Simulate only writing two bytes at a time
        expect(write).to receive(:write_nonblock).twice.and_return(2)
        ss = TcpipSocketStream.new(write,nil,nil,nil)
        ss.write('test')
      end

      it "should handle socket blocking exceptions" do
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
        ss.write('test')
      end

      it "should handle socket timeouts" do
        write = double("write_socket")
        allow(write).to receive(:write_nonblock).and_raise(Errno::EWOULDBLOCK)
        expect(IO).to receive(:select).at_least(:once).and_return(nil)
        ss = TcpipSocketStream.new(write,nil,nil,nil)
        expect { ss.write('test') }.to raise_error(Timeout::Error)
      end
    end

    describe "disconnect" do
      it "should close the write socket" do
        write = double("write_socket")
        expect(write).to receive(:closed?).and_return(false)
        expect(write).to receive(:close)
        ss = TcpipSocketStream.new(write,nil,nil,nil)
        ss.connected?.should be_truthy
        ss.disconnect
        ss.connected?.should be_falsey
      end

      it "should close the read socket" do
        read = double("read_socket")
        expect(read).to receive(:closed?).and_return(false)
        expect(read).to receive(:close)
        ss = TcpipSocketStream.new(nil,read,nil,nil)
        ss.connected?.should be_truthy
        ss.disconnect
        ss.connected?.should be_falsey
      end

      it "shouldn't close the socket twice" do
        socket = double("socket")
        expect(socket).to receive(:closed?).and_return(false, true)
        expect(socket).to receive(:close).once
        ss = TcpipSocketStream.new(socket,socket,nil,nil)
        ss.connected?.should be_truthy
        ss.disconnect
        ss.connected?.should be_falsey
        ss.disconnect
        ss.connected?.should be_falsey
      end
    end

  end
end

