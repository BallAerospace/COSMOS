# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/streams/preidentified_stream_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos

  class MyInterface < Interface; end

  describe PreidentifiedStreamProtocol do
    before(:each) do
      @psp = PreidentifiedStreamProtocol.new
    end

    after(:all) do
      clean_config()
    end

    it "handles receiving a bad packet length" do
      @psp = PreidentifiedStreamProtocol.new(nil, 5)
      pkt = System.telemetry.packet("COSMOS","VERSION")
      class MyStream < Stream
        def connect; end
        def connected?; true; end
        def read; $buffer; end
        def write(data); $buffer = data; end
      end
      stream = MyStream.new
      @psp.connect(stream)
      time = Time.new(2020,1,31,12,15,30.5)
      pkt.received_time = time
      @psp.write(pkt)
      expect { packet = @psp.read }.to raise_error(RuntimeError)
    end

    describe "initialize" do
      it "initializes attributes" do
        @psp.bytes_read.should eql 0
        @psp.bytes_written.should eql 0
        @psp.interface.should be_nil
        @psp.stream.should be_nil
        @psp.post_read_data_callback.should be_nil
        @psp.post_read_packet_callback.should be_nil
        @psp.pre_write_packet_callback.should be_nil
      end
    end

    describe "write" do
      it "creates a packet header" do
        pkt = System.telemetry.packet("COSMOS","VERSION")
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read; $buffer; end
          def write(data); $buffer = data; end
        end
        stream = MyStream.new
        @psp.connect(stream)
        time = Time.new(2020,1,31,12,15,30.5)
        pkt.received_time = time
        @psp.write(pkt)
        $buffer[0..3].unpack('N')[0].should eql time.to_f.to_i
        $buffer[4..7].unpack('N')[0].should eql 500000
        offset = 8
        tgt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        $buffer[offset...(offset+tgt_name_length)].should eql 'COSMOS'
        offset += tgt_name_length
        pkt_name_length = $buffer[offset].unpack('C')[0]
        offset += 1 # for the length field
        $buffer[offset...(offset+pkt_name_length)].should eql 'VERSION'
        offset += pkt_name_length
        $buffer[offset..(offset+3)].unpack('N')[0].should eql pkt.buffer.length
        offset += 4
        $buffer[offset..-1].should eql pkt.buffer
      end
    end

    describe "read" do
      it "returns a packet" do
        pkt = System.telemetry.packet("COSMOS","VERSION")
        pkt.write("PKT_ID", 1)
        pkt.write("COSMOS", "TEST")
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read; $buffer; end
          def write(data); $buffer = data; end
        end
        stream = MyStream.new
        @psp.connect(stream)
        time = Time.new(2020,1,31,12,15,30.5)
        pkt.received_time = time
        @psp.write(pkt)
        packet = @psp.read
        packet.target_name.should eql 'COSMOS'
        packet.packet_name.should eql 'VERSION'
        packet.identified?.should be_truthy
        packet.defined?.should be_falsey

        pkt2 = System.telemetry.update!("COSMOS","VERSION",packet.buffer)
        pkt2.read('PKT_ID').should eql 1
        pkt2.read('COSMOS').should eql 'TEST'
        pkt2.identified?.should be_truthy
        pkt2.defined?.should be_truthy
      end
    end

  end
end

