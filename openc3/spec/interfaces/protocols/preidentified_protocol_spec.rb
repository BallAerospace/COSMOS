# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'spec_helper'
require 'openc3/interfaces/protocols/preidentified_protocol'
require 'openc3/interfaces/interface'
require 'openc3/streams/stream'

module OpenC3
  describe PreidentifiedProtocol do
    before(:all) do
      setup_system()
    end

    before(:each) do
      $buffer = ''
      @interface = StreamInterface.new
      allow(@interface).to receive(:connected?) { true }
    end

    saved_verbose = $VERBOSE; $VERBOSE = nil
    class PreStream < Stream
      def connect; end

      def connected?; true; end

      def disconnect; end

      def read; $buffer; end

      def write(data); $buffer = data; end
    end
    $VERBOSE = saved_verbose

    it "handles receiving a bad packet length" do
      @interface.instance_variable_set(:@stream, PreStream.new)
      @interface.add_protocol(PreidentifiedProtocol, [nil, 5], :READ_WRITE)
      pkt = System.telemetry.packet("SYSTEM", "META")
      time = Time.new(2020, 1, 31, 12, 15, 30.5)
      pkt.received_time = time
      @interface.write(pkt)
      expect { @interface.read }.to raise_error(RuntimeError)
    end

    describe "initialize" do
      it "initializes attributes" do
        @interface.add_protocol(PreidentifiedProtocol, ['0xDEADBEEF', 100], :READ_WRITE)
        expect(@interface.read_protocols[0].instance_variable_get(:@data)).to eq ''
        expect(@interface.read_protocols[0].instance_variable_get(:@sync_pattern)).to eq "\xDE\xAD\xBE\xEF"
        expect(@interface.read_protocols[0].instance_variable_get(:@max_length)).to eq 100
      end
    end

    describe "write" do
      it "creates a packet header" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(PreidentifiedProtocol, [nil, 5], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META")
        time = Time.new(2020, 1, 31, 12, 15, 30.5)
        pkt.received_time = time
        @interface.write(pkt)
        expect($buffer[0..0].unpack('C')[0]).to eql 0
        expect($buffer[1..4].unpack('N')[0]).to eql time.to_f.to_i
        expect($buffer[5..8].unpack('N')[0]).to eql 500000
        offset = 9
        tgt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + tgt_name_length)]).to eql 'SYSTEM'
        offset += tgt_name_length
        pkt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + pkt_name_length)]).to eql 'META'
        offset += pkt_name_length
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql pkt.buffer.length
        offset += 4
        expect($buffer[offset..-1]).to eql pkt.buffer
      end

      it "creates a packet header with stored" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(PreidentifiedProtocol, [nil, 5], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META").clone
        time = Time.new(2020, 1, 31, 12, 15, 30.5)
        pkt.received_time = time
        pkt.stored = true
        @interface.write(pkt)
        expect($buffer[0..0].unpack('C')[0]).to eql 0x80
        expect($buffer[1..4].unpack('N')[0]).to eql time.to_f.to_i
        expect($buffer[5..8].unpack('N')[0]).to eql 500000
        offset = 9
        tgt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + tgt_name_length)]).to eql 'SYSTEM'
        offset += tgt_name_length
        pkt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + pkt_name_length)]).to eql 'META'
        offset += pkt_name_length
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql pkt.buffer.length
        offset += 4
        expect($buffer[offset..-1]).to eql pkt.buffer
      end

      it "creates a packet header with extra" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(PreidentifiedProtocol, [nil, 5], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META").clone
        time = Time.new(2020, 1, 31, 12, 15, 30.5)
        pkt.received_time = time
        pkt.stored = false
        extra_data = { "vcid" => 2 }
        pkt.extra = extra_data
        @interface.write(pkt)
        offset = 0
        expect($buffer[0..0].unpack('C')[0]).to eql 0x40
        json_extra = extra_data.as_json(:allow_nan => true).to_json(:allow_nan => true)
        offset += 1
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql json_extra.length
        offset += 4
        expect($buffer[offset..(offset + json_extra.length - 1)]).to eql json_extra
        offset += json_extra.length
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql time.to_f.to_i
        expect($buffer[(offset + 4)..(offset + 7)].unpack('N')[0]).to eql 500000
        offset = offset += 8 # time fields
        tgt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + tgt_name_length)]).to eql 'SYSTEM'
        offset += tgt_name_length
        pkt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + pkt_name_length)]).to eql 'META'
        offset += pkt_name_length
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql pkt.buffer.length
        offset += 4
        expect($buffer[offset..-1]).to eql pkt.buffer
      end

      it "creates a packet header with stored and extra" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(PreidentifiedProtocol, [nil, 5], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META").clone
        time = Time.new(2020, 1, 31, 12, 15, 30.5)
        pkt.received_time = time
        pkt.stored = true
        extra_data = { "vcid" => 2 }
        pkt.extra = extra_data
        @interface.write(pkt)
        offset = 0
        expect($buffer[0..0].unpack('C')[0]).to eql 0xC0
        json_extra = extra_data.as_json(:allow_nan => true).to_json(:allow_nan => true)
        offset += 1
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql json_extra.length
        offset += 4
        expect($buffer[offset..(offset + json_extra.length - 1)]).to eql json_extra
        offset += json_extra.length
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql time.to_f.to_i
        expect($buffer[(offset + 4)..(offset + 7)].unpack('N')[0]).to eql 500000
        offset = offset += 8 # time fields
        tgt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + tgt_name_length)]).to eql 'SYSTEM'
        offset += tgt_name_length
        pkt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + pkt_name_length)]).to eql 'META'
        offset += pkt_name_length
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql pkt.buffer.length
        offset += 4
        expect($buffer[offset..-1]).to eql pkt.buffer
      end

      it "handles a sync pattern" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(PreidentifiedProtocol, ["DEAD"], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META")
        time = Time.new(2020, 1, 31, 12, 15, 30.5)
        pkt.received_time = time
        @interface.write(pkt)
        expect($buffer[0..1]).to eql("\xDE\xAD")
        expect($buffer[2..2].unpack('C')[0]).to eql 0
        expect($buffer[3..6].unpack('N')[0]).to eql time.to_f.to_i
        expect($buffer[7..10].unpack('N')[0]).to eql 500000
        offset = 11
        tgt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + tgt_name_length)]).to eql 'SYSTEM'
        offset += tgt_name_length
        pkt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + pkt_name_length)]).to eql 'META'
        offset += pkt_name_length
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql pkt.buffer.length
        offset += 4
        expect($buffer[offset..-1]).to eql pkt.buffer
      end

      it "handles a sync pattern with stored and extra" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(PreidentifiedProtocol, ["DEAD", 5], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META").clone
        time = Time.new(2020, 1, 31, 12, 15, 30.5)
        pkt.received_time = time
        pkt.stored = true
        extra_data = { "vcid" => 2 }
        pkt.extra = extra_data
        @interface.write(pkt)
        expect($buffer[0..1]).to eql("\xDE\xAD")
        offset = 2
        expect($buffer[2..2].unpack('C')[0]).to eql 0xC0
        json_extra = extra_data.as_json(:allow_nan => true).to_json(:allow_nan => true)
        offset += 1
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql json_extra.length
        offset += 4
        expect($buffer[offset..(offset + json_extra.length - 1)]).to eql json_extra
        offset += json_extra.length
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql time.to_f.to_i
        expect($buffer[(offset + 4)..(offset + 7)].unpack('N')[0]).to eql 500000
        offset = offset += 8 # time fields
        tgt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + tgt_name_length)]).to eql 'SYSTEM'
        offset += tgt_name_length
        pkt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + pkt_name_length)]).to eql 'META'
        offset += pkt_name_length
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql pkt.buffer.length
        offset += 4
        expect($buffer[offset..-1]).to eql pkt.buffer
      end
    end

    describe "read" do
      it "handles a sync pattern" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(PreidentifiedProtocol, ["0x1234"], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META")
        pkt.write("OPENC3_VERSION", "TEST")
        time = Time.new(2020, 1, 31, 12, 15, 30.5)
        pkt.received_time = time
        @interface.write(pkt)
        expect($buffer[0]).to eql "\x12"
        expect($buffer[1]).to eql "\x34"
        packet = @interface.read
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'META'
        expect(packet.identified?).to be true
        expect(packet.defined?).to be false

        pkt2 = System.telemetry.update!("SYSTEM", "META", packet.buffer)
        expect(pkt2.read('OPENC3_VERSION')).to eql 'TEST'
        expect(pkt2.identified?).to be true
        expect(pkt2.defined?).to be true
      end

      it "returns a packet" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(PreidentifiedProtocol, [], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META")
        pkt.write("OPENC3_VERSION", "TEST")
        time = Time.new(2020, 1, 31, 12, 15, 30.5)
        pkt.received_time = time
        @interface.write(pkt)
        packet = @interface.read
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'META'
        expect(packet.identified?).to be true
        expect(packet.defined?).to be false

        pkt2 = System.telemetry.update!("SYSTEM", "META", packet.buffer)
        expect(pkt2.read('OPENC3_VERSION')).to eql 'TEST'
        expect(pkt2.identified?).to be true
        expect(pkt2.defined?).to be true
      end
    end

    describe "write in mode 2" do
      it "creates a packet header" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(PreidentifiedProtocol, [nil, 5, 2], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META")
        time = Time.new(2020, 1, 31, 12, 15, 30.5)
        pkt.received_time = time
        @interface.write(pkt)
        expect($buffer[0..3].unpack('N')[0]).to eql time.to_f.to_i
        expect($buffer[4..7].unpack('N')[0]).to eql 500000
        offset = 8
        tgt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + tgt_name_length)]).to eql 'SYSTEM'
        offset += tgt_name_length
        pkt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + pkt_name_length)]).to eql 'META'
        offset += pkt_name_length
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql pkt.buffer.length
        offset += 4
        expect($buffer[offset..-1]).to eql pkt.buffer
      end

      it "handles a sync pattern" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(PreidentifiedProtocol, ["DEAD", nil, 2], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META")
        time = Time.new(2020, 1, 31, 12, 15, 30.5)
        pkt.received_time = time
        @interface.write(pkt)
        expect($buffer[0..1]).to eql("\xDE\xAD")
        expect($buffer[2..5].unpack('N')[0]).to eql time.to_f.to_i
        expect($buffer[6..9].unpack('N')[0]).to eql 500000
        offset = 10
        tgt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + tgt_name_length)]).to eql 'SYSTEM'
        offset += tgt_name_length
        pkt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        expect($buffer[offset...(offset + pkt_name_length)]).to eql 'META'
        offset += pkt_name_length
        expect($buffer[offset..(offset + 3)].unpack('N')[0]).to eql pkt.buffer.length
        offset += 4
        expect($buffer[offset..-1]).to eql pkt.buffer
      end
    end

    describe "read in mode 2" do
      it "handles a sync pattern" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(PreidentifiedProtocol, ["0x1234", nil, 2], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META")
        pkt.write("OPENC3_VERSION", "TEST")
        time = Time.new(2020, 1, 31, 12, 15, 30.5)
        pkt.received_time = time
        @interface.write(pkt)
        expect($buffer[0]).to eql "\x12"
        expect($buffer[1]).to eql "\x34"
        packet = @interface.read
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'META'
        expect(packet.identified?).to be true
        expect(packet.defined?).to be false

        pkt2 = System.telemetry.update!("SYSTEM", "META", packet.buffer)
        expect(pkt2.read('OPENC3_VERSION')).to eql 'TEST'
        expect(pkt2.identified?).to be true
        expect(pkt2.defined?).to be true
      end

      it "returns a packet" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(PreidentifiedProtocol, [nil, nil, 2], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META")
        pkt.write("OPENC3_VERSION", "TEST")
        time = Time.new(2020, 1, 31, 12, 15, 30.5)
        pkt.received_time = time
        @interface.write(pkt)
        packet = @interface.read
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'META'
        expect(packet.identified?).to be true
        expect(packet.defined?).to be false

        pkt2 = System.telemetry.update!("SYSTEM", "META", packet.buffer)
        expect(pkt2.read('OPENC3_VERSION')).to eql 'TEST'
        expect(pkt2.identified?).to be true
        expect(pkt2.defined?).to be true
      end
    end
  end
end
