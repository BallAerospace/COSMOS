# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
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
      it "should initialize the instance variables" do
        i = UdpInterface.new('localhost','8888','8889','8890','127.0.0.1','64','5','5')
      end

      it "should not be writeable if no write port given" do
        i = UdpInterface.new('localhost','nil','8889')
        i.name.should eql "Cosmos::UdpInterface"
        i.write_allowed?.should be_falsey
        i.write_raw_allowed?.should be_falsey
        i.read_allowed?.should be_truthy
      end

      it "should not be readable if no read port given" do
        i = UdpInterface.new('localhost','8888','nil')
        i.name.should eql "Cosmos::UdpInterface"
        i.write_allowed?.should be_truthy
        i.write_raw_allowed?.should be_truthy
        i.read_allowed?.should be_falsey
      end
    end

    describe "connect, connected?, disconnect" do
      it "should create a UdpWriteSocket and UdpReadSocket if both given" do
        write = double("write")
        expect(write).to receive(:closed?).and_return(false)
        expect(write).to receive(:close)
        read = double("read")
        expect(read).to receive(:closed?).and_return(false)
        expect(read).to receive(:close)
        expect(UdpWriteSocket).to receive(:new).and_return(write)
        expect(UdpReadSocket).to receive(:new).and_return(read)
        i = UdpInterface.new('localhost','8888','8889')
        i.connected?.should be_falsey
        i.connect
        i.connected?.should be_truthy
        i.disconnect
        i.connected?.should be_falsey
      end

      it "should create a UdpWriteSocket if write port given" do
        write = double("write")
        expect(write).to receive(:closed?).and_return(false)
        expect(write).to receive(:close)
        expect(UdpWriteSocket).to receive(:new).and_return(write)
        expect(UdpReadSocket).to_not receive(:new)
        i = UdpInterface.new('localhost','8888','nil')
        i.connected?.should be_falsey
        i.connect
        i.connected?.should be_truthy
        i.disconnect
        i.connected?.should be_falsey
      end

      it "should create a UdpReadSocket if read port given" do
        read = double("read")
        expect(read).to receive(:closed?).and_return(false)
        expect(read).to receive(:close)
        expect(UdpWriteSocket).to_not receive(:new)
        expect(UdpReadSocket).to receive(:new).and_return(read)
        i = UdpInterface.new('localhost','nil','8889')
        i.connected?.should be_falsey
        i.connect
        i.connected?.should be_truthy
        i.disconnect
        i.connected?.should be_falsey
      end
    end

    describe "disconnect" do
      it "should rescue IOError from close" do
        write = double("write")
        expect(write).to receive(:closed?).and_return(false)
        expect(write).to receive(:close).and_raise(IOError)
        read = double("read")
        expect(read).to receive(:closed?).and_return(false)
        expect(read).to receive(:close).and_raise(IOError)
        expect(UdpWriteSocket).to receive(:new).and_return(write)
        expect(UdpReadSocket).to receive(:new).and_return(read)
        i = UdpInterface.new('localhost','8888','8889')
        i.connected?.should be_falsey
        i.connect
        i.connected?.should be_truthy
        i.disconnect
        i.connected?.should be_falsey
      end
    end

    describe "read" do
      it "should stop the read thread if no read port given" do
        i = UdpInterface.new('localhost','8888','nil')
        thread = Thread.new { i.read }
        sleep 0.1
        thread.stop?.should be_truthy
        thread.kill
      end

      it "should stop the read thread if there is an IOError" do
        read = double("read")
        allow(read).to receive(:read).and_raise(IOError)
        expect(UdpReadSocket).to receive(:new).and_return(read)
        i = UdpInterface.new('localhost','nil','8889')
        i.connect
        thread = Thread.new { i.read }
        sleep 0.1
        thread.stop?.should be_truthy
        thread.kill
      end

      it "should count the packets received" do
        read = double("read")
        allow(read).to receive(:read) { "\x00\x01\x02\x03" }
        expect(UdpReadSocket).to receive(:new).and_return(read)
        i = UdpInterface.new('localhost','nil','8889')
        i.connect
        i.read_count.should eql 0
        i.bytes_read.should eql 0
        i.read
        i.read_count.should eql 1
        i.bytes_read.should eql 4
        i.read
        i.read_count.should eql 2
        i.bytes_read.should eql 8
      end
    end

    describe "write, write_raw" do
      it "should complain if write_dest not given" do
        i = UdpInterface.new('localhost','nil','8889')
        expect { i.write(Packet.new('','')) }.to raise_error(/read only/)
        expect { i.write_raw('') }.to raise_error(/read only/)
      end

      it "should complain if the server is not connected" do
        i = UdpInterface.new('localhost','8888','nil')
        expect { i.write(Packet.new('','')) }.to raise_error(/Interface not connected/)
        expect { i.write_raw('') }.to raise_error(/Interface not connected/)
      end

      it "should count the packets written" do
        write = double("write")
        expect(UdpWriteSocket).to receive(:new).and_return(write)
        allow(write).to receive(:write)
        i = UdpInterface.new('localhost','8888','nil')
        i.connect
        i.write_count.should eql 0
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\x01\x02\x03"
        i.write(pkt)
        i.write_count.should eql 1
        i.bytes_written.should eql 4
        i.write_raw(pkt.buffer)
        i.write_count.should eql 2
        i.bytes_written.should eql 8
      end
    end
  end
end

