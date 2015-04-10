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
      it "initializes the instance variables" do
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
      end

      it "is not writeable if no write port given" do
        i = TcpipServerInterface.new('nil','8889','nil','5','burst')
        expect(i.name).to eql "Cosmos::TcpipServerInterface"
        expect(i.write_allowed?).to be false
        expect(i.write_raw_allowed?).to be false
        expect(i.read_allowed?).to be true
      end

      it "is not readable if no read port given" do
        i = TcpipServerInterface.new('8888','nil','5','nil','burst')
        expect(i.name).to eql "Cosmos::TcpipServerInterface"
        expect(i.write_allowed?).to be true
        expect(i.write_raw_allowed?).to be true
        expect(i.read_allowed?).to be false
      end
    end

    describe "connect, connected?, disconnect, bytes_read, bytes_written, num_clients, read_queue_size, write_queue_size" do
      it "calls forward to the TcpipServer" do
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
        expect(i.connected?).to be false
        i.connect
        expect(i.connected?).to be true
        i.disconnect
        expect(i.connected?).to be false
        i.bytes_read = 1000
        i.bytes_written = 2000
        expect(i.bytes_read).to eql 10
        expect(i.bytes_written).to eql 20
        expect(i.num_clients).to eql 30
        expect(i.read_queue_size).to eql 40
        expect(i.write_queue_size).to eql 50
      end
    end

    describe "read" do
      it "counts the packets received" do
        allow(@stream).to receive(:read) { Packet.new('','') }
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect(i.read_count).to eql 0
        i.read
        expect(i.read_count).to eql 1
        i.read
        expect(i.read_count).to eql 2
      end

      it "does not count nil packets" do
        allow(@stream).to receive(:read) { nil }
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect(i.read_count).to eql 0
        i.read
        expect(i.read_count).to eql 0
        i.read
        expect(i.read_count).to eql 0
      end
    end

    describe "write" do
      it "complains if the server is not connected" do
        expect(@stream).to receive(:connected?).and_return(false)
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect { i.write(Packet.new('','')) }.to raise_error(/Interface not connected/)
      end

      it "counts the packets written" do
        allow(@stream).to receive(:connected?).and_return(true)
        allow(@stream).to receive(:write).with(kind_of(Packet))
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect(i.write_count).to eql 0
        i.write(Packet.new('',''))
        expect(i.write_count).to eql 1
        i.write(Packet.new('',''))
        expect(i.write_count).to eql 2
      end

      it "handles server exceptions and disconnect" do
        allow(@stream).to receive(:connected?).and_return(true)
        allow(@stream).to receive(:write).with(kind_of(Packet)).and_raise(RuntimeError.new("TEST"))
        expect(@stream).to receive(:disconnect)
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect { i.write(Packet.new('','')) }.to raise_error("TEST")
      end
    end

    describe "write_raw" do
      it "complains if the server is not connected" do
        expect(@stream).to receive(:connected?).and_return(false)
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect { i.write_raw(Packet.new('','')) }.to raise_error(/Interface not connected/)
      end

      it "counts the packets written" do
        allow(@stream).to receive(:connected?).and_return(true)
        allow(@stream).to receive(:write_raw).with(kind_of(String))
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect(i.write_count).to eql 0
        i.write_raw('')
        expect(i.write_count).to eql 1
        i.write_raw('')
        expect(i.write_count).to eql 2
      end

      it "handles server exceptions and disconnect" do
        allow(@stream).to receive(:connected?).and_return(true)
        allow(@stream).to receive(:write_raw).with(kind_of(String)).and_raise(RuntimeError.new("TEST"))
        expect(@stream).to receive(:disconnect)
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect { i.write_raw('') }.to raise_error("TEST")
      end
    end

    describe "set_option" do
      it "sets the listen address for the tcpip_server" do
        expect(@stream).to receive(:listen_address=).with('127.0.0.1')
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        i.set_option('LISTEN_ADDRESS', ['127.0.0.1'])
      end
    end

  end
end

