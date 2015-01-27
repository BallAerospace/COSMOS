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
require 'cosmos/tools/cmd_tlm_server/router_thread'
require 'cosmos/interfaces/interface'

module Cosmos

  describe RouterThread do

    before(:each) do
      @packet = Packet.new('TGT','PKT')
      @packet.buffer = "\x01\x02"

      @interface = Interface.new
      @connected_count = 0
      allow(@interface).to receive(:connected?) do
        if @connected_count == 0
          @connected_count += 1
          false
        else
          @connected_count += 1
          true
        end
      end
      allow(@interface).to receive(:connect)
      allow(@interface).to receive(:disconnect)
      allow(@interface).to receive(:read) do
        sleep 0.06
        @packet
      end
    end

    describe "start" do
      it "should log the connection" do
        commanding = double("commanding")
        expect(commanding).to receive(:send_command_to_interface).at_least(1).times
        allow(CmdTlmServer).to receive(:commanding).and_return(commanding)
        @interface.interfaces = [@interface]
        thread = RouterThread.new(@interface)
        thread.start
        sleep 1
        Thread.list.length.should eql(2)
        thread.stop
        sleep 0.5
        Thread.list.length.should eql(1)
      end
    end

    describe "handle_packet" do
      it "should handle errors when sending packets" do
        commanding = double("commanding")
        expect(commanding).to receive(:send_command_to_interface).and_raise(RuntimeError.new("Death")).at_least(1).times
        allow(CmdTlmServer).to receive(:commanding).and_return(commanding)
        @interface.interfaces = [@interface]
        thread = RouterThread.new(@interface)
        capture_io do |stdout|
          thread.start
          sleep 0.2
          Thread.list.length.should eql(2)
          thread.stop
          sleep 0.5
          Thread.list.length.should eql(1)
          stdout.string.should match "Error routing command"
        end
      end

      it "should handle identified yet unknown commands" do
        commanding = double("commanding")
        expect(commanding).to receive(:send_command_to_interface).at_least(1).times
        allow(CmdTlmServer).to receive(:commanding).and_return(commanding)
        @interface.interfaces = [@interface]
        @packet.target_name = 'BOB'
        @packet.packet_name = 'SMITH'
        thread = RouterThread.new(@interface)
        capture_io do |stdout|
          thread.start
          sleep 0.2
          Thread.list.length.should eql(2)
          thread.stop
          sleep 0.5
          Thread.list.length.should eql(1)
          stdout.string.should match "Received unknown identified command: BOB SMITH"
        end
      end
    end
  end
end

