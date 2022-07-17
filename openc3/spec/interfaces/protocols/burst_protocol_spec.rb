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
require 'openc3/interfaces/protocols/burst_protocol'
require 'openc3/interfaces/interface'
require 'openc3/streams/stream'

module OpenC3
  describe BurstProtocol do
    $data = "\x01\x02\x03\x04"
    class StreamStub < Stream
      def connect; end

      def connected?; true; end

      def disconnect; end

      def read; $data; end

      def write(data) $data = data; end
    end

    before(:each) do
      @interface = StreamInterface.new
      allow(@interface).to receive(:connected?) { true }
    end

    describe "configure_protocol" do
      it "initializes attributes" do
        @interface.add_protocol(BurstProtocol, [1, '0xDEADBEEF', true], :READ_WRITE)
        expect(@interface.read_protocols[0].instance_variable_get(:@data)).to eq ''
        expect(@interface.read_protocols[0].instance_variable_get(:@discard_leading_bytes)).to eq 1
        expect(@interface.read_protocols[0].instance_variable_get(:@sync_pattern)).to eq "\xDE\xAD\xBE\xEF"
        expect(@interface.read_protocols[0].instance_variable_get(:@fill_fields)).to be true
      end
    end

    describe "connect" do
      it "clears the data" do
        @interface.add_protocol(BurstProtocol, [1, '0xDEADBEEF', true], :READ_WRITE)
        @interface.read_protocols[0].instance_variable_set(:@data, '\x00\x01\x02\x03')
        @interface.connect
        expect(@interface.read_protocols[0].instance_variable_get(:@data)).to eql ''
      end
    end

    describe "disconnect" do
      it "clears the data" do
        @interface.add_protocol(BurstProtocol, [1, '0xDEADBEEF', true], :READ_WRITE)
        @interface.read_protocols[0].instance_variable_set(:@data, '\x00\x01\x02\x03')
        @interface.connect
        expect(@interface.read_protocols[0].instance_variable_get(:@data)).to eql ''
      end
    end

    describe "read_data" do
      it "reads data from the stream" do
        @interface.instance_variable_set(:@stream, StreamStub.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 4
      end

      it "handles timeouts from the stream" do
        class TimeoutStream < StreamStub
          def read; raise Timeout::Error; end
        end
        @interface.instance_variable_set(:@stream, TimeoutStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        expect(@interface.read).to be_nil
      end

      it "discards leading bytes from the stream" do
        @interface.instance_variable_set(:@stream, StreamStub.new)
        @interface.add_protocol(BurstProtocol, [2], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 2
        expect(pkt.buffer.formatted).to match(/03 04/)
      end

      # The sync pattern is NOT part of the data
      it "discards the entire sync pattern" do
        $data = "\x12\x34\x56\x78\x9A\xBC"
        @interface.instance_variable_set(:@stream, StreamStub.new)
        @interface.add_protocol(BurstProtocol, [2, '0x1234'], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 4
        expect(pkt.buffer.formatted).to match(/56 78 9A BC/)
      end

      # The sync pattern is partially part of the data
      it "discards part of the sync pattern" do
        $data = "\x12\x34\x56\x78\x9A\xBC"
        @interface.instance_variable_set(:@stream, StreamStub.new)
        @interface.add_protocol(BurstProtocol, [1, '0x123456'], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 5
        expect(pkt.buffer.formatted).to match(/34 56 78 9A BC/)
      end

      # The sync pattern is completely part of the data
      it "handles a sync pattern" do
        $read_cnt = 0
        class SyncStream1 < StreamStub
          def read
            $read_cnt += 1
            case $read_cnt
            when 1
              "\x00\x00\x00\x00\x00\x00"
            when 2
              "\x00\x12\x34\x10\x20"
            when 3
              ""
            end
          end
        end
        @interface.instance_variable_set(:@stream, SyncStream1.new)
        @interface.add_protocol(BurstProtocol, [0, '0x1234'], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 4 # sync plus two bytes
        expect(pkt.buffer.formatted).to match(/12 34 10 20/)
      end

      it "handles a sync pattern split across reads" do
        $read_cnt = 0
        class SyncStream2 < StreamStub
          def read
            $read_cnt += 1
            case $read_cnt
            when 1
              "\x00\x00\x00\x00\x00\x00\x00\x12"
            when 2
              "\x34\x20"
            when 3
              ""
            end
          end
        end
        @interface.instance_variable_set(:@stream, SyncStream2.new)
        @interface.add_protocol(BurstProtocol, [0, '0x1234'], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 3 # sync plus one byte
      end

      it "handles a false positive sync pattern" do
        $read_cnt = 0
        class SyncStream3 < StreamStub
          def read
            $read_cnt += 1
            case $read_cnt
            when 1
              "\x00\x00\x12\x00\x00\x12"
            when 2
              "\x34\x20"
            when 3
              ""
            end
          end
        end
        @interface.instance_variable_set(:@stream, SyncStream3.new)
        @interface.add_protocol(BurstProtocol, [0, '0x1234'], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 3 # sync plus one byte
      end

      it "handle auto allow_empty_data correctly" do
        @interface.add_protocol(BurstProtocol, [0, nil, false, nil], :READ_WRITE)
        expect(@interface.read_protocols[0].read_data("")).to eql :STOP
        expect(@interface.read_protocols[0].read_data("A")).to eql "A"
        @interface.add_protocol(BurstProtocol, [0, nil, false, nil], :READ_WRITE)
        expect(@interface.read_protocols[0].read_data("")).to eql ""
        expect(@interface.read_protocols[1].read_data("")).to eql :STOP
        expect(@interface.read_protocols[0].read_data("A")).to eql "A"
        expect(@interface.read_protocols[1].read_data("A")).to eql "A"
        @interface.add_protocol(BurstProtocol, [0, nil, false, nil], :READ_WRITE)
        expect(@interface.read_protocols[0].read_data("")).to eql ""
        expect(@interface.read_protocols[1].read_data("")).to eql ""
        expect(@interface.read_protocols[2].read_data("")).to eql :STOP
        expect(@interface.read_protocols[0].read_data("A")).to eql "A"
        expect(@interface.read_protocols[1].read_data("A")).to eql "A"
        expect(@interface.read_protocols[2].read_data("A")).to eql "A"
      end
    end

    describe "write" do
      it "doesn't change the data if fill_fields is false" do
        $data = ''
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        @interface.instance_variable_set(:@stream, StreamStub.new)
        @interface.add_protocol(BurstProtocol, [0, '0x1234'], :READ_WRITE)
        data = @interface.write(data)
        expect($data).to eql "\x00\x01\x02\x03"
      end

      it "complains if the data isn't big enough to hold the sync pattern" do
        $data = ''
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x00")
        # Don't discard bytes, include and fill the sync pattern
        @interface.instance_variable_set(:@stream, StreamStub.new)
        @interface.add_protocol(BurstProtocol, [0, '0x12345678', true], :READ_WRITE)
        # 2 bytes are not enough to hold the 4 byte sync
        expect { @interface.write(data) }.to raise_error(ArgumentError, /buffer insufficient/)
      end

      it "fills the sync pattern in the data" do
        $data = ''
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        # Don't discard bytes, include and fill the sync pattern
        @interface.instance_variable_set(:@stream, StreamStub.new)
        @interface.add_protocol(BurstProtocol, [0, '0x1234', true], :READ_WRITE)
        @interface.write(data)
        expect($data).to eql "\x12\x34\x02\x03"
      end

      it "adds the sync pattern to the data stream" do
        $data = ''
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        # Discard first 2 bytes (the sync pattern), include and fill the sync pattern
        @interface.instance_variable_set(:@stream, StreamStub.new)
        @interface.add_protocol(BurstProtocol, [2, '0x12345678', true], :READ_WRITE)
        @interface.write(data)
        expect($data).to eql "\x12\x34\x56\x78\x02\x03"
      end

      it "adds part of the sync pattern to the data stream" do
        $data = ''
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x00\x02\x03")
        # Discard first byte (part of the sync pattern), include and fill the sync pattern
        @interface.instance_variable_set(:@stream, StreamStub.new)
        @interface.add_protocol(BurstProtocol, [1, '0x123456', true], :READ_WRITE)
        @interface.write(data)
        expect($data).to eql "\x12\x34\x56\x02\x03"
      end
    end

    describe "write_raw" do
      it "doesnt change the data" do
        $data = ''
        # Discard first 2 bytes (the sync pattern), include and fill the sync pattern
        @interface.instance_variable_set(:@stream, StreamStub.new)
        @interface.add_protocol(BurstProtocol, [2, '0x1234', true], :READ_WRITE)
        @interface.write_raw("\x00\x01\x02\x03")
        expect($data).to eql "\x00\x01\x02\x03"
      end
    end
  end
end
