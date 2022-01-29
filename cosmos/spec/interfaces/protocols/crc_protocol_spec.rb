# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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
        ['ERROR', 0, nil].each do |strip_crc|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      strip_crc, # strip crc
                                      'ERROR', # bad strategy
                                      -16, # bit offset
                                      16
                                    ], # bit size
                                    :READ_WRITE)
          }.to raise_error(/Invalid strip CRC/)
        end
      end

      it "complains if bad strategy is not ERROR or DISCONNECT" do
        ['BAD', 0, nil].each do |strategy|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      'TRUE', # strip crc
                                      strategy, # bad strategy
                                      -16, # bit offset
                                      16
                                    ], # bit size
                                    :READ_WRITE)
          }.to raise_error(/Invalid bad CRC strategy/)
        end
      end

      it "complains if bit size is not 16, 32, or 64" do
        ['0', 0, nil].each do |bit_size|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      'TRUE', # strip crc
                                      'ERROR', # bad strategy
                                      128, # bit offset
                                      bit_size
                                    ], # bit size
                                    :READ_WRITE)
          }.to raise_error(/Invalid bit size/)
        end
      end

      it "accepts a string bit size of 16, 32, or 64" do
        %w(16 32 64).each do |bit_size|
          @interface.add_protocol(CrcProtocol, [
                                    nil, # item name
                                    'TRUE', # strip crc
                                    'ERROR', # bad strategy
                                    -32, # bit offset
                                    bit_size
                                  ], # bit size
                                  :READ_WRITE)
          expect(@interface.read_protocols[-1].instance_variable_get(:@bit_size)).to eq Integer(bit_size)
        end
      end

      it "complains if bit offset is not byte divisible" do
        [nil, 100, '100'].each do |offset|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      'TRUE', # strip crc
                                      'ERROR', # bad strategy
                                      offset, # bit offset
                                      16
                                    ], # bit size
                                    :READ_WRITE)
          }.to raise_error(/Invalid bit offset/)
        end
      end

      it "accepts a string for bit offset" do
        %w(0 32 -32).each do |offset|
          @interface.add_protocol(CrcProtocol, [
                                    nil, # item name
                                    'TRUE', # strip crc
                                    'ERROR', # bad strategy
                                    offset, # bit offset
                                    16
                                  ], # bit size
                                  :READ_WRITE)
          expect(@interface.read_protocols[-1].instance_variable_get(:@bit_offset)).to eq Integer(offset)
        end
      end

      it "complains if the endianness is not BIG_ENDIAN or LITTLE_ENDIAN" do
        ['ENDIAN', 0, nil].each do |endianness|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      'FALSE', # strip crc
                                      'ERROR', # bad strategy
                                      -16, # bit offset
                                      16, # bit size
                                      endianness, # endianness
                                      0xDEAD, # poly
                                      0x0, # seed
                                      'TRUE', # xor
                                      'TRUE', # reflect
                                    ],
                                    :READ_WRITE)
          }.to raise_error(/Invalid endianness/)
        end
      end

      it "complains if the poly is not a number" do
        ['TRUE', '123abc'].each do |poly|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      'FALSE', # strip crc
                                      'ERROR', # bad strategy
                                      -16, # bit offset
                                      16, # bit size
                                      'BIG_ENDIAN', # endianness
                                      poly, # poly
                                      0x0, # seed
                                      'TRUE', # xor
                                      'TRUE', # reflect
                                    ],
                                    :READ_WRITE)
          }.to raise_error(/Invalid poly/)
        end
      end

      it "accepts nil and numeric polynomials" do
        ['0xABCD', 0xABCD, nil, '', 'NIL', 'NULL'].each do |poly|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      'FALSE', # strip crc
                                      'ERROR', # bad strategy
                                      -16, # bit offset
                                      16, # bit size
                                      'BIG_ENDIAN', # endianness
                                      poly, # poly
                                      0x0, # seed
                                      'TRUE', # xor
                                      'TRUE', # reflect
                                    ],
                                    :READ_WRITE)
          }.to_not raise_error
        end
      end

      it "complains if the seed is not a number" do
        ['TRUE', '123abc'].each do |seed|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      'FALSE', # strip crc
                                      'ERROR', # bad strategy
                                      -16, # bit offset
                                      16, # bit size
                                      'LITTLE_ENDIAN', # endianness
                                      0xABCD, # poly
                                      seed, # seed
                                      'TRUE', # xor
                                      'TRUE', # reflect
                                    ],
                                    :READ_WRITE)
          }.to raise_error(/Invalid seed/)
        end
      end

      it "accepts nil and numeric seeds" do
        ['0xABCD', 0xABCD, nil, '', 'NIL', 'NULL'].each do |seed|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      'FALSE', # strip crc
                                      'ERROR', # bad strategy
                                      -16, # bit offset
                                      16, # bit size
                                      'BIG_ENDIAN', # endianness
                                      nil, # poly
                                      seed, # seed
                                      'TRUE', # xor
                                      'TRUE', # reflect
                                    ],
                                    :READ_WRITE)
          }.to_not raise_error
        end
      end

      it "accepts nil TRUE FALSE for xor" do
        [nil, '', 'NIL', 'NULL', 'TRUE', 'FALSE'].each do |xor|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      'FALSE', # strip crc
                                      'ERROR', # bad strategy
                                      -16, # bit offset
                                      16, # bit size
                                      'BIG_ENDIAN', # endianness
                                      0xABCD, # poly
                                      0, # seed
                                      xor, # xor
                                      'TRUE', # reflect
                                    ],
                                    :READ_WRITE)
          }.to_not raise_error
        end
      end

      it "complains if the xor is not boolean" do
        ['ERROR', 0].each do |xor|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      'FALSE', # strip crc
                                      'ERROR', # bad strategy
                                      -16, # bit offset
                                      16, # bit size
                                      'BIG_ENDIAN', # endianness
                                      0xABCD, # poly
                                      0, # seed
                                      xor, # xor
                                      'TRUE', # reflect
                                    ],
                                    :READ_WRITE)
          }.to raise_error(/Invalid XOR value/)
        end
      end

      it "accepts nil TRUE FALSE for reflect" do
        [nil, '', 'NIL', 'NULL', 'TRUE', 'FALSE'].each do |reflect|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      'FALSE', # strip crc
                                      'ERROR', # bad strategy
                                      -16, # bit offset
                                      16, # bit size
                                      'BIG_ENDIAN', # endianness
                                      0xABCD, # poly
                                      0, # seed
                                      'TRUE', # xor
                                      reflect, # reflect
                                    ],
                                    :READ_WRITE)
          }.to_not raise_error
        end
      end

      it "complains if the reflect is not boolean" do
        ['ERROR', 0].each do |reflect|
          expect {
            @interface.add_protocol(CrcProtocol, [
                                      nil, # item name
                                      'FALSE', # strip crc
                                      'ERROR', # bad strategy
                                      -16, # bit offset
                                      16, # bit size
                                      'BIG_ENDIAN', # endianness
                                      0xABCD, # poly
                                      0, # seed
                                      'TRUE', # xor
                                      reflect, # reflect
                                    ],
                                    :READ_WRITE)
          }.to raise_error(/Invalid reflect value/)
        end
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
                                  32
                                ], # bit size
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
                                  16
                                ], # bit size
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
                                  32
                                ], # bit size
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
                                  64
                                ], # bit size
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
                                  32
                                ], # bit size
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
                                  32
                                ], # bit size
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
                                  16
                                ], # bit size
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
                                  32
                                ], # bit size
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
                                  64
                                ], # bit size
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
                                  16
                                ], # bit size
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
                                  32
                                ], # bit size
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
                                  32
                                ], # bit size
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
                                  16
                                ], # bit size
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
                                  32
                                ], # bit size
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
                                  64
                                ], # bit size
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
                                  16
                                ], # bit size
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
                                  32
                                ], # bit size
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
                                  64
                                ], # bit size
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
