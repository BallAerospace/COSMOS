# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/tcpip_server_interface'

module Cosmos

  describe TcpipServerInterface do
    before(:each) do
      @stream = double("stream")
      expect(@stream).to receive(:interface=)
      expect(TcpipServer).to receive(:new) { @stream }
    end

    describe "initialize" do
      it "should initialize the instance variables" do
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
      end

      it "should not be writeable if no write port given" do
        i = TcpipServerInterface.new('nil','8889','nil','5','burst')
        i.name.should eql "Cosmos::TcpipServerInterface"
        i.write_allowed?.should be_falsey
        i.write_raw_allowed?.should be_falsey
        i.read_allowed?.should be_truthy
      end

      it "should not be readable if no read port given" do
        i = TcpipServerInterface.new('8888','nil','5','nil','burst')
        i.name.should eql "Cosmos::TcpipServerInterface"
        i.write_allowed?.should be_truthy
        i.write_raw_allowed?.should be_truthy
        i.read_allowed?.should be_falsey
      end
    end

    describe "connect, connected?, disconnect, bytes_read, bytes_written, num_clients, read_queue_size, write_queue_size" do
      it "should call forward to the TcpipServer" do
        expect(@stream).to receive(:connected?).and_return(false, true, false)
        expect(@stream).to receive(:connect)
        expect(@stream).to receive(:disconnect)
        expect(@stream).to receive(:bytes_read=)
        expect(@stream).to receive(:bytes_written=)
        expect(@stream).to receive(:bytes_read).and_return(10)
        expect(@stream).to receive(:bytes_written).and_return(20)
        expect(@stream).to receive(:num_clients).and_return(30)
        expect(@stream).to receive(:read_queue_size).and_return(40)
        expect(@stream).to receive(:write_queue_size).and_return(50)
        expect(@stream).to receive(:raw_logger_pair=) { nil }
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        i.connected?.should be_falsey
        i.connect
        i.connected?.should be_truthy
        i.disconnect
        i.connected?.should be_falsey
        i.bytes_read = 1000
        i.bytes_written = 2000
        i.bytes_read.should eql 10
        i.bytes_written.should eql 20
        i.num_clients.should eql 30
        i.read_queue_size.should eql 40
        i.write_queue_size.should eql 50
      end
    end

    describe "read" do
      it "should count the packets received" do
        allow(@stream).to receive(:read) { Packet.new('','') }
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        i.read_count.should eql 0
        i.read
        i.read_count.should eql 1
        i.read
        i.read_count.should eql 2
      end

      it "should not count nil packets" do
        allow(@stream).to receive(:read) { nil }
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        i.read_count.should eql 0
        i.read
        i.read_count.should eql 0
        i.read
        i.read_count.should eql 0
      end
    end

    describe "write" do
      it "should complain if the server is not connected" do
        expect(@stream).to receive(:connected?).and_return(false)
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect { i.write(Packet.new('','')) }.to raise_error(/Interface not connected/)
      end

      it "should count the packets written" do
        allow(@stream).to receive(:connected?).and_return(true)
        allow(@stream).to receive(:write).with(kind_of(Packet))
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        i.write_count.should eql 0
        i.write(Packet.new('',''))
        i.write_count.should eql 1
        i.write(Packet.new('',''))
        i.write_count.should eql 2
      end

      it "should handle server exceptions and disconnect" do
        allow(@stream).to receive(:connected?).and_return(true)
        allow(@stream).to receive(:write).with(kind_of(Packet)).and_raise(RuntimeError.new("TEST"))
        expect(@stream).to receive(:disconnect)
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect { i.write(Packet.new('','')) }.to raise_error("TEST")
      end
    end

    describe "write_raw" do
      it "should complain if the server is not connected" do
        expect(@stream).to receive(:connected?).and_return(false)
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect { i.write_raw(Packet.new('','')) }.to raise_error(/Interface not connected/)
      end

      it "should count the packets written" do
        allow(@stream).to receive(:connected?).and_return(true)
        allow(@stream).to receive(:write_raw).with(kind_of(String))
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        i.write_count.should eql 0
        i.write_raw('')
        i.write_count.should eql 1
        i.write_raw('')
        i.write_count.should eql 2
      end

      it "should handle server exceptions and disconnect" do
        allow(@stream).to receive(:connected?).and_return(true)
        allow(@stream).to receive(:write_raw).with(kind_of(String)).and_raise(RuntimeError.new("TEST"))
        expect(@stream).to receive(:disconnect)
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect { i.write_raw('') }.to raise_error("TEST")
      end
    end
  end
end

