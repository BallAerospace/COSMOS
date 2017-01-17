# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/protocols/length_stream_protocol'
require 'cosmos/interfaces/interface'
require 'cosmos/streams/stream'

module Cosmos
  describe LengthStreamProtocol do
    class LengthStream < Stream
      def connect; end
      def connected?; true; end
      def disconnect; end
      def read; $buffer; end
      def write(data); $buffer = data; end
    end

    before(:each) do
      @interface = Interface.new
      @interface.extend(LengthStreamProtocol)
      allow(@interface).to receive(:connected?) { true }
      $buffer = ''
    end

    describe "initialize" do
      it "initializes attributes" do
        @interface.configure_stream_protocol(16, 32, 16, 2, 'LITTLE_ENDIAN', 2, '0xDEADBEEF', 100, true)
        expect(@interface.instance_variable_get(:@data)).to eq ''
        expect(@interface.instance_variable_get(:@length_bit_offset)).to eq 16
        expect(@interface.instance_variable_get(:@length_bit_size)).to eq 32
        expect(@interface.instance_variable_get(:@length_value_offset)).to eq 16
        expect(@interface.instance_variable_get(:@length_bytes_per_count)).to eq 2
        expect(@interface.instance_variable_get(:@length_endianness)).to eq :LITTLE_ENDIAN
        expect(@interface.instance_variable_get(:@discard_leading_bytes)).to eq 2
        expect(@interface.instance_variable_get(:@sync_pattern)).to eq "\xDE\xAD\xBE\xEF"
        expect(@interface.instance_variable_get(:@max_length)).to be 100
        expect(@interface.instance_variable_get(:@fill_fields)).to be true
      end
    end

    describe "read" do
      it "reads LITTLE_ENDIAN length fields from the stream" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(16, # bit offset
                                             16, # bit size
                                             0,  # length offset
                                             1,  # bytes per count
                                             'LITTLE_ENDIAN')
        $buffer = "\x00\x01\x06\x00\x03\x04"
        packet = @interface.read
        expect(packet.buffer.length).to eql 6
      end

      it "reads LITTLE_ENDIAN bit fields from the stream" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(19, # bit offset
                                             5,  # bit size
                                             0,  # length offset
                                             1,  # bytes per count
                                             'LITTLE_ENDIAN')
        $buffer = "\x00\x01\x05\x03\x04"
        packet = @interface.read
        expect(packet.buffer.length).to eql 5
      end

      it "adjusts length by offset" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(16, # bit offset
                                             16, # bit size
                                             1, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN')
        $buffer = "\x00\x01\x00\x05\x03\x04"
        packet = @interface.read
        expect(packet.buffer.length).to eql 6
      end

      it "adjusts length by bytes per count" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(16, # bit offset
                                             16, # bit size
                                             1, # length offset
                                             2, # bytes per count
                                             'BIG_ENDIAN')
        $buffer = "\x00\x01\x00\x05\x03\x04\x05\x06\x07\x08\x09"
        packet = @interface.read
        expect(packet.buffer.length).to eql 11
      end

      it "accesses length at odd offset and bit sizes" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(19, # bit offset
                                             5, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN')
        $buffer = "\x00\x01\x05\x03\x04"
        packet = @interface.read
        expect(packet.buffer.length).to eql 5
      end

      it "validates length against the maximum length" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(16, # bit offset
                                             16, # bit size
                                             0,  # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             0, # discard
                                             nil, # sync
                                             50) # max_length
        $buffer = "\x00\x01\xFF\xFF\x03\x04"
        expect { packet = @interface.read }.to raise_error(RuntimeError, "Length value received larger than max_length: 65535 > 50")
      end

      it "handles a sync value in the packet" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(16, # bit offset
                                             16, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             0, # discard
                                             "DEAD") # sync
        $buffer = "\x00\xDE\xAD\x00\x08\x01\x02\x03\x04\x05\x06"
        packet = @interface.read
        expect(packet.buffer).to eql("\xDE\xAD\x00\x08\x01\x02\x03\x04")
      end

      it "handles a sync value that is discarded" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(16, # bit offset (past the discard)
                                             16, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             2, # discard
                                             "DEAD") # sync
        $buffer = "\x00\xDE\xAD\x00\x08\x01\x02\x03\x04\x05\x06\x07\x08"
        packet = @interface.read
        expect(packet.buffer).to eql("\x00\x08\x01\x02\x03\x04")
      end

      it "handles a length value that is discarded" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(8, # bit offset
                                             16, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             4, # discard
                                             nil) # sync
        $buffer = "\x00\x00\x08\x00\x01\x02\x03\x04\x05\x06\x07\x08"
        packet = @interface.read
        expect(packet.buffer).to eql("\x01\x02\x03\x04")
      end

      it "handles a sync and length value that are discarded" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(16, # bit offset
                                             8, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             4, # discard
                                             'DEAD') # sync
        $buffer = "\x00\xDE\xAD\x0A\x00\x01\x02\x03\x04\x05\x06\x07\x08"
        packet = @interface.read
        expect(packet.buffer).to eql("\x01\x02\x03\x04\x05\x06")
      end
    end

    describe "write" do
      it "sends data directly to the stream if no fill" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(32, # bit offset
                                             16, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             0, # discard no leading bytes
                                             "DEAD", # sync
                                             nil, # max length
                                             false) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02"
        @interface.write(packet)
        expect($buffer).to eql("\x01\x02")
      end

      it "complains if not enough data to write the sync and length fields" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(32, # bit offset
                                             16, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             0, # discard no leading bytes
                                             "DEAD", # sync
                                             nil, # max length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04"
        # 4 bytes are not enough since we expect the length field at offset 32
        expect { @interface.write(packet) }.to raise_error(ArgumentError, /buffer insufficient/)
      end

      it "adjusts length by offset" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(16, # bit offset
                                             16, # bit size
                                             2, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             0, # discard no leading bytes
                                             nil, # sync
                                             nil, # max length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04\x05\x06"
        @interface.write(packet)
        # Length is 4 instead of 6 due to length offset
        expect(packet.buffer).to eql("\x01\x02\x00\x04\x05\x06")
        expect($buffer).to eql("\x01\x02\x00\x04\x05\x06")
      end

      it "adjusts length by bytes per count" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(0, # bit offset
                                             16, # bit size
                                             0, # length offset
                                             2, # bytes per count
                                             'BIG_ENDIAN',
                                             0, # discard no leading bytes
                                             nil, # sync
                                             nil, # max length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04\x05\x06"
        @interface.write(packet)
        # Length is 3 instead of 6 due to bytes per count
        expect(packet.buffer).to eql("\x00\x03\x03\x04\x05\x06")
        expect($buffer).to eql("\x00\x03\x03\x04\x05\x06")
      end

      it "writes length at odd offset and bit sizes" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(19, # bit offset
                                             5, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             0, # discard no leading bytes
                                             nil, # sync
                                             nil, # max length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x55\xAA\x00\xAA\x55\xAA"
        @interface.write(packet)
        expect(packet.buffer).to eql("\x55\xAA\x06\xAA\x55\xAA")
        expect($buffer).to eql("\x55\xAA\x06\xAA\x55\xAA")
      end

      it "validates length against the maximum length" do
        # Length inside packet
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(0, # bit offset
                                             16, # bit size
                                             0,  # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             0, # discard
                                             nil, # sync
                                             4, # max_length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04\x05\x06"
        expect { packet = @interface.write(packet)}.to raise_error(RuntimeError, "Calculated buffer length 6 larger than max_length 4")

        # Length outside packet (data stream)
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(0, # bit offset
                                             16, # bit size
                                             0,  # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             2, # discard
                                             nil, # sync
                                             4, # max_length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04\x05\x06"
        expect { packet = @interface.write(packet)}.to raise_error(RuntimeError, "Calculated buffer length 6 larger than max_length 4")
      end

      it "inserts the sync and length fields into the packet" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(16, # bit offset
                                             16, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             0, # discard no leading bytes
                                             "DEAD", # sync
                                             nil, # max length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04\x05\x06\x07\x08"
        @interface.write(packet)
        expect(packet.buffer).to eql("\xDE\xAD\x00\x08\x05\x06\x07\x08")
        expect($buffer).to eql("\xDE\xAD\x00\x08\x05\x06\x07\x08")

        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(64, # bit offset
                                             32, # bit size
                                             12, # length offset
                                             1,  # bytes per count
                                             'BIG_ENDIAN',
                                             0,  # discard no leading bytes
                                             "BA5EBA11CAFEBABE",
                                             nil,
                                             true)
        packet = Packet.new(nil, nil)
        # The packet buffer contains the sync and length fields which are overwritten by the write call
        packet.buffer = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04"
        @interface.write(packet)
        # Since we discarded 0 leading bytes, they are simply written over by the write call
        expect(packet.buffer).to eql("\xBA\x5E\xBA\x11\xCA\xFE\xBA\xBE\x00\x00\x00\x04\x01\x02\x03\x04")
        expect($buffer).to eql("\xBA\x5E\xBA\x11\xCA\xFE\xBA\xBE\x00\x00\x00\x04\x01\x02\x03\x04")
      end

      it "inserts the length field into the packet and sync into data stream" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(16, # bit offset
                                             16, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             2, # discard sync
                                             "DEAD", # sync
                                             nil, # max length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04\x05\x06"
        @interface.write(packet)
        expect(packet.buffer).to eql("\x00\x08\x03\x04\x05\x06")
        expect($buffer).to eql("\xDE\xAD\x00\x08\x03\x04\x05\x06")

        $buffer = ''
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(32, # bit offset
                                             16, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             4, # discard sync
                                             "BA5EBA11", # sync
                                             nil, # max length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04\x05\x06"
        @interface.write(packet)
        expect(packet.buffer).to eql("\x00\x0A\x03\x04\x05\x06")
        expect($buffer).to eql("\xBA\x5E\xBA\x11\x00\x0A\x03\x04\x05\x06")

        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(64, # bit offset
                                             32, # bit size
                                             12, # length offset
                                             1,  # bytes per count
                                             'BIG_ENDIAN',
                                             8,  # discard 8 leading bytes (sync)
                                             "BA5EBA11CAFEBABE",
                                             nil,
                                             true)
        packet = Packet.new(nil, nil)
        # The packet buffer contains the length field which is overwritten by the write call
        packet.buffer = "\x00\x00\x00\x00\x01\x02\x03\x04"
        @interface.write(packet)
        # Since we discarded 8 leading bytes, they are put back in the final stream data
        expect(packet.buffer).to eql("\x00\x00\x00\x04\x01\x02\x03\x04")
        expect($buffer).to eql("\xBA\x5E\xBA\x11\xCA\xFE\xBA\xBE\x00\x00\x00\x04\x01\x02\x03\x04")

      end

      it "inserts the length field into the data stream" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(8, # bit offset
                                             16, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             4, # discard
                                             nil, # sync
                                             nil, # max length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04"
        @interface.write(packet)
        expect(packet.buffer).to eql("\x01\x02\x03\x04")
        expect($buffer).to eql("\x00\x00\x08\x00\x01\x02\x03\x04")

        $buffer = ''
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(16, # bit offset
                                             8, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             4, # discard
                                             nil, # sync
                                             nil, # max length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A"
        @interface.write(packet)
        expect(packet.buffer).to eql("\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A")
        expect($buffer).to eql("\x00\x00\x0E\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A")
      end

      it "inserts the sync and length fields into the data stream" do
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(16, # bit offset
                                             8, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             4, # discard
                                             "0xDEAD", # sync
                                             nil, # max length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04\x05\x06"
        @interface.write(packet)
        expect(packet.buffer).to eql("\x01\x02\x03\x04\x05\x06")
        expect($buffer).to eql("\xDE\xAD\x0A\x00\x01\x02\x03\x04\x05\x06")

        $buffer = ''
        @interface.instance_variable_set(:@stream, LengthStream.new)
        @interface.configure_stream_protocol(32, # bit offset
                                             8, # bit size
                                             0, # length offset
                                             1, # bytes per count
                                             'BIG_ENDIAN',
                                             5, # discard
                                             "BA5EBA11", # sync
                                             nil, # max length
                                             true) # fill fields
        packet = Packet.new(nil, nil)
        packet.buffer = "\x01\x02\x03\x04"
        @interface.write(packet)
        expect(packet.buffer).to eql("\x01\x02\x03\x04")
        expect($buffer).to eql("\xBA\x5E\xBA\x11\x09\x01\x02\x03\x04")
      end
    end
  end
end
