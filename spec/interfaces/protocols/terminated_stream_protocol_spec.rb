# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/protocols/terminated_stream_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos
  describe TerminatedStreamProtocol do
    class TerminatedStream < Stream
      def connect; end
      def connected?; true; end
      def disconnect; end
      def read; $buffer; end
      def write(data); $buffer = data; end
    end

    before(:each) do
      @interface = StreamInterface.new
      allow(@interface).to receive(:connected?) { true }
      $buffer = ''
    end

    describe "initialize" do
      it "initializes attributes" do
        @interface.add_protocol(TerminatedStreamProtocol, ['0xABCD','0xABCD'], :READ_WRITE)
        expect(@interface.read_protocols[0].instance_variable_get(:@data)).to eq ''
      end
    end

    describe "read" do
      it "handles multiple reads" do
        $index = 0
        class MultiTerminatedStream < TerminatedStream
          def read
            case $index
            when 0
              $index += 1
              "\x01\x02"
            when 1
              $index += 1
              "\xAB"
            when 2
              $index += 1
              "\xCD"
            end
          end
        end

        @interface.instance_variable_set(:@stream, MultiTerminatedStream.new)
        @interface.add_protocol(TerminatedStreamProtocol, ['', '0xABCD', true], :READ_WRITE)
        packet = @interface.read
        expect(packet.buffer).to eql("\x01\x02")
      end

      context "when stripping termination characters" do
        it "handles empty packets" do
          @interface.instance_variable_set(:@stream, TerminatedStream.new)
          @interface.add_protocol(TerminatedStreamProtocol, ['', '0xABCD', true], :READ_WRITE)
          $buffer = "\xAB\xCD\x01\x02\xAB\xCD"
          packet = @interface.read
          expect(packet.buffer.length).to eql 0
          packet = @interface.read
          expect(packet.buffer).to eql("\x01\x02")
        end

        it "handles no sync pattern" do
          @interface.instance_variable_set(:@stream, TerminatedStream.new)
          @interface.add_protocol(TerminatedStreamProtocol, ['', '0xABCD', true], :READ_WRITE)
          $buffer = "\x00\x01\x02\xAB\xCD\x44\x02\x03"
          packet = @interface.read
          expect(packet.buffer).to eql("\x00\x01\x02")
        end

        it "handles a sync pattern inside the packet" do
          @interface.instance_variable_set(:@stream, TerminatedStream.new)
          @interface.add_protocol(TerminatedStreamProtocol, ['', '0xABCD', true, 0, 'DEAD'], :READ_WRITE)
          $buffer = "\xDE\xAD\x00\x01\x02\xAB\xCD\x44\x02\x03"
          packet = @interface.read
          expect(packet.buffer).to eql("\xDE\xAD\x00\x01\x02")
        end

        it "handles a sync pattern outside the packet" do
          @interface.instance_variable_set(:@stream, TerminatedStream.new)
          @interface.add_protocol(TerminatedStreamProtocol, ['', '0xABCD', true, 2, 'DEAD'], :READ_WRITE)
          $buffer = "\xDE\xAD\x00\x01\x02\xAB\xCD\x44\x02\x03"
          packet = @interface.read
          expect(packet.buffer).to eql("\x00\x01\x02")
        end
      end

      context "when keeping termination characters" do
        it "handles empty packets" do
          @interface.instance_variable_set(:@stream, TerminatedStream.new)
          @interface.add_protocol(TerminatedStreamProtocol, ['', '0xABCD', false], :READ_WRITE)
          $buffer = "\xAB\xCD\x01\x02\xAB\xCD"
          packet = @interface.read
          expect(packet.buffer).to eql("\xAB\xCD")
          packet = @interface.read
          expect(packet.buffer).to eql("\x01\x02\xAB\xCD")
        end

        it "handles no sync pattern" do
          @interface.instance_variable_set(:@stream, TerminatedStream.new)
          @interface.add_protocol(TerminatedStreamProtocol, ['', '0xABCD', false], :READ_WRITE)
          $buffer = "\x00\x01\x02\xAB\xCD\x44\x02\x03"
          packet = @interface.read
          expect(packet.buffer).to eql("\x00\x01\x02\xAB\xCD")
        end

        it "handles a sync pattern inside the packet" do
          @interface.instance_variable_set(:@stream, TerminatedStream.new)
          @interface.add_protocol(TerminatedStreamProtocol, ['','0xABCD',false,0,'DEAD'], :READ_WRITE)
          $buffer = "\xDE\xAD\x00\x01\x02\xAB\xCD\x44\x02\x03"
          packet = @interface.read
          expect(packet.buffer).to eql("\xDE\xAD\x00\x01\x02\xAB\xCD")
        end

        it "handles a sync pattern outside the packet" do
          @interface.instance_variable_set(:@stream, TerminatedStream.new)
          @interface.add_protocol(TerminatedStreamProtocol, ['','0xABCD',false,2,'DEAD'], :READ_WRITE)
          $buffer = "\xDE\xAD\x00\x01\x02\xAB\xCD\x44\x02\x03"
          packet = @interface.read
          expect(packet.buffer).to eql("\x00\x01\x02\xAB\xCD")
        end
      end
    end

    describe "write" do
      it "appends termination characters to the packet" do
        @interface.instance_variable_set(:@stream, TerminatedStream.new)
        @interface.add_protocol(TerminatedStreamProtocol, ['0xCDEF',''], :READ_WRITE)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\x01\x02\x03"
        @interface.write(pkt)
        expect($buffer).to eql("\x00\x01\x02\x03\xCD\xEF")
      end

      it "complains if the packet buffer contains the termination characters" do
        @interface.instance_variable_set(:@stream, TerminatedStream.new)
        @interface.add_protocol(TerminatedStreamProtocol, ['0xCDEF',''], :READ_WRITE)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\xCD\xEF\x03"
        expect { @interface.write(pkt) }.to raise_error("Packet contains termination characters!")
      end

      it "handles writing the sync field inside the packet" do
        @interface.instance_variable_set(:@stream, TerminatedStream.new)
        @interface.add_protocol(TerminatedStreamProtocol, ['0xCDEF','',true,0,'DEAD',true], :READ_WRITE)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\x01\x02\x03"
        @interface.write(pkt)
        expect($buffer).to eql("\xDE\xAD\x02\x03\xCD\xEF")
      end

      it "handles writing the sync field outside the packet" do
        @interface.instance_variable_set(:@stream, TerminatedStream.new)
        @interface.add_protocol(TerminatedStreamProtocol, ['0xCDEF','',true,2,'DEAD',true], :READ_WRITE)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\x01\x02\x03"
        @interface.write(pkt)
        expect($buffer).to eql("\xDE\xAD\x00\x01\x02\x03\xCD\xEF")
      end
    end
  end
end
