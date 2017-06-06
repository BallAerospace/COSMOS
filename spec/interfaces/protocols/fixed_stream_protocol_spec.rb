# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/protocols/fixed_stream_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos
  describe FixedStreamProtocol do
    before(:each) do
      @interface = Interface.new
      @interface.extend(FixedStreamProtocol)
      allow(@interface).to receive(:connected?) { true }
    end

    after(:each) do
      clean_config()
    end

    describe "initialize" do
      it "initializes attributes" do
        @interface.configure_stream_protocol(2, 1, '0xDEADBEEF', false, true)
        expect(@interface.instance_variable_get(:@data)).to eq ''
        expect(@interface.instance_variable_get(:@min_id_size)).to eq 2
        expect(@interface.instance_variable_get(:@discard_leading_bytes)).to eq 1
        expect(@interface.instance_variable_get(:@sync_pattern)).to eq "\xDE\xAD\xBE\xEF"
        expect(@interface.instance_variable_get(:@telemetry_stream)).to be false
        expect(@interface.instance_variable_get(:@fill_fields)).to be true
      end
    end

    describe "read_data" do
      class FixedStream < Stream
        def connect; end
        def connected?; true; end
        def read; "\x01\x02"; end
      end

      it "reads telemetry data from the stream" do
        @interface.instance_variable_set(:@stream, FixedStream.new)
        @interface.configure_stream_protocol(1)
        @interface.target_names = ['SYSTEM']
        packet = @interface.read
        expect(packet.received_time.to_f).to be_within(0.1).of(Time.now.to_f)
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'META'
        packet = @interface.read
        expect(packet.received_time.to_f).to be_within(0.1).of(Time.now.to_f)
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'LIMITS_CHANGE'
        packet = @interface.read
        expect(packet.received_time.to_f).to be_within(0.1).of(Time.now.to_f)
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'META'
        packet = @interface.read
        expect(packet.received_time.to_f).to be_within(0.1).of(Time.now.to_f)
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'LIMITS_CHANGE'
      end

      it "reads command data from the stream" do
        $index = 0
        class FixedStream < Stream
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
        @interface.instance_variable_set(:@stream, FixedStream.new)
        @interface.configure_stream_protocol(8, 0, '0x1ACFFC1D', false)
        @interface.target_names = ['SYSTEM']
        packet = @interface.read
        expect(packet.received_time.to_f).to be_within(0.01).of(Time.now.to_f)
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'STARTLOGGING'
      end
    end
  end
end
