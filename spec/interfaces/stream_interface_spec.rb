# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/stream_interface'

module Cosmos

  describe StreamInterface do
    before(:each) do
      @file = File.join(File.dirname(__FILE__),'..','..','lib','test_stream_protocol.rb')
    end

    after(:each) do
      File.delete(@file) if File.exist?(@file)
    end

    describe "initialize" do
      it "complains if the stream protocol doesn't exist" do
        File.delete(@file) if File.exist?(@file)
        expect { StreamInterface.new("test") }.to raise_error(/Unable to require test_stream_protocol.rb/)
        expect { StreamInterface.new("test") }.to raise_error(/Ensure test_stream_protocol.rb is in the COSMOS lib directory./)
      end

      it "complains if the stream protocol has a bug" do
        File.open(@file, 'w') {|file| file.puts "blah" }
        expect { StreamInterface.new("test") }.to raise_error(/undefined local variable or method/)
      end
    end

    describe "connect" do
      it "raises an exception" do
        si = StreamInterface.new("burst")
        expect { si.connect }.to raise_error("Interface connect method not implemented")
      end
    end

    describe "connected?, disconnect, bytes_read, bytes_written" do
      it "defers to the stream protocol" do
        File.open(@file, 'w') do |file|
          file.puts "class TestStreamProtocol"
          file.puts "attr_accessor :bytes_read, :bytes_written"
          file.puts "def interface=(i); i; end"
          file.puts "def connected?; 1; end"
          file.puts "def disconnect; 2; end"
          file.puts "end"
        end
        # Ensure we reload since TestStreamProtocol is used throughout
        load @file

        si = StreamInterface.new("test")
        expect(si.connected?).to eql 1
        expect(si.disconnect).to eql 2
        si.bytes_read = 10
        expect(si.bytes_read).to eql 10
        si.bytes_written = 20
        expect(si.bytes_written).to eql 20
      end
    end

    describe "read" do
      it "reads from the stream interface and count the packet" do
        File.open(@file, 'w') do |file|
          file.puts "class TestStreamProtocol"
          file.puts "def interface=(i); i; end"
          file.puts "def read; 1; end"
          file.puts "end"
        end
        # Ensure we reload since TestStreamProtocol is used throughout
        load @file

        si = StreamInterface.new("test")
        expect(si.read).to eql 1
        expect(si.read_count).to eql 1
      end
    end

    describe "write, write_raw" do
      it "complains if the stream interface isn't connected" do
        File.open(@file, 'w') do |file|
          file.puts "class TestStreamProtocol"
          file.puts "def interface=(i); i; end"
          file.puts "def connected?; false; end"
          file.puts "end"
        end
        # Ensure we reload since TestStreamProtocol is used throughout
        load @file

        si = StreamInterface.new("test")
        expect { si.write(nil) }.to raise_error(/Interface not connected/)
        expect { si.write_raw(nil) }.to raise_error(/Interface not connected/)
      end

      it "disconnects after write errors" do
        $disconnect = false
        File.open(@file, 'w') do |file|
          file.puts "class TestStreamProtocol"
          file.puts "def interface=(i); i; end"
          file.puts "def connected?; true; end"
          file.puts "def disconnect; $disconnect = true; end"
          file.puts "def write(p); raise 'ERROR'; end"
          file.puts "def write_raw(p); raise 'ERROR'; end"
          file.puts "end"
        end
        # Ensure we reload since TestStreamProtocol is used throughout
        load @file

        expect($disconnect).to be false
        si = StreamInterface.new("test")
        begin
          si.write(nil)
        rescue
        end
        expect(si.write_count).to eql 0
        expect($disconnect).to be true

        $disconnect = false
        expect($disconnect).to be false
        si = StreamInterface.new("test")
        begin
          si.write_raw(nil)
        rescue
        end
        expect(si.write_count).to eql 0
        expect($disconnect).to be true
      end

      it "writes to the stream interface and count the packet" do
        File.open(@file, 'w') do |file|
          file.puts "class TestStreamProtocol"
          file.puts "def interface=(i); i; end"
          file.puts "def connected?; true; end"
          file.puts "def write(p); p; end"
          file.puts "def write_raw(p); p; end"
          file.puts "end"
        end
        # Ensure we reload since TestStreamProtocol is used throughout
        load @file

        si = StreamInterface.new("test")
        si.write(nil)
        expect(si.write_count).to eql 1
        si.write_raw(nil)
        expect(si.write_count).to eql 2
      end
    end

  end
end

