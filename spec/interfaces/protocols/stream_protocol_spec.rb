# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/protocols/stream_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos
  describe StreamProtocol do
    before(:each) do
      @interface = Interface.new
      @interface.extend(StreamProtocol)
      allow(@interface).to receive(:connected?) { true }
    end

    describe "configure_stream_protocol" do
      it "initializes attributes" do
        @interface.configure_stream_protocol(1, '0xDEADBEEF', true)
        expect(@interface.instance_variable_get(:@data)).to eq ''
        expect(@interface.instance_variable_get(:@discard_leading_bytes)).to eq 1
        expect(@interface.instance_variable_get(:@sync_pattern)).to eq "\xDE\xAD\xBE\xEF"
        expect(@interface.instance_variable_get(:@fill_fields)).to be true
      end
    end

    describe "connect" do
      it "clears the data" do
        @interface.instance_variable_set(:@data, '\x00\x01\x02\x03')
        @interface.connect
        expect(@interface.instance_variable_get(:@data)).to eql ''
      end
    end

    describe "disconnect" do
      it "clears the data" do
        @interface.instance_variable_set(:@data, '\x00\x01\x02\x03')
        @interface.connect
        expect(@interface.instance_variable_get(:@data)).to eql ''
      end
    end

    describe "read_data" do
      it "reads data from the stream" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read; "\x01\x02\x03\x04"; end
        end
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol
        data = @interface.read_data
        expect(data.length).to eql 4
      end

      it "handles timeouts from the stream" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read; raise Timeout::Error; end
        end
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol
        expect(@interface.read_data).to be_nil
      end

      it "discards leading bytes from the stream" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read
            "\x01\x02\x03\x04"
          end
        end
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol(2)
        data = @interface.read_data
        expect(data.length).to eql 2
        expect(data.formatted).to match(/03 04/)
      end

      # The sync pattern is NOT part of the data
      it "discards the entire sync pattern" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read
            "\x12\x34\x56\x78\x9A\xBC"
          end
        end
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol(2, '0x1234')
        data = @interface.read_data
        expect(data.length).to eql 4
        expect(data.formatted).to match(/56 78 9A BC/)
      end

      # The sync pattern is partially part of the data
      it "discards part of the sync pattern" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read
            "\x12\x34\x56\x78\x9A\xBC"
          end
        end
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol(1, '0x123456')
        data = @interface.read_data
        expect(data.length).to eql 5
        expect(data.formatted).to match(/34 56 78 9A BC/)
      end

      # The sync pattern is completely part of the data
      it "handles a sync pattern" do
        $read_cnt = 0
        class MyStream < Stream
          def connect; end
          def connected?; true; end
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
        @interface.configure_stream_protocol(0, '0x1234')
        data = @interface.read_data
        expect(data.length).to eql 4 # sync plus two bytes
        expect(data.formatted).to match(/12 34 10 20/)
      end

      it "handles a sync pattern split across reads" do
        $read_cnt = 0
        class MyStream < Stream
          def connect; end
          def connected?; true; end
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
        @interface.configure_stream_protocol(0, '0x1234')
        data = @interface.read_data
        expect(data.length).to eql 3 # sync plus one byte
      end

      it "handles a false positive sync pattern" do
        $read_cnt = 0
        class MyStream < Stream
          def connect; end
          def connected?; true; end
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
        @interface.configure_stream_protocol(0, '0x1234')
        data = @interface.read_data
        expect(data.length).to eql 3 # sync plus one byte
      end
    end

    describe "write" do
      it "doesn't change the data if fill_fields is false" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol(0, '0x1234')
        data = @interface.write(data)
        expect($buffer).to eql "\x00\x01\x02\x03"
      end

      it "complains if the data isn't big enough to hold the sync pattern" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x00")
        # Don't discard bytes, include and fill the sync pattern
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol(0, '0x12345678', true)
        # 2 bytes are not enough to hold the 4 byte sync
        expect { @interface.write(data) }.to raise_error(ArgumentError, /buffer insufficient/)
      end

      it "fills the sync pattern in the data" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        # Don't discard bytes, include and fill the sync pattern
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol(0, '0x1234', true)
        data = @interface.write(data)
        expect($buffer).to eql "\x12\x34\x02\x03"
      end

      it "adds the sync pattern to the data stream" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        # Discard first 2 bytes (the sync pattern), include and fill the sync pattern
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol(2, '0x1234', true)
        data = @interface.write(data)
        expect($buffer).to eql "\x12\x34\x00\x01\x02\x03"
      end

      it "adds part of the sync pattern to the data stream" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        data = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x00\x02\x03")
        # Discard first byte (part of the sync pattern), include and fill the sync pattern
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol(1, '0x123456', true)
        data = @interface.write(data)
        expect($buffer).to eql "\x12\x34\x56\x02\x03"
      end
    end

    describe "write_raw" do
      it "doesn't change the data if fill_fields is false" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol(0, '0x1234')
        @interface.write_raw("\x00\x01\x02\x03")
        expect($buffer).to eql "\x00\x01\x02\x03"
      end

      # Discard bytes 0 means sync pattern is inside the data
      # and write_raw only operates on the data stream
      it "doesn't change the data if discard bytes is 0" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        # Don't discard bytes, include and fill the sync pattern
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol(0, '0x1234', true)
        @interface.write_raw("\x00\x01\x02\x03")
        expect($buffer).to eql "\x00\x01\x02\x03"
      end

      it "adds the sync pattern to the data stream if discard bytes" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        # Discard first 2 bytes (the sync pattern), include and fill the sync pattern
        @interface.instance_variable_set(:@stream, MyStream.new)
        @interface.configure_stream_protocol(2, '0x1234', true)
        @interface.write_raw("\x00\x01\x02\x03")
        expect($buffer).to eql "\x12\x34\x00\x01\x02\x03"
      end
    end
  end
end
