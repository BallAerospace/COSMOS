# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/tools/cmd_tlm_server/packet_logging'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server_config'
require 'tempfile'

module Cosmos

  describe PacketLogging do
    before(:all) do
      system_path = File.join(__dir__, '..', '..', 'install', 'config', 'system', 'system.txt')
      @sc = Cosmos::SystemConfig.new(system_path)
    end

    describe "start" do
      it "starts each log writer" do
        tf = Tempfile.new('unittest')
        tf.puts '#'
        tf.close
        pl = PacketLogging.new(CmdTlmServerConfig.new(tf.path, @sc))
        default = pl.all['DEFAULT']
        expect(default).to be_a PacketLogWriterPair
        expect(default.cmd_log_writer).to receive(:start).with('LABEL')
        expect(default.tlm_log_writer).to receive(:start).with('LABEL')
        pl.start('ALL','LABEL')
        tf.unlink
      end
    end

    describe "stop" do
      it "stops each log writer" do
        tf = Tempfile.new('unittest')
        tf.puts '#'
        tf.close
        pl = PacketLogging.new(CmdTlmServerConfig.new(tf.path, @sc))
        default = pl.all['DEFAULT']
        expect(default).to be_a PacketLogWriterPair
        expect(default.cmd_log_writer).to receive(:stop)
        expect(default.tlm_log_writer).to receive(:stop)
        pl.stop
        tf.unlink
      end
    end

    describe "start_cmd, stop_cmd" do
      it "complains about unknown log writers" do
        tf = Tempfile.new('unittest')
        tf.puts '#'
        tf.close
        pl = PacketLogging.new(CmdTlmServerConfig.new(tf.path, @sc))
        expect { pl.start_cmd('BLAH') }.to raise_error("Unknown packet log writer: BLAH")
        expect { pl.stop_cmd('BLAH') }.to raise_error("Unknown packet log writer: BLAH")
        tf.unlink
      end

      it "starts/stop a telemetry log writer" do
        tf = Tempfile.new('unittest')
        tf.puts 'PACKET_LOG_WRITER MY_WRITER packet_log_writer.rb'
        tf.close
        pl = PacketLogging.new(CmdTlmServerConfig.new(tf.path, @sc))
        mine = pl.all['MY_WRITER']
        expect(mine).to be_a PacketLogWriterPair
        expect(mine.cmd_log_writer).to receive(:start).with('LABEL')
        pl.start_cmd('MY_WRITER','LABEL')
        expect(mine.cmd_log_writer).to receive(:stop)
        pl.stop_cmd('MY_WRITER')
        tf.unlink
      end
    end

    describe "start_tlm, stop_tlm" do
      it "complains about unknown log writers" do
        tf = Tempfile.new('unittest')
        tf.puts '#'
        tf.close
        pl = PacketLogging.new(CmdTlmServerConfig.new(tf.path, @sc))
        expect { pl.start_tlm('BLAH') }.to raise_error("Unknown packet log writer: BLAH")
        expect { pl.stop_tlm('BLAH') }.to raise_error("Unknown packet log writer: BLAH")
        tf.unlink
      end

      it "starts/stop a telemetry log writer" do
        tf = Tempfile.new('unittest')
        tf.puts 'PACKET_LOG_WRITER MY_WRITER packet_log_writer.rb'
        tf.close
        pl = PacketLogging.new(CmdTlmServerConfig.new(tf.path, @sc))
        mine = pl.all['MY_WRITER']
        expect(mine).to be_a PacketLogWriterPair
        expect(mine.tlm_log_writer).to receive(:start).with('LABEL')
        pl.start_tlm('MY_WRITER','LABEL')
        expect(mine.tlm_log_writer).to receive(:stop)
        pl.stop_tlm('MY_WRITER')
        tf.unlink
      end
    end

    describe "cmd_filename, tlm_filename" do
      it "complains about unknown log writers" do
        tf = Tempfile.new('unittest')
        tf.puts '#'
        tf.close
        pl = PacketLogging.new(CmdTlmServerConfig.new(tf.path, @sc))
        expect { pl.cmd_filename('BLAH') }.to raise_error("Unknown packet log writer: BLAH")
        expect { pl.tlm_filename('BLAH') }.to raise_error("Unknown packet log writer: BLAH")
        tf.unlink
      end

      it "returns the filename" do
        tf = Tempfile.new('unittest')
        tf.puts '#'
        tf.close
        pl = PacketLogging.new(CmdTlmServerConfig.new(tf.path, @sc))
        default = pl.all['DEFAULT']
        expect(default).to be_a PacketLogWriterPair
        expect(default.cmd_log_writer).to receive(:filename).and_return("test_file")
        expect(pl.cmd_filename("DEFAULT")).to eql "test_file"
        expect(default.tlm_log_writer).to receive(:filename).and_return("test_file")
        expect(pl.tlm_filename("DEFAULT")).to eql "test_file"
        tf.unlink
      end
    end

    describe "all"
      it "lists all telemetry log writer pairs" do
        tf = Tempfile.new('unittest')
        tf.puts 'PACKET_LOG_WRITER MY_WRITER packet_log_writer.rb'
        tf.close
        pl = PacketLogging.new(CmdTlmServerConfig.new(tf.path, @sc))
        expect(pl.all.keys).to eql %w(DEFAULT MY_WRITER)
        tf.unlink
      end
  end
end
