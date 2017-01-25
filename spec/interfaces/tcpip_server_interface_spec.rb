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
      @server = double("TcpipServer")
      allow(@server).to receive(:raw_logger_pair=)
      expect(TcpipServer).to receive(:new) { @server }
    end

    describe "initialize" do
      it "initializes the instance variables" do
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect(i.name).to eql "TcpipServerInterface"
      end

      it "is not writeable if no write port given" do
        i = TcpipServerInterface.new('nil','8889','nil','5','burst')
        expect(i.write_allowed?).to be false
        expect(i.write_raw_allowed?).to be false
        expect(i.read_allowed?).to be true
      end

      it "is not readable if no read port given" do
        i = TcpipServerInterface.new('8888','nil','5','nil','burst')
        expect(i.write_allowed?).to be true
        expect(i.write_raw_allowed?).to be true
        expect(i.read_allowed?).to be false
      end
    end

    describe "read_data" do
      it "counts the packets received" do
        allow(@server).to receive(:connected?).and_return(true)
        allow(@server).to receive(:read) { Packet.new('','') }
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect(i.read_count).to eql 0
        i.read
        expect(i.read_count).to eql 1
        i.read
        expect(i.read_count).to eql 2
      end

      it "does not count nil packets" do
        allow(@server).to receive(:connected?).and_return(true)
        allow(@server).to receive(:read) { nil }
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
        expect(@server).to receive(:connected?).and_return(false)
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect { i.write(Packet.new('','')) }.to raise_error(/Interface not connected/)
      end

      it "counts the packets written" do
        allow(@server).to receive(:connected?).and_return(true)
        allow(@server).to receive(:write_raw).with(kind_of(String))
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect(i.write_count).to eql 0
        i.write(Packet.new('',''))
        expect(i.write_count).to eql 1
        i.write(Packet.new('',''))
        expect(i.write_count).to eql 2
      end

      it "handles server exceptions and disconnect" do
        allow(@server).to receive(:connected?).and_return(true)
        allow(@server).to receive(:write_raw).with(kind_of(String)).and_raise(RuntimeError.new("TEST"))
        expect(@server).to receive(:disconnect)
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect { i.write(Packet.new('','')) }.to raise_error("TEST")
      end
    end

    describe "write_raw" do
      it "complains if the server is not connected" do
        expect(@server).to receive(:connected?).and_return(false)
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect { i.write_raw(Packet.new('','')) }.to raise_error(/Interface not connected/)
      end

      it "counts the bytes written" do
        allow(@server).to receive(:connected?).and_return(true)
        allow(@server).to receive(:write_raw).with(kind_of(String))
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect(i.write_count).to eql 0
        expect(i.bytes_written).to eql 0
        i.write_raw("\x00\x01")
        expect(i.write_count).to eql 0
        expect(i.bytes_written).to eql 2
        i.write_raw("\x02")
        expect(i.write_count).to eql 0
        expect(i.bytes_written).to eql 3
      end

      it "handles server exceptions and disconnect" do
        allow(@server).to receive(:connected?).and_return(true)
        allow(@server).to receive(:write_raw).with(kind_of(String)).and_raise(RuntimeError.new("TEST"))
        expect(@server).to receive(:disconnect)
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        expect { i.write_raw('') }.to raise_error("TEST")
      end
    end

    describe "set_option" do
      it "sets the listen address for the tcpip_server" do
        expect(@server).to receive(:listen_address=).with('127.0.0.1')
        i = TcpipServerInterface.new('8888','8889','5','5','burst')
        i.set_option('LISTEN_ADDRESS', ['127.0.0.1'])
      end
    end

  end
end

