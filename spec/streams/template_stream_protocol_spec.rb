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
        expect(tsp.bytes_read).to eql 0
        expect(tsp.bytes_written).to eql 0
        expect(tsp.interface).to be_a Interface
        expect(tsp.stream).to be_nil
      end
    end

    $buffer = ''
    $read_cnt = 0
    class TemplateStream < Stream
      def connect; end
      def connected?; true; end
      def disconnect; end
      def read_nonblock; []; end
      def write(buffer) $buffer = buffer; end
      def read
        $read_cnt += 1
        raise Timeout::Error if $read_cnt == 1
        return "\x31\x30\xAB\xCD" if $read_cnt == 2
      end
    end

    before(:each) { $buffer = ''; $read_cnt = 0 }

    describe "connect" do
      it "supports an initial read delay" do
        stream = TemplateStream.new
        tsp = TemplateStreamProtocol.new('0xABCD','0xABCD',0,2)
        time = Time.now
        tsp.connect(stream)
        expect(Time.now - time).to be >= 2.0
      end
    end

    describe "disconnect" do
      it "unblocks the read queue" do
        tsp = TemplateStreamProtocol.new('0xABCD','0xABCD')
        tsp.connect(TemplateStream.new)

        result = nil
        t = Thread.new { result = tsp.read() }
        sleep 0.1
        expect(t.status).to eq("sleep")
        tsp.disconnect
        sleep 0.1
        expect(t.status).to be false
      end
    end

    describe "write" do
      it "works without a response" do
        interface = StreamInterface.new("Template",'0xABCD','0xABCD')
        interface.instance_variable_get(:@stream_protocol).connect(TemplateStream.new)
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 1
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 2
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "SOUR:VOLT <VOLTAGE>, (@<CHANNEL>)"
        packet.restore_defaults
        interface.write(packet)
        expect($buffer).to eql("SOUR:VOLT 1, (@2)\xAB\xCD")
      end

      it "processes responses" do
        rsp_pkt = Packet.new('TGT', 'READ_VOLTAGE')
        rsp_pkt.append_item("VOLTAGE", 16, :UINT)
        allow(System).to receive_message_chain(:telemetry, :packet).and_return(rsp_pkt)
        interface = StreamInterface.new("Template",'0xABCD','0xABCD',1)
        interface.instance_variable_get(:@stream_protocol).connect(TemplateStream.new)
        interface.target_names = ['TGT']
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
        interface.write(packet)
        expect($buffer).to eql("SOUR:VOLT 10, (@20)\xAB\xCD")
        pkt = interface.read()
        expect(pkt.read("VOLTAGE")).to eq 10
      end
    end

  end
end

