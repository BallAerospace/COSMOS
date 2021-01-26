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
require 'cosmos/api/tlm_api'
require 'cosmos/microservices/interface_microservice'
require 'cosmos/microservices/decom_microservice'
require 'cosmos/microservices/cvt_microservice'
require 'cosmos/operators/microservice_operator'
require 'cosmos/script/extract'
require 'cosmos/utilities/authorization'
require 'cosmos/models/target_model'

module Cosmos
  describe Api do
    class ApiTest
      include Extract
      include Api
      include Authorization
    end

    before(:each) do
      redis = mock_redis()
      setup_system()
      %w(INST SYSTEM).each do |target|
        model = TargetModel.new(folder_name: target, name: target, scope: "DEFAULT")
        model.create
        model.update_store(File.join(SPEC_DIR, 'install', 'config', 'targets'))
      end

      @cm = CvtMicroservice.new("DEFAULT__CVT__INST_INT")
      @cm.instance_variable_set("@topics", %w(DEFAULT__DECOM__INST__HEALTH_STATUS DEFAULT__DECOM__INST__IMAGE DEFAULT__DECOM__INST__ADCS))
      @cm_thead = Thread.new { @cm.run }
      sleep(0.01) # Allow the thread to run

      packet = System.telemetry.packet('INST', 'HEALTH_STATUS')
      packet.received_time = Time.now.sys
      packet.stored = false
      packet.check_limits
      TelemetryDecomTopic.write_packet(packet, scope: "DEFAULT")
      sleep(0.01) # Allow the write to happen
      @api = ApiTest.new
    end

    after(:each) do
      @cm.shutdown
      Thread.list.each do |t|
        t.join if t != Thread.current
      end
    end

    def test_tlm_unknown(method)
      expect { @api.send(method, "BLAH HEALTH_STATUS COLLECTS") }.to raise_error(/does not exist/)
      expect { @api.send(method, "INST UNKNOWN COLLECTS") }.to raise_error(/does not exist/)
      expect { @api.send(method, "INST HEALTH_STATUS BLAH") }.to raise_error(/does not exist/)
      expect { @api.send(method, "BLAH", "HEALTH_STATUS", "COLLECTS") }.to raise_error(/does not exist/)
      expect { @api.send(method, "INST", "UNKNOWN", "COLLECTS") }.to raise_error(/does not exist/)
      expect { @api.send(method, "INST", "HEALTH_STATUS", "BLAH") }.to raise_error(/does not exist/)
    end

    describe "tlm" do
      it "complains about unknown targets, commands, and parameters" do
        test_tlm_unknown(:tlm)
      end

      it "processes a string" do
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql(-100.0)
      end

      it "returns the value using LATEST" do
        time = Time.now.sys
        packet = System.telemetry.packet('INST', 'IMAGE')
        packet.received_time = time
        packet.write('CCSDSVER', 1)
        TelemetryDecomTopic.write_packet(packet, scope: "DEFAULT")
        packet = System.telemetry.packet('INST', 'ADCS')
        packet.received_time = time + 1
        packet.write('CCSDSVER', 2)
        TelemetryDecomTopic.write_packet(packet, scope: "DEFAULT")
        sleep(0.1) # Allow the writes to happen
        expect(@api.tlm("INST LATEST CCSDSVER")).to eql 2
      end

      it "processes parameters" do
        expect(@api.tlm("INST","HEALTH_STATUS","TEMP1")).to eql(-100.0)
      end

      it "complains if too many parameters" do
        expect { @api.tlm("INST","HEALTH_STATUS","TEMP1","TEMP2") }.to raise_error(/Invalid number of arguments/)
      end
    end

    describe "tlm_raw" do
      it "complains about unknown targets, commands, and parameters" do
        test_tlm_unknown(:tlm_raw)
      end

      it "processes a string" do
        expect(@api.tlm_raw("INST HEALTH_STATUS TEMP1")).to eql 0
      end

      it "returns the value using LATEST" do
        expect(@api.tlm_raw("INST LATEST TEMP1")).to eql 0
      end

      it "processes parameters" do
        expect(@api.tlm_raw("INST","HEALTH_STATUS","TEMP1")).to eql 0
      end
    end

    describe "tlm_formatted" do
      it "complains about unknown targets, commands, and parameters" do
        test_tlm_unknown(:tlm_formatted)
      end

      it "processes a string" do
        expect(@api.tlm_formatted("INST HEALTH_STATUS TEMP1")).to eql "-100.000"
      end

      it "returns the value using LATEST" do
        expect(@api.tlm_formatted("INST LATEST TEMP1")).to eql "-100.000"
      end

      it "processes parameters" do
        expect(@api.tlm_formatted("INST","HEALTH_STATUS","TEMP1")).to eql "-100.000"
      end
    end

    describe "tlm_with_units" do
      it "complains about unknown targets, commands, and parameters" do
        test_tlm_unknown(:tlm_with_units)
      end

      it "processes a string" do
        expect(@api.tlm_with_units("INST HEALTH_STATUS TEMP1")).to eql "-100.000 C"
      end

      it "returns the value using LATEST" do
        expect(@api.tlm_with_units("INST LATEST TEMP1")).to eql "-100.000 C"
      end

      it "processes parameters" do
        expect(@api.tlm_with_units("INST","HEALTH_STATUS","TEMP1")).to eql "-100.000 C"
      end
    end

    describe "tlm_variable" do
      it "complains about unknown targets, commands, and parameters" do
        expect { @api.tlm_variable("BLAH HEALTH_STATUS COLLECTS",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("INST UNKNOWN COLLECTS",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("INST HEALTH_STATUS BLAH",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("BLAH","HEALTH_STATUS","COLLECTS",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("INST","UNKNOWN","COLLECTS",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("INST","HEALTH_STATUS","BLAH",:RAW) }.to raise_error(/does not exist/)
      end

      it "processes a string" do
        expect(@api.tlm_variable("INST HEALTH_STATUS TEMP1",:CONVERTED)).to eql(-100.0)
        expect(@api.tlm_variable("INST HEALTH_STATUS TEMP1",:RAW)).to eql 0
        expect(@api.tlm_variable("INST HEALTH_STATUS TEMP1",:FORMATTED)).to eql "-100.000"
        expect(@api.tlm_variable("INST HEALTH_STATUS TEMP1",:WITH_UNITS)).to eql "-100.000 C"
      end

      it "returns the value using LATEST" do
        expect(@api.tlm_variable("INST LATEST TEMP1",:CONVERTED)).to eql(-100.0)
        expect(@api.tlm_variable("INST LATEST TEMP1",:RAW)).to eql 0
        expect(@api.tlm_variable("INST LATEST TEMP1",:FORMATTED)).to eql "-100.000"
        expect(@api.tlm_variable("INST LATEST TEMP1",:WITH_UNITS)).to eql "-100.000 C"
      end

      it "processes parameters" do
        expect(@api.tlm_variable("INST","HEALTH_STATUS","TEMP1",:CONVERTED)).to eql(-100.0)
        expect(@api.tlm_variable("INST","HEALTH_STATUS","TEMP1",:RAW)).to eql 0
        expect(@api.tlm_variable("INST","HEALTH_STATUS","TEMP1",:FORMATTED)).to eql "-100.000"
        expect(@api.tlm_variable("INST","HEALTH_STATUS","TEMP1",:WITH_UNITS)).to eql "-100.000 C"
      end

      it "complains with too many parameters" do
        expect { @api.tlm_variable("INST","HEALTH_STATUS","TEMP1","TEMP2",:CONVERTED) }.to raise_error(/Invalid number of arguments/)
      end

      it "complains with an unknown conversion" do
        expect { @api.tlm_variable("INST","HEALTH_STATUS","TEMP1",:NOPE) }.to raise_error(/Invalid type 'NOPE'/)
      end
    end

    describe "set_tlm" do
      it "complains about unknown targets, packets, and parameters" do
        expect { @api.set_tlm("BLAH HEALTH_STATUS COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm("INST UNKNOWN COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm("INST HEALTH_STATUS BLAH = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm("BLAH","HEALTH_STATUS","COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.set_tlm("INST","UNKNOWN","COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.set_tlm("INST","HEALTH_STATUS","BLAH",1) }.to raise_error(/does not exist/)
      end

      it "doesn't allow SYSTEM META PKTID or CONFIG" do
        expect { @api.set_tlm("SYSTEM META PKTID = 1") }.to raise_error(/set_tlm not allowed/)
        expect { @api.set_tlm("SYSTEM META CONFIG = 1") }.to raise_error(/set_tlm not allowed/)
      end

      xit "sets SYSTEM META command as well as tlm" do
        cmd = System.commands.packet("SYSTEM", "META")
        tlm = System.telemetry.packet("SYSTEM", "META")
        @api.set_tlm("SYSTEM META RUBY_VERSION = 1.8.0")
        expect(cmd.read("RUBY_VERSION")).to eq("1.8.0")
        expect(tlm.read("RUBY_VERSION")).to eq("1.8.0")
      end

      it "processes a string" do
        @api.set_tlm("INST HEALTH_STATUS TEMP1 = 0.0")
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql(0.0)
      end

      it "processes parameters" do
        @api.set_tlm("INST","HEALTH_STATUS","TEMP1", 0.0)
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql(0.0)
      end

      it "complains with too many parameters" do
        expect { @api.set_tlm("INST","HEALTH_STATUS","TEMP1","TEMP2",0.0) }.to raise_error(/Invalid number of arguments/)
      end
    end

    describe "set_tlm_raw" do
      it "complains about unknown targets, packets, and parameters" do
        expect { @api.set_tlm_raw("BLAH HEALTH_STATUS COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm_raw("INST UNKNOWN COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm_raw("INST HEALTH_STATUS BLAH = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm_raw("BLAH","HEALTH_STATUS","COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.set_tlm_raw("INST","UNKNOWN","COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.set_tlm_raw("INST","HEALTH_STATUS","BLAH",1) }.to raise_error(/does not exist/)
      end

      it "processes a string" do
        @api.set_tlm_raw("INST HEALTH_STATUS TEMP1 = 0.0")
        expect(@api.tlm_raw("INST HEALTH_STATUS TEMP1")).to eql 0.0
      end

      it "processes parameters" do
        @api.set_tlm_raw("INST","HEALTH_STATUS","TEMP1", 0.0)
        expect(@api.tlm_raw("INST HEALTH_STATUS TEMP1")).to eql 0.0
      end
    end

    describe "inject_tlm" do
      before(:each) do
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

        sleep(0.1)
      end

      after(:each) do
        @im.shutdown
        @dm.shutdown
        sleep 0.1
        Thread.list.each do |t|
          t.kill if t != Thread.current
        end
      end

      it "complains about non-existant targets" do
        expect { @api.inject_tlm("BLAH","HEALTH_STATUS") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.inject_tlm("INST","BLAH") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.inject_tlm("INST","HEALTH_STATUS",{'BLAH' => 0}) }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      xit "logs errors writing routers" do
        @api.inject_tlm("INST","HEALTH_STATUS",{TEMP1: 50, TEMP2: 50, TEMP3: 50, TEMP4: 50}, :CONVERTED)
        allow_any_instance_of(Interface).to receive(:write_allowed?).and_raise("PROBLEM!")
        expect(Logger).to receive(:error) do |msg|
          expect(msg).to match(/Problem writing to router/)
        end
        @api.inject_tlm("INST","HEALTH_STATUS")
      end

      it "injects a packet into the system" do
        @api.inject_tlm("INST","HEALTH_STATUS",{TEMP1: 10, TEMP2: 20}, :CONVERTED, true, true, false)
        sleep 0.3
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to be_within(0.1).of(10.0)
        expect(@api.tlm("INST HEALTH_STATUS TEMP2")).to be_within(0.1).of(20.0)

        @api.inject_tlm("INST","HEALTH_STATUS",{TEMP1: 0, TEMP2: 0}, :RAW, true, true, false)
        sleep 0.3
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql(-100.0)
        expect(@api.tlm("INST HEALTH_STATUS TEMP2")).to eql(-100.0)
      end

      xit "writes to routers and logs even if the packet has no interface" do
        sys = System.targets["SYSTEM"]
        interface = sys.interface
        sys.interface = nil

        allow_any_instance_of(Interface).to receive(:write_allowed?).and_raise("PROBLEM!")
        expect(Logger).to receive(:error) do |msg|
          expect(msg).to match(/Problem writing to router/)
        end

        @api.inject_tlm("SYSTEM","LIMITS_CHANGE")
        sys.interface = interface
      end
    end

    describe "override_tlm" do
      it "complains about unknown targets, packets, and parameters" do
        expect { @api.override_tlm("BLAH HEALTH_STATUS COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.override_tlm("INST UNKNOWN COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.override_tlm("INST HEALTH_STATUS BLAH = 1") }.to raise_error(/does not exist/)
        expect { @api.override_tlm("BLAH","HEALTH_STATUS","COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.override_tlm("INST","UNKNOWN","COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.override_tlm("INST","HEALTH_STATUS","BLAH",1) }.to raise_error(/does not exist/)
      end

      it "complains with too many parameters" do
        expect { @api.override_tlm("INST","HEALTH_STATUS","TEMP1","TEMP2",0.0) }.to raise_error(/Invalid number of arguments/)
      end

      it "returns the new value and ignores updates" do
        expect(@api.tlm("INST","HEALTH_STATUS","TEMP1")).to eql(-100.0)
        @api.override_tlm("INST","HEALTH_STATUS","TEMP1", 50.0)
        expect(@api.tlm("INST","HEALTH_STATUS","TEMP1")).to eql(50.0)
        @api.set_tlm("INST","HEALTH_STATUS","TEMP1", 10.0)
        expect(@api.tlm("INST","HEALTH_STATUS","TEMP1")).to eql(50.0)
      end
    end

    describe "override_tlm_raw" do
      it "complains about unknown targets, commands, and parameters" do
        expect { @api.override_tlm_raw("BLAH HEALTH_STATUS COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.override_tlm_raw("INST UNKNOWN COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.override_tlm_raw("INST HEALTH_STATUS BLAH = 1") }.to raise_error(/does not exist/)
        expect { @api.override_tlm_raw("BLAH","HEALTH_STATUS","COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.override_tlm_raw("INST","UNKNOWN","COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.override_tlm_raw("INST","HEALTH_STATUS","BLAH",1) }.to raise_error(/does not exist/)
      end

      it "complains with too many parameters" do
        expect { @api.override_tlm_raw("INST","HEALTH_STATUS","TEMP1","TEMP2",0.0) }.to raise_error(/Invalid number of arguments/)
      end

      it "returns the new value and ignores updates" do
        expect(@api.tlm_raw("INST","HEALTH_STATUS","TEMP1")).to eql(0)
        @api.override_tlm_raw("INST","HEALTH_STATUS","TEMP1", 5.0)
        expect(@api.tlm_raw("INST","HEALTH_STATUS","TEMP1")).to eql(5.0)
        @api.set_tlm_raw("INST","HEALTH_STATUS","TEMP1", 10.0)
        expect(@api.tlm_raw("INST","HEALTH_STATUS","TEMP1")).to eql(5.0)
      end
    end

    describe "normalize_tlm" do
      it "complains about unknown targets, commands, and parameters" do
        expect { @api.normalize_tlm("BLAH HEALTH_STATUS COLLECTS") }.to raise_error(/does not exist/)
        expect { @api.normalize_tlm("INST UNKNOWN COLLECTS") }.to raise_error(/does not exist/)
        expect { @api.normalize_tlm("INST HEALTH_STATUS BLAH") }.to raise_error(/does not exist/)
        expect { @api.normalize_tlm("BLAH","HEALTH_STATUS","COLLECTS") }.to raise_error(/does not exist/)
        expect { @api.normalize_tlm("INST","UNKNOWN","COLLECTS") }.to raise_error(/does not exist/)
        expect { @api.normalize_tlm("INST","HEALTH_STATUS","BLAH") }.to raise_error(/does not exist/)
      end

      it "complains with too many parameters" do
        expect { @api.normalize_tlm("INST","HEALTH_STATUS","TEMP1",0.0) }.to raise_error(/Invalid number of arguments/)
      end

      it "clears all overrides" do
        @api.override_tlm("INST","HEALTH_STATUS","TEMP1", 50.0)
        @api.override_tlm_raw("INST","HEALTH_STATUS","TEMP1", 5.0)
        expect(@api.tlm("INST","HEALTH_STATUS","TEMP1")).to eql(50.0)
        expect(@api.tlm_raw("INST","HEALTH_STATUS","TEMP1")).to eql(5.0)
        @api.normalize_tlm("INST","HEALTH_STATUS","TEMP1")
        expect(@api.tlm("INST","HEALTH_STATUS","TEMP1")).to eql(-100.0)
        expect(@api.tlm_raw("INST","HEALTH_STATUS","TEMP1")).to eql(0)
      end
    end

    describe "get_tlm_buffer" do
      it "returns a telemetry packet buffer" do
        buffer = "\x01\x02\x03\x04"
        packet = System.telemetry.packet('INST', 'HEALTH_STATUS')
        packet.buffer = buffer
        TelemetryTopic.write_packet(packet, scope: 'DEFAULT')
        expect(@api.get_tlm_buffer("INST", "HEALTH_STATUS")[0..3]).to eq buffer
      end
    end

    describe "get_tlm_packet" do
      it "complains about non-existant targets" do
        expect { @api.get_tlm_packet("BLAH","HEALTH_STATUS") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_tlm_packet("INST","BLAH") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains using LATEST" do
        expect { @api.get_tlm_packet("INST","LATEST") }.to raise_error(RuntimeError, "Packet 'INST LATEST' does not exist")
      end

      it "complains about non-existant value_types" do
        expect { @api.get_tlm_packet("INST","HEALTH_STATUS",:MINE) }.to raise_error(RuntimeError, "Unknown value type on read: MINE")
      end

      it "reads all telemetry items as CONVERTED with their limits states" do
        vals = @api.get_tlm_packet("INST","HEALTH_STATUS")
        expect(vals[0][0]).to eql "PACKET_TIMESECONDS"
        expect(vals[0][1]).to be > 0
        expect(vals[0][2]).to be_nil
        expect(vals[1][0]).to eql "PACKET_TIMEFORMATTED"
        expect(vals[1][1].split(' ')[0]).to eql Time.now.formatted.split(' ')[0] # Match the date
        expect(vals[1][2]).to be_nil
        expect(vals[2][0]).to eql "RECEIVED_TIMESECONDS"
        expect(vals[2][1]).to be > 0
        expect(vals[2][2]).to be_nil
        expect(vals[3][0]).to eql "RECEIVED_TIMEFORMATTED"
        expect(vals[3][1].split(' ')[0]).to eql Time.now.formatted.split(' ')[0] # Match the date
        expect(vals[3][2]).to be_nil
        expect(vals[4][0]).to eql "RECEIVED_COUNT"
        expect(vals[4][1]).to eql 0
        expect(vals[4][2]).to be_nil
        # Spot check a few more
        expect(vals[24][0]).to eql "TEMP1"
        expect(vals[24][1]).to eql(-100.0)
        expect(vals[24][2]).to eql "RED_LOW"
        expect(vals[25][0]).to eql "TEMP2"
        expect(vals[25][1]).to eql(-100.0)
        expect(vals[25][2]).to eql "RED_LOW"
        expect(vals[26][0]).to eql "TEMP3"
        expect(vals[26][1]).to eql(-100.0)
        expect(vals[26][2]).to eql "RED_LOW"
        expect(vals[27][0]).to eql "TEMP4"
        expect(vals[27][1]).to eql(-100.0)
        expect(vals[27][2]).to eql "RED_LOW"
      end

      it "reads all telemetry items as RAW" do
        vals = @api.get_tlm_packet("INST","HEALTH_STATUS", :RAW)
        expect(vals[24][0]).to eql "TEMP1"
        expect(vals[24][1]).to eql 0
        expect(vals[24][2]).to eql "RED_LOW"
        expect(vals[25][0]).to eql "TEMP2"
        expect(vals[25][1]).to eql 0
        expect(vals[25][2]).to eql "RED_LOW"
        expect(vals[26][0]).to eql "TEMP3"
        expect(vals[26][1]).to eql 0
        expect(vals[26][2]).to eql "RED_LOW"
        expect(vals[27][0]).to eql "TEMP4"
        expect(vals[27][1]).to eql 0
        expect(vals[27][2]).to eql "RED_LOW"
      end

      it "reads all telemetry items as FORMATTED" do
        vals = @api.get_tlm_packet("INST","HEALTH_STATUS", :FORMATTED)
        expect(vals[24][0]).to eql "TEMP1"
        expect(vals[24][1]).to eql "-100.000"
        expect(vals[24][2]).to eql "RED_LOW"
        expect(vals[25][0]).to eql "TEMP2"
        expect(vals[25][1]).to eql "-100.000"
        expect(vals[25][2]).to eql "RED_LOW"
        expect(vals[26][0]).to eql "TEMP3"
        expect(vals[26][1]).to eql "-100.000"
        expect(vals[26][2]).to eql "RED_LOW"
        expect(vals[27][0]).to eql "TEMP4"
        expect(vals[27][1]).to eql "-100.000"
        expect(vals[27][2]).to eql "RED_LOW"
      end

      it "reads all telemetry items as WITH_UNITS" do
        vals = @api.get_tlm_packet("INST","HEALTH_STATUS", :WITH_UNITS)
        expect(vals[24][0]).to eql "TEMP1"
        expect(vals[24][1]).to eql "-100.000 C"
        expect(vals[24][2]).to eql "RED_LOW"
        expect(vals[25][0]).to eql "TEMP2"
        expect(vals[25][1]).to eql "-100.000 C"
        expect(vals[25][2]).to eql "RED_LOW"
        expect(vals[26][0]).to eql "TEMP3"
        expect(vals[26][1]).to eql "-100.000 C"
        expect(vals[26][2]).to eql "RED_LOW"
        expect(vals[27][0]).to eql "TEMP4"
        expect(vals[27][1]).to eql "-100.000 C"
        expect(vals[27][2]).to eql "RED_LOW"
      end
    end

    describe "get_tlm_values" do
      it "complains about non-existant targets" do
        expect { @api.get_tlm_values(["BLAH__HEALTH_STATUS__TEMP1__CONVERTED"]) }.to raise_error(RuntimeError, "Item 'BLAH HEALTH_STATUS TEMP1' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_tlm_values(["INST__BLAH__TEMP1__CONVERTED"]) }.to raise_error(RuntimeError, "Item 'INST BLAH TEMP1' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.get_tlm_values(["INST__LATEST__BLAH__CONVERTED"]) }.to raise_error(RuntimeError, "Item 'INST LATEST BLAH' does not exist")
      end

      it "complains about non-existant value_types" do
        expect { @api.get_tlm_values(["INST__HEALTH_STATUS__TEMP1__MINE"]) }.to raise_error(RuntimeError, "Unknown value type MINE")
      end

      it "complains about bad arguments" do
        expect { @api.get_tlm_values() }.to raise_error(ArgumentError)
        expect { @api.get_tlm_values([]) }.to raise_error(ArgumentError, /items must be array of strings/)
        expect { @api.get_tlm_values([["INST","HEALTH_STATUS","TEMP1"]]) }.to raise_error(ArgumentError, /items must be array of strings/)
        expect { @api.get_tlm_values(["INST","HEALTH_STATUS","TEMP1"]) }.to raise_error(ArgumentError, /items must be formatted/)
      end

      it "reads all the specified items" do
        items = []
        items << 'INST__HEALTH_STATUS__TEMP1__CONVERTED'
        items << 'INST__HEALTH_STATUS__TEMP2__CONVERTED'
        items << 'INST__HEALTH_STATUS__TEMP3__CONVERTED'
        items << 'INST__HEALTH_STATUS__TEMP4__CONVERTED'
        vals = @api.get_tlm_values(items)
        expect(vals[0][0]).to eql(-100.0)
        expect(vals[1][0]).to eql(-100.0)
        expect(vals[2][0]).to eql(-100.0)
        expect(vals[3][0]).to eql(-100.0)
        expect(vals[0][1]).to eql :RED_LOW
        expect(vals[1][1]).to eql :RED_LOW
        expect(vals[2][1]).to eql :RED_LOW
        expect(vals[3][1]).to eql :RED_LOW
      end

      it "reads all the specified items with one conversion" do
        items = []
        items << 'INST__HEALTH_STATUS__TEMP1__RAW'
        items << 'INST__HEALTH_STATUS__TEMP2__RAW'
        items << 'INST__HEALTH_STATUS__TEMP3__RAW'
        items << 'INST__HEALTH_STATUS__TEMP4__RAW'
        vals = @api.get_tlm_values(items)
        expect(vals[0][0]).to eql 0
        expect(vals[1][0]).to eql 0
        expect(vals[2][0]).to eql 0
        expect(vals[3][0]).to eql 0
        expect(vals[0][1]).to eql :RED_LOW
        expect(vals[1][1]).to eql :RED_LOW
        expect(vals[2][1]).to eql :RED_LOW
        expect(vals[3][1]).to eql :RED_LOW
      end

      it "reads all the specified items with different conversions" do
        items = []
        items << 'INST__HEALTH_STATUS__TEMP1__RAW'
        items << 'INST__HEALTH_STATUS__TEMP2__CONVERTED'
        items << 'INST__HEALTH_STATUS__TEMP3__FORMATTED'
        items << 'INST__HEALTH_STATUS__TEMP4__WITH_UNITS'
        vals = @api.get_tlm_values(items)
        expect(vals[0][0]).to eql 0
        expect(vals[1][0]).to eql(-100.0)
        expect(vals[2][0]).to eql "-100.000"
        expect(vals[3][0]).to eql "-100.000 C"
        expect(vals[0][1]).to eql :RED_LOW
        expect(vals[1][1]).to eql :RED_LOW
        expect(vals[2][1]).to eql :RED_LOW
        expect(vals[3][1]).to eql :RED_LOW
      end
    end

    describe "get_tlm_list" do
      it "complains about non-existant targets" do
        expect { @api.get_tlm_list("BLAH") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
      end

      it "returns the sorted packet names for a target" do
        pkts = @api.get_tlm_list("INST")
        expect(pkts[0][0]).to eql "ADCS"
        expect(pkts[1][0]).to eql "ERROR"
        expect(pkts[2][0]).to eql "HANDSHAKE"
        expect(pkts[3][0]).to eql "HEALTH_STATUS"
        expect(pkts[4][0]).to eql "IMAGE"
        expect(pkts[5][0]).to eql "MECH"
        expect(pkts[6][0]).to eql "PARAMS"
      end
    end

    describe "get_tlm_item_list" do
      it "complains about non-existant targets" do
        expect { @api.get_tlm_item_list("BLAH","HEALTH_STATUS") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_tlm_item_list("INST","BLAH") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "returns all the items for a target/packet" do
        items = @api.get_tlm_item_list("INST","HEALTH_STATUS")
        # expect(items[0][0]).to eql "PACKET_TIMESECONDS"
        # expect(items[1][0]).to eql "PACKET_TIMEFORMATTED"
        # expect(items[2][0]).to eql "RECEIVED_TIMESECONDS"
        # expect(items[3][0]).to eql "RECEIVED_TIMEFORMATTED"
        # expect(items[4][0]).to eql "RECEIVED_COUNT"
        # Spot check a few more
        expect(items[11][0]).to eql "TEMP1"
        expect(items[11][1]).to be_nil
        expect(items[11][2]).to eql "Temperature #1"
        expect(items[17][0]).to eql "COLLECT_TYPE"
        expect(items[17][1]).to include("NORMAL" => { "value" => 0 }, "SPECIAL" => { "value" => 1 })
        expect(items[17][2]).to eql "Most recent collect type"
      end
    end

    xdescribe "get_tlm_details" do
      it "complains about non-existant targets" do
        expect { @api.get_tlm_details([["BLAH","HEALTH_STATUS","TEMP1"]]) }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_tlm_details([["INST","BLAH","TEMP1"]]) }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.get_tlm_details([["INST","LATEST","BLAH"]]) }.to raise_error(RuntimeError, "Telemetry item 'INST LATEST BLAH' does not exist")
      end

      it "complains about bad parameters" do
        expect { @api.get_tlm_details("INST") }.to raise_error(ArgumentError, /item_array must be nested array/)
        expect { @api.get_tlm_details(["INST","LATEST","BLAH"]) }.to raise_error(ArgumentError, /item_array must be nested array/)
      end

      it "reads all the specified items" do
        items = []
        items << %w(INST HEALTH_STATUS TEMP1)
        items << %w(INST HEALTH_STATUS TEMP2)
        items << %w(INST HEALTH_STATUS TEMP3)
        items << %w(INST HEALTH_STATUS TEMP4)
        details = @api.get_tlm_details(items)
        expect(details.length).to eql 4
        expect(details[0]["name"]).to eql "TEMP1"
        expect(details[1]["name"]).to eql "TEMP2"
        expect(details[2]["name"]).to eql "TEMP3"
        expect(details[3]["name"]).to eql "TEMP4"
      end
    end
  end
end
