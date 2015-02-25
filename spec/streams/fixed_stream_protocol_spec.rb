# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/streams/fixed_stream_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos

  class MyInterface < Interface; end

  describe FixedStreamProtocol do
    before(:each) do
      @fsp = FixedStreamProtocol.new(1)
    end

    after(:each) do
      clean_config()
    end

    describe "initialize" do
      it "initializes attributes" do
        expect(@fsp.bytes_read).to eql 0
        expect(@fsp.bytes_written).to eql 0
        expect(@fsp.interface).to be_nil
        expect(@fsp.stream).to be_nil
        expect(@fsp.post_read_data_callback).to be_nil
        expect(@fsp.post_read_packet_callback).to be_nil
        expect(@fsp.pre_write_packet_callback).to be_nil
      end
    end

    describe "read" do
      it "complains if no interface set" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read; "\x01\x02\x03\x04"; end
        end
        stream = MyStream.new
        @fsp.connect(stream)
        expect { @fsp.read }.to raise_error(/Interface required/)
      end

      it "reads telemetry data from the stream" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read; "\x01\x02"; end
        end
        stream = MyStream.new
        @fsp.connect(stream)
        interface = MyInterface.new
        interface.target_names = %w(TEST COSMOS)
        @fsp.interface = interface
        packet = @fsp.read
        expect(packet.received_time.to_f).to be_within(0.1).of(Time.now.to_f)
        expect(packet.target_name).to eql 'COSMOS'
        expect(packet.packet_name).to eql 'VERSION'
        packet = @fsp.read
        expect(packet.received_time.to_f).to be_within(0.1).of(Time.now.to_f)
        expect(packet.target_name).to eql 'COSMOS'
        expect(packet.packet_name).to eql 'LIMITS_CHANGE'
        packet = @fsp.read
        expect(packet.received_time.to_f).to be_within(0.1).of(Time.now.to_f)
        expect(packet.target_name).to eql 'COSMOS'
        expect(packet.packet_name).to eql 'VERSION'
        packet = @fsp.read
        expect(packet.received_time.to_f).to be_within(0.1).of(Time.now.to_f)
        expect(packet.target_name).to eql 'COSMOS'
        expect(packet.packet_name).to eql 'LIMITS_CHANGE'
      end

      it "reads command data from the stream" do
        @fsp = FixedStreamProtocol.new(8, 0, '0x1ACFFC1D', false)

        $index = 0
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read
            case $index
            when 0
              $index += 1
              "\x1A\xCF\xFC\x1D\x00\x00\x00\x02"
            else
              "\x00\x00\x00\x00\x00\x00\x00\x00"
            end
          end
        end
        stream = MyStream.new
        @fsp.connect(stream)
        interface = MyInterface.new
        interface.target_names = %w(TEST COSMOS)
        @fsp.interface = interface
        packet = @fsp.read
        expect(packet.received_time.to_f).to be_within(0.01).of(Time.now.to_f)
        expect(packet.target_name).to eql 'COSMOS'
        expect(packet.packet_name).to eql 'STARTLOGGING'
      end
    end

  end
end

