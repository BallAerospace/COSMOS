# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/protocols/fixed_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos
  describe FixedProtocol do
    before(:each) do
      @interface = StreamInterface.new
      allow(@interface).to receive(:connected?) { true }
      allow(@interface).to receive(:disconnect) { nil }
    end

    after(:each) do
      clean_config()
    end

    describe "initialize" do
      it "initializes attributes" do
        @interface.add_protocol(FixedProtocol, [2, 1, '0xDEADBEEF', false, true], :READ_WRITE)
        expect(@interface.read_protocols[0].instance_variable_get(:@data)).to eq ''
        expect(@interface.read_protocols[0].instance_variable_get(:@min_id_size)).to eq 2
        expect(@interface.read_protocols[0].instance_variable_get(:@discard_leading_bytes)).to eq 1
        expect(@interface.read_protocols[0].instance_variable_get(:@sync_pattern)).to eq "\xDE\xAD\xBE\xEF"
        expect(@interface.read_protocols[0].instance_variable_get(:@telemetry)).to be false
        expect(@interface.read_protocols[0].instance_variable_get(:@fill_fields)).to be true
      end
    end

    describe "read_data" do
      $index = 0
      class FixedStream < Stream
        def connect; end
        def connected?; true; end
        def read
          case $index
          when 0
            "\x00" # UNKNOWN
          when 1
            "\x01" # SYSTEM META
          when 2
            "\x02" # SYSTEM LIMITS
          end
        end
      end

      it "returns unknown packets" do
        @interface.add_protocol(FixedProtocol, [1], :READ)
        @interface.instance_variable_set(:@stream, FixedStream.new)
        @interface.target_names = ['SYSTEM']
        # Initialize the read with a packet identified as SYSTEM META
        $index = 1
        packet = @interface.read
        expect(packet.received_time.to_f).to_not eql 0.0
        expect(packet.target_name).to eql "SYSTEM"
        expect(packet.packet_name).to eql "META"
        expect(packet.buffer[0]).to eql "\x01"
        # Return zeros which will not be identified
        $index = 0
        packet = @interface.read
        expect(packet.received_time.to_f).to eql 0.0
        expect(packet.target_name).to eql nil
        expect(packet.packet_name).to eql nil
        expect(packet.buffer).to eql "\x00"
      end

      it "raises an exception if unknown packet" do
        @interface.add_protocol(FixedProtocol, [1, 0, nil, true, false, true], :READ)
        @interface.instance_variable_set(:@stream, FixedStream.new)
        @interface.target_names = ['SYSTEM']
        expect { @interface.read }.to raise_error(/Unknown data/)
      end

      it "handles targets with no defined telemetry" do
        @interface.add_protocol(FixedProtocol, [1], :READ)
        @interface.instance_variable_set(:@stream, FixedStream.new)
        @interface.target_names = ['BLAH']
        $index = 1
        packet = @interface.read
        expect(packet.received_time.to_f).to eql 0.0
        expect(packet.target_name).to eql nil
        expect(packet.packet_name).to eql nil
        expect(packet.buffer).to eql "\x01"
      end

      it "reads telemetry data from the stream" do
        @interface.add_protocol(FixedProtocol, [1], :READ_WRITE)
        @interface.instance_variable_set(:@stream, FixedStream.new)
        @interface.target_names = ['SYSTEM']
        $index = 1
        packet = @interface.read
        expect(packet.received_time.to_f).to be_within(0.1).of(Time.now.to_f)
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'META'
        $index = 2
        packet = @interface.read
        expect(packet.received_time.to_f).to be_within(0.1).of(Time.now.to_f)
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'LIMITS_CHANGE'
        $index = 1
        packet = @interface.read
        expect(packet.received_time.to_f).to be_within(0.1).of(Time.now.to_f)
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'META'
        $index = 2
        packet = @interface.read
        expect(packet.received_time.to_f).to be_within(0.1).of(Time.now.to_f)
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'LIMITS_CHANGE'
      end

      it "reads command data from the stream" do
        $index = 0
        class FixedStream2 < Stream
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
        @interface.add_protocol(FixedProtocol, [8, 0, '0x1ACFFC1D', false], :READ_WRITE)
        @interface.instance_variable_set(:@stream, FixedStream2.new)
        @interface.target_names = ['SYSTEM']
        packet = @interface.read
        expect(packet.received_time.to_f).to be_within(0.01).of(Time.now.to_f)
        expect(packet.target_name).to eql 'SYSTEM'
        expect(packet.packet_name).to eql 'STARTLOGGING'
      end
    end
  end
end
