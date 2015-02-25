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

module Cosmos

  describe UdpInterface do
    describe "initialize" do
      it "initializes the instance variables" do
        i = UdpInterface.new('localhost','8888','8889','8890','127.0.0.1','64','5','5')
      end

      it "is not writeable if no write port given" do
        i = UdpInterface.new('localhost','nil','8889')
        expect(i.name).to eql "Cosmos::UdpInterface"
        expect(i.write_allowed?).to be_falsey
        expect(i.write_raw_allowed?).to be_falsey
        expect(i.read_allowed?).to be_truthy
      end

      it "is not readable if no read port given" do
        i = UdpInterface.new('localhost','8888','nil')
        expect(i.name).to eql "Cosmos::UdpInterface"
        expect(i.write_allowed?).to be_truthy
        expect(i.write_raw_allowed?).to be_truthy
        expect(i.read_allowed?).to be_falsey
      end
    end

    describe "connect, connected?, disconnect" do
      it "creates a UdpWriteSocket and UdpReadSocket if both given" do
        write = double("write")
        expect(write).to receive(:closed?).and_return(false)
        expect(write).to receive(:close)
        read = double("read")
        expect(read).to receive(:closed?).and_return(false)
        expect(read).to receive(:close)
        expect(UdpWriteSocket).to receive(:new).and_return(write)
        expect(UdpReadSocket).to receive(:new).and_return(read)
        i = UdpInterface.new('localhost','8888','8889')
        expect(i.connected?).to be_falsey
        i.connect
        expect(i.connected?).to be_truthy
        i.disconnect
        expect(i.connected?).to be_falsey
      end

      it "creates a UdpWriteSocket if write port given" do
        write = double("write")
        expect(write).to receive(:closed?).and_return(false)
        expect(write).to receive(:close)
        expect(UdpWriteSocket).to receive(:new).and_return(write)
        expect(UdpReadSocket).to_not receive(:new)
        i = UdpInterface.new('localhost','8888','nil')
        expect(i.connected?).to be_falsey
        i.connect
        expect(i.connected?).to be_truthy
        i.disconnect
        expect(i.connected?).to be_falsey
      end

      it "creates a UdpReadSocket if read port given" do
        read = double("read")
        expect(read).to receive(:closed?).and_return(false)
        expect(read).to receive(:close)
        expect(UdpWriteSocket).to_not receive(:new)
        expect(UdpReadSocket).to receive(:new).and_return(read)
        i = UdpInterface.new('localhost','nil','8889')
        expect(i.connected?).to be_falsey
        i.connect
        expect(i.connected?).to be_truthy
        i.disconnect
        expect(i.connected?).to be_falsey
      end
    end

    describe "disconnect" do
      it "rescues IOError from close" do
        write = double("write")
        expect(write).to receive(:closed?).and_return(false)
        expect(write).to receive(:close).and_raise(IOError)
        read = double("read")
        expect(read).to receive(:closed?).and_return(false)
        expect(read).to receive(:close).and_raise(IOError)
        expect(UdpWriteSocket).to receive(:new).and_return(write)
        expect(UdpReadSocket).to receive(:new).and_return(read)
        i = UdpInterface.new('localhost','8888','8889')
        expect(i.connected?).to be_falsey
        i.connect
        expect(i.connected?).to be_truthy
        i.disconnect
        expect(i.connected?).to be_falsey
      end
    end

    describe "read" do
      it "stops the read thread if no read port given" do
        i = UdpInterface.new('localhost','8888','nil')
        thread = Thread.new { i.read }
        sleep 0.1
        expect(thread.stop?).to be_truthy
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
        expect(thread.stop?).to be_truthy
        Cosmos.kill_thread(nil, thread)
      end

      it "counts the packets received" do
        read = double("read")
        allow(read).to receive(:read) { "\x00\x01\x02\x03" }
        expect(UdpReadSocket).to receive(:new).and_return(read)
        i = UdpInterface.new('localhost','nil','8889')
        i.connect
        expect(i.read_count).to eql 0
        expect(i.bytes_read).to eql 0
        i.read
        expect(i.read_count).to eql 1
        expect(i.bytes_read).to eql 4
        i.read
        expect(i.read_count).to eql 2
        expect(i.bytes_read).to eql 8
      end
    end

    describe "write, write_raw" do
      it "complains if write_dest not given" do
        i = UdpInterface.new('localhost','nil','8889')
        expect { i.write(Packet.new('','')) }.to raise_error(/read only/)
        expect { i.write_raw('') }.to raise_error(/read only/)
      end

      it "complains if the server is not connected" do
        i = UdpInterface.new('localhost','8888','nil')
        expect { i.write(Packet.new('','')) }.to raise_error(/Interface not connected/)
        expect { i.write_raw('') }.to raise_error(/Interface not connected/)
      end

      it "counts the packets written" do
        write = double("write")
        expect(UdpWriteSocket).to receive(:new).and_return(write)
        allow(write).to receive(:write)
        i = UdpInterface.new('localhost','8888','nil')
        i.connect
        expect(i.write_count).to eql 0
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\x01\x02\x03"
        i.write(pkt)
        expect(i.write_count).to eql 1
        expect(i.bytes_written).to eql 4
        i.write_raw(pkt.buffer)
        expect(i.write_count).to eql 2
        expect(i.bytes_written).to eql 8
      end
    end
  end
end

