# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/interface'

module Cosmos
  describe Interface do
    describe "include API" do
      it "includes API" do
        expect(Interface.new.methods).to include :cmd
      end
    end

    describe "initialize" do
      it "initializes the instance variables" do
        i = Interface.new
        expect(i.name).to eql "Interface"
        expect(i.target_names).to eql []
        expect(i.thread).to be_nil
        expect(i.connect_on_startup).to be true
        expect(i.auto_reconnect).to be true
        expect(i.reconnect_delay).to eql 5.0
        expect(i.disable_disconnect).to be false
        expect(i.packet_log_writer_pairs).to eql []
        expect(i.routers).to eql []
        expect(i.read_count).to eql 0
        expect(i.write_count).to eql 0
        expect(i.bytes_read).to eql 0
        expect(i.bytes_written).to eql 0
        expect(i.num_clients).to eql 0
        expect(i.read_queue_size).to eql 0
        expect(i.write_queue_size).to eql 0
        expect(i.interfaces).to eql []
        expect(i.options).to be_empty
        expect(i.protocol_params).to be_empty
      end
    end

    describe "connected?" do
      it "is false" do
        expect(Interface.new.connected?).to be false
      end
    end

    describe "read_allowed?" do
      it "is true" do
        expect(Interface.new.read_allowed?).to be true
      end
    end

    describe "write_allowed?" do
      it "is true" do
        expect(Interface.new.write_allowed?).to be true
      end
    end

    describe "write_raw_allowed?" do
      it "is true" do
        expect(Interface.new.write_raw_allowed?).to be true
      end
    end

    describe "read" do
      let(:interface) { Interface.new }

      it "raises unless connected" do
        expect { interface.read }.to raise_error(/Interface not connected/)
      end

      it "optionally logs raw data received from read_data" do
        class <<interface
          def connected?; true; end
          def read_data; "\x01\x02\x03\x04"; end
        end
        interface.start_raw_logging
        packet = interface.read
        expect(packet.buffer).to eql "\x01\x02\x03\x04"
        expect(interface.read_count).to eq 1
        expect(interface.bytes_read).to eq 4
        filename = interface.raw_logger_pair.read_logger.filename
        interface.stop_raw_logging
        expect(File.read(filename)).to eq "\x01\x02\x03\x04"
      end

      it "aborts and doesn't log if no data is returned from read_data" do
        class <<interface
          def connected?; true; end
          def read_data; nil end
        end
        interface.start_raw_logging
        expect(interface.read).to be_nil
        # Filenames don't get assigned until logging starts
        expect(interface.raw_logger_pair.read_logger.filename).to be_nil
        expect(interface.bytes_read).to eq 0
      end

      it "counts raw bytes read" do
        $i = 0
        class <<interface
          def connected?; true; end
          def read_data
            case $i
            when 0
              $i += 1
              "\x01\x02\x03\x04"
            when 1
              $i += 1
              "\x01\x02"
            when 2
              $i += 1
              "\x01\x02\x03\x04\x01\x02"
            end
          end
        end
        interface.read
        expect(interface.bytes_read).to eq 4
        interface.read
        expect(interface.bytes_read).to eq 6
        interface.read
        expect(interface.bytes_read).to eq 12
      end

      it "allows post_read_data to manipulate data" do
        class <<interface
          def connected?; true; end
          def read_data; "\x01\x02\x03\x04"; end
          def post_read_data(data); "\x02\x03\x04\x05"; end
        end
        interface.start_raw_logging
        packet = interface.read
        expect(packet.buffer).to eq "\x02\x03\x04\x05"
        expect(interface.read_count).to eq 1
        expect(interface.bytes_read).to eq 4
        filename = interface.raw_logger_pair.read_logger.filename
        interface.stop_raw_logging
        # Raw logging is still the original read_data return
        expect(File.read(filename)).to eq "\x01\x02\x03\x04"
      end

      it "aborts if post_read_data returns nil" do
        class <<interface
          def connected?; true; end
          def read_data; "\x01\x02\x03\x04"; end
          def post_read_data(data); nil; end
        end
        interface.start_raw_logging
        packet = interface.read
        expect(packet).to be_nil
        expect(interface.read_count).to eq 0
        expect(interface.bytes_read).to eq 4
        filename = interface.raw_logger_pair.read_logger.filename
        interface.stop_raw_logging
        expect(File.read(filename)).to eq "\x01\x02\x03\x04"
      end

      it "allows post_read_packet to manipulate packet" do
        class <<interface
          def connected?; true; end
          def read_data; "\x01\x02\x03\x04"; end
          def post_read_packet(packet); packet.buffer = "\x02\x03\x04\x05"; packet; end
        end
        packet = interface.read
        expect(packet.buffer).to eq "\x02\x03\x04\x05"
        expect(interface.read_count).to eq 1
        expect(interface.bytes_read).to eq 4
      end

      it "aborts if post_read_packet returns nil" do
        class <<interface
          def connected?; true; end
          def read_data; "\x01\x02\x03\x04"; end
          def post_read_packet(packet); nil; end
        end
        packet = interface.read
        expect(packet).to be_nil
        expect(interface.read_count).to eq 0
        expect(interface.bytes_read).to eq 4
      end

      it "returns an unidentified packet" do
        class <<interface
          def connected?; true; end
          def read_data; "\x01\x02\x03\x04"; end
        end
        packet = interface.read
        expect(packet.target_name).to be_nil
        expect(packet.packet_name).to be_nil
      end
    end

    describe "write" do
      let(:interface) { Interface.new }
      let(:packet) { Packet.new('TGT', 'PKT', :BIG_ENDIAN, 'Packet', "\x01\x02\x03\x04") }

      it "raises unless connected" do
        expect { interface.write(packet)}.to raise_error(/Interface not connected/)
      end

      it "is single threaded" do
        class <<interface
          def connected?; true; end
          def write_data(data); super(data); sleep 0.1; end
        end
        start_time = Time.now
        threads = []
        10.times do
          threads << Thread.new do
            interface.write(packet)
          end
        end
        threads.collect {|t| t.join }
        expect(Time.now - start_time).to be > 1
        expect(interface.write_count).to eq 10
        expect(interface.bytes_written).to eq 40
      end

      it "aborts if pre_write_packet returns nil" do
        class <<interface
          def connected?; true; end
          def pre_write_packet(packet); nil; end
        end
        interface.write(packet)
        expect(interface.write_count).to be 0
        expect(interface.bytes_written).to be 0
      end

      it "allows pre_write_packet to modify the packet" do
        class <<interface
          def connected?; true; end
          def pre_write_packet(packet)
            packet.buffer = "\x02\x03\x04\x05"
            packet
          end
        end
        interface.start_raw_logging
        interface.write(packet)
        expect(interface.write_count).to eq 1
        expect(interface.bytes_written).to eq 4
        filename = interface.raw_logger_pair.write_logger.filename
        interface.stop_raw_logging
        expect(File.read(filename)).to eq "\x02\x03\x04\x05"
      end

      it "aborts if pre_write_data returns nil" do
        class <<interface
          def connected?; true; end
          def pre_write_data(data); nil; end
        end
        interface.write(packet)
        expect(interface.write_count).to be 0
        expect(interface.bytes_written).to be 0
      end

      it "allows pre_write_data to modify the data" do
        class <<interface
          def connected?; true; end
          def pre_write_data(data)
            "\x02\x03\x04\x05"
          end
        end
        interface.start_raw_logging
        interface.write(packet)
        expect(interface.write_count).to be 1
        expect(interface.bytes_written).to be 4
        filename = interface.raw_logger_pair.write_logger.filename
        interface.stop_raw_logging
        expect(File.read(filename)).to eq "\x02\x03\x04\x05"
      end

      it "calls post_write_data with the packet and data" do
        $packet = nil
        $data = nil
        class <<interface
          def connected?; true; end
          def post_write_data(packet, data)
            $packet = packet
            $data = data
          end
        end
        expect($packet).to be_nil
        expect($data).to be_nil
        interface.write(packet)
        expect(interface.write_count).to be 1
        expect(interface.bytes_written).to be 4
        expect($packet).to eq packet
        expect($data).to eq packet.buffer
      end
    end

    describe "write_raw" do
      let(:interface) { Interface.new }
      let(:data) { "\x01\x02\x03\x04" }

      it "raises unless connected" do
        expect { interface.write_raw(data)}.to raise_error(/Interface not connected/)
      end

      it "is single threaded" do
        class <<interface
          def connected?; true; end
          def write_data(data); super(data); sleep 0.1; end
        end
        start_time = Time.now
        threads = []
        10.times do
          threads << Thread.new do
            interface.write_raw(data)
          end
        end
        threads.collect {|t| t.join }
        expect(Time.now - start_time).to be > 1
        expect(interface.write_count).to eq 0
        expect(interface.bytes_written).to eq 40
      end

      it "aborts if pre_write_data returns nil" do
        class <<interface
          def connected?; true; end
          def pre_write_data(data); nil; end
        end
        interface.write_raw(data)
        expect(interface.write_count).to be 0
        expect(interface.bytes_written).to be 0
      end

      it "allows pre_write_data to modify the data" do
        class <<interface
          def connected?; true; end
          def pre_write_data(data)
            "\x02\x03\x04\x05"
          end
        end
        interface.start_raw_logging
        interface.write_raw(data)
        expect(interface.write_count).to be 0
        expect(interface.bytes_written).to be 4
        filename = interface.raw_logger_pair.write_logger.filename
        interface.stop_raw_logging
        expect(File.read(filename)).to eq "\x02\x03\x04\x05"
      end
    end

    describe "copy_to" do
      it "copies the interface" do
        i = Interface.new
        i.name = 'TEST'
        i.target_names = ['TGT1','TGT2']
        i.thread = Thread.new {}
        i.connect_on_startup = false
        i.auto_reconnect = false
        i.reconnect_delay = 1.0
        i.disable_disconnect = true
        i.packet_log_writer_pairs = [1,2]
        i.routers = [3,4]
        i.read_count = 1
        i.write_count = 2
        i.bytes_read = 3
        i.bytes_written = 4
        i.num_clients = 5
        i.read_queue_size = 6
        i.write_queue_size = 7
        i.interfaces = [5,6]

        i2 = Interface.new
        i.copy_to(i2)
        expect(i2.name).to eql 'TEST'
        expect(i2.target_names).to eql ['TGT1','TGT2']
        expect(i2.thread).to be_nil # Thread does not get copied
        expect(i2.connect_on_startup).to be false
        expect(i2.auto_reconnect).to be false
        expect(i2.reconnect_delay).to eql 1.0
        expect(i2.disable_disconnect).to be true
        expect(i2.packet_log_writer_pairs).to eql [1,2]
        expect(i2.routers).to eql [3,4]
        expect(i2.read_count).to eql 1
        expect(i2.write_count).to eql 2
        expect(i2.bytes_read).to eql 3
        expect(i2.bytes_written).to eql 4
        expect(i2.num_clients).to eql 0 # does not get copied
        expect(i2.read_queue_size).to eql 0 # does not get copied
        expect(i2.write_queue_size).to eql 0 # does not get copied
        expect(i2.interfaces).to eql [5,6]

        Cosmos.kill_thread(nil, i.thread)
      end
    end

    describe "post_identify_packet" do
      it "does nothing" do
        expect { Interface.new.post_identify_packet(nil) }.to_not raise_error
      end
    end

  end
end

