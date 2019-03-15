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
require 'socket'

module Cosmos

  if RUBY_ENGINE == 'ruby' # For some reason this test causes uncatchable exceptions in Jruby when run with other tests - Skip for now

  describe TcpipSocketStream do
    describe "initialize, connected?" do
      it "is not be connected when initialized" do
        ss = TcpipSocketStream.new(nil,nil,nil,nil)
        expect(ss.connected?).to be false
      end
    end

    # This test takes time and doesn't actually assert any functionality
    # It was created to verify the changes to socket reads in PR#181.
    #describe "read benchmark" do
    #  it "determines how fast the read is" do
    #    server = TCPServer.new(2000) # Server bound to port 2000
    #    thread = Thread.new do
    #      client = server.accept    # Wait for a client to connect
    #      i = 0
    #      100000.times do
    #        client.write "test"
    #        i += 1
    #        sleep 0.001 if i % 100 == 1
    #      end
    #      client.close
    #    end
    #    socket = TCPSocket.new('localhost', 2000)
    #    ss = TcpipSocketStream.new(nil,socket,nil,nil)
    #    bytes = 0
    #    while bytes < 400000
    #      bytes += ss.read.length
    #    end
    #    Cosmos.close_socket(socket)
    #    Cosmos.close_socket(server)
    #    thread.kill
    #    sleep 0.1
    #  end
    #end

    describe "read" do
      it "raises an error if no read socket given" do
        ss = TcpipSocketStream.new('write',nil,nil,nil)
        ss.connect
        expect { ss.read }.to raise_error("Attempt to read from write only stream")
        ss.disconnect
      end

      it "calls read_nonblock from the socket" do
        server = TCPServer.new(2000) # Server bound to port 2000
        thread = Thread.new do
          client = server.accept    # Wait for a client to connect
          sleep 0.1
          client.write "test"
          client.close
        end
        sleep 0.1
        socket = TCPSocket.new('localhost', 2000)
        ss = TcpipSocketStream.new(nil,socket,nil,nil)
        expect(ss.read_nonblock).to eql ''
        sleep 0.2
        expect(ss.read_nonblock).to eql 'test'
        thread.join
        Cosmos.close_socket(socket)
        Cosmos.close_socket(server)
        sleep 0.1
        ss.disconnect
      end

      it "handles socket blocking exceptions" do
        server = TCPServer.new(2000) # Server bound to port 2000
        thread = Thread.new do
          client = server.accept    # Wait for a client to connect
          sleep 0.2
          client.write "test"
          client.close
        end
        sleep 0.1
        socket = TCPSocket.new('localhost', 2000)
        ss = TcpipSocketStream.new(nil,socket,nil,nil)
        expect(ss.read).to eql 'test'
        thread.join
        Cosmos.close_socket(socket)
        Cosmos.close_socket(server)
        sleep 0.1
        ss.disconnect
      end

      it "handles socket timeouts" do
        server = TCPServer.new(2000) # Server bound to port 2000
        thread = Thread.new do
          client = server.accept    # Wait for a client to connect
          sleep 0.2
          client.close
        end
        socket = TCPSocket.new('localhost', 2000)
        ss = TcpipSocketStream.new(nil,socket,nil,0.1)
        expect { ss.read }.to raise_error(Timeout::Error)
        thread.join
        sleep 0.2
        Cosmos.close_socket(socket)
        Cosmos.close_socket(server)
        ss.disconnect
        sleep 0.1
      end

      it "handles socket connection reset exceptions" do
        server = TCPServer.new(2000) # Server bound to port 2000
        thread = Thread.new do
          client = server.accept    # Wait for a client to connect
          sleep 0.2
          begin
            client.close
          rescue IOError
            # Closing the socket causes an IOError
          end
        end
        socket = TCPSocket.new('localhost', 2000)
        ss = TcpipSocketStream.new(nil,socket,nil,5)
        sleep 0.1 # Allow the server thread to accept
        # Close the socket before trying to read from it
        Cosmos.close_socket(socket)
        expect(ss.read).to eql ''
        Cosmos.close_socket(server)
        thread.join
        ss.disconnect
        sleep 0.1
      end
    end

    describe "write" do
      it "raises an error if no write port given" do
        ss = TcpipSocketStream.new(nil,'read',nil,nil)
        ss.connect
        expect { ss.write('test') }.to raise_error("Attempt to write to read only stream")
        ss.disconnect
      end

      it "calls write from the driver" do
        write = double("write_socket")
        # Simulate only writing two bytes at a time
        expect(write).to receive(:write_nonblock).twice.and_return(2)
        ss = TcpipSocketStream.new(write,nil,nil,nil)
        ss.connect
        ss.write('test')
        ss.disconnect
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
        expect(IO).to receive(:fast_select).at_least(:once).and_return([])
        $index = 1
        ss = TcpipSocketStream.new(write,nil,nil,nil)
        ss.connect
        ss.write('test')
        ss.disconnect
      end

      it "handles socket timeouts" do
        write = double("write_socket")
        allow(write).to receive(:write_nonblock).and_raise(Errno::EWOULDBLOCK)
        expect(IO).to receive(:fast_select).at_least(:once).and_return(nil)
        ss = TcpipSocketStream.new(write,nil,nil,nil)
        ss.connect
        expect { ss.write('test') }.to raise_error(Timeout::Error)
        ss.disconnect
      end
    end

    describe "disconnect" do
      it "closes the write socket" do
        write = double("write_socket")
        expect(write).to receive(:closed?).and_return(false)
        expect(write).to receive(:close)
        ss = TcpipSocketStream.new(write,nil,nil,nil)
        ss.connect
        expect(ss.connected?).to be true
        ss.disconnect
        expect(ss.connected?).to be false
      end

      it "closes the read socket" do
        read = double("read_socket")
        expect(read).to receive(:closed?).and_return(false)
        expect(read).to receive(:close)
        ss = TcpipSocketStream.new(nil,read,nil,nil)
        ss.connect
        expect(ss.connected?).to be true
        ss.disconnect
        expect(ss.connected?).to be false
      end

      it "does not close the socket twice" do
        socket = double("socket")
        expect(socket).to receive(:closed?).and_return(false, true, true, true)
        expect(socket).to receive(:close).once
        ss = TcpipSocketStream.new(socket,socket,nil,nil)
        ss.connect
        expect(ss.connected?).to be true
        ss.disconnect
        expect(ss.connected?).to be false
        ss.disconnect
        expect(ss.connected?).to be false
      end
    end
  end
  end # TEMP for Jruby
end
