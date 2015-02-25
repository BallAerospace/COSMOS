# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/streams/template_stream_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos

  describe TemplateStreamProtocol do
    describe "initialize" do
      it "initializes attributes" do
        tsp = TemplateStreamProtocol.new('0xABCD','0xABCD')
        tsp.bytes_read.should eql 0
        tsp.bytes_written.should eql 0
        tsp.interface.should be_nil
        tsp.stream.should be_nil
        tsp.post_read_data_callback.should be_nil
        tsp.post_read_packet_callback.should be_nil
        tsp.pre_write_packet_callback.should be_nil
      end
    end

    describe "connect" do
      it "supports an initial read delay" do
        class MyStream1 < Stream
          def connect; end
          def read_nonblock; []; end
        end
        stream = MyStream1.new
        tsp = TemplateStreamProtocol.new('0xABCD','0xABCD',0,2)
        time = Time.now
        tsp.connect(stream)
        expect(Time.now - time).to be >= 2.0
      end
    end

    describe "disconnect" do
      it "unblocks the read queue" do
        tsp = TemplateStreamProtocol.new('0xABCD','0xABCD')
        class MyStream1 < Stream
          def connect; end
          def disconnect; end
        end
        tsp.connect(MyStream1.new)

        result = nil
        t = Thread.new { result = tsp.read() }
        sleep 0.1
        expect(t.status).to eq("sleep")
        tsp.disconnect
        sleep 0.1
        expect(t.status).to be_falsey
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

        tsp = TemplateStreamProtocol.new('','0xABCD')

        tsp.connect(stream)
        $index = 0
        $buffer1 = "\x00\x01\x02\xAB"
        $buffer2 = "\xCD\x44\x02\x03"
        packet = tsp.read(false)
        packet.buffer.length.should eql 3
      end
    end

    describe "write" do
      it "works without a response" do
        $buffer = ''
        class MyStream1 < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        tsp = TemplateStreamProtocol.new('0xABCD','0xABCD')
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 1
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 2
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "SOUR:VOLT <VOLTAGE>, (@<CHANNEL>)"
        packet.restore_defaults
        tsp.connect(MyStream1.new)
        tsp.write(packet)
        $buffer.should eq "SOUR:VOLT 1, (@2)\xAB\xCD"
      end

      it "processes responses" do
        $buffer = ''
        $read_cnt = 0
        class MyStream2 < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
          def read
            $read_cnt += 1
            raise Timeout::Error if $read_cnt == 1
            return "\x31\x30\xAB\xCD" if $read_cnt == 2
          end
        end
        rsp_pkt = Packet.new('TGT', 'READ_VOLTAGE')
        rsp_pkt.append_item("VOLTAGE", 16, :UINT)
        allow(System).to receive_message_chain(:telemetry, :packet).and_return(rsp_pkt)
        tsp = TemplateStreamProtocol.new('0xABCD','0xABCD', 1)
        class MyInterface; def target_names; ['TGT']; end; end
        tsp.interface = MyInterface.new
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 10
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 20
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "SOUR:VOLT <VOLTAGE>, (@<CHANNEL>)"
        packet.append_item("RSP_TEMPLATE", 1024, :STRING)
        packet.get_item("RSP_TEMPLATE").default = "<VOLTAGE>"
        packet.append_item("RSP_PACKET", 1024, :STRING)
        packet.get_item("RSP_PACKET").default = "READ_VOLTAGE"
        packet.restore_defaults
        tsp.connect(MyStream2.new)
        tsp.write(packet)
        $buffer.should eq "SOUR:VOLT 10, (@20)\xAB\xCD"
        pkt = tsp.read()
        pkt.read("VOLTAGE").should eq 10
      end
    end

  end
end

