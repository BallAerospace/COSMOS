# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos'
require 'cosmos/api/api'
require 'cosmos/microservices/interface_microservice'

module Cosmos
  xdescribe Api do
    before(:each) do
      @redis = configure_store()
      allow_any_instance_of(Interface).to receive(:connected?)
      allow_any_instance_of(Interface).to receive(:connect)
      allow_any_instance_of(Interface).to receive(:disconnect)
      allow_any_instance_of(Interface).to receive(:write_raw)
      allow_any_instance_of(Interface).to receive(:read)
      allow_any_instance_of(Interface).to receive(:write)
      @api = CmdTlmServer.new
    end

    after(:each) do
      @api.stop
    end

    describe "subscribe_server_messages" do
      xit "calls CmdTlmServer" do
        stub_const("Cosmos::CmdTlmServer::DEFAULT_SERVER_MESSAGES_QUEUE_SIZE", 100)
        expect(CmdTlmServer).to receive(:subscribe_server_messages)
        @api.subscribe_server_messages
      end
    end

    describe "unsubscribe_server_messages" do
      xit "calls CmdTlmServer" do
        expect(CmdTlmServer).to receive(:unsubscribe_server_messages)
        @api.unsubscribe_server_messages(0)
      end
    end

    describe "get_server_message" do
      xit "gets a server message" do
        expect(CmdTlmServer).to receive(:get_server_message)
        @api.get_server_message(0)
      end
    end

    describe "get_interface_targets" do
      xit "returns the targets associated with an interface" do
        expect(@api.get_interface_targets("INST_INT")).to eql ["INST"]
      end
    end

    describe "get_background_tasks" do
      xit "gets background task details" do
        sleep 0.1
        tasks = @api.get_background_tasks
        expect(tasks[0][0]).to eql("Example Background Task1")
        expect(tasks[0][1]).to eql("sleep")
        expect(tasks[0][2]).to eql("This is example one")
        expect(tasks[1][0]).to eql("Example Background Task2")
        expect(tasks[1][1]).to eql("sleep")
        expect(tasks[1][2]).to eql("This is example two")
        sleep 0.5
        tasks = @api.get_background_tasks
        expect(tasks[0][0]).to eql("Example Background Task1")
        expect(tasks[0][1]).to eql("complete") # Thread completes
        expect(tasks[0][2]).to eql("This is example one")
        expect(tasks[1][0]).to eql("Example Background Task2")
        expect(tasks[1][1]).to eql("sleep")
        expect(tasks[1][2]).to eql("This is example two")
      end
    end

    describe "get_server_status" do
      it "gets server details" do
        status = @api.get_server_status
        expect(status[0]).to eql 'DEFAULT'
        expect(status[1]).to eql 0 # TODO: this was the old port value 7777
        expect(status[2]).to eql 0
        expect(status[3]).to eql 0
        expect(status[4]).to eql 0
        expect(status[5]).to be > 0
      end
    end

    describe "get_interface_info" do
      it "complains about non-existant interfaces" do
        expect { @api.get_interface_info("BLAH") }.to raise_error(RuntimeError, "Interface 'BLAH' does not exist")
      end

      xit "gets interface info" do
        info = @api.get_interface_info("INST_INT")
        expect(info[0]).to eq "ATTEMPTING"
        expect(info[1..-1]).to eq [0,0,0,0,0,0,0]
      end
    end

    describe "get_all_interface_info" do
      xit "gets interface name and all info" do
        info = @api.get_all_interface_info.sort
        expect(info[0][0]).to eq "INST_INT"
      end
    end

    describe "get_router_names" do
      xit "returns all router names" do
        expect(@api.get_router_names.sort).to eq %w(PREIDENTIFIED_CMD_ROUTER PREIDENTIFIED_ROUTER ROUTE)
      end
    end

    describe "get_router_info" do
      it "complains about non-existant routers" do
        expect { @api.get_router_info("BLAH") }.to raise_error(RuntimeError, "Interface 'BLAH' does not exist")
      end

      xit "gets router info" do
        info = @api.get_router_info("ROUTE")
        expect(info[0]).to eq "ATTEMPTING"
        expect(info[1..-1]).to eq [0,0,0,0,0,0,0]
      end
    end

    describe "get_all_router_info" do
      xit "gets router name and all info" do
        info = @api.get_all_router_info.sort
        expect(info[0][0]).to eq "PREIDENTIFIED_CMD_ROUTER"
        expect(info[1][0]).to eq "PREIDENTIFIED_ROUTER"
        expect(info[2][0]).to eq "ROUTE"
      end
    end

    describe "get_packet_logger_info" do
      xit "complains about non-existant loggers" do
        expect { @api.get_packet_logger_info("BLAH") }.to raise_error(RuntimeError, "Unknown packet log writer: BLAH")
      end

      xit "gets packet logger info" do
        info = @api.get_packet_logger_info("DEFAULT")
        expect(info[0]).to eq ["INST_INT"]
      end
    end

    describe "get_all_packet_logger_info" do
      xit "gets all packet loggers info" do
        info = @api.get_all_packet_logger_info.sort
        expect(info[0][0]).to eq "DEFAULT"
        expect(info[0][1]).to eq ["INST_INT"]
      end
    end

    describe "background_task apis" do
      xit "starts, gets into, and stops background tasks" do
        @api.start_background_task("Example Background Task2")
        sleep 0.1
        info = @api.get_background_tasks.sort
        expect(info[1][0]).to eq "Example Background Task2"
        expect(info[1][1]).to eq "sleep"
        expect(info[1][2]).to eq "This is example two"
        @api.stop_background_task("Example Background Task2")
        sleep 0.1
        info = @api.get_background_tasks.sort
        expect(info[1][0]).to eq "Example Background Task2"
        expect(info[1][1]).to eq "complete"
        expect(info[1][2]).to eq "This is example two"
      end
    end

    # All these methods simply pass through directly to CmdTlmServer without
    # adding any functionality. Thus we just test that they are are received
    # by the CmdTlmServer.
    # TODO: We need to evaluate each of these in the new system
    describe "CmdTlmServer pass-throughs" do
      xit "calls through to the CmdTlmServer" do
        @api.get_interface_names
        @api.connect_interface("INST_INT")
        @api.disconnect_interface("INST_INT")
        @api.interface_state("INST_INT")
        @api.map_target_to_interface("INST", "INST_INT")
        @api.get_packet_loggers
        @api.connect_router("ROUTE")
        @api.disconnect_router("ROUTE")
        @api.router_state("ROUTE")
        @api.send_raw("INST_INT","\x00\x01")
        @api.get_cmd_log_filename('DEFAULT')
        @api.get_tlm_log_filename('DEFAULT')
        @api.start_logging('ALL')
        @api.stop_logging('ALL')
        @api.start_cmd_log('ALL')
        @api.start_tlm_log('ALL')
        @api.stop_cmd_log('ALL')
        @api.stop_tlm_log('ALL')
        @api.get_server_message_log_filename
        @api.start_new_server_message_log
        @api.start_raw_logging_interface
        @api.stop_raw_logging_interface
        @api.start_raw_logging_router
        @api.stop_raw_logging_router
      end
    end
  end
end
