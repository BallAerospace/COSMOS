# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'tempfile'
require 'cosmos'
require 'cosmos/tools/cmd_tlm_server/commanding'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server_config'

module Cosmos

  describe Commanding do
    after(:all) do
      clean_config()
    end

    describe "send_command_to_target" do
      it "complains about unknown targets" do
        tf = Tempfile.new('unittest')
        tf.close
        cmd = Commanding.new(CmdTlmServerConfig.new(tf.path))
        expect { cmd.send_command_to_target('BLAH', Packet.new('TGT','PKT')) }.to raise_error("Unknown target: BLAH")
        tf.unlink
      end

      it "identifies and command to the interface" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        config = CmdTlmServerConfig.new(tf.path)
        cmd = Commanding.new(config)
        interfaces = Interfaces.new(config)
        interfaces.map_target("COSMOS","MY_INT")
        expect(interfaces.all["MY_INT"]).to receive(:write)
        expect(interfaces.all["MY_INT"].packet_log_writer_pairs[0].cmd_log_writer).to receive(:write)

        # Grab an existing packet
        pkt = System.commands.packet('COSMOS','STARTLOGGING')
        # Restore defaults so it can be identified
        pkt.restore_defaults
        # Set the target_name to nil to make it "unidentified"
        pkt.target_name = nil

        count = System.targets['COSMOS'].cmd_cnt
        cmd.send_command_to_target('COSMOS', pkt)
        # Verify the COSMOS STARTLOGGING packet has been updated
        expect(System.commands.packet("COSMOS","STARTLOGGING").buffer).to eql pkt.buffer
        # Verify the target count didn't get updated
        expect(System.targets['COSMOS'].cmd_cnt).to eq count
        # Restore target name
        pkt.target_name = 'COSMOS'
        tf.unlink
      end

      it "sends already identified commands" do
        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        config = CmdTlmServerConfig.new(tf.path)
        cmd = Commanding.new(config)
        interfaces = Interfaces.new(config)
        interfaces.map_target("COSMOS","MY_INT")
        expect(interfaces.all["MY_INT"]).to receive(:write)
        expect(interfaces.all["MY_INT"].packet_log_writer_pairs[0].cmd_log_writer).to receive(:write)

        # Grab an existing packet
        pkt = System.commands.packet('COSMOS','STARTLOGGING')

        count = System.targets['COSMOS'].cmd_cnt
        cmd.send_command_to_target('COSMOS', pkt)
        # Verify the COSMOS STARTLOGGING packet has been updated
        expect(System.commands.packet("COSMOS","STARTLOGGING").buffer).to eql pkt.buffer
        expect(System.targets['COSMOS'].cmd_cnt).to eq count + 1
        tf.unlink
      end


      it "logs unknown commands" do
        Logger.level = Logger::DEBUG
        stdout = StringIO.new('', 'r+')
        $stdout = stdout

        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        config = CmdTlmServerConfig.new(tf.path)
        cmd = Commanding.new(config)
        interfaces = Interfaces.new(config)
        interfaces.map_target("COSMOS","MY_INT")
        expect(interfaces.all["MY_INT"]).to receive(:write)
        expect(interfaces.all["MY_INT"].packet_log_writer_pairs[0].cmd_log_writer).to receive(:write)

        # Grab an existing packet
        pkt = System.commands.packet('COSMOS','STARTLOGGING')
        # Mess up the opcode so it won't be identifyable
        pkt.write('OPCODE',100)
        # Set the target_name to nil to make it "unidentified"
        pkt.target_name = nil

        cmd.send_command_to_target('COSMOS', pkt)
        # Verify the unknown packet has been updated
        expect(System.commands.packet("UNKNOWN","UNKNOWN").buffer).to eql pkt.buffer
        tf.unlink

        expect(stdout.string).to match "Unidentified packet"
        Logger.level = Logger::FATAL
        $stdout = STDOUT
      end
    end

    describe "send_raw" do
      it "complains about unknown interfaces" do
        tf = Tempfile.new('unittest')
        tf.close
        cmd = Commanding.new(CmdTlmServerConfig.new(tf.path))
        expect { cmd.send_raw('BLAH', Packet.new('TGT','PKT')) }.to raise_error("Unknown interface: BLAH")
        tf.unlink
      end

      it "logs writes" do
        Logger.level = Logger::DEBUG
        stdout = StringIO.new('', 'r+')
        $stdout = stdout

        tf = Tempfile.new('unittest')
        tf.puts 'INTERFACE MY_INT interface.rb'
        tf.close
        config = CmdTlmServerConfig.new(tf.path)
        cmd = Commanding.new(config)
        interfaces = Interfaces.new(config)
        expect(interfaces.all["MY_INT"]).to receive(:write_raw)

        cmd.send_raw('MY_INT', "\x00\x01")
        tf.unlink

        expect(stdout.string).to match "Unlogged raw data of 2 bytes being sent to interface MY_INT"
        Logger.level = Logger::FATAL
        $stdout = STDOUT
      end
    end

  end
end

