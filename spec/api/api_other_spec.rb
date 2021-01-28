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

    describe "get_out_of_limits" do
      xit "returns all out of limits items" do
        @api.inject_tlm("INST","HEALTH_STATUS",{TEMP1: 0, TEMP2: 0, TEMP3: 0, TEMP4: 0}, :RAW)
        items = @api.get_out_of_limits
        (0..3).each do |i|
          expect(items[i][0]).to eql "INST"
          expect(items[i][1]).to eql "HEALTH_STATUS"
          expect(items[i][2]).to eql "TEMP#{i+1}"
          expect(items[i][3]).to eql :RED_LOW
        end
      end
    end

    describe "get_overall_limits_state" do
      xit "returns the overall system limits state" do
        @api.inject_tlm("INST","HEALTH_STATUS",{TEMP1: 0, TEMP2: 0, TEMP3: 0, TEMP4: 0}, :RAW)
        expect(@api.get_overall_limits_state).to eq :RED
      end
    end

    describe "limits_enabled?" do
      it "complains about non-existant targets" do
        expect { @api.limits_enabled?("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.limits_enabled?("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.limits_enabled?("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "returns whether limits are enable for an item" do
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
      end
    end

    describe "enable_limits" do
      it "complains about non-existant targets" do
        expect { @api.enable_limits("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.enable_limits("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.enable_limits("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "enables limits for an item" do
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
        @api.disable_limits("INST","HEALTH_STATUS","TEMP1")
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be false
        @api.enable_limits("INST","HEALTH_STATUS","TEMP1")
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
      end
    end

    describe "disable_limits" do
      it "complains about non-existant targets" do
        expect { @api.disable_limits("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.disable_limits("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.disable_limits("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "disables limits for an item" do
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
        @api.disable_limits("INST","HEALTH_STATUS","TEMP1")
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be false
        @api.enable_limits("INST","HEALTH_STATUS","TEMP1")
      end
    end

    describe "subscribe_packet_data" do
      xit "calls CmdTlmServer" do
        stub_const("Cosmos::CmdTlmServer::DEFAULT_PACKET_DATA_QUEUE_SIZE", 100)
        expect(CmdTlmServer).to receive(:subscribe_packet_data)
        @api.subscribe_packet_data([["TGT","PKT1"],["TGT","PKT2"]])
      end
    end

    describe "unsubscribe_packet_datas" do
      xit "calls CmdTlmServer" do
        expect(CmdTlmServer).to receive(:unsubscribe_packet_data)
        @api.unsubscribe_packet_data(10)
      end
    end

    describe "get_packet_data" do
      xit "calls CmdTlmServer" do
        expect(CmdTlmServer).to receive(:get_packet_data)
        @api.get_packet_data(10)
      end
    end

    describe "get_packet" do
      xit "creates a packet out of the get_packet_data" do
        time = Time.now
        expect(CmdTlmServer).to receive(:get_packet_data).and_return(["\xAB","INST","HEALTH_STATUS",time.to_f,0,10])
        pkt = @api.get_packet(10)
        expect(pkt.buffer[0]).to eq "\xAB"
        expect(pkt.target_name).to eq "INST"
        expect(pkt.packet_name).to eq "HEALTH_STATUS"
        expect(pkt.received_time.formatted).to eq time.formatted
        expect(pkt.received_count).to eq 10
      end
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

    describe "get_cmd_cnt" do
      before(:each) do
        # Configure the store to return a matching IDs so commands don't timeout
        allow(Store.instance).to receive(:write_topic).and_wrap_original do |m, *args|
          if args[0] =~ /COMMAND__/
            m.call(*args)
          else
            '1577836800000-0'
          end
        end
        allow(Store.instance).to receive(:read_topics).and_yield('topic', '1577836800000-0', {"result" => "SUCCESS"}, nil)
      end

      it "complains about non-existant targets" do
        expect { @api.get_cmd_cnt("BLAH", "ABORT") }.to raise_error(RuntimeError, /does not exist/)
      end

      it "complains about non-existant packets" do
        expect { @api.get_cmd_cnt("INST", "BLAH") }.to raise_error(RuntimeError, /does not exist/)
      end

      it "gets the command packet count" do
        cnt1 = @api.get_cmd_cnt("INST", "ABORT")
        @api.cmd("INST", "ABORT")
        cnt2 = @api.get_cmd_cnt("INST", "ABORT")
        expect(cnt2 - cnt1).to eq 1
      end
    end

    describe "get_tlm_cnt" do
      it "complains about non-existant targets" do
        expect { @api.get_tlm_cnt("BLAH", "ABORT") }.to raise_error(RuntimeError, /does not exist/)
      end

      it "complains about non-existant packets" do
        expect { @api.get_tlm_cnt("INST", "BLAH") }.to raise_error(RuntimeError, /does not exist/)
      end

      xit "gets the telemetry packet count" do
        cnt1 = @api.get_tlm_cnt("INST", "ADCS")
        @api.inject_tlm("INST","ADCS")
        cnt2 = @api.get_tlm_cnt("INST", "ADCS")
        expect(cnt2 - cnt1).to eq 1
      end
    end

    describe "get_all_cmd_info" do
      it "gets tgt, pkt, rx cnt for all commands" do
        total = 0 # TODO: Unknown is 1
        System.commands.target_names.each do |tgt|
          next if tgt == 'SYSTEM' # TODO: System target
          total += System.commands.packets(tgt).keys.length
        end
        info = @api.get_all_cmd_info.sort
        expect(info.length).to eq total
        expect(info[0][0]).to eq "INST"
        expect(info[0][1]).to eq "ABORT"
        expect(info[0][2]).to be >= 0
        # TODO: What about UNKNOWN
        # expect(info[-1][0]).to eq "UNKNOWN"
        # expect(info[-1][1]).to eq "UNKNOWN"
        # expect(info[-1][2]).to eq 0
      end
    end

    describe "get_all_tlm_info" do
      it "gets tgt, pkt, rx cnt for all telemetry" do
        total = 0 # TODO: Unknown is 1
        System.telemetry.target_names.each do |tgt|
          next if tgt == 'SYSTEM'
          total += System.telemetry.packets(tgt).keys.length
        end
        info = @api.get_all_tlm_info.sort
        expect(info.length).to eq total
        expect(info[0][0]).to eq "INST"
        expect(info[0][1]).to eq "ADCS"
        expect(info[0][2]).to be >= 0
        # TODO: Unknown?
        # expect(info[-1][0]).to eq "UNKNOWN"
        # expect(info[-1][1]).to eq "UNKNOWN"
        # expect(info[-1][2]).to eq 0
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
        @api.get_target_ignored_parameters("INST")
        @api.get_target_ignored_items("INST")
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
