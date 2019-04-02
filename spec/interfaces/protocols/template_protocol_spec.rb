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
require 'cosmos/utilities/logger'

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
      $write_buffer = ''
      $read_buffer = ''
      $read_cnt = 0
    end

    describe "initialize" do
      it "initializes attributes" do
        @interface.add_protocol(TemplateProtocol, %w(0xABCD 0xABCD), :READ_WRITE)
        expect(@interface.read_protocols[0].instance_variable_get(:@data)).to eq ''
      end
    end

    describe "connect" do
      it "supports an initial read delay" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, %w(0xABCD 0xABCD 0 2), :READ_WRITE)
        time = Time.now
        @interface.connect
        expect(@interface.read_protocols[0].instance_variable_get(:@connect_complete_time)).to be >= time + 2.0
      end
    end

    describe "disconnect" do
      it "unblocks writes waiting for responses" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, %w(0xABCD 0xABCD), :READ_WRITE)
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
        @interface.add_protocol(TemplateProtocol, %w(0xABCD 0xABCD 0 1.5), :READ_WRITE)
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
        @interface.add_protocol(TemplateProtocol, %w(0xABCD 0xABCD 0 1.5), :READ_WRITE)
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
        @interface.add_protocol(TemplateProtocol, %w(0xABCD 0xABCD), :READ_WRITE)
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

      it "logs an error if it doesn't receive a response" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, %w(0xA 0xA 0 nil 1 true 0 nil false 1.5), :READ_WRITE)
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
        logger = class_double("Cosmos::Logger").as_stubbed_const(:transfer_nested_constants => true)
        expect(logger).to receive(:error).with("StreamInterface: Timeout waiting for response")
        @interface.write(packet)
        expect(Time.now - start).to be_within(0.1).of(1.5)
      end

      it "disconnects if it doesn't receive a response" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, %w(0xA 0xA 0 nil 1 true 0 nil false 1.5 0.02 true), :READ_WRITE)
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
        expect { @interface.write(packet) }.to raise_error(/Timeout waiting for response/)
        expect(Time.now - start).to be_within(0.1).of(1.5)
      end

      it "doesn't expect responses for empty response fields" do
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, %w(0xA 0xA 0 nil 1 true 0 nil false nil), :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "GO"
        packet.append_item("RSP_TEMPLATE", 1024, :STRING)
        packet.get_item("RSP_TEMPLATE").default = ""
        packet.append_item("RSP_PACKET", 1024, :STRING)
        packet.get_item("RSP_PACKET").default = ""
        packet.restore_defaults
        @interface.connect
        logger = class_double("Cosmos::Logger").as_stubbed_const(:transfer_nested_constants => true)
        expect(logger).to_not receive(:error)
        @interface.write(packet)
      end

      it "processes responses with no ID fields" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY TGT READ_VOLTAGE BIG_ENDIAN'
        tf.puts '  APPEND_ITEM VOLTAGE 16 UINT'
        tf.close
        pc = PacketConfig.new
        pc.process_file(tf.path, "SYSTEM")
        telemetry = Telemetry.new(pc)
        tf.unlink

        allow(System).to receive_message_chain(:telemetry).and_return(telemetry)
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, %w(0xABCD 0xABCD 0 nil 1 true 0 nil false nil nil), :READ_WRITE)
        # Add extra target names to the interface to ensure we grab the correct one
        @interface.target_names = ['BLAH','TGT','OTHER']
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 11
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 1
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
        sleep 0.55
        expect($write_buffer).to eql("SOUR:VOLT 11, (@1)\xAB\xCD")
        expect(read_result.read("VOLTAGE")).to eql(10)
      end

      it "sets the response ID to the defined ID value" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY TGT READ_VOLTAGE BIG_ENDIAN'
        tf.puts '  APPEND_ID_ITEM PKT_ID 16 UINT 1'
        tf.puts '  APPEND_ITEM VOLTAGE 16 UINT'
        tf.close
        pc = PacketConfig.new
        pc.process_file(tf.path, "SYSTEM")
        telemetry = Telemetry.new(pc)
        tf.unlink

        allow(System).to receive_message_chain(:telemetry).and_return(telemetry)
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, %w(0xABCD 0xABCD 0 nil 1 true 0 nil false nil nil), :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("CMD_ID", 16, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, nil, nil, 1) # ID == 1
        packet.get_item("CMD_ID").default = 1
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 11
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 1
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
        sleep 0.55
        expect($write_buffer).to eql("SOUR:VOLT 11, (@1)\xAB\xCD")
        expect(read_result.read("PKT_ID")).to eql(1) # Result ID set to the defined value
        expect(read_result.read("VOLTAGE")).to eql(10)
      end

      it "handles multiple response IDs" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY TGT READ_VOLTAGE BIG_ENDIAN'
        tf.puts '  APPEND_ID_ITEM APID 16 UINT 10'
        tf.puts '  APPEND_ID_ITEM PKTID 16 UINT 20'
        tf.puts '  APPEND_ITEM VOLTAGE 16 UINT'
        tf.close
        pc = PacketConfig.new
        pc.process_file(tf.path, "SYSTEM")
        telemetry = Telemetry.new(pc)
        tf.unlink

        allow(System).to receive_message_chain(:telemetry).and_return(telemetry)
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, %w(0xABCD 0xABCD 0 nil 1 true 0 nil false nil nil), :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("APID", 16, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, nil, nil, 1) # ID == 1
        packet.get_item("APID").default = 1
        packet.append_item("PKTID", 16, :UINT, nil, :BIG_ENDIAN, :ERROR, nil, nil, nil, 2) # ID == 2
        packet.get_item("PKTID").default = 2
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 11
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 1
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "SOUR:VOLT <VOLTAGE>, (@<CHANNEL>)"
        packet.append_item("RSP_TEMPLATE", 1024, :STRING)
        packet.get_item("RSP_TEMPLATE").default = "<VOLTAGE>"
        packet.append_item("RSP_PACKET", 1024, :STRING)
        packet.get_item("RSP_PACKET").default = "READ_VOLTAGE"
        packet.restore_defaults
        # Explicitly write in values to the ID items different than the defaults
        packet.write("APID", 10)
        packet.write("PKTID", 20)
        @interface.connect
        read_result = nil
        $read_buffer = "\x31\x30\xAB\xCD" # ASCII 31, 30 is '10'
        Thread.new { sleep(0.5); read_result = @interface.read }
        @interface.write(packet)
        sleep 0.55
        expect($write_buffer).to eql("SOUR:VOLT 11, (@1)\xAB\xCD")
        expect(read_result.read("APID")).to eql(10) # ID item set to the defined value
        expect(read_result.read("PKTID")).to eql(20) # ID item set to the defined value
      end

      it "handles templates with more values than the response" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY TGT READ_VOLTAGE BIG_ENDIAN'
        tf.puts '  APPEND_ITEM VOLTAGE 16 UINT'
        tf.close
        pc = PacketConfig.new
        pc.process_file(tf.path, "SYSTEM")
        telemetry = Telemetry.new(pc)
        tf.unlink

        allow(System).to receive_message_chain(:telemetry).and_return(telemetry)
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, %w(0xABCD 0xABCD 0 nil 1 true 0 nil false nil), :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 12
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 2
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "SOUR:VOLT <VOLTAGE>, (@<CHANNEL>)"
        packet.append_item("RSP_TEMPLATE", 1024, :STRING)
        packet.get_item("RSP_TEMPLATE").default = "<VOLTAGE>;<CURRENT>"
        packet.append_item("RSP_PACKET", 1024, :STRING)
        packet.get_item("RSP_PACKET").default = "READ_VOLTAGE"
        packet.restore_defaults
        @interface.connect
        read_result = nil
        $read_buffer = "\x31\x30\xAB\xCD" # ASCII 31, 30 is '10'
        Thread.new { sleep(0.5); read_result = @interface.read }
        logger = class_double("Cosmos::Logger").as_stubbed_const(:transfer_nested_constants => true)
        expect(logger).to receive(:error) do |arg|
          expect(arg).to match(/Unexpected response: 10/)
        end
        @interface.write(packet)
        sleep 0.55
        expect($write_buffer).to eql("SOUR:VOLT 12, (@2)\xAB\xCD")
      end

      it "handles responses with more values than the template" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY TGT READ_VOLTAGE BIG_ENDIAN'
        tf.puts '  APPEND_ITEM VOLTAGE 16 UINT'
        tf.close
        pc = PacketConfig.new
        pc.process_file(tf.path, "SYSTEM")
        telemetry = Telemetry.new(pc)
        tf.unlink

        allow(System).to receive_message_chain(:telemetry).and_return(telemetry)
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, %w(0xABCD 0xABCD 0 nil 1 true 0 nil false nil), :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'CMD')
        packet.append_item("VOLTAGE", 16, :UINT)
        packet.get_item("VOLTAGE").default = 12
        packet.append_item("CHANNEL", 16, :UINT)
        packet.get_item("CHANNEL").default = 2
        packet.append_item("CMD_TEMPLATE", 1024, :STRING)
        packet.get_item("CMD_TEMPLATE").default = "SOUR:VOLT <VOLTAGE>, (@<CHANNEL>)"
        packet.append_item("RSP_TEMPLATE", 1024, :STRING)
        packet.get_item("RSP_TEMPLATE").default = "<VOLTAGE>"
        packet.append_item("RSP_PACKET", 1024, :STRING)
        packet.get_item("RSP_PACKET").default = "READ_VOLTAGE"
        packet.restore_defaults
        @interface.connect
        read_result = nil
        $read_buffer = "\x31\x30\x3B\x31\x31\xAB\xCD" # ASCII is '10;11'
        Thread.new { sleep(0.5); read_result = @interface.read }
        logger = class_double("Cosmos::Logger").as_stubbed_const(:transfer_nested_constants => true)
        expect(logger).to receive(:error) do |arg|
          expect(arg).to match(/Could not write value 10;11/)
        end
        @interface.write(packet)
        sleep 0.55
        expect($write_buffer).to eql("SOUR:VOLT 12, (@2)\xAB\xCD")
      end

      it "ignores response lines" do
        tf = Tempfile.new('unittest')
        tf.puts 'TELEMETRY TGT READ_VOLTAGE BIG_ENDIAN'
        tf.puts '  APPEND_ITEM VOLTAGE 16 UINT'
        tf.close
        pc = PacketConfig.new
        pc.process_file(tf.path, "SYSTEM")
        telemetry = Telemetry.new(pc)
        tf.unlink

        allow(System).to receive_message_chain(:telemetry).and_return(telemetry)
        @interface.instance_variable_set(:@stream, TemplateStream.new)
        @interface.add_protocol(TemplateProtocol, %w(0xAD 0xA 1), :READ_WRITE)
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
      tf = Tempfile.new('unittest')
      tf.puts 'TELEMETRY TGT DATA BIG_ENDIAN'
      tf.puts '  APPEND_ITEM STRING 512 STRINg'
      tf.close
      pc = PacketConfig.new
      pc.process_file(tf.path, "SYSTEM")
      telemetry = Telemetry.new(pc)
      tf.unlink

      allow(System).to receive_message_chain(:telemetry).and_return(telemetry)
      @interface.instance_variable_set(:@stream, TemplateStream.new)
      @interface.add_protocol(TemplateProtocol, %w(0xAD 0xA 0 nil 2), :READ_WRITE)
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
