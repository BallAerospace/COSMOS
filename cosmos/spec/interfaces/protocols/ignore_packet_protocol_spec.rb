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
require 'cosmos/interfaces/protocols/ignore_packet_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos
  describe IgnorePacketProtocol do
    before(:all) do
      setup_system()
    end

    before(:each) do
      $buffer = nil
      @interface = StreamInterface.new
      @interface.target_names = ['SYSTEM', 'INST']
      allow(@interface).to receive(:connected?) { true }
    end

    class PreStream < Stream
      def connect; end

      def connected?; true; end

      def disconnect; end

      def read; $buffer; end

      def write(data); $buffer = data; end
    end

    describe "initialize" do
      it "complains if target is not given" do
        expect { @interface.add_protocol(IgnorePacketProtocol, [], :READ_WRITE) }.to raise_error(ArgumentError)
      end

      it "complains if packet is not given" do
        expect { @interface.add_protocol(IgnorePacketProtocol, ['SYSTEM'], :READ_WRITE) }.to raise_error(ArgumentError)
      end

      it "complains if the target is not found" do
        expect { @interface.add_protocol(IgnorePacketProtocol, ['BLAH', 'META'], :READ_WRITE) }.to raise_error(/target 'BLAH' does not exist/)
      end

      it "complains if the target is not found" do
        expect { @interface.add_protocol(IgnorePacketProtocol, ['SYSTEM', 'BLAH'], :READ_WRITE) }.to raise_error(/packet 'SYSTEM BLAH' does not exist/)
      end
    end

    describe "read" do
      it "ignores the packet specified" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        pkt = System.telemetry.packet("SYSTEM", "META")
        # Ensure the ID items are set so this packet can be identified
        pkt.id_items.each do |item|
          pkt.write_item(item, item.id_value)
        end
        pkt.received_time = Time.now
        $buffer = nil
        @interface.write(pkt)
        # Verify the write went out
        expect(pkt.buffer).to eql $buffer
        # Verify we read the packet back
        packet = @interface.read
        expect(packet.buffer).to eql $buffer

        # Now add the protocol to ignore the packet
        @interface.add_protocol(IgnorePacketProtocol, ['SYSTEM', 'META'], :READ)
        $buffer = nil
        @interface.write(pkt)
        packet = nil
        # Try to read the interface
        # We put this in a thread because it calls it continuously
        thread = Thread.new do
          packet = @interface.read
        end
        sleep 0.1
        thread.kill
        sleep 0.2 # Allow thread to die
        expect(packet).to be_nil
      end

      it "can be added multiple times to ignore different packets" do
        @interface.instance_variable_set(:@stream, PreStream.new)

        pkt = System.telemetry.packet("INST", "HEALTH_STATUS")
        # Ensure the ID items are set so this packet can be identified
        pkt.id_items.each do |item|
          pkt.write_item(item, item.id_value)
        end
        pkt.received_time = Time.now
        $buffer = nil
        @interface.write(pkt)
        expect($buffer).to eql pkt.buffer

        # Verify we read the packet back
        packet = @interface.read
        expect(packet.buffer).to eql $buffer

        # Now add the protocol to ignore the packet
        @interface.add_protocol(IgnorePacketProtocol, ['INST', 'HEALTH_STATUS'], :READ)
        $buffer = nil
        @interface.write(pkt)
        expect($buffer).to eql pkt.buffer
        packet = nil
        # Try to read the interface
        # We put this in a thread because it calls it continuously
        thread = Thread.new do
          packet = @interface.read
        end
        sleep 0.1
        thread.kill
        sleep 0.2 # Allow thread to die
        expect(packet).to be_nil

        # Add another protocol to ignore another packet
        @interface.add_protocol(IgnorePacketProtocol, ['INST', 'ADCS'], :READ)

        pkt = System.telemetry.packet("INST", "ADCS")
        # Ensure the ID items are set so this packet can be identified
        pkt.id_items.each do |item|
          pkt.write_item(item, item.id_value)
        end
        pkt.received_time = Time.now
        $buffer = nil
        @interface.write(pkt)
        expect($buffer).to eql pkt.buffer

        packet = nil
        # Try to read the interface
        # We put this in a thread because it calls it continuously
        thread = Thread.new do
          packet = @interface.read
        end
        sleep 0.1
        thread.kill
        sleep 0.2 # Allow thread to die
        expect(packet).to be_nil

        pkt = System.telemetry.packet("INST", "PARAMS")
        # Ensure the ID items are set so this packet can be identified
        pkt.id_items.each do |item|
          pkt.write_item(item, item.id_value)
        end
        pkt.received_time = Time.now
        $buffer = nil
        @interface.write(pkt)
        # Verify the write went out
        expect($buffer).to eql pkt.buffer

        packet = @interface.read
        expect(packet.buffer).to eql pkt.buffer
      end
    end

    describe "write" do
      it "ignores the packet specified" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(IgnorePacketProtocol, ['SYSTEM', 'META'], :WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META")
        pkt.write("COSMOS_VERSION", "TEST")
        pkt.received_time = Time.now
        $buffer = nil
        @interface.write(pkt)
        # Verify the write was ignored
        expect($buffer).to be_nil

        # Verify reading the interface works
        $buffer = pkt.buffer
        packet = @interface.read
        expect(packet.buffer).to eql $buffer
      end

      it "can be added multiple times to ignore different packets" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(IgnorePacketProtocol, ['INST', 'HEALTH_STATUS'], :WRITE)
        @interface.add_protocol(IgnorePacketProtocol, ['INST', 'ADCS'], :WRITE)

        pkt = System.telemetry.packet("INST", "HEALTH_STATUS")
        pkt.received_time = Time.now
        $buffer = nil
        @interface.write(pkt)
        # Verify the write was ignored
        expect($buffer).to be_nil

        pkt = System.telemetry.packet("INST", "ADCS")
        pkt.received_time = Time.now
        $buffer = nil
        @interface.write(pkt)
        # Verify the write was ignored
        expect($buffer).to be_nil

        pkt = System.telemetry.packet("INST", "PARAMS")
        pkt.received_time = Time.now
        $buffer = nil
        @interface.write(pkt)
        # Verify the write went out
        expect($buffer).to eql pkt.buffer
      end
    end

    describe "read/write" do
      it "ignores the packet specified" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(IgnorePacketProtocol, ['SYSTEM', 'META'], :READ_WRITE)
        pkt = System.telemetry.packet("SYSTEM", "META")
        pkt.write("COSMOS_VERSION", "TEST")
        pkt.received_time = Time.now
        $buffer = nil
        @interface.write(pkt)
        # Verify the write was ignored
        expect($buffer).to be_nil

        packet = nil
        # Try to read the interface
        thread = Thread.new do
          packet = @interface.read
        end
        sleep 0.1
        thread.kill
        sleep 0.2 # Allow thread to die
        expect(packet).to be_nil
      end

      it "reads and writes unknown packets" do
        @interface.instance_variable_set(:@stream, PreStream.new)
        @interface.add_protocol(IgnorePacketProtocol, ['SYSTEM', 'META'], :READ_WRITE)
        $buffer = nil
        pkt = Packet.new("TGT", "PTK")
        pkt.append_item("ITEM", 8, :INT)
        pkt.write("ITEM", 33, :RAW)
        @interface.write(pkt)
        # Verify the write went out
        expect(pkt.buffer).to eql $buffer

        # Verify the read works
        packet = @interface.read
        expect(packet.buffer).to eq $buffer
      end
    end
  end
end
