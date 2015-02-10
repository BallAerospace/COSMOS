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
      it "should initialize attributes" do
        @sp.bytes_read.should eql 0
        @sp.bytes_written.should eql 0
        @sp.interface.should be_nil
        @sp.stream.should be_nil
        @sp.post_read_data_callback.should be_nil
        @sp.post_read_packet_callback.should be_nil
        @sp.pre_write_packet_callback.should be_nil
      end
    end

    describe "interface=" do
      it "should set the interface" do
        class MyInterface1 < Interface; end
        interface = MyInterface1.new
        @sp.interface = interface
        @sp.interface.should eql interface
      end

      it "should set the post_read_data callback" do
        class MyInterface2 < Interface
          def post_read_data(buffer); 1; end
        end
        interface = MyInterface2.new
        @sp.interface = interface
        @sp.post_read_data_callback.call(nil).should eql 1
      end

      it "should set the post_read_packet callback" do
        class MyInterface3 < Interface
          def post_read_packet(packet); 2; end
        end
        interface = MyInterface3.new
        @sp.interface = interface
        @sp.post_read_packet_callback.call(nil).should eql 2
      end

      it "should set the pre_write_packet callback" do
        class MyInterface4 < Interface
          def pre_write_packet(packet); 3; end
        end
        interface = MyInterface4.new
        @sp.interface = interface
        @sp.pre_write_packet_callback.call(nil).should eql 3
      end
    end

    describe "connect" do
      it "should set the stream" do
        class MyStream1 < Stream; end
        stream = MyStream1.new
        allow(stream).to receive(:connect)
        @sp.connect(stream)
        @sp.stream.should eql stream
      end
    end

    describe "connected" do
      it "should return false if the stream hasn't been set" do
        @sp.connected?.should be_falsey
      end

      it "should return the status of the stream connection" do
        class MyStream2 < Stream
          def connect; end
          def connected?; true; end
        end
        stream = MyStream2.new
        @sp.connect(stream)
        @sp.connected?.should be_truthy
      end
    end

    describe "disconnect" do
      it "should call disconnect on the stream" do
        $test = false
        class MyStream3 < Stream
          def connect; end
          def disconnect; $test = true; end
        end
        stream = MyStream3.new
        @sp.connect(stream)
        $test.should be_falsey
        @sp.disconnect
        $test.should be_truthy
      end
    end

    describe "read" do
      it "should read data from the stream" do
        class MyStream33 < Stream
          def connect; end
          def connected?; true; end
          def read; "\x01\x02\x03\x04"; end
        end
        stream = MyStream33.new
        @sp.connect(stream)
        packet = @sp.read
        packet.length.should eql 4
      end

      it "should handle timeouts from the stream" do
        class MyStream4 < Stream
          def connect; end
          def connected?; true; end
          def read; raise Timeout::Error; end
        end
        stream = MyStream4.new
        @sp.connect(stream)
        @sp.read.should be_nil
      end

      it "should handle a sync pattern" do
        $read_cnt = 0
        class MyStream5 < Stream
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
        stream = MyStream5.new
        @sp.connect(stream)
        packet = @sp.read
        packet.length.should eql 4 # sync plus two bytes
      end

      it "should handle a sync pattern split across reads" do
        $read_cnt = 0
        class MyStream6 < Stream
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
        stream = MyStream6.new
        @sp.connect(stream)
        packet = @sp.read
        packet.length.should eql 3 # sync plus one byte
      end

      it "should handle a false positive sync pattern" do
        $read_cnt = 0
        class MyStream7 < Stream
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
        stream = MyStream7.new
        @sp.connect(stream)
        packet = @sp.read
        packet.length.should eql 3 # sync plus one byte
      end

      it "should discard leading bytes from the stream" do
        class MyStream8 < Stream
          def connect; end
          def connected?; true; end
          def read
            "\x01\x02\x03\x04"
          end
        end
        @sp = StreamProtocol.new(2, nil)
        stream = MyStream8.new
        @sp.connect(stream)
        packet = @sp.read
        packet.length.should eql 2
        packet.buffer.formatted.should match(/03 04/)
      end

      it "should call the post_read_data method on the inteface" do
        class MyStream9 < Stream
          def connect; end
          def connected?; true; end
          def read
            "\x01\x02\x03\x04"
          end
        end
        class MyInterface5 < Interface
          def post_read_data(buffer); "\x00\x01\x02\x03"; end
        end
        interface = MyInterface5.new
        @sp.interface = interface
        stream = MyStream9.new
        @sp.connect(stream)
        packet = @sp.read
        packet.length.should eql 4
        packet.buffer.formatted.should match(/00 01 02 03/)

        # Simulate the interface returning an empty string which means to skip
        # this packet and go back to reading data.
        $read_cnt = 0
        class MyInterface5 < Interface
          def post_read_data(buffer)
            $read_cnt += 1
            case $read_cnt
            when 1
              ""
            when 2
              "\x01\x02"
            end
          end
        end
        interface = MyInterface5.new
        @sp.interface = interface
        packet = @sp.read
        packet.length.should eql 2

        # Simulate the interface returning nil which means the connection is
        # lost.
        $read_cnt = 0
        class MyInterface5 < Interface
          def post_read_data(buffer); nil; end
        end
        interface = MyInterface5.new
        @sp.interface = interface
        packet = @sp.read
        packet.should be_nil
      end

      it "should call the post_read_packet method on the inteface" do
        class MyStream10 < Stream
          def connect; end
          def connected?; true; end
          def read
            "\x01\x02\x03\x04"
          end
        end
        class MyInterface6 < Interface
          def post_read_packet(packet)
            packet.buffer = "\x00\x01\x02\x03"
            packet
          end
        end
        interface = MyInterface6.new
        @sp.interface = interface
        stream = MyStream10.new
        @sp.connect(stream)
        packet = @sp.read
        packet.length.should eql 4
        packet.buffer.formatted.should match(/00 01 02 03/)
      end
    end

    describe "write" do
      it "should call pre_write_packet on the interface" do
        $buffer = ''
        class MyStream11 < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        class MyInterface7 < Interface
          def pre_write_packet(packet); "\x01\x02\x03\x04"; end
        end
        packet = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x00\x01\x02\x03")
        @sp.interface = MyInterface7.new
        @sp.connect(MyStream11.new)
        @sp.write(packet)
        $buffer.should eql "\x01\02\03\04"
      end

      it "should write the packet buffer to the stream" do
        $buffer = ''
        class MyStream11 < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        packet = Packet.new(nil, nil, :BIG_ENDIAN, nil, "\x01\x02\x03\x04")
        @sp.connect(MyStream11.new)
        @sp.write(packet)
        $buffer.should eql "\x01\02\03\04"
      end
    end

    describe "write_raw" do
      it "should write the raw buffer to the stream" do
        $buffer = ''
        class MyStream11 < Stream
          def connect; end
          def connected?; true; end
          def write(buffer) $buffer = buffer; end
        end
        @sp.connect(MyStream11.new)
        @sp.write_raw("\x01\x02\x03\x04")
        $buffer.should eql "\x01\02\03\04"
      end
    end

  end
end

