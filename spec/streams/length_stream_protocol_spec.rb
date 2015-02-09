# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/streams/length_stream_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos

  describe LengthStreamProtocol do
    describe "initialize" do
      it "should initialize attributes" do
        lsp = LengthStreamProtocol.new(1)
        lsp.bytes_read.should eql 0
        lsp.bytes_written.should eql 0
        lsp.interface.should be_nil
        lsp.stream.should be_nil
        lsp.post_read_data_callback.should be_nil
        lsp.post_read_packet_callback.should be_nil
        lsp.pre_write_packet_callback.should be_nil
      end
    end

    describe "read" do
      it "should read BIG_ENDIAN length fields from the stream" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read
            case $index
            when 0
              $index += 1
              $buffer1
            when 1
              $buffer2
            end
          end
        end
        stream = MyStream.new

        lsp = LengthStreamProtocol.new(16, # bit offset
                                        16, # bit size
                                        1,  # length offset
                                        1,  # bytes per count
                                        'BIG_ENDIAN')
        lsp.connect(stream)
        $index = 0
        $buffer1 = "\x00\x01\x00\x05"
        $buffer2 = "\x03\x04"
        packet = lsp.read
        packet.buffer.length.should eql 6

        lsp = LengthStreamProtocol.new(16, # bit offset
                                        16, # bit size
                                        1,  # length offset
                                        2,  # bytes per count
                                        'BIG_ENDIAN')
        lsp.connect(stream)
        $index = 0
        $buffer1 = "\x00\x01\x00\x05"
        $buffer2 = "\x03\x04\x05\x06\x07\x08\x09"
        packet = lsp.read
        packet.buffer.length.should eql 11

        lsp = LengthStreamProtocol.new(19, # bit offset
                                        5,  # bit size
                                        0,  # length offset
                                        1,  # bytes per count
                                        'BIG_ENDIAN')
        lsp.connect(stream)
        $index = 0
        $buffer1 = "\x00\x01\x05"
        $buffer2 = "\x03\x04"
        packet = lsp.read
        packet.buffer.length.should eql 5

        lsp = LengthStreamProtocol.new(16, # bit offset
                                        16, # bit size
                                        1,  # length offset
                                        1,  # bytes per count
                                        'BIG_ENDIAN',
                                        0,
                                        nil,
                                        50)
        lsp.connect(stream)
        $index = 0
        $buffer1 = "\x00\x01\xFF\xFF"
        $buffer2 = "\x03\x04"
        expect { packet = lsp.read }.to raise_error(RuntimeError, "Length value received larger than max_length: 65535 > 50")
      end

      it "should read LITTLE_ENDIAN length fields from the stream" do
        class MyStream < Stream
          def connect; end
          def connected?; true; end
          def read
            case $index
            when 0
              $index += 1
              $buffer1
            when 1
              $buffer2
            end
          end
        end
        stream = MyStream.new

        lsp = LengthStreamProtocol.new(16, # bit offset
                                        16, # bit size
                                        1,  # length offset
                                        1,  # bytes per count
                                        'LITTLE_ENDIAN')
        lsp.connect(stream)
        $index = 0
        $buffer1 = "\x00\x01\x05\x00"
        $buffer2 = "\x03\x04"
        packet = lsp.read
        packet.buffer.length.should eql 6

        lsp = LengthStreamProtocol.new(16, # bit offset
                                        16, # bit size
                                        1,  # length offset
                                        2,  # bytes per count
                                        'LITTLE_ENDIAN')
        lsp.connect(stream)
        $index = 0
        $buffer1 = "\x00\x01\x05\x00"
        $buffer2 = "\x03\x04\x05\x06\x07\x08\x09"
        packet = lsp.read
        packet.buffer.length.should eql 11

        lsp = LengthStreamProtocol.new(19, # bit offset
                                        5,  # bit size
                                        0,  # length offset
                                        1,  # bytes per count
                                        'LITTLE_ENDIAN')
        lsp.connect(stream)
        $index = 0
        $buffer1 = "\x00\x01\x05"
        $buffer2 = "\x03\x04"
        packet = lsp.read
        packet.buffer.length.should eql 5

        lsp = LengthStreamProtocol.new(16, # bit offset
                                        16, # bit size
                                        1,  # length offset
                                        1,  # bytes per count
                                        'LITTLE_ENDIAN',
                                        0,
                                        nil,
                                        239)
        lsp.connect(stream)
        $index = 0
        $buffer1 = "\x00\x01\xF0\x00"
        $buffer2 = "\x03\x04"
        expect { packet = lsp.read }.to raise_error(RuntimeError, "Length value received larger than max_length: 240 > 239")
      end
    end

    describe "write" do
      it "should fill the length field and sync pattern if told to" do
        class MyStream < Stream
          def connect; end
          @@written_data = nil
          def self.written_data
            @@written_data
          end
          def connected?; true; end
          def write(data)
            @@written_data = data
          end
        end
        stream = MyStream.new

        lsp = LengthStreamProtocol.new(32, # bit offset
                                        16, # bit size
                                        6,  # length offset
                                        2,  # bytes per count
                                        'BIG_ENDIAN',
                                        0,  # discard no leading bytes
                                        "BA5EBA11",
                                        nil,
                                        true)

        lsp.connect(stream)
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04"
        # 4 bytes are not enough since we expect the length field at offset 32
        expect { lsp.write(packet) }.to raise_error(ArgumentError, /buffer insufficient/)

        lsp = LengthStreamProtocol.new(32, # bit offset
                                        16, # bit size
                                        6,  # length offset
                                        2,  # bytes per count
                                        'BIG_ENDIAN',
                                        2,  # discard 2 leading bytes
                                        "BA5EBA11",
                                        nil,
                                        true)

        lsp.connect(stream)
        packet = Packet.new(nil, nil)
        # The packet buffer contains data
        packet.buffer = "\x01\x02\x03\x04"
        lsp.write(packet)
        # Since we discarded 2 leading bytes, they are put back in the final stream data
        # with the sync word and then then length is set to 0
        MyStream.written_data.should eql("\xBA\x5E\xBA\x11\x00\x00")
        packet.buffer.should eql("\x01\x02\x00\x00")

        lsp = LengthStreamProtocol.new(32, # bit offset
                                        16, # bit size
                                        6,  # length offset
                                        2,  # bytes per count
                                        'BIG_ENDIAN',
                                        4,  # discard 4 leading bytes
                                        "BA5EBA11",
                                        nil,
                                        true)

        lsp.connect(stream)
        packet = Packet.new(nil, nil)
        # The packet buffer contains data
        packet.buffer = "\x01\x02\x03\x04"
        lsp.write(packet)
        # Since we discarded 4 leading bytes, they are put back in the final stream data
        # with the sync word and then then length is set to 1 followed by the
        # last two bytes in the buffer. The \x01\x02 get written over by the length.
        MyStream.written_data.should eql("\xBA\x5E\xBA\x11\x00\x01\x03\x04")
        packet.buffer.should eql("\x00\x01\x03\x04")

        lsp = LengthStreamProtocol.new(32, # bit offset
                                        16, # bit size
                                        6,  # length offset
                                        2,  # bytes per count
                                        'BIG_ENDIAN',
                                        6,  # discard 6 leading bytes (sync and length)
                                        "BA5EBA11",
                                        nil,
                                        true)

        lsp.connect(stream)
        packet = Packet.new(nil, nil)
        # The packet buffer contains only the data
        packet.buffer = "\x01\x02\x03\x04"
        lsp.write(packet)
        # Since we discarded 6 leading bytes, they are put back in the final stream data
        # with the sync word and then then length is set to 2 followed by the buffer data.
        MyStream.written_data.should eql("\xBA\x5E\xBA\x11\x00\x02\x01\x02\x03\x04")
        packet.buffer.should eql("\x01\x02\x03\x04")

        lsp = LengthStreamProtocol.new(64, # bit offset
                                        32, # bit size
                                        12, # length offset
                                        1,  # bytes per count
                                        'BIG_ENDIAN',
                                        8,  # discard 8 leading bytes (sync)
                                        "BA5EBA11CAFEBABE",
                                        nil,
                                        true)
        lsp.connect(stream)
        packet = Packet.new(nil, nil)
        # The packet buffer contains the length field which is overwritten by the write call
        packet.buffer = "\x00\x00\x00\x00\x01\x02\x03\x04"
        lsp.write(packet)
        # Since we discarded 8 leading bytes, they are put back in the final stream data
        MyStream.written_data.should eql("\xBA\x5E\xBA\x11\xCA\xFE\xBA\xBE\x00\x00\x00\x04\x01\x02\x03\x04")
        packet.buffer.should eql("\x00\x00\x00\x04\x01\x02\x03\x04")

        lsp = LengthStreamProtocol.new(64, # bit offset
                                        32, # bit size
                                        12, # length offset
                                        1,  # bytes per count
                                        'BIG_ENDIAN',
                                        0,  # discard no leading bytes
                                        "BA5EBA11CAFEBABE",
                                        nil,
                                        true)
        lsp.connect(stream)
        packet = Packet.new(nil, nil)
        # The packet buffer contains the sync and length fields which are overwritten by the write call
        packet.buffer = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04"
        lsp.write(packet)
        # Since we discarded 0 leading bytes, they are simply written over by the write call
        MyStream.written_data.should eql("\xBA\x5E\xBA\x11\xCA\xFE\xBA\xBE\x00\x00\x00\x04\x01\x02\x03\x04")
        packet.buffer.should eql("\xBA\x5E\xBA\x11\xCA\xFE\xBA\xBE\x00\x00\x00\x04\x01\x02\x03\x04")
      end
    end

  end
end

