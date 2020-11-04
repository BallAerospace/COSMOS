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
      System.instance.instance_variable_set(:@allow_router_commanding, true)
      @interface = Interface.new
      # Interface#connected? implemented in each test case
      allow(@interface).to receive(:connect)
      allow(@interface).to receive(:disconnect)
      allow(@interface).to receive(:read) do
        sleep 0.06
        @packet.clone
      end
    end

    describe "handle_packet" do
      it "handles disconnected interfaces" do
        allow(@interface).to receive(:connected?).and_return(false)
        @interface.interfaces = [@interface]
        thread = RouterThread.new(@interface)
        capture_io do |stdout|
          thread.start
          sleep 0.2
          expect(running_threads.length).to eql(2)
          thread.stop
          sleep 0.5
          expect(running_threads.length).to eql(1)
          expect(stdout.string).to match("disconnected interface")
        end
      end

      it "handles errors when sending packets" do
        allow(@interface).to receive(:connected?).and_return(true)
        commanding = double("commanding")
        expect(commanding).to receive(:send_command_to_interface).and_raise(RuntimeError.new("Death")).at_least(1).times
        allow(CmdTlmServer).to receive(:commanding).and_return(commanding)
        @interface.interfaces = [@interface]
        thread = RouterThread.new(@interface)
        capture_io do |stdout|
          thread.start
          sleep 0.2
          expect(running_threads.length).to eql(2)
          thread.stop
          sleep 0.5
          expect(running_threads.length).to eql(1)
          expect(stdout.string).to match("Error routing command")
        end
      end

      it "handles identified yet unknown commands" do
        allow(@interface).to receive(:connected?).and_return(true)
        commanding = spy("commanding")
        interface2 = double("interface")
        allow(interface2).to receive(:connected?).and_return(true)
        # Setup two interface
        @interface.interfaces = [@interface, interface2]
        # Verify that the command gets sent twice (one for each interface)
        expect(commanding).to receive(:send_command_to_interface).at_least(2).times
        allow(CmdTlmServer).to receive(:commanding).and_return(commanding)
        @packet.target_name = 'BOB'
        @packet.packet_name = 'SMITH'
        thread = RouterThread.new(@interface)
        capture_io do |stdout|
          thread.start
          sleep 0.2
          expect(running_threads.length).to eql(2)
          thread.stop
          sleep 0.5
          expect(running_threads.length).to eql(1)
          expect(stdout.string).to match("Received unknown identified command: BOB SMITH")
        end
      end

      it "handles identified known commands" do
        allow(@interface).to receive(:connected?).and_return(true)
        commanding = double("commanding")
        # Setup two interface
        interface2 = double("interface")
        allow(interface2).to receive(:connected?).and_return(true)
        @interface.interfaces = [@interface, interface2]
        # Verify that the command gets sent once to the target interface
        expect(commanding).to receive(:send_command_to_interface).at_least(1).times
        allow(CmdTlmServer).to receive(:commanding).and_return(commanding)
        target = spy("target")
        allow(target).to receive(:interface).and_return(@interface)
        allow(System).to receive(:targets).and_return({'BOB' => target})
        @interface.interfaces = [@interface]
        @packet.target_name = 'BOB'
        @packet.packet_name = 'SMITH'
        thread = RouterThread.new(@interface)
        capture_io do |stdout|
          thread.start
          sleep 0.2
          expect(running_threads.length).to eql(2)
          thread.stop
          sleep 0.5
          expect(running_threads.length).to eql(1)
          expect(stdout.string).to match("Received unknown identified command: BOB SMITH")
        end
        expect(target).to have_received(:interface).at_least(2).times #and_return(@interface)
      end

      it "does not send identified commands with a target and no interface" do
        allow(@interface).to receive(:connected?).and_return(true)
        commanding = double("commanding")
        # Setup two interface
        interface2 = double("interface")
        allow(interface2).to receive(:connected?).and_return(true)
        @interface.interfaces = [@interface, interface2]
        # Verify that the command gets sent once to the target interface
        expect(commanding).to_not receive(:send_command_to_interface)
        allow(CmdTlmServer).to receive(:commanding).and_return(commanding)
        target = spy("target")
        allow(target).to receive(:interface).and_return(nil)
        allow(System).to receive(:targets).and_return({'BOB' => target})
        @interface.interfaces = [@interface]
        @packet.target_name = 'BOB'
        @packet.packet_name = 'SMITH'
        thread = RouterThread.new(@interface)
        capture_io do |stdout|
          thread.start
          sleep 0.2
          expect(running_threads.length).to eql(2)
          thread.stop
          sleep 0.5
          expect(running_threads.length).to eql(1)
          expect(stdout.string).to match("target with no interface")
        end
      end
    end
  end
end
