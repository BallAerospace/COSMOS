# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/streams/stream_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos

  describe StreamProtocol do
    before(:each) do
      @sp = StreamProtocol.new
    end

    describe "initialize" do
      it "initializes attributes" do
        expect(@sp.bytes_read).to eql 0
        expect(@sp.bytes_written).to eql 0
        expect(@sp.interface).to be_a Interface
        expect(@sp.stream).to be_nil
      end
    end

    describe "interface=" do
      it "sets the interface" do
        interface = StreamInterface.new("")
        @sp.interface = interface
        expect(@sp.interface).to eql interface
      end
    end

    describe "connect" do
      it "sets the stream" do
        class MyStream < Stream; end
        stream = MyStream.new
        allow(stream).to receive(:connect)
        @sp.connect(stream)
        expect(@sp.stream).to eql stream
      end
    end

    describe "connected" do
      it "returns false if the stream hasn't been set" do
        expect(@sp.connected?).to be false
      end

      it "returns the status of the stream connection" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
        end
        stream = MyStream.new
        @sp.connect(stream)
        expect(@sp.connected?).to be true
      end
    end

    describe "disconnect" do
      it "calls disconnect on the stream" do
        $test = false
        class MyStream < Stream
          def connect; end
          def disconnect; $test = true; end
        end
        stream = MyStream.new
        @sp.connect(stream)
        expect($test).to be false
        @sp.disconnect
        expect($test).to be true
      end
    end

    describe "read" do
      it "reads data from the stream" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read; "\x01\x02\x03\x04"; end
        end
        stream = MyStream.new
        @sp.connect(stream)
        packet = @sp.read
        expect(packet.length).to eql 4
      end

      it "handles timeouts from the stream" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read; raise Timeout::Error; end
        end
        stream = MyStream.new
        @sp.connect(stream)
        expect(@sp.read).to be_nil
      end

      it "discards leading bytes from the stream" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read
            "\x01\x02\x03\x04"
          end
        end
        @sp = StreamProtocol.new(2, nil)
        stream = MyStream.new
        @sp.connect(stream)
        packet = @sp.read
        expect(packet.length).to eql 2
        expect(packet.buffer.formatted).to match(/03 04/)
      end

      # The sync pattern is NOT part of the packet
      it "discards the entire sync pattern" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read
            "\x12\x34\x56\x78\x9A\xBC"
          end
        end
        @sp = StreamProtocol.new(2, '0x1234')
        stream = MyStream.new
        @sp.connect(stream)
        packet = @sp.read
        expect(packet.length).to eql 4
        expect(packet.buffer.formatted).to match(/56 78 9A BC/)
      end

      # The sync pattern is partially part of the packet
      it "discards part of the sync pattern" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read
            "\x12\x34\x56\x78\x9A\xBC"
          end
        end
        @sp = StreamProtocol.new(1, '0x123456')
        stream = MyStream.new
        @sp.connect(stream)
        packet = @sp.read
        expect(packet.length).to eql 5
        expect(packet.buffer.formatted).to match(/34 56 78 9A BC/)
      end

      # The sync pattern is completely part of the packet
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
        @sp = StreamProtocol.new(0, '0x1234')
        stream = MyStream.new
        @sp.connect(stream)
        packet = @sp.read
        expect(packet.length).to eql 4 # sync plus two bytes
        expect(packet.buffer.formatted).to match(/12 34 10 20/)
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
        @sp = StreamProtocol.new(0, '0x1234')
        stream = MyStream.new
        @sp.connect(stream)
        packet = @sp.read
        expect(packet.length).to eql 3 # sync plus one byte
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
        @sp = StreamProtocol.new(0, '0x1234')
        stream = MyStream.new
        @sp.connect(stream)
        packet = @sp.read
        expect(packet.length).to eql 3 # sync plus one byte
      end
    end

    describe "write" do
      it "doesn't change the packet if fill_fields is false" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        packet = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        @sp = StreamProtocol.new(0, '0x1234')
        stream = MyStream.new
        @sp.connect(stream)
        packet = @sp.write(packet)
        expect($buffer).to eql "\x00\x01\x02\x03"
      end

      it "complains if the packet isn't big enough to hold the sync pattern" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        packet = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x00")
        # Don't discard bytes, include and fill the sync pattern
        @sp = StreamProtocol.new(0, '0x12345678', true)
        stream = MyStream.new
        @sp.connect(stream)
        # 2 bytes are not enough to hold the 4 byte sync
        expect { @sp.write(packet) }.to raise_error(ArgumentError, /buffer insufficient/)
      end

      it "fills the sync pattern in the packet" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        packet = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        # Don't discard bytes, include and fill the sync pattern
        @sp = StreamProtocol.new(0, '0x1234', true)
        stream = MyStream.new
        @sp.connect(stream)
        packet = @sp.write(packet)
        expect($buffer).to eql "\x12\x34\x02\x03"
      end

      it "adds the sync pattern to the data stream" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        packet = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        # Discard first 2 bytes (the sync pattern), include and fill the sync pattern
        @sp = StreamProtocol.new(2, '0x1234', true)
        stream = MyStream.new
        @sp.connect(stream)
        packet = @sp.write(packet)
        expect($buffer).to eql "\x12\x34\x00\x01\x02\x03"
      end

      it "adds part of the sync pattern to the data stream" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        packet = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x00\x02\x03")
        # Discard first byte (part of the sync pattern), include and fill the sync pattern
        @sp = StreamProtocol.new(1, '0x123456', true)
        stream = MyStream.new
        @sp.connect(stream)
        packet = @sp.write(packet)
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
        @sp = StreamProtocol.new(0, '0x1234')
        stream = MyStream.new
        @sp.connect(stream)
        @sp.write_raw("\x00\x01\x02\x03")
        expect($buffer).to eql "\x00\x01\x02\x03"
      end

      # Discard bytes 0 means sync pattern is inside the packet
      # and write_raw only operates on the data stream
      it "doesn't change the data if discard bytes is 0" do
        $buffer = ''
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        # Don't discard bytes, include and fill the sync pattern
        @sp = StreamProtocol.new(0, '0x1234', true)
        stream = MyStream.new
        @sp.connect(stream)
        @sp.write_raw("\x00\x01\x02\x03")
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
        @sp = StreamProtocol.new(2, '0x1234', true)
        stream = MyStream.new
        @sp.connect(stream)
        @sp.write_raw("\x00\x01\x02\x03")
        expect($buffer).to eql "\x12\x34\x00\x01\x02\x03"
      end
    end

  end
end

