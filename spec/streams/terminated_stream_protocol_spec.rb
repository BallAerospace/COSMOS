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
        expect(tsp.interface).to be_nil
        expect(tsp.stream).to be_nil
        expect(tsp.post_read_data_callback).to be_nil
        expect(tsp.post_read_packet_callback).to be_nil
        expect(tsp.pre_write_packet_callback).to be_nil
      end
    end

    describe "read" do
      it "reads packets from the stream" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read
            case $index
            when 0
              $index += 1
              $buffer1
            when 1
              $buffer2
            end
          end
        end
        stream = MyStream.new

        lsp = TerminatedStreamProtocol.new('','0xABCD',true)

        lsp.connect(stream)
        $index = 0
        $buffer1 = "\x00\x01\x02\xAB"
        $buffer2 = "\xCD\x44\x02\x03"
        packet = lsp.read
        expect(packet.buffer.length).to eql 3
      end

      it "keeps the the termination characters" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read
            case $index
            when 0
              $index += 1
              $buffer1
            when 1
              $buffer2
            end
          end
        end
        stream = MyStream.new

        lsp = TerminatedStreamProtocol.new('','0xABCD',false)

        lsp.connect(stream)
        $index = 0
        $buffer1 = "\x00\x01\x02\xAB"
        $buffer2 = "\xCD\x44\x02\x03"
        packet = lsp.read
        expect(packet.buffer.length).to eql 5
        expect(packet.buffer[-2].unpack('C')[0]).to eql 0xAB
        expect(packet.buffer[-1].unpack('C')[0]).to eql 0xCD
      end
    end

    describe "write" do
      it "appends termination characters to the packet" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(data); $buffer = data; end
        end
        stream = MyStream.new

        lsp = TerminatedStreamProtocol.new('0xCDEF','0xCDEF')

        lsp.connect(stream)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\x01\x02\x03"
        packet = lsp.write(pkt)
        expect($buffer.length).to eql 6
        expect($buffer[-2].unpack('C')[0]).to eql 0xCD
        expect($buffer[-1].unpack('C')[0]).to eql 0xEF
      end

      it "complains if the packet buffer contains the termination characters" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(data); $buffer = data; end
        end
        stream = MyStream.new

        lsp = TerminatedStreamProtocol.new('0xCDEF','0xCDEF')

        lsp.connect(stream)
        pkt = Packet.new('tgt','pkt')
        pkt.buffer = "\x00\xCD\xEF\x03"
        expect { lsp.write(pkt) }.to raise_error("Packet contains termination characters!")
      end
    end

  end
end

