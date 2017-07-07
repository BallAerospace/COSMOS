# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/protocols/template_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos
  describe TemplateProtocol do
    class TemplateStream < Stream
      def connect; end
      def connected?; true; end
      def disconnect; end
      def read_nonblock; []; end
      def write(buffer) $write_buffer = buffer; end
      def read; $read_buffer; end
    end

    before(:each) do
      @interface = StreamInterface.new
      allow(@interface).to receive(:connected?) { true }
      $read_buffer = ''
      $read_cnt = 0
    end

    describe "initialize" do
      it "initializes attributes" do
        @interface.add_protocol(TemplateProtocol, ['0xABCD','0xABCD'], :READ_WRITE)
        expect(@interface.read_protocols[0].instance_variable_get(:@data)).to eq ''
      end
    end

    describe "connect" do
      it "supports an initial read delay" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, ['0xABCD', '0xABCD', 0, 2], :READ_WRITE)
        time = Time.now
        @interface.connect
        expect(@interface.read_protocols[0].instance_variable_get(:@connect_complete_time)).to be >= time + 2.0
      end
    end

    describe "disconnect" do
      it "unblocks writes waiting for responses" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, ['0xABCD', '0xABCD'], :READ_WRITE)
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "SOUR:VOLT"
        packet.append_item("RSP_TEMPLATE", 1024, :STRING)
        packet.get_item("RSP_TEMPLATE").default = "<VOLTAGE>"
        packet.append_item("RSP_PACKET", 1024, :STRING)
        packet.get_item("RSP_PACKET").default = "READ_VOLTAGE"
        packet.restore_defaults
        # write blocks waiting for the response so spawn a thread
        thread = Thread.new { @interface.write(packet) }
        sleep 0.1
        @interface.disconnect
        sleep 0.1
        expect(thread.alive?).to be false
      end
    end

    describe "read_data" do
      it "ignores all data during the connect period" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, ['0xABCD', '0xABCD', 0, 1.5], :READ_WRITE)
        start = Time.now
        @interface.connect
        $read_buffer = "\x31\x30\xAB\xCD"
        data = @interface.read
        expect(Time.now - start).to be_within(0.1).of(1.5)
        expect(data.buffer).to eql("\x31\x30")
      end
    end

    describe "write" do
      it "waits before writing during the initial delay period" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, ['0xABCD','0xABCD',0,1.5], :READ_WRITE)
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 1
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 2
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "SOUR:VOLT <VOLTAGE>, (@<CHANNEL>)"
        packet.restore_defaults
        @interface.connect
        write = Time.now
        @interface.write(packet)
        expect(Time.now - write).to be_within(0.1).of(1.5)
      end

      it "works without a response" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, ['0xABCD','0xABCD'], :READ_WRITE)
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 1
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 2
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "SOUR:VOLT <VOLTAGE>, (@<CHANNEL>)"
        packet.restore_defaults
        @interface.write(packet)
        expect($write_buffer).to eql("SOUR:VOLT 1, (@2)\xAB\xCD")
      end

      it "times out if it doesn't receive a response" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, ['0xA','0xA',0,nil,1,true,0,nil,false,1.5], :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "GO"
        packet.append_item("RSP_TEMPLATE", 1024, :STRING)
        packet.get_item("RSP_TEMPLATE").default = "<VOLTAGE>"
        packet.append_item("RSP_PACKET", 1024, :STRING)
        packet.get_item("RSP_PACKET").default = "DATA"
        packet.restore_defaults
        @interface.connect
        start = Time.now
        expect { @interface.write(packet) }.to raise_error(Timeout::Error)
        expect(Time.now - start).to be_within(0.1).of(1.5)
      end

      it "processes responses" do
        rsp_pkt = Packet.new('TGT', 'READ_VOLTAGE')
        rsp_pkt.append_item("VOLTAGE", 16, :UINT)
        allow(System).to receive_message_chain(:telemetry, :packet).and_return(rsp_pkt)
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, ['0xABCD','0xABCD', 0, nil, 1, true, 0, nil, false, nil, nil], :READ_WRITE)
      #@interface.add_protocol(TemplateProtocol, ['0xABCD','0xABCD'], :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 11
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 20
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "SOUR:VOLT <VOLTAGE>, (@<CHANNEL>)"
        packet.append_item("RSP_TEMPLATE", 1024, :STRING)
        packet.get_item("RSP_TEMPLATE").default = "<VOLTAGE>"
        packet.append_item("RSP_PACKET", 1024, :STRING)
        packet.get_item("RSP_PACKET").default = "READ_VOLTAGE"
        packet.restore_defaults
        @interface.connect
        read_result = nil
        $read_buffer = "\x31\x30\xAB\xCD" # ASCII 31, 30 is '10'
        Thread.new { sleep(0.5); read_result = @interface.read }
        @interface.write(packet)
        expect($write_buffer).to eql("SOUR:VOLT 11, (@20)\xAB\xCD")
        expect(read_result.read("VOLTAGE")).to eq 10
      end

      it "ignores response lines" do
        rsp_pkt = Packet.new('TGT', 'READ_VOLTAGE')
        rsp_pkt.append_item("VOLTAGE", 16, :UINT)
        allow(System).to receive_message_chain(:telemetry, :packet).and_return(rsp_pkt)
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, ['0xAD','0xA', 1], :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 11
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 20
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "SOUR:VOLT <VOLTAGE>, (@<CHANNEL>)"
        packet.append_item("RSP_TEMPLATE", 1024, :STRING)
        packet.get_item("RSP_TEMPLATE").default = "<VOLTAGE>"
        packet.append_item("RSP_PACKET", 1024, :STRING)
        packet.get_item("RSP_PACKET").default = "READ_VOLTAGE"
        packet.restore_defaults
        @interface.connect
        read_result = nil
        $read_buffer = "\x31\x30\x0A\x31\x32\x0A" # ASCII: 30:'0', 31:'1', etc
        Thread.new { sleep(0.5); read_result = @interface.read }
        @interface.write(packet)
        expect($write_buffer).to eql("SOUR:VOLT 11, (@20)\xAD")
        expect(read_result.read("VOLTAGE")).to eq 12
      end
    end

    it "allows multiple response lines" do
      rsp_pkt = Packet.new('TGT', 'DATA')
      rsp_pkt.append_item("STRING", 512, :STRING)
      allow(System).to receive_message_chain(:telemetry, :packet).and_return(rsp_pkt)
      @interface.instance_variable_set(:@stream, TemplateStream.new)
      @interface.add_protocol(TemplateProtocol, ['0xAD','0xA', 0, nil, 2], :READ_WRITE)
      @interface.target_names = ['TGT']
      packet = Packet.new('TGT', 'CMD')
      packet.append_item("CMD_TEMPLATE", 1024, :STRING)
      packet.get_item("CMD_TEMPLATE").default = "GO"
      packet.append_item("RSP_TEMPLATE", 1024, :STRING)
      packet.get_item("RSP_TEMPLATE").default = "<STRING>"
      packet.append_item("RSP_PACKET", 1024, :STRING)
      packet.get_item("RSP_PACKET").default = "DATA"
      packet.restore_defaults
      @interface.connect
      read_result = nil
      $read_buffer = "\x43\x4F\x53\x0A\x4D\x4F\x53\x0A" # ASCII
      Thread.new { sleep(0.5); read_result = @interface.read }
      @interface.write(packet)
      expect($write_buffer).to eql("GO\xAD")
      expect(read_result.read("STRING")).to eq 'COSMOS'
    end
  end
end
