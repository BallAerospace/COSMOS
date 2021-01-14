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
require 'cosmos/script'
require 'tempfile'

module Cosmos
  xdescribe Script do
    before(:all) do
      # Save cmd_tlm_server.txt
      @cts = File.join(Cosmos::USERPATH,'config','tools','cmd_tlm_server','cmd_tlm_server.txt')
      FileUtils.mv @cts, Cosmos::USERPATH

      # Recreate cmd_tlm_server.txt with a PROTOCOL
      FileUtils.mkdir_p(File.dirname(@cts))
      File.open(@cts,'w') do |file|
        file.puts 'INTERFACE INST_INT interface.rb'
        file.puts 'TARGET INST'
        file.puts 'PROTOCOL READ override_protocol.rb'
      end
      System.class_eval('@@instance = nil')
      require 'cosmos/script'
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
      allow_any_instance_of(Interface).to receive(:write)
      allow_any_instance_of(Interface).to receive(:read)

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

    describe "tlm, tlm_raw, tlm_formatted, tlm_with_units, tlm_variable, get_tlm_buffer" do
      it "passes through to the cmd_tlm_server" do
        expect {
          expect(tlm("INST HEALTH_STATUS TEMP1")).to eql -100.0
          expect(tlm_raw("INST HEALTH_STATUS TEMP1")).to eql 0
          expect(tlm_formatted("INST HEALTH_STATUS TEMP1")).to eql "-100.000"
          expect(tlm_with_units("INST HEALTH_STATUS TEMP1")).to eql "-100.000 C"
          expect(tlm_variable("INST HEALTH_STATUS TEMP1", :RAW)).to eql 0
          get_tlm_buffer("INST", "HEALTH_STATUS")
        }.to_not raise_error
      end
    end

    describe "set_tlm, set_tlm_raw, override_tlm_raw" do
      it "passes through to the cmd_tlm_server" do
        expect {
          set_tlm("INST HEALTH_STATUS TEMP3 = 1")
          set_tlm("INST HEALTH_STATUS ASCIICMD = 'Hi'")
          expect(tlm_raw("INST HEALTH_STATUS ASCIICMD")).to eql 'Hi'
          set_tlm("INST HEALTH_STATUS ASCIICMD ='Hello'")
          expect(tlm_raw("INST HEALTH_STATUS ASCIICMD")).to eql 'Hello'
          set_tlm("INST HEALTH_STATUS ASCIICMD= 'Hello World'")
          expect(tlm_raw("INST HEALTH_STATUS ASCIICMD")).to eql 'Hello World'
          set_tlm("INST HEALTH_STATUS ASCIICMD='Hello World'")
          expect(tlm_raw("INST HEALTH_STATUS ASCIICMD")).to eql 'Hello World'
          set_tlm("INST HEALTH_STATUS ASCIICMD='Hello = World'")
          expect(tlm_raw("INST HEALTH_STATUS ASCIICMD")).to eql 'Hello = World'
          set_tlm_raw("INST HEALTH_STATUS TEMP3 = 0")
          expect(tlm_raw("INST HEALTH_STATUS TEMP3")).to eql 0
          set_tlm_raw("INST HEALTH_STATUS ASCIICMD = 'Hi'")
          expect(tlm_raw("INST HEALTH_STATUS ASCIICMD")).to eql 'Hi'
          set_tlm_raw("INST HEALTH_STATUS ASCIICMD ='Hello'")
          expect(tlm_raw("INST HEALTH_STATUS ASCIICMD")).to eql 'Hello'
          set_tlm_raw("INST HEALTH_STATUS ASCIICMD= 'Hello World'")
          expect(tlm_raw("INST HEALTH_STATUS ASCIICMD")).to eql 'Hello World'
          set_tlm_raw("INST HEALTH_STATUS ASCIICMD='Hello World'")
          expect(tlm_raw("INST HEALTH_STATUS ASCIICMD")).to eql 'Hello World'
          set_tlm_raw("INST HEALTH_STATUS ASCIICMD='Hello = World'")
          expect(tlm_raw("INST HEALTH_STATUS ASCIICMD")).to eql 'Hello = World'
          override_tlm_raw("INST HEALTH_STATUS TEMP3 = 0")
          override_tlm_raw("INST HEALTH_STATUS ASCIICMD = 'Hi'")
          override_tlm_raw("INST HEALTH_STATUS ASCIICMD ='Hello'")
          override_tlm_raw("INST HEALTH_STATUS ASCIICMD= 'Hello World'")
          override_tlm_raw("INST HEALTH_STATUS ASCIICMD='Hello World'")
          override_tlm_raw("INST HEALTH_STATUS ASCIICMD='Hello = World'")
        }.to_not raise_error
      end

      it "raises with bad syntax" do
        error_msg = "ERROR: Set Telemetry Item must be specified as 'TargetName PacketName ItemName = Value'"
        expect { set_tlm("INST HEALTH_STATUS = 5") }.to raise_error(/#{error_msg}/)
        expect { set_tlm("INST HEALTH_STATUS TEMP3") }.to raise_error(/#{error_msg}/)
        expect { set_tlm("INST HEALTH_STATUS TEMP3 = ") }.to raise_error(/#{error_msg}/)
        expect { set_tlm_raw("INST HEALTH_STATUS = 5") }.to raise_error(/#{error_msg}/)
        expect { set_tlm_raw("INST HEALTH_STATUS TEMP3") }.to raise_error(/#{error_msg}/)
        expect { set_tlm_raw("INST HEALTH_STATUS = 5") }.to raise_error(/#{error_msg}/)
        expect { override_tlm_raw("INST HEALTH_STATUS TEMP3") }.to raise_error(/#{error_msg}/)
        expect { override_tlm_raw("INST HEALTH_STATUS TEMP3 = ") }.to raise_error(/#{error_msg}/)
        expect { override_tlm_raw("INST HEALTH_STATUS TEMP3 = ") }.to raise_error(/#{error_msg}/)
      end
    end

    describe "get_tlm_packet" do
      it "gets the packet values" do
        expect(get_tlm_packet("INST", "HEALTH_STATUS", :RAW)).to include(["TEMP1", 0, :RED_LOW])
      end
    end

    # TODO:
    # describe "get_tlm_values" do
    #   it "gets the given values" do
    #     vals = get_tlm_values(["INST__HEALTH_STATUS__TEMP1__CONVERTED", "INST__HEALTH_STATUS__TEMP2__CONVERTED"])
    #     expect(vals[0][0]).to eql -100.0
    #     expect(vals[0][1]).to eql :RED_LOW
    #     expect(vals[2][0]).to eql [-80.0, -70.0, 60.0, 80.0, -20.0, 20.0]
    #     expect(vals[3]).to eql :DEFAULT
    #   end
    # end

    describe "get_tlm_list" do
      it "gets packets for a given target" do
        expect(get_tlm_list("INST")).to include(["HEALTH_STATUS", "Health and status from the instrument"])
      end
    end

    describe "get_tlm_item_list" do
      it "gets telemetry for a given packet" do
        expect(get_tlm_item_list("INST", "HEALTH_STATUS")).to include(["TEMP1",nil,"Temperature #1"])
      end
    end

    describe "get_tlm_details" do
      it "gets telemetry for a given packet" do
        details = get_tlm_details([["INST", "HEALTH_STATUS", "TEMP1"], ["INST", "HEALTH_STATUS", "TEMP2"]])
        expect(details[0]["name"]).to eql "TEMP1"
        expect(details[1]["name"]).to eql "TEMP2"
      end
    end

    describe "get_target_list" do
      it "returns the list of targets" do
        expect(get_target_list).to include("INST")
      end
    end

    describe "subscribe_packet_data, get_packet, unsubscribe_packet_data" do
      it "raises an error if non_block and the queue is empty" do
        id = subscribe_packet_data([["INST","HEALTH_STATUS"]])
        expect { get_packet(id, true) }.to raise_error(ThreadError, "queue empty")
        unsubscribe_packet_data(id)
      end

      it "subscribes and gets packets" do
        id = subscribe_packet_data([["SYSTEM","META"]])
        packet = get_packet(id)
        inject_tlm("SYSTEM", "META")
        expect(packet.target_name).to eql "SYSTEM"
        expect(packet.packet_name).to eql "META"
        expect(packet.received_count).to eql 0
        packet = get_packet(id)
        expect(packet.target_name).to eql "SYSTEM"
        expect(packet.packet_name).to eql "META"
        expect(packet.received_time).to be_within(1).of Time.now
        expect(packet.received_count).to eql 1
        unsubscribe_packet_data(id)
      end
    end
  end
end
