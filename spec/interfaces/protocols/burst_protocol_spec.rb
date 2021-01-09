# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos/interfaces/protocols/burst_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos
  describe BurstProtocol do
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
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
          def read; "\x01\x02\x03\x04"; end
        end
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 4
      end

      it "handles timeouts from the stream" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
          def read; raise Timeout::Error; end
        end
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        expect(@interface.read).to be_nil
      end

      it "discards leading bytes from the stream" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
          def read
            "\x01\x02\x03\x04"
          end
        end
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [2], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 2
        expect(pkt.buffer.formatted).to match(/03 04/)
      end

      # The sync pattern is NOT part of the data
      it "discards the entire sync pattern" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
          def read
            "\x12\x34\x56\x78\x9A\xBC"
          end
        end
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [2, '0x1234'], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 4
        expect(pkt.buffer.formatted).to match(/56 78 9A BC/)
      end

      # The sync pattern is partially part of the data
      it "discards part of the sync pattern" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
          def read
            "\x12\x34\x56\x78\x9A\xBC"
          end
        end
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [1, '0x123456'], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 5
        expect(pkt.buffer.formatted).to match(/34 56 78 9A BC/)
      end

      # The sync pattern is completely part of the data
      it "handles a sync pattern" do
        $read_cnt = 0
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
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
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [0, '0x1234'], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 4 # sync plus two bytes
        expect(pkt.buffer.formatted).to match(/12 34 10 20/)
      end

      it "handles a sync pattern split across reads" do
        $read_cnt = 0
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
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
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [0, '0x1234'], :READ_WRITE)
        pkt = @interface.read
        expect(pkt.length).to eql 3 # sync plus one byte
      end

      it "handles a false positive sync pattern" do
        $read_cnt = 0
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
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
        @interface.instance_variable_set(:@stream, MyStream.new)
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
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
          def write(buffer) $buffer = buffer; end
        end
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [0, '0x1234'], :READ_WRITE)
        data = @interface.write(data)
        expect($buffer).to eql "\x00\x01\x02\x03"
      end

      it "complains if the data isn't big enough to hold the sync pattern" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
          def disconnect; end
        end
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x00")
        # Don't discard bytes, include and fill the sync pattern
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [0, '0x12345678', true], :READ_WRITE)
        # 2 bytes are not enough to hold the 4 byte sync
        expect { @interface.write(data) }.to raise_error(ArgumentError, /buffer insufficient/)
      end

      it "fills the sync pattern in the data" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
          def write(buffer) $buffer = buffer; end
        end
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        # Don't discard bytes, include and fill the sync pattern
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [0, '0x1234', true], :READ_WRITE)
        @interface.write(data)
        expect($buffer).to eql "\x12\x34\x02\x03"
      end

      it "adds the sync pattern to the data stream" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
          def write(buffer) $buffer = buffer; end
        end
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        # Discard first 2 bytes (the sync pattern), include and fill the sync pattern
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [2, '0x12345678', true], :READ_WRITE)
        @interface.write(data)
        expect($buffer).to eql "\x12\x34\x56\x78\x02\x03"
      end

      it "adds part of the sync pattern to the data stream" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
          def write(buffer) $buffer = buffer; end
        end
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x00\x02\x03")
        # Discard first byte (part of the sync pattern), include and fill the sync pattern
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [1, '0x123456', true], :READ_WRITE)
        @interface.write(data)
        expect($buffer).to eql "\x12\x34\x56\x02\x03"
      end
    end

    describe "write_raw" do
      it "doesnt change the data" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def disconnect; end
          def write(buffer) $buffer = buffer; end
        end
        # Discard first 2 bytes (the sync pattern), include and fill the sync pattern
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.add_protocol(BurstProtocol, [2, '0x1234', true], :READ_WRITE)
        @interface.write_raw("\x00\x01\x02\x03")
        expect($buffer).to eql "\x00\x01\x02\x03"
      end
    end
  end
end
