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
        expect(@psp.bytes_read).to eql 0
        expect(@psp.bytes_written).to eql 0
        expect(@psp.interface).to be_nil
        expect(@psp.stream).to be_nil
        expect(@psp.post_read_data_callback).to be_nil
        expect(@psp.post_read_packet_callback).to be_nil
        expect(@psp.pre_write_packet_callback).to be_nil
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
        expect($buffer[0..3].unpack('N')[0]).to eql time.to_f.to_i
        expect($buffer[4..7].unpack('N')[0]).to eql 500000
        offset = 8
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
        expect(packet.target_name).to eql 'COSMOS'
        expect(packet.packet_name).to eql 'VERSION'
        expect(packet.identified?).to be true
        expect(packet.defined?).to be false

        pkt2 = System.telemetry.update!("COSMOS","VERSION",packet.buffer)
        expect(pkt2.read('PKT_ID')).to eql 1
        expect(pkt2.read('COSMOS')).to eql 'TEST'
        expect(pkt2.identified?).to be true
        expect(pkt2.defined?).to be true
      end
    end

  end
end

