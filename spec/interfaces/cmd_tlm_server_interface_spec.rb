# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/interfaces/cmd_tlm_server_interface'

module Cosmos

  describe CmdTlmServerInterface do
    skip "TODO: this may no longer be needed" do

    before(:all) do
      # Save cmd_tlm_server.txt
      cts = File.join(Cosmos::USERPATH,'config','tools','cmd_tlm_server','cmd_tlm_server.txt')
      FileUtils.mv cts, Cosmos::USERPATH
      FileUtils.mkdir_p(File.dirname(cts))
      File.open(cts,'w') do |file|
        file.puts 'INTERFACE INT interface.rb'
      end
      System.class_eval('@@instance = nil')
    end

    after(:all) do
      # Restore cmd_tlm_server.txt
      FileUtils.mv File.join(Cosmos::USERPATH, 'cmd_tlm_server.txt'),
      File.join(Cosmos::USERPATH,'config','tools','cmd_tlm_server')
      System.class_eval('@@instance = nil')
    end

    before(:each) do
      allow_any_instance_of(Interface).to receive(:connected?).and_return(true)
      allow_any_instance_of(Interface).to receive(:disconnect)
      @cts = CmdTlmServer.new
      sleep 1
      @ctsi = CmdTlmServerInterface.new
    end

    after(:each) do
      @ctsi.disconnect# if @ctsi
      sleep 0.1
      @cts.stop# if @cts
      sleep 0.1 # Give the server time to really stop all the Threads
    end

    specify { expect(@ctsi.methods).to include(:cmd) }

    describe "connect, connected?, disconnect" do
      it "subscribes to the server" do
        expect { @ctsi.connect }.to_not raise_error
        expect(@ctsi.connected?).to be true
        expect { @ctsi.disconnect}.to_not raise_error
        expect(@ctsi.connected?).to be false
      end
    end

    describe "write_raw_allowed?" do
      it "returns false" do
        expect(@ctsi.write_raw_allowed?).to be false
      end
    end

    describe "write_raw" do
      it "raises an error" do
        expect { @ctsi.write_raw(nil) }.to raise_error(/write_raw not implemented/)
      end
    end

    describe "read" do
      it "returns SYSTEM LIMITS_CHANGE" do
        @ctsi.connect

        pkt = Packet.new("TGT","PKT")
        pi = PacketItem.new("ITEM", 0, 32, :UINT, :BIG_ENDIAN, nil)
        # Create a limits change event
        pi.limits.state = :GREEN
        @cts.limits_change_callback(pkt, pi, :RED, 100, true)

        result = @ctsi.read
        expect(result.read('TARGET')).to eql "TGT"
        expect(result.read('PACKET')).to eql "PKT"
        expect(result.read('ITEM')).to eql "ITEM"
        expect(result.read('OLD_STATE')).to eql "RED"
        expect(result.read('NEW_STATE')).to eql "GREEN"
      end
    end

    describe "write" do
      it "raises an error if the packet is not identified" do
        pkt = Packet.new("COSMOS", "STARTLOGGING")
        pkt.buffer = "\x00\x00\x00\x00\x00\x00\x00\x00"
        expect { @ctsi.write(pkt) }.to raise_error(/Unknown command/)
      end

      it "raises an error if the command is not recognized" do
        pkt = Packet.new("COSMOS", "DOSOMETHING")
        pkt.buffer = "\x00\x00\x00\x00\x00\x00\x00\x00"
        expect { @ctsi.write(pkt) }.to raise_error(/Unknown command/)
      end

      it "accepts STARTLOGGING" do
        pkt = System.commands.packet("SYSTEM","STARTLOGGING")
        pkt.restore_defaults
        pkt.write('INTERFACE','DEFAULT')
        @ctsi.write(pkt)
      end

      it "accepts STARTCMDLOG" do
        pkt = System.commands.packet("SYSTEM","STARTCMDLOG")
        pkt.restore_defaults
        pkt.write('INTERFACE','DEFAULT')
        @ctsi.write(pkt)
      end

      it "accepts STARTTLMLOG" do
        pkt = System.commands.packet("SYSTEM","STARTTLMLOG")
        pkt.restore_defaults
        pkt.write('INTERFACE','DEFAULT')
        @ctsi.write(pkt)
      end

      it "accepts STOPLOGGING" do
        pkt = System.commands.packet("SYSTEM","STOPLOGGING")
        pkt.restore_defaults
        pkt.write('INTERFACE','DEFAULT')
        @ctsi.write(pkt)
      end

      it "accepts STOPCMDLOG" do
        pkt = System.commands.packet("SYSTEM","STOPCMDLOG")
        pkt.restore_defaults
        pkt.write('INTERFACE','DEFAULT')
        @ctsi.write(pkt)
      end

      it "accepts STOPTLMLOG" do
        pkt = System.commands.packet("SYSTEM","STOPTLMLOG")
        pkt.restore_defaults
        pkt.write('INTERFACE','DEFAULT')
        @ctsi.write(pkt)
      end
    end

  end
  end
end
