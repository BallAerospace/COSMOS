# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/protocols/template_stream_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos
  describe TemplateStreamProtocol do
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

    before(:each) do
      @interface = Interface.new
      @interface.extend(TemplateStreamProtocol)
      allow(@interface).to receive(:connected?) { true }
      $buffer = ''
      $read_cnt = 0
    end

    describe "initialize" do
      it "initializes attributes" do
        @interface.configure_stream_protocol('0xABCD','0xABCD')
        expect(@interface.instance_variable_get(:@data)).to eq ''
      end
    end

    describe "connect" do
      it "supports an initial read delay" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.configure_stream_protocol('0xABCD', '0xABCD', 0, 2)
        time = Time.now
        @interface.connect
        expect(Time.now - time).to be >= 2.0
      end
    end

    describe "disconnect" do
      it "unblocks the read queue" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.configure_stream_protocol('0xABCD','0xABCD')
        result = nil
        t = Thread.new { result = @interface.read() }
        sleep 0.1
        expect(t.status).to eq("sleep")
        @interface.disconnect
        sleep 0.1
        expect(t.status).to be false
      end
    end

    describe "write" do
      it "works without a response" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.configure_stream_protocol('0xABCD','0xABCD')
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 1
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 2
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "SOUR:VOLT <VOLTAGE>, (@<CHANNEL>)"
        packet.restore_defaults
        @interface.write(packet)
        expect($buffer).to eql("SOUR:VOLT 1, (@2)\xAB\xCD")
      end

      it "processes responses" do
        rsp_pkt = Packet.new('TGT', 'READ_VOLTAGE')
        rsp_pkt.append_item("VOLTAGE", 16, :UINT)
        allow(System).to receive_message_chain(:telemetry, :packet).and_return(rsp_pkt)
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.configure_stream_protocol('0xABCD','0xABCD', 1)
        @interface.target_names = ['TGT']
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
        @interface.write(packet)
        expect($buffer).to eql("SOUR:VOLT 10, (@20)\xAB\xCD")
        pkt = @interface.read()
        expect(pkt.read("VOLTAGE")).to eq 10
      end
    end
  end
end

