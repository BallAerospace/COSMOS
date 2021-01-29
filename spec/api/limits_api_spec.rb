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
require 'cosmos/api/limits_api'
require 'cosmos/script/extract'
require 'cosmos/utilities/authorization'
require 'cosmos/microservices/interface_microservice'
require 'cosmos/microservices/decom_microservice'
require 'cosmos/microservices/cvt_microservice'

module Cosmos
  describe Api do
    class ApiTest
      include Extract
      include Api
      include Authorization
    end

    before(:each) do
      mock_redis()
      setup_system()
      %w(INST SYSTEM).each do |target|
        model = TargetModel.new(folder_name: target, name: target, scope: "DEFAULT")
        model.create
        model.update_store(File.join(SPEC_DIR, 'install', 'config', 'targets'))
      end

      model = InterfaceModel.new(name: "INST_INT", scope: "DEFAULT", target_names: ["INST"], config_params: ["interface.rb"])
      model.create

      # Mock out some stuff in Microservice initialize()
      dbl = double("AwsS3Client").as_null_object
      allow(Aws::S3::Client).to receive(:new).and_return(dbl)
      allow(Zip::File).to receive(:open).and_return(true)
      allow_any_instance_of(Cosmos::Interface).to receive(:connected?).and_return(true)
      allow_any_instance_of(Cosmos::Interface).to receive(:read_interface) { sleep }

      model = MicroserviceModel.new(name: "DEFAULT__INTERFACE__INST_INT", scope: "DEFAULT", target_names: ["INST"])
      model.create
      @im = InterfaceMicroservice.new("DEFAULT__INTERFACE__INST_INT")
      @im_thread = Thread.new { @im.run }

      model = MicroserviceModel.new(name: "DEFAULT__DECOM__INST_INT", scope: "DEFAULT", topics: ["DEFAULT__TELEMETRY__INST__HEALTH_STATUS"])
      model.create
      @dm = DecomMicroservice.new("DEFAULT__DECOM__INST_INT")
      @dm_thread = Thread.new { @dm.run }

      # model = MicroserviceModel.new(name: "DEFAULT__CVT__INST_INT", scope: "DEFAULT", topics: ["DEFAULT__DECOM__INST__HEALTH_STATUS"])
      # model.create
      # @cm = CvtMicroservice.new("DEFAULT__CVT__INST_INT")
      # @cm_thead = Thread.new { @cm.run }
      sleep(0.01) # Allow the thread to run

      @api = ApiTest.new
    end

    after(:each) do
      # @cm.shutdown
      @dm.shutdown
      @im.shutdown
      sleep(0.01)
      Thread.list.each do |t|
        if t != Thread.current
          t.kill
        end
      end
      sleep(0.01)
    end

    describe "get_stale" do
      it "complains about non-existant targets" do
        expect { @api.get_stale(false, "BLAH") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
      end

      it "gets stale packets for the specified target" do
        inst_packets = []
        all = @api.get_all_telemetry("INST")
        all.each {|item| inst_packets << [item['target_name'], item['packet_name']] }
        stale = @api.get_stale(false, "INST").sort
        # Initially all packets are stale
        expect(stale).to eql inst_packets.sort

        # packet = System.telemetry.packet('INST', 'HEALTH_STATUS')
        # @im.handle_packet(packet)
        # # TelemetryTopic.write_packet(packet, scope: 'DEFAULT')
        # sleep(0.1)
        # puts @api.get_stale(false, "INST").sort

      #   # Set HEALTH_STATUS not stale
      #   packet = TargetModel.get_packet("INST", "HEALTH_STATUS", scope: "DEFAULT")
      #   packet.delete('stale')
      #   Store.instance.hset("cosmostlm__INST", "HEALTH_STATUS", JSON.generate(packet))
      #   stale = @api.get_stale(false,"INST").sort
      #   inst_pkts = []
      #   System.telemetry.packets("INST").each do |name, pkt|
      #     next if name == "HEALTH_STATUS" # not stale
      #     inst_pkts << ["INST", name]
      #   end
      #   expect(stale).to eq inst_pkts.sort
      end

      # it "only gets stale packets with limits items" do
      #   stale = @api.get_stale(true,"INST").sort
      #   expect(stale).to eq [["INST","HEALTH_STATUS"]]
      # end
    end

    # describe "get_limits" do
    #   it "complains about non-existant targets" do
    #     expect { @api.get_limits("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
    #   end

    #   it "complains about non-existant packets" do
    #     expect { @api.get_limits("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
    #   end

    #   it "complains about non-existant items" do
    #     expect { @api.get_limits("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
    #   end

    #   it "gets limits for an item" do
    #     expect(@api.get_limits("INST","HEALTH_STATUS","TEMP1")).to eql({ 'DEFAULT' => [-80.0, -70.0, 60.0, 80.0, -20.0, 20.0],
    #                                                                      'TVAC' => [-80.0, -30.0, 30.0, 80.0] })
    #   end
    # end

    # describe "set_limits" do
    #   it "complains about non-existant targets" do
    #     expect { @api.set_limits("BLAH","HEALTH_STATUS","TEMP1",0.0,10.0,20.0,30.0) }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
    #   end

    #   it "complains about non-existant packets" do
    #     expect { @api.set_limits("INST","BLAH","TEMP1",0.0,10.0,20.0,30.0) }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
    #   end

    #   it "complains about non-existant items" do
    #     expect { @api.set_limits("INST","HEALTH_STATUS","BLAH",0.0,10.0,20.0,30.0) }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
    #   end

    #   it "creates a CUSTOM limits set" do
    #     @api.set_limits("INST","HEALTH_STATUS","TEMP1",0.0,10.0,20.0,30.0)
    #     expect(@api.get_limits("INST","HEALTH_STATUS","TEMP1")['CUSTOM']).to eql([0.0, 10.0, 20.0, 30.0])
    #   end

    #   it "overrides existing limits" do
    #     item = @api.get_item("INST","HEALTH_STATUS","TEMP1")
    #     expect(item['limits']['persistence_setting']).to_not eql(10)
    #     expect(item['limits']['enabled']).to be true
    #     @api.set_limits("INST","HEALTH_STATUS","TEMP1",0.0,1.0,2.0,3.0,4.0,5.0,'DEFAULT',10,false)
    #     item = @api.get_item("INST","HEALTH_STATUS","TEMP1")
    #     expect(item['limits']['persistence_setting']).to eql(10)
    #     expect(item['limits']['enabled']).to be_nil
    #     expect(item['limits']['DEFAULT']).to eql({ 'red_low' => 0.0, 'yellow_low' => 1.0, 'yellow_high' => 2.0,
    #         'red_high' => 3.0, 'green_low' => 4.0, 'green_high' => 5.0 })
    #   end
    # end

    # describe "get_limits_groups" do
    #   it "returns all the limits groups" do
    #     expect(@api.get_limits_groups).to eql({ "FIRST" => [%w(INST HEALTH_STATUS TEMP1), %w(INST HEALTH_STATUS TEMP3)],
    #         "SECOND" => [%w(INST HEALTH_STATUS TEMP2), %w(INST HEALTH_STATUS TEMP4)] })
    #   end
    # end

    # describe "enable_limits_group" do
    #   it "complains about undefined limits groups" do
    #     expect { @api.enable_limits_group("MINE") }.to raise_error(RuntimeError, "LIMITS_GROUP MINE undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP MINE")
    #   end

    #   it "enables limits for all items in the group" do
    #     @api.disable_limits("INST","HEALTH_STATUS","TEMP1")
    #     @api.disable_limits("INST","HEALTH_STATUS","TEMP3")
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be false
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP3")).to be false
    #     @api.enable_limits_group("FIRST")
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP3")).to be true
    #   end
    # end

    # describe "disable_limits_group" do
    #   it "complains about undefined limits groups" do
    #     expect { @api.disable_limits_group("MINE") }.to raise_error(RuntimeError, "LIMITS_GROUP MINE undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP MINE")
    #   end

    #   it "disables limits for all items in the group" do
    #     @api.enable_limits("INST","HEALTH_STATUS","TEMP1")
    #     @api.enable_limits("INST","HEALTH_STATUS","TEMP3")
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP3")).to be true
    #     @api.disable_limits_group("FIRST")
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be false
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP3")).to be false
    #   end
    # end

    # describe "get_limits_sets, get_limits_set, set_limits_set" do
    #   it "gets and set the active limits set" do
    #     expect(@api.get_limits_sets).to eql ['DEFAULT', 'TVAC']
    #     @api.set_limits_set("TVAC")
    #     expect(@api.get_limits_set).to eql "TVAC"
    #     @api.set_limits_set("DEFAULT")
    #     expect(@api.get_limits_set).to eql "DEFAULT"
    #   end
    # end

    # describe "subscribe_limits_events" do
    #   xit "calls CmdTlmServer" do
    #     stub_const("Cosmos::CmdTlmServer::DEFAULT_LIMITS_EVENT_QUEUE_SIZE", 100)
    #     expect(CmdTlmServer).to receive(:subscribe_limits_events)
    #     @api.subscribe_limits_events
    #   end
    # end

    # describe "unsubscribe_limits_events" do
    #   xit "calls CmdTlmServer" do
    #     expect(CmdTlmServer).to receive(:unsubscribe_limits_events)
    #     @api.unsubscribe_limits_events(0)
    #   end
    # end

    # describe "get_limits_event" do
    #   xit "gets a limits event" do
    #     expect(CmdTlmServer).to receive(:get_limits_event)
    #     @api.get_limits_event(0)
    #   end
    # end

    # describe "get_out_of_limits" do
    #   xit "returns all out of limits items" do
    #     @api.inject_tlm("INST","HEALTH_STATUS",{TEMP1: 0, TEMP2: 0, TEMP3: 0, TEMP4: 0}, :RAW)
    #     items = @api.get_out_of_limits
    #     (0..3).each do |i|
    #       expect(items[i][0]).to eql "INST"
    #       expect(items[i][1]).to eql "HEALTH_STATUS"
    #       expect(items[i][2]).to eql "TEMP#{i+1}"
    #       expect(items[i][3]).to eql :RED_LOW
    #     end
    #   end
    # end

    # describe "get_overall_limits_state" do
    #   xit "returns the overall system limits state" do
    #     @api.inject_tlm("INST","HEALTH_STATUS",{TEMP1: 0, TEMP2: 0, TEMP3: 0, TEMP4: 0}, :RAW)
    #     expect(@api.get_overall_limits_state).to eq :RED
    #   end
    # end

    # describe "limits_enabled?" do
    #   it "complains about non-existant targets" do
    #     expect { @api.limits_enabled?("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
    #   end

    #   it "complains about non-existant packets" do
    #     expect { @api.limits_enabled?("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
    #   end

    #   it "complains about non-existant items" do
    #     expect { @api.limits_enabled?("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
    #   end

    #   it "returns whether limits are enable for an item" do
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
    #   end
    # end

    # describe "enable_limits" do
    #   it "complains about non-existant targets" do
    #     expect { @api.enable_limits("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
    #   end

    #   it "complains about non-existant packets" do
    #     expect { @api.enable_limits("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
    #   end

    #   it "complains about non-existant items" do
    #     expect { @api.enable_limits("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
    #   end

    #   it "enables limits for an item" do
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
    #     @api.disable_limits("INST","HEALTH_STATUS","TEMP1")
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be false
    #     @api.enable_limits("INST","HEALTH_STATUS","TEMP1")
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
    #   end
    # end

    # describe "disable_limits" do
    #   it "complains about non-existant targets" do
    #     expect { @api.disable_limits("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
    #   end

    #   it "complains about non-existant packets" do
    #     expect { @api.disable_limits("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
    #   end

    #   it "complains about non-existant items" do
    #     expect { @api.disable_limits("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
    #   end

    #   it "disables limits for an item" do
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
    #     @api.disable_limits("INST","HEALTH_STATUS","TEMP1")
    #     expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be false
    #     @api.enable_limits("INST","HEALTH_STATUS","TEMP1")
    #   end
    # end
  end
end
