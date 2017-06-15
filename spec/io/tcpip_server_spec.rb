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
require 'cosmos/interfaces/protocols/burst_stream_protocol'

module Cosmos
  describe TcpipServer do
    describe "instance" do
      it "rescues bad stream protocol names" do
        expect { TcpipServer.new(8888,8889,nil,nil,'Unknown') }.to raise_error(/Unable to require/)
      end
    end

    describe "connect, connected?, disconnect" do
      it "only allows connect once" do
        server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        server.connect
        sleep 0.2
        expect { server.connect }.to raise_error(/Error binding/)
        server.disconnect
        sleep(0.2)
      end

      it "creates a listener thread for the read port" do
        server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        server.connect
        sleep 0.5
        expect(server.connected?).to be true
        # 2 because the RSpec main thread plus the listener
        expect(Thread.list.length).to eql 2
        socket = TCPSocket.open("127.0.0.1",8889)
        sleep 0.2
        expect(server.num_clients).to eql 1
        server.disconnect
        sleep 0.2
        expect(server.connected?).to be false
        expect(Thread.list.length).to eql 1
      end

      it "creates a listener thread for the write port" do
        server = TcpipServer.new(8888,nil,nil,nil,'Burst')
        server.connect
        sleep 0.5
        expect(server.connected?).to be true
        # 3 because the RSpec main thread plus the listener
        # plus one for the write thread
        expect(Thread.list.length).to eql 3
        socket = TCPSocket.open("127.0.0.1",8888)
        sleep 0.2
        expect(server.num_clients).to eql 1
        server.disconnect
        sleep 0.2
        expect(server.connected?).to be false
        expect(Thread.list.length).to eql 1
      end

      it "creates a single listener thread if read = write port" do
        server = TcpipServer.new(8888,8888,nil,nil,'Burst')
        server.connect
        sleep 0.5
        expect(server.connected?).to be true
        # 3 because the RSpec main thread plus the listener
        # plus one for the write thread
        expect(Thread.list.length).to eql 3
        socket = TCPSocket.open("127.0.0.1",8888)
        sleep 0.2
        expect(server.num_clients).to eql 1
        server.disconnect
        sleep 0.2
        expect(server.connected?).to be false
        expect(Thread.list.length).to eql 1
      end

      it "creates two listener threads if read != write port" do
        server = TcpipServer.new(8888,8889,nil,nil,'Burst')
        server.connect
        sleep 0.5
        expect(server.connected?).to be true
        # 4 because the RSpec main thread plus the two listeners
        # plus one for the write thread
        expect(Thread.list.length).to eql 4
        server.disconnect
        sleep 0.2
        expect(server.connected?).to be false
        expect(Thread.list.length).to eql 1
      end

      it "logs an error if the listener thread dies" do
        capture_io do |stdout|
          system = double("System")
          allow(system).to receive(:use_dns) { raise "Error" }
          allow(System).to receive(:instance).and_return(system)

          server = TcpipServer.new(8888,8888,nil,nil,'Burst')
          server.connect
          sleep 0.5
          socket = TCPSocket.open("127.0.0.1",8888)
          sleep 0.2
          server.disconnect
          socket.close
          sleep(0.2)

          expect(stdout.string).to match /Tcpip server listen thread unexpectedly died/
        end
      end
    end

    describe "read" do
      it "returns nil if there is no read port" do
        server = TcpipServer.new(8888,nil,nil,nil,'Burst')
        expect(server.read).to be_nil
        server.disconnect
        sleep(0.2)
      end

      #~ it "should block if no data is available" do
        #~ server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        #~ lambda { server.read }.should raise_error
      #~ end

      it "reads from all connected clients on the read port" do
        allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
        allow(System).to receive_message_chain(:instance, :acl).and_return(false)

        server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        server.connect
        sleep 0.5

        socket = TCPSocket.open("127.0.0.1",8889)
        socket.write("\x00\x01")
        sleep 0.2
        expect(server.num_clients).to eql 1
        expect(server.read_queue_size).to eql 1
        socket2 = TCPSocket.open("127.0.0.1",8889)
        socket2.write("\x02\x03")
        sleep 0.2
        expect(server.num_clients).to eql 2
        expect(server.read_queue_size).to eql 2
        pkt = server.read
        expect(pkt.buffer).to eq "\x00\x01"
        pkt = server.read
        expect(pkt.buffer).to eq "\x02\x03"
        socket.close
        sleep 0.2
        expect(server.num_clients).to eql 1
        server.disconnect
        sleep 0.2
        expect(server.num_clients).to eql 0
        socket2.close
        sleep(0.2)
      end

      it "checks the client against the ACL" do
        capture_io do |stdout|
          allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
          allow(System).to receive_message_chain(:instance, :acl).and_return(true)
          allow(System).to receive_message_chain(:instance, :acl, :allow_addr?).and_return(false)

          server = TcpipServer.new(nil,8889,nil,nil,'Burst')
          server.connect
          sleep 0.5
          socket = TCPSocket.open("127.0.0.1",8889)
          sleep 0.2
          expect(server.num_clients).to eql 0
          expect(socket.eof?).to be true
          server.disconnect
          sleep 0.2
          socket.close
          sleep(0.2)

          expect(stdout.string).to match /Tcpip server rejected connection/
        end
      end

      it "logs an error if the stream protocol can't disconnect" do
        capture_io do |stdout|
          allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
          allow(System).to receive_message_chain(:instance, :acl).and_return(false)
          allow_any_instance_of(BurstStreamProtocol).to receive(:read) { raise "Error" }
          allow_any_instance_of(BurstStreamProtocol).to receive(:disconnect) { raise "Error" }

          server = TcpipServer.new(nil,8889,nil,nil,'Burst')
          server.connect
          sleep 0.5
          socket = TCPSocket.open("127.0.0.1",8889)
          sleep 0.2
          server.disconnect
          sleep 0.2
          expect(server.num_clients).to eql 0
          socket.close
          sleep(0.2)

          expect(stdout.string).to match /Tcpip server read thread unexpectedly died/
        end
      end

      it "logs an error if the read thread dies" do
        capture_io do |stdout|
          allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
          allow(System).to receive_message_chain(:instance, :acl).and_return(false)
          allow_any_instance_of(BurstStreamProtocol).to receive(:read) { raise "Error" }

          server = TcpipServer.new(8888,8888,nil,nil,'Burst')
          server.connect
          sleep 0.5
          socket = TCPSocket.open("127.0.0.1",8888)
          socket.write("\x00\x01")
          sleep 0.2
          server.disconnect
          socket.close
          sleep(0.2)

          expect(stdout.string).to match /Tcpip server read thread unexpectedly died/
        end
      end
    end

    describe "write" do
      it "does nothing if there is no write port" do
        server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        expect { server.write(Packet.new('TGT','PKT')) }.to_not raise_error
      end

      it "writes to all connected clients" do
        allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
        allow(System).to receive_message_chain(:instance, :acl).and_return(false)

        server = TcpipServer.new(8888,nil,nil,nil,'Burst')
        server.connect
        sleep 0.5

        socket = TCPSocket.open("127.0.0.1",8888)
        sleep 0.2
        expect(server.num_clients).to eql 1
        socket2 = TCPSocket.open("127.0.0.1",8888)
        sleep 0.2
        expect(server.num_clients).to eql 2
        packet = Packet.new("TGT","PKT")
        packet.buffer = "\x01\x02\x03\x04"
        expect(server.write_queue_size).to eql 0
        server.write(packet)
        sleep 0.2
        data = socket.read(packet.length)
        expect(data).to eql "\x01\x02\x03\x04"
        data = socket2.read(packet.length)
        expect(data).to eql "\x01\x02\x03\x04"
        socket.close
        sleep 0.5
        expect(server.num_clients).to eql 1
        server.disconnect
        sleep 0.2
        expect(server.num_clients).to eql 0
        socket2.close
        sleep(0.2)
      end

      it "handles errors during the interface write" do
        allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
        allow(System).to receive_message_chain(:instance, :acl).and_return(false)
        class Interface
          def pre_write_packet(packet)
            raise "pre_write_packet error"
          end
        end

        server = TcpipServer.new(8888,8888,nil,nil,'Burst')
        server.connect
        sleep 0.5
        expect(Thread.list.length).to eql 3
        socket = TCPSocket.open("127.0.0.1",8888)
        sleep 0.2
        expect(server.num_clients).to eql 1
        packet = Packet.new("TGT","PKT")
        packet.buffer = "\x01\x02\x03\x04"
        server.write(packet)
        sleep 0.2
        # Error causes client to disconnect
        expect(server.num_clients).to eql 0
        server.disconnect
        sleep(0.2)
        class Interface
          def pre_write_packet(packet); packet; end
        end
      end

      it "logs an error if the write thread dies" do
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
          sleep 0.5
          socket = TCPSocket.open("127.0.0.1",8888)
          sleep 0.2
          expect(server.num_clients).to eql 1
          server.write(Packet.new("TGT","PKT"))
          sleep 0.2
          expect(server.num_clients).to eql 0
          server.disconnect
          socket.close
          sleep(0.2)

          expect(stdout.string).to match /Tcpip server write thread unexpectedly died/
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
          expect(server.num_clients).to eql 0
          sleep 0.5
          socket = TCPSocket.open("127.0.0.1",8888)
          sleep 0.2
          expect(server.num_clients).to eql 0
          server.disconnect
          socket.close
          sleep(0.2)

          expect(stdout.string).to match /Tcpip server lost write connection/
        end
      end

      it "logs an error if the client disconnects" do
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
          expect(server.num_clients).to eql 2
          packet = Packet.new("TGT","PKT")
          packet.buffer = "\x01\x02\x03\x04"
          expect(server.write_queue_size).to eql 0
          server.write(packet)
          sleep 0.2
          expect(server.num_clients).to eql 1
          server.disconnect
          socket1.close
          socket2.close
          sleep(0.2)

          expect(stdout.string).to match /Tcpip server lost write connection/
        end
      end
    end

    describe "write_raw" do
      it "does nothing if there is no write port" do
        server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        expect { server.write_raw(Packet.new('TGT','PKT')) }.to_not raise_error
      end

      it "writes to the client" do
        allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
        allow(System).to receive_message_chain(:instance, :acl).and_return(false)

        server = TcpipServer.new(8888,8889,nil,nil,'Burst')
        server.connect
        sleep 0.5

        socket = TCPSocket.open("127.0.0.1",8888)
        sleep 0.2
        expect(server.num_clients).to eql 1
        server.write_raw("\x01\x02\x03\x04")
        sleep 0.2
        data = socket.read(4)
        expect(data).to eql "\x01\x02\x03\x04"
        server.disconnect
        sleep 0.2
        expect(server.num_clients).to eql 0
        socket.close
        sleep(0.2)
      end
    end

    describe "read_queue_size" do
      it "returns 0 if there is no read port" do
        server = TcpipServer.new(8888,nil,nil,nil,'Burst')
        expect(server.read_queue_size).to eql 0
        server.disconnect
        sleep(0.2)
      end
    end

    describe "write_queue_size" do
      it "returns 0 if there is no write port" do
        server = TcpipServer.new(nil,8889,nil,nil,'Burst')
        expect(server.write_queue_size).to eql 0
        server.disconnect
        sleep(0.2)
      end
    end

    # server = TcpipServer.new(8888,nil,nil,nil,'Burst')
    # server.connect
    # sleep 0.5
    # socket = TCPSocket.open("127.0.0.1",8888)
    # sleep 0.2
    # expect(server.num_clients).to eql 1
    # socket2 = TCPSocket.open("127.0.0.1",8888)
    # sleep 0.2
    # expect(server.num_clients).to eql 2
    # packet = Packet.new("TGT","PKT")
    # packet.buffer = "\x01\x02\x03\x04"
    # expect(server.write_queue_size).to eql 0
    # server.write(packet)
    # sleep 0.2
    # data = socket.read(packet.length)
    # expect(data).to eql "\x01\x02\x03\x04"
    # data = socket2.read(packet.length)
    # expect(data).to eql "\x01\x02\x03\x04"
    # socket.close
    # sleep 0.5
    # expect(server.num_clients).to eql 1
    # server.disconnect
    # sleep 0.2
    # expect(server.num_clients).to eql 0
    # socket2.close
    # sleep(0.2)

    describe "start_raw_logging" do
      it "enables raw logging on all clients" do
        allow(System).to receive_message_chain(:instance, :use_dns).and_return(false)
        allow(System).to receive_message_chain(:instance, :acl).and_return(false)
        log_dir = File.join(Cosmos::USERPATH, 'outputs', 'logs')
        allow(System).to receive_message_chain(:instance, :paths).and_return({'LOGS'=>log_dir})

        read_loggers = []
        write_loggers = []
        server = TcpipServer.new(8888,8888,nil,nil,'Burst')
        server.raw_logger_pair = RawLoggerPair.new('test')
        server.read_connection_callback = Proc.new do |interface|
          read_loggers << interface.raw_logger_pair.read_logger
        end
        server.write_connection_callback = Proc.new do |interface|
          write_loggers << interface.raw_logger_pair.write_logger
        end
        server.connect
        server.start_raw_logging
        sleep 0.5

        socket = TCPSocket.open("127.0.0.1",8888)
        socket.write("\x00\x01")
        sleep 0.2
        expect(server.num_clients).to eql 1
        expect(server.read_queue_size).to eql 1
        socket2 = TCPSocket.open("127.0.0.1",8888)
        socket2.write("\x02\x03")
        sleep 0.2
        expect(server.num_clients).to eql 2
        expect(server.read_queue_size).to eql 2
        packet = Packet.new("TGT","PKT",:BIG_ENDIAN,nil,"\x05\x06\x07\x08")
        expect(server.write_queue_size).to eql 0
        server.write(packet)
        expect(server.write_queue_size).to eql 1
        sleep 0.1
        pkt = server.read
        expect(pkt.buffer).to eq "\x00\x01"
        pkt = server.read
        expect(pkt.buffer).to eq "\x02\x03"
        data = socket.read(packet.length)
        expect(data).to eql "\x05\x06\x07\x08"
        data = socket2.read(packet.length)
        expect(data).to eql "\x05\x06\x07\x08"

        # Capture the logger filenames before we close the logs and they go nil
        read_log_filenames = read_loggers.collect {|logger| logger.filename }
        write_log_filenames = write_loggers.collect {|logger| logger.filename }
        # Close the packet logs so they are written out
        server.stop_raw_logging
        # Try writing more and ensure it doesn't get in the log
        socket.write("\x09\x0a")
        sleep 0.1
        socket2.write("\x0b\x0c")
        sleep 0.1
        pkt = server.read
        expect(pkt.buffer).to eq "\x09\x0a"
        pkt = server.read
        expect(pkt.buffer).to eq "\x0b\x0c"
        expect(File.read(read_log_filenames[0])).to eq "\x00\x01"
        expect(File.read(read_log_filenames[1])).to eq "\x02\x03"
        expect(File.read(write_log_filenames[0])).to eq "\x05\x06\x07\x08"
        expect(File.read(write_log_filenames[1])).to eq "\x05\x06\x07\x08"

        # Ensure we can restart logging on exsting interfaces
        #
        # Add additional delay to push us past 1s since we started logging
        # (time starts from the last write) so we'll get a new log file
        sleep 1
        server.start_raw_logging
        packet.buffer = "\xAA\xBB\xCC\xDD"
        server.write(packet)
        sleep 0.1
        data = socket.read(packet.length)
        expect(data).to eql "\xAA\xBB\xCC\xDD"
        data = socket2.read(packet.length)
        expect(data).to eql "\xAA\xBB\xCC\xDD"
        # Capture the logger filenames before we close the logs and they go nil
        read_log_filenames = read_loggers.collect {|logger| logger.filename }
        write_log_filenames = write_loggers.collect {|logger| logger.filename }
        # Close the packet logs so they are written out
        server.stop_raw_logging
        expect(File.read(write_log_filenames[0])).to eq "\xAA\xBB\xCC\xDD"
        expect(File.read(write_log_filenames[1])).to eq "\xAA\xBB\xCC\xDD"

        socket.close
        sleep 0.2
        expect(server.num_clients).to eql 1
        server.disconnect
        sleep 0.2
        expect(server.num_clients).to eql 0
        socket2.close
        sleep(0.2)
      end
    end
  end
end
