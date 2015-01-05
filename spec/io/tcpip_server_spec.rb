# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/io/tcpip_server'

module Cosmos

  describe TcpipServer do

    describe "instance" do
      it "should rescue bad stream protocol names" do
        expect { TcpipServer.new(8888,8889,nil,nil,'Unknown') }.to raise_error(/Unable to require/)
      end
    end

    describe "connect, connected?, disconnect" do
      it "should only allow connect once" do
        server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        server.connect
        sleep 0.2
        expect { server.connect }.to raise_error(/Error binding/)
        server.disconnect
        sleep(0.2)
      end

      it "should create a listener thread for the read port" do
        server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        server.connect
        sleep 0.2
        server.connected?.should be_truthy
        # 2 because the RSpec main thread plus the listener
        Thread.list.length.should eql 2
        server.disconnect
        sleep 0.2
        server.connected?.should be_falsey
        Thread.list.length.should eql 1
      end

      it "should create a listener thread for the write port" do
        server = TcpipServer.new(8888,nil,nil,nil,'Burst')
        server.connect
        sleep 0.2
        server.connected?.should be_truthy
        # 3 because the RSpec main thread plus the listener
        # plus one for the write thread
        Thread.list.length.should eql 3
        server.disconnect
        sleep 0.2
        server.connected?.should be_falsey
        Thread.list.length.should eql 1
      end

      it "should create a single listener thread if read = write port" do
        server = TcpipServer.new(8888,8888,nil,nil,'Burst')
        server.connect
        sleep 0.2
        server.connected?.should be_truthy
        # 3 because the RSpec main thread plus the listener
        # plus one for the write thread
        Thread.list.length.should eql 3
        server.disconnect
        sleep 0.2
        server.connected?.should be_falsey
        Thread.list.length.should eql 1
      end

      it "should create a two listener threads if read != write port" do
        server = TcpipServer.new(8888,8889,nil,nil,'Burst')
        server.connect
        sleep 0.2
        server.connected?.should be_truthy
        # 4 because the RSpec main thread plus the two listeners
        # plus one for the write thread
        Thread.list.length.should eql 4
        server.disconnect
        sleep 0.2
        server.connected?.should be_falsey
        Thread.list.length.should eql 1
      end

      it "should log an error if the listener thread dies" do
        capture_io do |stdout|
          system = double("System")
          allow(system).to receive(:use_dns) { raise "Error" }
          allow(System).to receive(:instance).and_return(system)

          server = TcpipServer.new(8888,8888,nil,nil,'Burst')
          server.connect
          sleep 0.2
          socket = TCPSocket.open("127.0.0.1",8888)
          sleep 0.2
          server.disconnect
          socket.close
          sleep(0.2)

          stdout.string.should match /Tcpip server listen thread unexpectedly died/
        end
      end
    end

    describe "read" do
      it "should return nil if there is no read port" do
        server = TcpipServer.new(8888,nil,nil,nil,'Burst')
        server.read.should be_nil
        server.disconnect
        sleep(0.2)
      end

      #~ it "should block if no data is available" do
        #~ server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        #~ lambda { server.read }.should raise_error
      #~ end

      it "should read from the client" do
        allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
        allow(System).to receive_message_chain(:instance, :acl).and_return(false)

        server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        server.connect
        sleep 0.2

        socket = TCPSocket.open("127.0.0.1",8889)
        socket.write("\x00\x01")
        sleep 0.2
        server.num_clients.should eql 1
        server.read_queue_size.should eql 1
        server.read.should be_a Packet
        server.disconnect
        sleep 0.2
        server.num_clients.should eql 0
        socket.close
        sleep(0.2)
      end

      it "should check the client against the ACL" do
        capture_io do |stdout|
          allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
          allow(System).to receive_message_chain(:instance, :acl).and_return(true)
          allow(System).to receive_message_chain(:instance, :acl, :allow_addr?).and_return(false)

          server = TcpipServer.new(nil,8889,nil,nil,'Burst')
          server.connect
          sleep 0.2
          socket = TCPSocket.open("127.0.0.1",8889)
          sleep 0.2
          server.num_clients.should eql 0
          socket.eof?.should be_truthy
          server.disconnect
          sleep 0.2
          socket.close
          sleep(0.2)

          stdout.string.should match /Tcpip server rejected connection/
        end
      end

      it "should log an error if the stream protocol can't disconnect" do
        capture_io do |stdout|
          allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
          allow(System).to receive_message_chain(:instance, :acl).and_return(false)
          allow_any_instance_of(BurstStreamProtocol).to receive(:read) { raise "Error" }
          allow_any_instance_of(BurstStreamProtocol).to receive(:disconnect) { raise "Error" }

          server = TcpipServer.new(nil,8889,nil,nil,'Burst')
          server.connect
          sleep 0.2
          socket = TCPSocket.open("127.0.0.1",8889)
          sleep 0.2
          server.disconnect
          sleep 0.2
          server.num_clients.should eql 0
          socket.close
          sleep(0.2)

          stdout.string.should match /Tcpip server read thread unexpectedly died/
        end
      end

      it "should log an error if the read thread dies" do
        capture_io do |stdout|
          allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
          allow(System).to receive_message_chain(:instance, :acl).and_return(false)
          allow_any_instance_of(BurstStreamProtocol).to receive(:read) { raise "Error" }

          server = TcpipServer.new(8888,8888,nil,nil,'Burst')
          server.connect
          sleep 0.2
          socket = TCPSocket.open("127.0.0.1",8888)
          socket.write("\x00\x01")
          sleep 0.2
          server.disconnect
          socket.close
          sleep(0.2)

          stdout.string.should match /Tcpip server read thread unexpectedly died/
        end
      end
    end

    describe "write" do
      it "should do nothing if there is no write port" do
        server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        expect { server.write(Packet.new('TGT','PKT')) }.to_not raise_error
      end

      it "should write to the client" do
        allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
        allow(System).to receive_message_chain(:instance, :acl).and_return(false)

        server = TcpipServer.new(8888,8889,nil,nil,'Burst')
        server.connect
        sleep 0.2

        socket = TCPSocket.open("127.0.0.1",8888)
        sleep 0.2
        server.num_clients.should eql 1
        packet = Packet.new("TGT","PKT")
        packet.buffer = "\x01\x02\x03\x04"
        server.write_queue_size.should eql 0
        server.write(packet)
        sleep 0.2
        data = socket.read_nonblock(packet.length)
        data.length.should eql 4
        server.disconnect
        sleep 0.2
        server.num_clients.should eql 0
        socket.close
        sleep(0.2)
      end

      it "should log an error if the write thread dies" do
        class MyTcpipServer3 < TcpipServer
          def write_thread_hook(packet)
            raise "Error"
          end
        end
        capture_io do |stdout|
          allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
          allow(System).to receive_message_chain(:instance, :acl).and_return(false)

          server = MyTcpipServer3.new(8888,nil,nil,nil,'Burst')
          server.connect
          sleep 0.2
          socket = TCPSocket.open("127.0.0.1",8888)
          sleep 0.2
          server.num_clients.should eql 1
          server.write(Packet.new("TGT","PKT"))
          sleep 0.2
          server.num_clients.should eql 0
          server.disconnect
          socket.close
          sleep(0.2)

          stdout.string.should match /Tcpip server write thread unexpectedly died/
        end
      end

      it "log an error if the client disconnects" do
        capture_io do |stdout|
          allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
          allow(System).to receive_message_chain(:instance, :acl).and_return(false)
          allow_any_instance_of(BurstStreamProtocol).to receive_message_chain(:stream, :write_socket, :recvfrom_nonblock) { raise Errno::ECONNRESET }
          allow_any_instance_of(BurstStreamProtocol).to receive_message_chain(:stream, :raw_logger_pair).and_return(nil)

          server = TcpipServer.new(8888,8889,nil,nil,'Burst')
          server.connect
          server.num_clients.should eql 0
          sleep 0.2
          socket = TCPSocket.open("127.0.0.1",8888)
          sleep 0.2
          server.num_clients.should eql 0
          server.disconnect
          socket.close
          sleep(0.2)

          stdout.string.should match /Tcpip server lost write connection/
        end
      end

      it "should log an error if the client disconnects" do
        capture_io do |stdout|
          allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
          allow(System).to receive_message_chain(:instance, :acl).and_return(false)
          allow_any_instance_of(BurstStreamProtocol).to receive(:write) { raise Errno::ECONNABORTED }

          server = TcpipServer.new(8888,8889,nil,nil,'Burst')
          server.connect
          sleep 0.5

          socket1 = TCPSocket.open("127.0.0.1",8888)
          socket2 = TCPSocket.open("127.0.0.1",8889)
          sleep 0.5
          server.num_clients.should eql 2
          packet = Packet.new("TGT","PKT")
          packet.buffer = "\x01\x02\x03\x04"
          server.write_queue_size.should eql 0
          server.write(packet)
          sleep 0.2
          server.num_clients.should eql 1
          server.disconnect
          socket1.close
          socket2.close
          sleep(0.2)

          stdout.string.should match /Tcpip server lost write connection/
        end
      end
    end

    describe "read_queue_size" do
      it "should return 0 if there is no read port" do
        server = TcpipServer.new(8888,nil,nil,nil,'Burst')
        server.read_queue_size.should eql 0
        server.disconnect
        sleep(0.2)
      end
    end

    describe "write_queue_size" do
      it "should return 0 if there is no write port" do
        server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        server.write_queue_size.should eql 0
        server.disconnect
        sleep(0.2)
      end
    end

  end
end

