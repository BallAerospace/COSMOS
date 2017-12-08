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

    describe "initialize" do
      it "complains if strip crc is not boolean" do
        expect { @interface.add_protocol(CrcProtocol, [
          nil, # item name
          '', # strip crc
          'ERROR', # bad strategy
          -16, # bit offset
           16], # bit size
          :READ_WRITE) }.to raise_error(/Invalid strip CRC/)
      end

      it "complains if bad strategy is not ERROR or DISCONNECT" do
        expect { @interface.add_protocol(CrcProtocol, [
          nil, # item name
          'TRUE', # strip crc
          '', # bad strategy
          -16, # bit offset
           16], # bit size
          :READ_WRITE) }.to raise_error(/Invalid bad CRC strategy/)
      end

      it "complains if bit size is not 16, 32, or 64" do
        expect { @interface.add_protocol(CrcProtocol, [
          nil, # item name
          'TRUE', # strip crc
          'ERROR', # bad strategy
          128, # bit offset
          8], # bit size
          :READ_WRITE) }.to raise_error( /Invalid bit size/)
      end

      it "complains if bit offset is not byte divisible" do
        expect { @interface.add_protocol(CrcProtocol, [
          nil, # item name
          'TRUE', # strip crc
          'ERROR', # bad strategy
          100, # bit offset
          16], # bit size
          :READ_WRITE) }.to raise_error(/Invalid bit offset/)
      end

      it "complains if the endianness is not a BIG_ENDIAN or LITTLE_ENDIAN" do
        expect { @interface.add_protocol(CrcProtocol, [
          nil, # item name
          'FALSE', # strip crc
          'ERROR', # bad strategy
          -16, # bit offset
          16, # bit size
          'TRUE', # endianness
          0xDEAD, # poly
          0x0, # seed
          'TRUE', # xor
          'TRUE', # reflect
          ],
          :READ_WRITE) }.to raise_error(/Invalid endianness/)
      end

      it "complains if the poly is not a number" do
        expect { @interface.add_protocol(CrcProtocol, [
          nil, # item name
          'FALSE', # strip crc
          'ERROR', # bad strategy
          -16, # bit offset
          16, # bit size
          'BIG_ENDIAN', # endianness
          'TRUE', # poly
          0x0, # seed
          'TRUE', # xor
          'TRUE', # reflect
          ],
          :READ_WRITE) }.to raise_error(/invalid value/)
      end

      it "complains if the seed is not a number" do
        expect { @interface.add_protocol(CrcProtocol, [
          nil, # item name
          'FALSE', # strip crc
          'ERROR', # bad strategy
          -16, # bit offset
          16, # bit size
          'LITTLE_ENDIAN', # endianness
          0xABCD, # poly
          'TRUE', # seed
          'TRUE', # xor
          'TRUE', # reflect
          ],
          :READ_WRITE) }.to raise_error(/invalid value/)
      end

      it "complains if the xor is not boolean" do
        expect { @interface.add_protocol(CrcProtocol, [
          nil, # item name
          'FALSE', # strip crc
          'ERROR', # bad strategy
          -16, # bit offset
          16, # bit size
          'BIG_ENDIAN', # endianness
          0xABCD, # poly
          0, # seed
          0, # xor
          'TRUE', # reflect
          ],
          :READ_WRITE) }.to raise_error(/Invalid XOR value/)
      end

      it "complains if the reflect is not boolean" do
        expect { @interface.add_protocol(CrcProtocol, [
          nil, # item name
          'FALSE', # strip crc
          'ERROR', # bad strategy
          -16, # bit offset
          16, # bit size
          'BIG_ENDIAN', # endianness
          0xABCD, # poly
          0, # seed
          'TRUE', # xor
          0, # reflect
          ],
          :READ_WRITE) }.to raise_error(/Invalid reflect value/)
      end
    end

    describe "read" do
      it "does nothing if protocol added as :WRITE" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          nil, # item name
          'FALSE', # strip crc
          'ERROR', # bad strategy
          -32, # bit offset
           32], # bit size
          :WRITE)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 32, :UINT)
        $buffer = "\x00\x01\x02\x03\x04\x05\x06\x07"

        expect(Logger).to_not receive(:error)
        packet = @interface.read
        expect(packet.buffer.length).to eql 8
        expect(packet.buffer).to eql $buffer
      end

      it "reads the 16 bit CRC field and compares to the CRC" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'FALSE', # strip crc
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
          'FALSE', # strip crc
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
          'FALSE', # strip crc
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

      context "with a specified CRC poly, seed, xor, and reflect" do
        it "reads the 16 bit CRC field and compares to the CRC" do
          @interface.instance_variable_set(:@stream, CrcStream.new)
          @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
          @interface.add_protocol(CrcProtocol, [
            'CRC', # item name
            'FALSE', # strip crc
            'ERROR', # bad strategy
            -16, # bit offset
            16, # bit size
            :BIG_ENDIAN, # endianness
            0x8005, # poly
            0x0, # seed
            'TRUE', # xor
            'TRUE', # reflect
            ],
            :READ_WRITE)
          @interface.target_names = ['TGT']
          packet = Packet.new('TGT', 'PKT')
          packet.append_item("DATA", 32, :UINT)
          packet.append_item("CRC", 16, :UINT)

          $buffer = "\x00\x01\x02\x03"
          crc16 = Crc16.new(0x8005, 0, true, true)
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
            'FALSE', # strip crc
            'ERROR', # bad strategy
            -32, # bit offset
            32, # bit size
            :BIG_ENDIAN, # endianness
            0x1EDC6F41, # poly
            0x0, # seed
            'FALSE', # xor
            'FALSE', # reflect
            ],
            :READ_WRITE)
          @interface.target_names = ['TGT']
          packet = Packet.new('TGT', 'PKT')
          packet.append_item("DATA", 32, :UINT)
          packet.append_item("CRC", 32, :UINT)

          $buffer = "\x00\x01\x02\x03"
          crc32 = Crc32.new(0x1EDC6F41, 0, false, false)
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
            'FALSE', # strip crc
            'ERROR', # bad strategy
            -64, # bit offset
            64, # bit size
            :BIG_ENDIAN, # endianness
            0x000000000000001B, # poly
            0x0, # seed
            'FALSE', # xor
            'FALSE', # reflect
            ],
            :READ_WRITE)
          @interface.target_names = ['TGT']
          packet = Packet.new('TGT', 'PKT')
          packet.append_item("DATA", 32, :UINT)
          packet.append_item("CRC", 64, :UINT)

          $buffer = "\x00\x01\x02\x03"
          crc64 = Crc64.new(0x000000000000001B, 0, false, false)
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
      end

      it "logs an error if the CRC does not match" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'FALSE', # strip crc
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
          expect(msg).to match("Invalid CRC detected!")
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
          'FALSE', # strip crc
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
          expect(msg).to match("Invalid CRC detected!")
        end
        packet = @interface.read
        expect(packet).to be_nil # thread disconnects when packet is nil
      end

      it "can strip the 16 bit CRC at the end" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'TRUE', # strip crc
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
          'TRUE', # strip crc
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
          'TRUE', # strip crc
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
          'TRUE', # strip crc
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
      it "does nothing if protocol added as :READ" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          nil, # item name
          'FALSE', # strip crc
          'ERROR', # bad strategy
          -32, # bit offset
           32], # bit size
          :READ)
        @interface.target_names = ['TGT']
        packet = Packet.new('TGT', 'PKT')
        packet.append_item("DATA", 32, :UINT)
        packet.append_item("CRC", 32, :UINT)
        packet.append_item("TRAILER", 32, :UINT)
        packet.buffer = "\x00\x01\x02\x03\x00\x00\x00\x00\x04\x05\x06\x07"
        @interface.write(packet)
        expect($buffer.length).to eql 12
        expect($buffer).to eql packet.buffer
      end

      it "complains if the item does not exist" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'MYCRC', # item name
          'FALSE', # strip crc
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
        expect { @interface.write(packet) }.to raise_error(/Packet item 'TGT PKT MYCRC' does not exist/)
      end

      it "calculates and writes the 16 bit CRC item" do
        @interface.instance_variable_set(:@stream, CrcStream.new)
        @interface.add_protocol(BurstProtocol, [], :READ_WRITE)
        @interface.add_protocol(CrcProtocol, [
          'CRC', # item name
          'FALSE', # strip crc
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
          'FALSE', # strip crc
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
          'FALSE', # strip crc
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
          'FALSE', # strip crc
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
          'FALSE', # strip crc
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
          'FALSE', # strip crc
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
