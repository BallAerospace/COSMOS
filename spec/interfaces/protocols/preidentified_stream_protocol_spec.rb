# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/protocols/preidentified_stream_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos
  describe PreidentifiedStreamProtocol do
    before(:each) do
      $buffer = ''
      @interface = Interface.new
      @interface.extend(PreidentifiedStreamProtocol)
      allow(@interface).to receive(:connected?) { true }
    end

    after(:all) do
      clean_config()
    end

    class PreStream < Stream
      def connect; end
      def connected?; true; end
      def disconnect; end
      def read; $buffer; end
      def write(data); $buffer = data; end
    end

    it "handles receiving a bad packet length" do
      @interface.instance_variable_set(:@stream, PreStream.new)
      @interface.configure_stream_protocol(nil, 5)
      pkt = System.telemetry.packet("SYSTEM","META")
      time = Time.new(2020,1,31,12,15,30.5)
      pkt.received_time = time
      @interface.write(pkt)
      expect { packet = @interface.read }.to raise_error(RuntimeError)
    end

    describe "initialize" do
      it "initializes attributes" do
        @interface.configure_stream_protocol('0xDEADBEEF', 100)
        expect(@interface.instance_variable_get(:@data)).to eq ''
        expect(@interface.instance_variable_get(:@sync_pattern)).to eq "\xDE\xAD\xBE\xEF"
        expect(@interface.instance_variable_get(:@max_length)).to eq 100
      end
    end

    describe "write" do
      it "creates a packet header" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.configure_stream_protocol(nil, 5)
        pkt = System.telemetry.packet("COSMOS","VERSION")
        time = Time.new(2020,1,31,12,15,30.5)
        pkt.received_time = time
        @interface.write(pkt)
        expect($buffer[0..3].unpack('N')[0]).to eql time.to_f.to_i
        expect($buffer[4..7].unpack('N')[0]).to eql 500000
        offset = 8
        tgt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset+tgt_name_length)]).to eql 'SYSTEM'
        offset += tgt_name_length
        pkt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset+pkt_name_length)]).to eql 'META'
        offset += pkt_name_length
        expect($buffer[offset..(offset+3)].unpack('N')[0]).to eql pkt.buffer.length
        offset += 4
        expect($buffer[offset..-1]).to eql pkt.buffer
      end

      it "handles a sync pattern" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.configure_stream_protocol("DEAD")
        pkt = System.telemetry.packet("COSMOS","VERSION")
        time = Time.new(2020,1,31,12,15,30.5)
        pkt.received_time = time
        @interface.write(pkt)
        expect($buffer[0..1]).to eql("\xDE\xAD")
        expect($buffer[2..5].unpack('N')[0]).to eql time.to_f.to_i
        expect($buffer[6..9].unpack('N')[0]).to eql 500000
        offset = 10
        tgt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset+tgt_name_length)]).to eql 'COSMOS'
        offset += tgt_name_length
        pkt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset+pkt_name_length)]).to eql 'VERSION'
        offset += pkt_name_length
        expect($buffer[offset..(offset+3)].unpack('N')[0]).to eql pkt.buffer.length
        offset += 4
        expect($buffer[offset..-1]).to eql pkt.buffer
      end
    end

    describe "read" do
      it "returns a packet" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.configure_stream_protocol()
        pkt = System.telemetry.packet("SYSTEM","META")
        pkt.write("COSMOS_VERSION", "TEST")
        time = Time.new(2020,1,31,12,15,30.5)
        pkt.received_time = time
        @interface.write(pkt)
        packet = @interface.read
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'META'
        expect(packet.identified?).to be true
        expect(packet.defined?).to be false

        pkt2 = System.telemetry.update!("SYSTEM","META",packet.buffer)
        expect(pkt2.read('COSMOS_VERSION')).to eql 'TEST'
        expect(pkt2.identified?).to be true
        expect(pkt2.defined?).to be true
      end
    end

  end
end

