# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/protocols/crc_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos
  describe CrcProtocol do
    let(:crc16) { Crc16.new() }
    let(:crc32) { Crc32.new() }
    let(:crc64) { Crc64.new() }

    class CrcStream < Stream
      def connect; end
      def connected?; true; end
      def disconnect; end
      def read; $buffer; end
      def write(data); $buffer = data; end
    end

    before(:each) do
      @interface = StreamInterface.new
      allow(@interface).to receive(:connected?) { true }
      $buffer = ''
    end

    describe "read" do
      it "reads the 16 bit CRC field and compares to the CRC" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'KEEP_ON_READ', # append remove
          'ERROR', # bad strategy
          -16, # bit offset
           16], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 16, :UINT)

        $buffer = "\x00\x01\x02\x03"
        crc = crc16.calc($buffer)
        $buffer << [crc].pack("n")

        expect(Logger).to_not receive(:error)
        packet = @interface.read
        expect(packet.buffer.length).to eql 6
        expect(packet.buffer).to eql $buffer
      end

      it "reads the 32 bit CRC field and compares to the CRC" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'KEEP_ON_READ', # append remove
          'ERROR', # bad strategy
          -32, # bit offset
           32], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 32, :UINT)

        $buffer = "\x00\x01\x02\x03"
        crc = crc32.calc($buffer)
        $buffer << [crc].pack("N")

        expect(Logger).to_not receive(:error)
        packet = @interface.read
        expect(packet.buffer.length).to eql 8
        expect(packet.buffer).to eql $buffer
      end

      it "reads the 64 bit CRC field and compares to the CRC" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'KEEP_ON_READ', # append remove
          'ERROR', # bad strategy
          -64, # bit offset
           64], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 64, :UINT)

        $buffer = "\x00\x01\x02\x03"
        crc = crc64.calc($buffer)
        top_crc = crc >> 32
        bottom_crc = crc & 0xFFFFFFFF
        $buffer << [top_crc].pack("N")
        $buffer << [bottom_crc].pack("N")

        expect(Logger).to_not receive(:error)
        packet = @interface.read
        expect(packet.buffer.length).to eql 12
        expect(packet.buffer).to eql $buffer
      end

      it "logs an error if the CRC does not match" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'KEEP_ON_READ', # append remove
          'ERROR', # bad strategy
          -32, # bit offset
           32], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 32, :UINT)

        $buffer = "\x00\x01\x02\x03"
        crc = crc32.calc($buffer)
        $buffer << [crc].pack("N")
        $buffer[0] = "\x01"

        expect(Logger).to receive(:error) do |msg|
          expect(msg).to match "Invalid CRC detected!"
        end
        packet = @interface.read
        expect(packet.buffer.length).to eql 8
        expect(packet.buffer).to eql $buffer
      end

      it "disconnects if the CRC does not match" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'KEEP_ON_READ', # append remove
          'DISCONNECT', # bad strategy
          -32, # bit offset
           32], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 32, :UINT)

        $buffer = "\x00\x01\x02\x03"
        crc = crc32.calc($buffer)
        $buffer << [crc].pack("N")
        $buffer[0] = "\x01"

        expect(Logger).to receive(:error) do |msg|
          expect(msg).to match "Invalid CRC detected!"
        end
        packet = @interface.read
        expect(packet).to be_nil # thread disconnects when packet is nil
      end

      it "can strip the 16 bit CRC at the end" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'STRIP_ON_READ', # append remove
          'ERROR', # bad strategy
          -16, # bit offset
           16], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 16, :UINT)

        $buffer = "\x00\x01\x02\x03"
        crc = crc16.calc($buffer)
        $buffer << [crc].pack("n")

        expect(Logger).to_not receive(:error)
        packet = @interface.read
        expect(packet.buffer.length).to eql 4
        expect(packet.buffer).to eql $buffer[0..3]
      end

      it "can strip the 32 bit CRC at the end" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'STRIP_ON_READ', # append remove
          'ERROR', # bad strategy
          -32, # bit offset
           32], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 32, :UINT)

        $buffer = "\x00\x01\x02\x03"
        crc = crc32.calc($buffer)
        $buffer << [crc].pack("N")

        expect(Logger).to_not receive(:error)
        packet = @interface.read
        expect(packet.buffer.length).to eql 4
        expect(packet.buffer).to eql $buffer[0..3]
      end

      it "can strip the 64 bit CRC at the end" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'STRIP_ON_READ', # append remove
          'ERROR', # bad strategy
          -64, # bit offset
           64], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 64, :UINT)

        $buffer = "\x00\x01\x02\x03"
        crc = crc64.calc($buffer)
        top_crc = crc >> 32
        bottom_crc = crc & 0xFFFFFFFF
        $buffer << [top_crc].pack("N")
        $buffer << [bottom_crc].pack("N")

        expect(Logger).to_not receive(:error)
        packet = @interface.read
        expect(packet.buffer.length).to eql 4
        expect(packet.buffer).to eql $buffer[0..3]
      end

      it "can strip the 32 bit CRC in the middle" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'STRIP_ON_READ', # append remove
          'ERROR', # bad strategy
          32, # bit offset
          16], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 16, :UINT)
        packet.append_item("TRAILER", 16, :UINT)

        $buffer = "\x00\x01\x02\x03"
        crc = crc16.calc($buffer)
        $buffer << [crc].pack("n")
        $buffer << "\x04\x05"

        expect(Logger).to_not receive(:error)
        packet = @interface.read
        expect(packet.buffer.length).to eql 6
        expect(packet.buffer).to eql "\x00\x01\x02\x03\x04\x05"
      end
    end

    describe "write" do
      it "calculates and writes the 16 bit CRC item" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'KEEP_ON_READ', # append remove
          'ERROR', # bad strategy
          -48, # bit offset
           16], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 16, :UINT)
        packet.append_item("TRAILER", 32, :UINT)
        packet.buffer = "\x00\x01\x02\x03\x00\x00\x04\x05\x06\x07"
        @interface.write(packet)
        buffer = "\x00\x01\x02\x03"
        buffer << [crc16.calc("\x00\x01\x02\x03")].pack("n")
        buffer << "\x04\x05\x06\x07"
        expect($buffer).to eql buffer
      end

      it "calculates and writes the 32 bit CRC item" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'KEEP_ON_READ', # append remove
          'ERROR', # bad strategy
          -32, # bit offset
           32], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 32, :UINT)
        packet.append_item("TRAILER", 32, :UINT)
        packet.buffer = "\x00\x01\x02\x03\x00\x00\x00\x00\x04\x05\x06\x07"
        @interface.write(packet)
        buffer = "\x00\x01\x02\x03"
        buffer << [crc32.calc("\x00\x01\x02\x03")].pack("N")
        buffer << "\x04\x05\x06\x07"
        expect($buffer).to eql buffer
      end

      it "calculates and writes the 64 bit CRC item" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'KEEP_ON_READ', # append remove
          'ERROR', # bad strategy
          -64, # bit offset
           64], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 64, :UINT)
        packet.append_item("TRAILER", 32, :UINT)
        packet.buffer = "\x00\x01\x02\x03\x00\x00\x00\x00\x00\x00\x00\x00\x04\x05\x06\x07"
        @interface.write(packet)
        buffer = "\x00\x01\x02\x03"
        crc = crc64.calc(buffer)
        top_crc = crc >> 32
        bottom_crc = crc & 0xFFFFFFFF
        buffer << [top_crc].pack("N")
        buffer << [bottom_crc].pack("N")
        buffer << "\x04\x05\x06\x07"
        expect($buffer).to eql buffer
      end

      it "appends the 16 bit CRC to the end" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          nil, # item name nil means append
          'KEEP_ON_READ', # append remove
          'ERROR', # bad strategy
          -16, # bit offset
           16], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 32, :UINT)
        packet.append_item("TRAILER", 32, :UINT)
        packet.buffer = "\x00\x01\x02\x03\x00\x00\x00\x00\x04\x05\x06\x07"
        buffer = packet.buffer
        buffer << [crc16.calc(packet.buffer)].pack("n")
        @interface.write(packet)
        expect($buffer.length).to eql 14
        expect($buffer).to eql buffer
      end

      it "appends the 32 bit CRC to the end" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          nil, # item name nil means append
          'KEEP_ON_READ', # append remove
          'ERROR', # bad strategy
          -32, # bit offset
           32], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 32, :UINT)
        packet.append_item("TRAILER", 32, :UINT)
        packet.buffer = "\x00\x01\x02\x03\x00\x00\x00\x00\x04\x05\x06\x07"
        buffer = packet.buffer
        buffer << [crc32.calc(packet.buffer)].pack("N")
        @interface.write(packet)
        expect($buffer.length).to eql 16
        expect($buffer).to eql buffer
      end

      it "appends the 64 bit CRC to the end" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          nil, # item name nil means append
          'KEEP_ON_READ', # append remove
          'ERROR', # bad strategy
          -64, # bit offset
           64], # bit size
          :READ_WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 32, :UINT)
        packet.append_item("TRAILER", 32, :UINT)
        packet.buffer = "\x00\x01\x02\x03\x00\x00\x00\x00\x04\x05\x06\x07"
        buffer = packet.buffer
        crc = crc64.calc(buffer)
        top_crc = crc >> 32
        bottom_crc = crc & 0xFFFFFFFF
        buffer << [top_crc].pack("N")
        buffer << [bottom_crc].pack("N")
        @interface.write(packet)
        expect($buffer.length).to eql 20
        expect($buffer).to eql buffer
      end
    end
  end
end
