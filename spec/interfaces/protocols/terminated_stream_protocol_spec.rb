# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/streams/terminated_stream_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos

  describe TerminatedStreamProtocol do
    describe "initialize" do
      it "initializes attributes" do
        tsp = TerminatedStreamProtocol.new('0xABCD','0xABCD')
        expect(tsp.bytes_read).to eql 0
        expect(tsp.bytes_written).to eql 0
        expect(tsp.interface).to be_a Interface
        expect(tsp.stream).to be_nil
      end
    end

    $buffer = ''
    class TerminatedStream < Stream
      def connect; end
      def connected?; true; end
      def disconnect; end
      def read; $buffer; end
      def write(data); $buffer = data; end
    end
    before(:each) { $buffer = '' }

    describe "read" do
      context "when stripping termination characters" do
        it "handles no sync pattern" do
          interface = StreamInterface.new("Terminated",'','0xABCD',true)
          interface.instance_variable_get(:@stream_protocol).connect(TerminatedStream.new)
          $buffer = "\x00\x01\x02\xAB\xCD\x44\x02\x03"
          packet = interface.read
          expect(packet.buffer).to eql("\x00\x01\x02")
        end

        it "handles a sync pattern inside the packet" do
          interface = StreamInterface.new("Terminated",'','0xABCD',true,0,'DEAD')
          interface.instance_variable_get(:@stream_protocol).connect(TerminatedStream.new)
          $buffer = "\xDE\xAD\x00\x01\x02\xAB\xCD\x44\x02\x03"
          packet = interface.read
          expect(packet.buffer).to eql("\xDE\xAD\x00\x01\x02")
        end

        it "handles a sync pattern outside the packet" do
          interface = StreamInterface.new("Terminated",'','0xABCD',true,2,'DEAD')
          interface.instance_variable_get(:@stream_protocol).connect(TerminatedStream.new)
          $buffer = "\xDE\xAD\x00\x01\x02\xAB\xCD\x44\x02\x03"
          packet = interface.read
          expect(packet.buffer).to eql("\x00\x01\x02")
        end
      end

      context "when keeping termination characters" do
        it "handles no sync pattern" do
          interface = StreamInterface.new("Terminated",'','0xABCD',false)
          interface.instance_variable_get(:@stream_protocol).connect(TerminatedStream.new)
          $buffer = "\x00\x01\x02\xAB\xCD\x44\x02\x03"
          packet = interface.read
          expect(packet.buffer).to eql("\x00\x01\x02\xAB\xCD")
        end

        it "handles a sync pattern inside the packet" do
          interface = StreamInterface.new("Terminated",'','0xABCD',false,0,'DEAD')
          interface.instance_variable_get(:@stream_protocol).connect(TerminatedStream.new)
          $buffer = "\xDE\xAD\x00\x01\x02\xAB\xCD\x44\x02\x03"
          packet = interface.read
          expect(packet.buffer).to eql("\xDE\xAD\x00\x01\x02\xAB\xCD")
        end

        it "handles a sync pattern outside the packet" do
          interface = StreamInterface.new("Terminated",'','0xABCD',false,2,'DEAD')
          interface.instance_variable_get(:@stream_protocol).connect(TerminatedStream.new)
          $buffer = "\xDE\xAD\x00\x01\x02\xAB\xCD\x44\x02\x03"
          packet = interface.read
          expect(packet.buffer).to eql("\x00\x01\x02\xAB\xCD")
        end
      end
    end

    describe "write" do
      it "appends termination characters to the packet" do
        interface = StreamInterface.new("Terminated", '0xCDEF','')
        interface.instance_variable_get(:@stream_protocol).connect(TerminatedStream.new)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\x01\x02\x03"
        interface.write(pkt)
        expect($buffer).to eql("\x00\x01\x02\x03\xCD\xEF")
      end

      it "complains if the packet buffer contains the termination characters" do
        interface = StreamInterface.new("Terminated", '0xCDEF','')
        interface.instance_variable_get(:@stream_protocol).connect(TerminatedStream.new)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\xCD\xEF\x03"
        expect { interface.write(pkt) }.to raise_error("Packet contains termination characters!")
      end

      it "handles writing the sync field inside the packet" do
        interface = StreamInterface.new("Terminated", '0xCDEF','',true,0,'DEAD',true)
        interface.instance_variable_get(:@stream_protocol).connect(TerminatedStream.new)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\x01\x02\x03"
        interface.write(pkt)
        expect($buffer).to eql("\xDE\xAD\x02\x03\xCD\xEF")
      end

      it "handles writing the sync field outside the packet" do
        interface = StreamInterface.new("Terminated", '0xCDEF','',true,2,'DEAD',true)
        interface.instance_variable_get(:@stream_protocol).connect(TerminatedStream.new)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\x01\x02\x03"
        interface.write(pkt)
        expect($buffer).to eql("\xDE\xAD\x00\x01\x02\x03\xCD\xEF")
      end
    end
  end
end

