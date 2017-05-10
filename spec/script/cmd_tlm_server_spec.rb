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

    describe "get_interface_cmd_pkt_count" do
      it "returns interface command count" do
        expect(get_interface_cmd_pkt_count("INST_INT")).to be >= 0
      end
    end

    describe "get_interface_tlm_pkt_count" do
      it "returns interface telemetry count" do
        expect(get_interface_tlm_pkt_count("INST_INT")).to be >= 0
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
        expect(filename).to match /server_messages.txt/
      end
    end

  end
end

