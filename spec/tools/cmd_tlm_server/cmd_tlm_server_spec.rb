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
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'

module Cosmos

  describe CmdTlmServer do
    before(:all) do
      cts = File.join(Cosmos::USERPATH,'config','tools','cmd_tlm_server','cmd_tlm_server.txt')
      FileUtils.mkdir_p(File.dirname(cts))
      File.open(cts,'w') do |file|
        file.puts 'INTERFACE SYSTEM_INT cmd_tlm_server_interface.rb'
        file.puts '  TARGET SYSTEM'
      end
    end

    after(:all) do
      clean_config()
    end

    before(:each) do
      allow_any_instance_of(Interface).to receive(:connect).and_return(true)
      allow_any_instance_of(Interface).to receive(:connected?).and_return(true)
      allow_any_instance_of(Interface).to receive(:read).and_return(nil)
      allow_any_instance_of(Interface).to receive(:disconnect).and_return(nil)
    end

    describe "initialize, self.instance" do
      it "creates the single instance of the CTS" do
        cts = CmdTlmServer.new
        expect(CmdTlmServer.instance).to eql cts
        expect(CmdTlmServer.background_tasks).to be_a BackgroundTasks
        expect(CmdTlmServer.commanding).to be_a Commanding
        expect(CmdTlmServer.interfaces).to be_a Interfaces
        expect(CmdTlmServer.packet_logging).to be_a PacketLogging
        expect(CmdTlmServer.routers).to be_a Routers
        expect(CmdTlmServer.message_log).to be_a MessageLog
        expect(CmdTlmServer.json_drb).to be_a JsonDRb
        sleep 0.1

        begin
          # Verify we can't start another CTS
          expect { CmdTlmServer.new }.to raise_error(FatalError, /Error starting JsonDRb on port 7777/)
        ensure
          cts.stop
          sleep 0.2
        end
      end

      it "creates the CTS in production mode" do
        # Production mode means we start logging
        expect_any_instance_of(PacketLogging).to receive(:start)
        cts = CmdTlmServer.new(CmdTlmServer::DEFAULT_CONFIG_FILE, true)
        begin
          # Verify we disabled the ability to stop logging
          expect(CmdTlmServer.json_drb.method_whitelist).to include('start_logging')
          expect(CmdTlmServer.json_drb.method_whitelist).not_to include('stop_logging')
          expect(CmdTlmServer.json_drb.method_whitelist).not_to include('stop_cmd_log')
          expect(CmdTlmServer.json_drb.method_whitelist).not_to include('stop_tlm_log')
        ensure
          cts.stop
          sleep 0.2
        end
      end
   end

    describe "start" do
      it "creates the CTS in production mode" do
        # Production mode means we start logging
        cts = CmdTlmServer.new
        begin
          expect(CmdTlmServer.json_drb.method_whitelist).to include('start_logging')
          expect(CmdTlmServer.json_drb.method_whitelist).to include('stop_logging')
          expect(CmdTlmServer.json_drb.method_whitelist).to include('stop_cmd_log')
          expect(CmdTlmServer.json_drb.method_whitelist).to include('stop_tlm_log')
          cts.start # Call start again ... it should do nothing
          expect(CmdTlmServer.json_drb.method_whitelist).to include('start_logging')
          expect(CmdTlmServer.json_drb.method_whitelist).to include('stop_logging')
          expect(CmdTlmServer.json_drb.method_whitelist).to include('stop_cmd_log')
          expect(CmdTlmServer.json_drb.method_whitelist).to include('stop_tlm_log')
        ensure
          cts.stop
          sleep 0.2
        end

        cts = CmdTlmServer.new(CmdTlmServer::DEFAULT_CONFIG_FILE, true)
        expect_any_instance_of(PacketLogging).to receive(:start)
        # Now start the server in production mode
        cts.start(true)
        begin
          # Verify we disabled the ability to stop logging
          expect(CmdTlmServer.json_drb.method_whitelist).to include('start_logging')
          expect(CmdTlmServer.json_drb.method_whitelist).not_to include('stop_logging')
          expect(CmdTlmServer.json_drb.method_whitelist).not_to include('stop_cmd_log')
          expect(CmdTlmServer.json_drb.method_whitelist).not_to include('stop_tlm_log')
        ensure
          cts.stop
          sleep 0.2
        end
      end

      it "monitors the staleness thread" do
        capture_io do |stdout|
          # Production mode means we start logging
          allow(System).to receive_message_chain(:telemetry,:limits_change_callback=)
          allow(System).to receive_message_chain(:telemetry,:check_stale) { raise "Stale Error" }
          sleep 0.1
          cts = CmdTlmServer.new
          sleep 0.1
          cts.stop
          sleep 0.2

          expect(stdout.string).to match "Staleness Monitor thread unexpectedly died"
        end
      end
    end

    describe "limits_change_callback" do
      it "logs the change according to the state" do
        capture_io do |stdout|
          cts = CmdTlmServer.new
          begin
            pkt = Packet.new("TGT","PKT")
            pi = PacketItem.new("TEST", 0, 32, :UINT, :BIG_ENDIAN, nil)
            cts.limits_change_callback(pkt, pi, :STALE, 100, true)
            expect(stdout.string).to match "TGT PKT TEST = 100 is UNKNOWN"

            pi.limits.state = :BLUE
            cts.limits_change_callback(pkt, pi, :STALE, 100, true)
            expect(stdout.string).to match "<B>TGT PKT TEST = 100 is BLUE"

            pi.limits.state = :GREEN
            cts.limits_change_callback(pkt, pi, :STALE, 100, true)
            expect(stdout.string).to match "<G>TGT PKT TEST = 100 is GREEN"

            pi.limits.state = :YELLOW
            cts.limits_change_callback(pkt, pi, :STALE, 100, true)
            expect(stdout.string).to match "<Y>TGT PKT TEST = 100 is YELLOW"

            pi.limits.state = :RED
            cts.limits_change_callback(pkt, pi, :STALE, 100, true)
            expect(stdout.string).to match "<R>TGT PKT TEST = 100 is RED"
          ensure
            cts.stop
            sleep 0.2
          end
        end
      end

      it "calls the limits response" do
        cts = CmdTlmServer.new
        begin
          pkt = Packet.new("TGT","PKT")
          pi = PacketItem.new("TEST", 0, 32, :UINT, :BIG_ENDIAN, nil)
          lr = LimitsResponse.new
          pi.limits.response = lr
          expect(pi.limits.response).to receive(:call) do |tgt, pkt, item, old_state, state|
            expect(tgt).to eql "TGT"
            expect(pkt).to eql "PKT"
            expect(item.name).to eql "TEST"
            expect(old_state).to eql :YELLOW
            expect(state).to eql :GREEN
          end
          pi.limits.state = :GREEN
          cts.limits_change_callback(pkt, pi, :YELLOW, 100, true)
        ensure
          cts.stop
          sleep 0.2
        end
      end

      it "logs limits response errors" do
        capture_io do |stdout|
          cts = CmdTlmServer.new
          begin
            pkt = Packet.new("TGT","PKT")
            pi = PacketItem.new("TEST", 0, 32, :UINT, :BIG_ENDIAN, nil)
            lr = LimitsResponse.new
            pi.limits.response = lr
            expect(pi.limits.response).to receive(:call) { raise "ResponseError" }
            pi.limits.state = :GREEN
            cts.limits_change_callback(pkt, pi, :YELLOW, 100, true)
            sleep 0.1
            expect(stdout.string).to match "TGT PKT TEST Limits Response Exception!"
          ensure
            cts.stop
            sleep 0.2
          end
        end
      end
    end

    describe "self.subscribe_limits_events" do
      it "rejects bad queue sizes" do
        expect{ CmdTlmServer.subscribe_limits_events(0) }.to raise_error(ArgumentError)
        expect{ CmdTlmServer.subscribe_limits_events(true) }.to raise_error(ArgumentError)
      end

      it "subscribes to limits events" do
        allow(System).to receive_message_chain(:telemetry,:stale).and_return([])
        allow(System).to receive_message_chain(:telemetry,:limits_change_callback=)
        allow(System).to receive_message_chain(:telemetry,:check_stale)
        cts = CmdTlmServer.new
        begin
          pkt = Packet.new("TGT","PKT")
          pi = PacketItem.new("TEST", 0, 32, :UINT, :BIG_ENDIAN, nil)
          id = CmdTlmServer.subscribe_limits_events()

          # Create two limits change events
          pi.limits.state = :GREEN
          cts.limits_change_callback(pkt, pi, :STALE, 100, true)
          pi.limits.state = :YELLOW
          cts.limits_change_callback(pkt, pi, :GREEN, 100, true)

          # Get and check the first one
          type,data = CmdTlmServer.get_limits_event(id)
          tgt,pkt,item,old_state,state = data # split the data array
          expect(type).to eql :LIMITS_CHANGE
          expect(tgt).to eql "TGT"
          expect(pkt).to eql "PKT"
          expect(item).to eql "TEST"
          expect(old_state).to eql :STALE
          expect(state).to eql :GREEN

          # Get and check the second one
          type,data = CmdTlmServer.get_limits_event(id)
          tgt,pkt,item,old_state,state = data # split the data array
          expect(type).to eql :LIMITS_CHANGE
          expect(tgt).to eql "TGT"
          expect(pkt).to eql "PKT"
          expect(item).to eql "TEST"
          expect(old_state).to eql :GREEN
          expect(state).to eql :YELLOW
        ensure
          cts.stop
          sleep 0.2
        end
      end

      it "deletes queues after the max events is reached" do
        allow(System).to receive_message_chain(:telemetry,:stale).and_return([])
        allow(System).to receive_message_chain(:telemetry,:limits_change_callback=)
        allow(System).to receive_message_chain(:telemetry,:check_stale)
        cts = CmdTlmServer.new
        begin
          pkt = Packet.new("TGT","PKT")
          pi = PacketItem.new("TEST", 0, 32, :UINT, :BIG_ENDIAN, nil)
          id = CmdTlmServer.subscribe_limits_events(2) # Max of 2 events

          # Create two limits change events
          pi.limits.state = :GREEN
          cts.limits_change_callback(pkt, pi, :STALE, 100, true)
          pi.limits.state = :YELLOW
          cts.limits_change_callback(pkt, pi, :GREEN, 100, true)

          # Pull off one
          type,data = CmdTlmServer.get_limits_event(id)

          # Add two more to put us over the limit
          cts.limits_change_callback(pkt, pi, :GREEN, 100, true)
          cts.limits_change_callback(pkt, pi, :GREEN, 100, true)

          # Try to pull off one
          expect { CmdTlmServer.get_limits_event(id) }.to raise_error("Limits event queue with id #{id} not found")
        ensure
          cts.stop
          sleep 0.2
        end
      end
    end

    describe "self.unsubscribe_limits_events" do
      it "unsubscribes to limits events" do
        allow(System).to receive_message_chain(:telemetry,:stale).and_return([])
        allow(System).to receive_message_chain(:telemetry,:limits_change_callback=)
        allow(System).to receive_message_chain(:telemetry,:check_stale)
        cts = CmdTlmServer.new
        begin
          pkt = Packet.new("TGT","PKT")
          pi = PacketItem.new("TEST", 0, 32, :UINT, :BIG_ENDIAN, nil)
          id = CmdTlmServer.subscribe_limits_events()

          # Create two limits change events
          pi.limits.state = :GREEN
          cts.limits_change_callback(pkt, pi, :STALE, 100, true)
          pi.limits.state = :YELLOW
          cts.limits_change_callback(pkt, pi, :GREEN, 100, true)

          # Get one
          type,data = CmdTlmServer.get_limits_event(id)

          # Unsubscribe and try to get the other one
          CmdTlmServer.unsubscribe_limits_events(id)
          expect { CmdTlmServer.get_limits_event(id) }.to raise_error("Limits event queue with id #{id} not found")
        ensure
          cts.stop
          sleep 0.2
        end
      end
    end

    describe "self.subscribe_packet_data" do
      it "rejects bad queue sizes" do
        expect{ CmdTlmServer.subscribe_packet_data([["SYSTEM","LIMITS_CHANGE"]], 0) }.to raise_error(ArgumentError)
        expect{ CmdTlmServer.subscribe_packet_data([["SYSTEM","LIMITS_CHANGE"]], true) }.to raise_error(ArgumentError)
      end

      it "rejects bad packet lists" do
        expect{ CmdTlmServer.subscribe_packet_data(["SYSTEM","LIMITS_CHANGE"]) }.to raise_error(ArgumentError, /packets must be nested array/)
      end

      it "subscribes to packets" do
        cts = CmdTlmServer.new
        id = CmdTlmServer.subscribe_packet_data([["SYSTEM","LIMITS_CHANGE"]])

        limits_change = System.telemetry.packet("SYSTEM","LIMITS_CHANGE")
        # Manually set the received_count since we're going to directly call
        # post_packet without going through the normal processing chain
        limits_change.received_count = 1
        cts.post_packet(limits_change)
        limits_change.received_count = 2
        cts.post_packet(limits_change)

        # Get and check the packet
        buffer,tgt,pkt,tv_sec,tv_usec,cnt = CmdTlmServer.get_packet_data(id, true)
        expect(buffer).not_to be_nil
        expect(tgt).to eql "SYSTEM"
        expect(pkt).to eql "LIMITS_CHANGE"
        expect(tv_sec).to be > 0
        expect(tv_usec).to be > 0
        expect(cnt).to eql 1

        # Get and check the second one
        buffer,tgt,pkt,tv_sec,tv_usec,cnt = CmdTlmServer.get_packet_data(id, true)
        expect(buffer).not_to be_nil
        expect(tgt).to eql "SYSTEM"
        expect(pkt).to eql "LIMITS_CHANGE"
        expect(tv_sec).to be > 0
        expect(tv_usec).to be > 0
        expect(cnt).to eql 2

        cts.stop
        sleep 0.2
      end

      it "deletes queues after the max packets is reached" do
        cts = CmdTlmServer.new
        id = CmdTlmServer.subscribe_packet_data([["SYSTEM","LIMITS_CHANGE"]], 2)
        limits_change = System.telemetry.packet("SYSTEM","LIMITS_CHANGE")
        # Manually set the received_count since we're going to directly call
        # post_packet without going through the normal processing chain
        limits_change.received_count = 1
        cts.post_packet(limits_change)

        # Get and check the packet
        buffer,tgt,pkt,tv_sec,tv_usec,cnt = CmdTlmServer.get_packet_data(id, true)
        expect(buffer).not_to be_nil
        expect(tgt).to eql "SYSTEM"
        expect(pkt).to eql "LIMITS_CHANGE"
        expect(tv_sec).to be > 0
        expect(tv_usec).to be > 0
        expect(cnt).to eql 1

        # Fill the queue
        1001.times { cts.post_packet(limits_change) }

        # Try to get another packet
        expect { CmdTlmServer.get_packet_data(id) }.to raise_error("Packet data queue with id #{id} not found")

        cts.stop
        sleep 0.2
      end
    end

    describe "self.unsubscribe_packet_data" do
      it "unsubscribes to packets" do
        cts = CmdTlmServer.new
        id = CmdTlmServer.subscribe_packet_data([["SYSTEM","LIMITS_CHANGE"]], 2)

        limits_change = System.telemetry.packet("SYSTEM","LIMITS_CHANGE")
        # Manually set the received_count since we're going to directly call
        # post_packet without going through the normal processing chain
        limits_change.received_count = 1
        cts.post_packet(limits_change)

        # Get and check the packet
        buffer,tgt,pkt,tv_sec,tv_usec,cnt = CmdTlmServer.get_packet_data(id, true)
        expect(buffer).not_to be_nil
        expect(tgt).to eql "SYSTEM"
        expect(pkt).to eql "LIMITS_CHANGE"
        expect(tv_sec).to be > 0
        expect(tv_usec).to be > 0
        expect(cnt).to eql 1

        CmdTlmServer.unsubscribe_packet_data(id)
        cts.post_packet(limits_change)
        expect { CmdTlmServer.get_packet_data(id) }.to raise_error("Packet data queue with id #{id} not found")
        cts.stop
        sleep 0.2
      end
    end

    describe "self.get_packet_data" do
      it "raises an error if the queue is empty and non_block" do
        cts = CmdTlmServer.new
        id = CmdTlmServer.subscribe_packet_data([["SYSTEM","LIMITS_CHANGE"]])

        expect { CmdTlmServer.get_packet_data(id, true) }.to raise_error(ThreadError)
        cts.stop
        sleep 0.2
      end

      it "works in disconnect mode" do
        cts = CmdTlmServer.new(CmdTlmServer::DEFAULT_CONFIG_FILE, false, true)
        id = CmdTlmServer.subscribe_packet_data([["SYSTEM","LIMITS_CHANGE"]])
        buffer,tgt,pkt,tv_sec,tv_usec,cnt = CmdTlmServer.get_packet_data(id, true)
        expect(buffer).not_to be_nil
        expect(tgt).to eql "SYSTEM"
        expect(pkt).to eql "LIMITS_CHANGE"
      end
    end

    describe "self.subscribe_server_messages" do
      it "rejects bad queue sizes" do
        expect{ CmdTlmServer.subscribe_server_messages(0) }.to raise_error(ArgumentError)
        expect{ CmdTlmServer.subscribe_server_messages(true) }.to raise_error(ArgumentError)
      end

      it "subscribes to server messages" do
        cts = CmdTlmServer.new
        id = CmdTlmServer.subscribe_server_messages()
        cts.post_server_message("This is a test")
        cts.post_server_message("Another test")
        message = CmdTlmServer.get_server_message(id, true)
        expect(message).to eql "This is a test"
        message = CmdTlmServer.get_server_message(id, true)
        expect(message).to eql "Another test"

        cts.stop
        sleep 0.2
      end

      it "deletes queues after the max packets is reached" do
        cts = CmdTlmServer.new
        id = CmdTlmServer.subscribe_server_messages(2)
        cts.post_server_message("One message")
        message = CmdTlmServer.get_server_message(id, true)
        expect(message).to eql "One message"

        # Fill the queue
        1001.times { cts.post_server_message("Message") }

        # Try to get another message
        expect { CmdTlmServer.get_server_message(id) }.to raise_error("Server message queue with id #{id} not found")

        cts.stop
        sleep 0.2
      end
    end

    describe "self.subscribe_server_messages" do
      it "unsubscribes to messages" do
        cts = CmdTlmServer.new
        id = CmdTlmServer.subscribe_server_messages(2)
        cts.post_server_message("One message")
        message = CmdTlmServer.get_server_message(id, true)
        expect(message).to eql "One message"

        CmdTlmServer.unsubscribe_server_messages(id)
        cts.post_server_message("Two message")
        expect { CmdTlmServer.get_server_message(id) }.to raise_error("Server message queue with id #{id} not found")
        cts.stop
        sleep 0.2
      end
    end

    describe "self.get_packet_data" do
      it "raises an error if the queue is empty and non_block" do
        cts = CmdTlmServer.new
        id = CmdTlmServer.subscribe_packet_data([["SYSTEM","LIMITS_CHANGE"]])

        expect { CmdTlmServer.get_packet_data(id, true) }.to raise_error(ThreadError)
        cts.stop
        sleep 0.2
      end
    end

    describe "self.clear_counters" do
      it "clears all counters" do
        cts = CmdTlmServer.new
        begin
          expect(System).to receive(:clear_counters)
          expect(CmdTlmServer.interfaces).to receive(:clear_counters)
          expect(CmdTlmServer.routers).to receive(:clear_counters)
          CmdTlmServer.json_drb.request_count = 100
          CmdTlmServer.clear_counters
          expect(CmdTlmServer.json_drb.request_count).to eql 0
        ensure
          cts.stop
          sleep 0.2
        end
      end
    end
  end
end
