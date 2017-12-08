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
require 'cosmos/script/script'
require 'tempfile'

module Cosmos

  describe Script do

    before(:all) do
      cts = File.join(Cosmos::USERPATH,'config','tools','cmd_tlm_server','cmd_tlm_server.txt')
      FileUtils.mkdir_p(File.dirname(cts))
      File.open(cts,'w') do |file|
        file.puts 'INTERFACE INST_INT interface.rb'
        file.puts 'TARGET INST'
      end
      System.class_eval('@@instance = nil')

      require 'cosmos/script'
    end

    after(:all) do
      clean_config()
      FileUtils.rm_rf File.join(Cosmos::USERPATH,'config','tools')
    end

    before(:each) do
      allow_any_instance_of(Interface).to receive(:connected?).and_return(true)
      allow_any_instance_of(Interface).to receive(:disconnect)

      @server = CmdTlmServer.new
      shutdown_cmd_tlm()
      initialize_script_module()
      sleep 0.1
    end

    after(:each) do
      @server.stop
      shutdown_cmd_tlm()
      sleep(0.1)
    end

    describe "get_interface_names" do
      it "returns all interfaces" do
        expect(get_interface_names).to include("INST_INT")
      end
    end

    describe "connect_interface, disconnect_interface, interface_state" do
      it "connects, disconnect and return the state of the interface CTS-3" do
        connect_interface("INST_INT")
        expect(interface_state("INST_INT")).to eql "CONNECTED"
        disconnect_interface("INST_INT")
      end
    end

    describe "map_target_to_interface" do
      it "maps a target name to an interface" do
        map_target_to_interface("INST","INST_INT")
      end
    end

    describe "get_interface_info" do
      it "returns interface info" do
        state, clients, tx_q_size, rx_q_size, bytes_tx, bytes_rx, cmd_cnt, tlm_cnt = get_interface_info("INST_INT")
        connect_interface("INST_INT")
        expect(state).to eql "CONNECTED"
        disconnect_interface("INST_INT")
        expect(clients).to be >= 0
        expect(tx_q_size).to be >= 0
        expect(rx_q_size).to be >= 0
        expect(bytes_tx).to be >= 0
        expect(bytes_rx).to be >= 0
        expect(cmd_cnt).to be >= 0
        expect(tlm_cnt).to be >= 0
      end
    end

    describe "get_router_info" do
      it "returns router info" do
        connect_router("PREIDENTIFIED_ROUTER")
        state, clients, tx_q_size, rx_q_size, bytes_tx, bytes_rx, pkts_rcvd, pkts_sent = get_router_info("PREIDENTIFIED_ROUTER")
        disconnect_router("PREIDENTIFIED_ROUTER")
        expect(state).to eql "CONNECTED"
        expect(clients).to be >= 0
        expect(tx_q_size).to be >= 0
        expect(rx_q_size).to be >= 0
        expect(bytes_tx).to be >= 0
        expect(bytes_rx).to be >= 0
        expect(pkts_rcvd).to be >= 0
        expect(pkts_sent).to be >= 0
      end
    end

    describe "get_target_info" do
      it "returns target info" do
        cmd_cnt, tlm_cnt = get_target_info("INST")
        expect(cmd_cnt).to be >= 0
        expect(tlm_cnt).to be >= 0
      end
    end

    describe "get_target_ignored_parameters" do
      it "returns ignored parameters" do
        params = get_target_ignored_parameters("INST")
        expect(params.length).to be >= 0
      end
    end

    describe "get_target_ignored_items" do
      it "returns ignored items" do
        items = get_target_ignored_items("INST")
        expect(items.length).to be >= 0
      end
    end

    describe "get_cmd_cnt" do
      it "returns cmd count" do
        expect(get_cmd_cnt("INST", "COLLECT")).to be >= 0
      end
    end

    describe "get_tlm_cnt" do
      it "returns tlm count" do
        expect(get_tlm_cnt("INST", "HEALTH_STATUS")).to be >= 0
      end
    end

    describe "get_packet_loggers" do
      it "returns all the packet logger names" do
        loggers = get_packet_loggers()
        expect(loggers).to include("DEFAULT")
      end
    end

    describe "get_packet_logger_info" do
      it "returns packet logger info" do
        interfaces, cmd_logging, cmd_q_size, cmd_filename, cmd_file_size,
                    tlm_logging, tlm_q_size, tlm_filename, tlm_file_size, = get_packet_logger_info("DEFAULT")
        expect(interfaces).to include("INST_INT")
        expect(cmd_logging).to eql true
        expect(cmd_q_size).to be >= 0
        expect(cmd_filename).to be_a(String)
        expect(cmd_file_size).to be >= 0
        expect(tlm_logging).to eql true
        expect(tlm_q_size).to be >= 0
        expect(tlm_filename).to be_a(String)
        expect(tlm_file_size).to be >= 0
      end
    end

    describe "connect_router, disconnect_router, get_router_names, router_state" do
      it "returns connect, disconnect, and list the routers CTS-11" do
        expect(get_router_names).to include("PREIDENTIFIED_ROUTER")
        connect_router("PREIDENTIFIED_ROUTER")
        expect(router_state("PREIDENTIFIED_ROUTER")).to eql "CONNECTED"
        disconnect_router("PREIDENTIFIED_ROUTER")
      end
    end

    describe "logging methods" do
      it "starts and stop logging and get filenames CTS-14" do
        start_logging
        stop_logging
        get_cmd_log_filename
        get_tlm_log_filename
        start_cmd_log
        start_tlm_log
        get_cmd_log_filename
        get_tlm_log_filename
        stop_cmd_log
        stop_tlm_log
        get_cmd_log_filename
        get_tlm_log_filename
        start_raw_logging_interface
        start_raw_logging_router
        stop_raw_logging_interface
        stop_raw_logging_router

        start_new_server_message_log
        sleep 0.1
        filename = get_server_message_log_filename
        expect(filename).to match(/server_messages.txt/)
      end
    end

    describe "subscribe_server_messages, get_server_message, unsubscribe_server_messages" do
      it "raises an error if non_block and the queue is empty" do
        id = subscribe_server_messages
        expect { get_server_message(id, true) }.to raise_error(ThreadError, "queue empty")
        unsubscribe_server_messages(id)
      end

      it "subscribes and gets server messages" do
        id = subscribe_server_messages
        CmdTlmServer.instance.post_server_message("This is a test")
        result = get_server_message(id, true)
        expect(result).to eql "This is a test"
        unsubscribe_server_messages(id)
      end
    end
  end
end
