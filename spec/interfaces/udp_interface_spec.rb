# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/udp_interface'
require 'cosmos/io/udp_sockets'

module Cosmos

  describe UdpInterface do
    describe "initialize" do
      it "initializes the instance variables" do
        i = UdpInterface.new('localhost','8888','8889','8890','127.0.0.1','64','5','5','127.0.0.1')
      end

      it "is not writeable if no write port given" do
        i = UdpInterface.new('localhost','nil','8889')
        expect(i.name).to eql "UdpInterface"
        expect(i.write_allowed?).to be false
        expect(i.write_raw_allowed?).to be false
        expect(i.read_allowed?).to be true
      end

      it "is not readable if no read port given" do
        i = UdpInterface.new('localhost','8888','nil')
        expect(i.name).to eql "UdpInterface"
        expect(i.write_allowed?).to be true
        expect(i.write_raw_allowed?).to be true
        expect(i.read_allowed?).to be false
      end
    end

    describe "connect, connected?, disconnect" do
      it "creates a UdpWriteSocket and UdpReadSocket if both given" do
        i = UdpInterface.new('localhost','8888','8889')
        expect(i.connected?).to be false
        i.connect
        expect(i.connected?).to be true
        expect(i.instance_variable_get(:@write_socket)).to_not be_nil
        expect(i.instance_variable_get(:@read_socket)).to_not be_nil
        i.disconnect
        expect(i.connected?).to be false
        expect(i.instance_variable_get(:@write_socket)).to be_nil
        expect(i.instance_variable_get(:@read_socket)).to be_nil
      end

      it "creates a UdpWriteSocket if write port given" do
        i = UdpInterface.new('localhost','8888','nil')
        expect(i.connected?).to be false
        i.connect
        expect(i.connected?).to be true
        expect(i.instance_variable_get(:@write_socket)).to_not be_nil
        expect(i.instance_variable_get(:@read_socket)).to be_nil
        i.disconnect
        expect(i.connected?).to be false
        expect(i.instance_variable_get(:@write_socket)).to be_nil
        expect(i.instance_variable_get(:@read_socket)).to be_nil
      end

      it "creates a UdpReadSocket if read port given" do
        i = UdpInterface.new('localhost','nil','8889')
        expect(i.connected?).to be false
        i.connect
        expect(i.connected?).to be true
        expect(i.instance_variable_get(:@write_socket)).to be_nil
        expect(i.instance_variable_get(:@read_socket)).to_not be_nil
        i.disconnect
        expect(i.connected?).to be false
        expect(i.instance_variable_get(:@write_socket)).to be_nil
        expect(i.instance_variable_get(:@read_socket)).to be_nil
      end
    end

    describe "read" do
      it "stops the read thread if no read port given" do
        i = UdpInterface.new('localhost','8888','nil')
        i.connect
        thread = Thread.new { i.read }
        sleep 0.1
        expect(thread.stop?).to be true
        Cosmos.kill_thread(nil, thread)
      end

      it "stops the read thread if there is an IOError" do
        read = double("read")
        allow(read).to receive(:read).and_raise(IOError)
        expect(UdpReadSocket).to receive(:new).and_return(read)
        i = UdpInterface.new('localhost','nil','8889')
        i.connect
        thread = Thread.new { i.read }
        sleep 0.1
        expect(thread.stop?).to be true
        Cosmos.kill_thread(nil, thread)
      end

      it "counts the packets received" do
        write = UdpWriteSocket.new('localhost', 8889)
        i = UdpInterface.new('localhost','nil','8889')
        i.connect
        expect(i.read_count).to eql 0
        expect(i.bytes_read).to eql 0
        packet = nil
        t = Thread.new { packet = i.read }
        write.write("\x00\x01\x02\x03")
        t.join
        expect(i.read_count).to eql 1
        expect(i.bytes_read).to eql 4
        expect(packet.buffer).to eql "\x00\x01\x02\x03"
        t = Thread.new { packet = i.read }
        write.write("\x04\x05\x06\x07")
        t.join
        expect(i.read_count).to eql 2
        expect(i.bytes_read).to eql 8
        expect(packet.buffer).to eql "\x04\x05\x06\x07"
        i.disconnect
        Cosmos.close_socket(write)
      end

      it "logs the raw data" do
        write = UdpWriteSocket.new('localhost', 8889)
        i = UdpInterface.new('localhost','nil','8889')
        i.connect
        expect(i.raw_logger_pair.read_logger.logging_enabled).to be false
        i.start_raw_logging
        expect(i.raw_logger_pair.read_logger.logging_enabled).to be true
        packet = nil
        t = Thread.new { packet = i.read }
        write.write("\x00\x01\x02\x03")
        t.join
        filename = i.raw_logger_pair.read_logger.filename
        i.stop_raw_logging
        expect(i.raw_logger_pair.read_logger.logging_enabled).to be false
        expect(File.read(filename)).to eq "\x00\x01\x02\x03"
        i.disconnect
        Cosmos.close_socket(write)
      end
    end

    describe "write" do
      it "complains if write_dest not given" do
        i = UdpInterface.new('localhost','nil','8889')
        expect { i.write(Packet.new('','')) }.to raise_error(/not connected for write/)
      end

      it "complains if the server is not connected" do
        i = UdpInterface.new('localhost','8888','nil')
        expect { i.write(Packet.new('','')) }.to raise_error(/Interface not connected/)
      end

      it "counts the packets and bytes written" do
        read = UdpReadSocket.new(8888, 'localhost')
        i = UdpInterface.new('localhost','8888','nil')
        i.connect
        expect(i.write_count).to eql 0
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\x01\x02\x03"
        packet = nil
        i.write(pkt)
        data = read.read
        expect(i.write_count).to eql 1
        expect(i.bytes_written).to eql 4
        expect(data).to eq "\x00\x01\x02\x03"
        i.disconnect
        Cosmos.close_socket(read)
      end

      it "logs the raw data" do
        read = UdpReadSocket.new(8888, 'localhost')
        i = UdpInterface.new('localhost','8888','nil')
        i.connect
        expect(i.raw_logger_pair.write_logger.logging_enabled).to be false
        i.start_raw_logging
        expect(i.raw_logger_pair.write_logger.logging_enabled).to be true
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\x01\x02\x03"
        packet = nil
        i.write(pkt)
        data = read.read
        filename = i.raw_logger_pair.write_logger.filename
        i.stop_raw_logging
        expect(i.raw_logger_pair.write_logger.logging_enabled).to be false
        expect(File.read(filename)).to eq "\x00\x01\x02\x03"
        i.disconnect
        Cosmos.close_socket(read)
      end
    end

    describe "write_raw" do
      it "complains if write_dest not given" do
        i = UdpInterface.new('localhost','nil','8889')
        expect { i.write_raw('') }.to raise_error(/not connected for write/)
      end

      it "complains if the server is not connected" do
        i = UdpInterface.new('localhost','8888','nil')
        expect { i.write_raw('') }.to raise_error(/Interface not connected/)
      end

      it "counts the bytes written" do
        read = UdpReadSocket.new(8888, 'localhost')
        i = UdpInterface.new('localhost','8888','nil')
        i.connect
        expect(i.write_count).to eql 0
        expect(i.bytes_written).to eql 0
        i.write_raw("\x04\x05\x06\x07")
        data = read.read
        expect(i.write_count).to eql 0
        expect(i.bytes_written).to eql 4
        expect(data).to eq "\x04\x05\x06\x07"
        i.disconnect
        Cosmos.close_socket(read)
      end

      it "logs the raw data" do
        read = UdpReadSocket.new(8888, 'localhost')
        i = UdpInterface.new('localhost','8888','nil')
        i.connect
        expect(i.raw_logger_pair.write_logger.logging_enabled).to be false
        i.start_raw_logging
        expect(i.raw_logger_pair.write_logger.logging_enabled).to be true
        i.write_raw("\x00\x01\x02\x03")
        data = read.read
        filename = i.raw_logger_pair.write_logger.filename
        i.stop_raw_logging
        expect(i.raw_logger_pair.write_logger.logging_enabled).to be false
        expect(File.read(filename)).to eq "\x00\x01\x02\x03"
        i.disconnect
        Cosmos.close_socket(read)
      end
    end
  end
end

