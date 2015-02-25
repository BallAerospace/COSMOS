# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/io/io_multiplexer'

module Cosmos

  describe IoMultiplexer do
    before(:each) do
      @io = IoMultiplexer.new
    end

    describe "add_stream" do
      it "adds a single stream" do
        @io.add_stream(STDOUT)
        expect($stdout).to receive(:puts).with("TEST")
        @io.puts "TEST"
      end

      it "adds multiple streams" do
        @io.add_stream(STDOUT)
        @io.add_stream(STDERR)
        expect($stdout).to receive(:puts).with("TEST")
        expect($stderr).to receive(:puts).with("TEST")
        @io.puts "TEST"
      end
    end

    describe "remove_stream" do
      it "removes the stream from output" do
        @io.add_stream(STDOUT)
        @io.add_stream(STDERR)
        @io.remove_stream(STDOUT)
        expect($stdout).not_to receive(:puts).with("TEST")
        expect($stderr).to receive(:puts).with("TEST")
        @io.puts "TEST"
      end
    end

    describe "print, printf, putc, puts, flush" do
      it "defers to the stream" do
        @io.add_stream(STDOUT)
        expect($stdout).to receive(:print).with("TEST")
        @io.print "TEST"
        expect($stdout).to receive(:printf).with("TEST")
        @io.printf "TEST"
        expect($stdout).to receive(:putc).with("TEST")
        @io.putc "TEST"
        expect($stdout).to receive(:puts).with("TEST")
        @io.puts "TEST"
        expect($stdout).to receive(:flush)
        @io.flush
      end
    end

    describe "write write_nonblock" do
      it "defers to the stream" do
        @io.add_stream(STDOUT)
        expect($stdout).to receive(:write).with("TEST")
        len = @io.write "TEST"
        len.should eql 4
        expect($stdout).to receive(:write_nonblock).with("TEST")
        len = @io.write_nonblock "TEST"
        len.should eql 4
      end
    end

    describe "remove_default_io" do
      it "removes STDOUT and STDERR from the streams" do
        f = File.open("unittest.txt",'w')
        @io.add_stream(STDOUT)
        @io.add_stream(STDERR)
        @io.add_stream(f)
        @io.remove_default_io
        @io.puts "TEST"
        f.close
        expect($stdout).not_to receive(:puts).with("TEST")
        expect($stderr).not_to receive(:puts).with("TEST")
        File.read("unittest.txt").should eql "TEST\n"
        File.delete("unittest.txt")
      end
    end

  end
end

