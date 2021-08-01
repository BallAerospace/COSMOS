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
      mock_redis()
      setup_system()

      %w(INST SYSTEM).each do |target|
        model = TargetModel.new(folder_name: target, name: target, scope: "DEFAULT")
        model.create
        model.update_store(File.join(SPEC_DIR, 'install', 'config', 'targets'))
      end

      packet = System.telemetry.packet('INST', 'HEALTH_STATUS')
      packet.received_time = Time.now.sys
      packet.stored = false
      packet.check_limits
      TelemetryDecomTopic.write_packet(packet, scope: "DEFAULT")
      sleep(0.01) # Allow the write to happen
      @api = ApiTest.new
    end

    after(:each) do
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
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1")).to eql(-100.0)
      end

      it "complains if too many parameters" do
        expect { @api.tlm("INST", "HEALTH_STATUS", "TEMP1", "TEMP2") }.to raise_error(/Invalid number of arguments/)
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
        expect(@api.tlm_raw("INST", "HEALTH_STATUS", "TEMP1")).to eql 0
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
        expect(@api.tlm_formatted("INST", "HEALTH_STATUS", "TEMP1")).to eql "-100.000"
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
        expect(@api.tlm_with_units("INST", "HEALTH_STATUS", "TEMP1")).to eql "-100.000 C"
      end
    end

    describe "tlm_variable" do
      it "complains about unknown targets, commands, and parameters" do
        expect { @api.tlm_variable("BLAH HEALTH_STATUS COLLECTS",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("INST UNKNOWN COLLECTS",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("INST HEALTH_STATUS BLAH",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("BLAH", "HEALTH_STATUS", "COLLECTS",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("INST", "UNKNOWN", "COLLECTS",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("INST", "HEALTH_STATUS", "BLAH",:RAW) }.to raise_error(/does not exist/)
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
        expect(@api.tlm_variable("INST", "HEALTH_STATUS", "TEMP1",:CONVERTED)).to eql(-100.0)
        expect(@api.tlm_variable("INST", "HEALTH_STATUS", "TEMP1",:RAW)).to eql 0
        expect(@api.tlm_variable("INST", "HEALTH_STATUS", "TEMP1",:FORMATTED)).to eql "-100.000"
        expect(@api.tlm_variable("INST", "HEALTH_STATUS", "TEMP1",:WITH_UNITS)).to eql "-100.000 C"
      end

      it "complains with too many parameters" do
        expect { @api.tlm_variable("INST", "HEALTH_STATUS", "TEMP1", "TEMP2", :CONVERTED) }.to raise_error(/Invalid number of arguments/)
      end

      it "complains with an unknown conversion" do
        expect { @api.tlm_variable("INST", "HEALTH_STATUS", "TEMP1", :NOPE) }.to raise_error(/Unknown type 'NOPE'/)
      end
    end

    describe "set_tlm" do
      it "complains about unknown targets, packets, and parameters" do
        expect { @api.set_tlm("BLAH HEALTH_STATUS COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm("INST UNKNOWN COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm("INST HEALTH_STATUS BLAH = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm("BLAH", "HEALTH_STATUS", "COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.set_tlm("INST", "UNKNOWN", "COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.set_tlm("INST", "HEALTH_STATUS", "BLAH",1) }.to raise_error(/does not exist/)
      end

      it "complains with too many parameters" do
        expect { @api.set_tlm("INST", "HEALTH_STATUS", "TEMP1", "TEMP2", 0.0) }.to raise_error(/Invalid number of arguments/)
      end

      it "complains with unknown types" do
        expect { @api.set_tlm("INST", "HEALTH_STATUS", "TEMP1", 0.0, type: :BLAH) }.to raise_error(/Unknown type 'BLAH'/)
      end

      it "processes a string" do
        @api.set_tlm("INST HEALTH_STATUS TEMP1 = 0.0")
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql(0.0)
        @api.set_tlm("INST HEALTH_STATUS TEMP1 = 100.0")
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql(100.0)
      end

      it "processes parameters" do
        @api.set_tlm("INST", "HEALTH_STATUS", "TEMP1", 0.0)
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql(0.0)
        @api.set_tlm("INST", "HEALTH_STATUS", "TEMP1", -50.0)
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql(-50.0)
      end

      it "sets raw telemetry" do
        @api.set_tlm("INST HEALTH_STATUS TEMP1 = 10.0", type: :RAW)
        expect(@api.tlm_raw("INST HEALTH_STATUS TEMP1")).to eql 10.0
        @api.set_tlm("INST", "HEALTH_STATUS", "TEMP1", 0.0, type: 'RAW')
        expect(@api.tlm_raw("INST HEALTH_STATUS TEMP1")).to eql 0.0
      end

      it "sets formatted telemetry" do
        @api.set_tlm("INST HEALTH_STATUS TEMP1 = '10.000'", type: :FORMATTED)
        expect(@api.tlm_formatted("INST HEALTH_STATUS TEMP1")).to eql "10.000"
        @api.set_tlm("INST", "HEALTH_STATUS", "TEMP1", "0.000", type: 'FORMATTED')
        expect(@api.tlm_formatted("INST HEALTH_STATUS TEMP1")).to eql "0.000"
      end

      it "sets with_units telemetry" do
        @api.set_tlm("INST HEALTH_STATUS TEMP1 = '10.0 C'", type: :WITH_UNITS)
        expect(@api.tlm_with_units("INST HEALTH_STATUS TEMP1")).to eql "10.0 C"
        @api.set_tlm("INST", "HEALTH_STATUS", "TEMP1", "0.0 F", type: 'WITH_UNITS')
        expect(@api.tlm_with_units("INST HEALTH_STATUS TEMP1")).to eql "0.0 F"
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

        model = MicroserviceModel.new(name: "DEFAULT__DECOM__INST_INT", scope: "DEFAULT", topics: ["DEFAULT__TELEMETRY__{INST}__HEALTH_STATUS"])
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
        expect { @api.inject_tlm("BLAH", "HEALTH_STATUS") }.to raise_error("Packet 'BLAH HEALTH_STATUS' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.inject_tlm("INST", "BLAH") }.to raise_error("Packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.inject_tlm("INST", "HEALTH_STATUS", { 'BLAH' => 0 }) }.to raise_error("Item(s) 'INST HEALTH_STATUS BLAH' does not exist")
      end

      xit "injects a packet into the system" do
        @api.inject_tlm("INST", "HEALTH_STATUS", { TEMP1: 10, TEMP2: 20 }, type: :CONVERTED)
        sleep 2
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to be_within(0.1).of(10.0)
        expect(@api.tlm("INST HEALTH_STATUS TEMP2")).to be_within(0.1).of(20.0)

        @api.inject_tlm("INST", "HEALTH_STATUS", { TEMP1: 0, TEMP2: 0 }, type: :RAW)
        sleep 2
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql(-100.0)
        expect(@api.tlm("INST HEALTH_STATUS TEMP2")).to eql(-100.0)
      end
    end

    describe "override_tlm" do
      it "complains about unknown targets, packets, and parameters" do
        expect { @api.override_tlm("BLAH HEALTH_STATUS COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.override_tlm("INST UNKNOWN COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.override_tlm("INST HEALTH_STATUS BLAH = 1") }.to raise_error(/does not exist/)
        expect { @api.override_tlm("BLAH", "HEALTH_STATUS", "COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.override_tlm("INST", "UNKNOWN", "COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.override_tlm("INST", "HEALTH_STATUS", "BLAH",1) }.to raise_error(/does not exist/)
      end

      it "complains with too many parameters" do
        expect { @api.override_tlm("INST", "HEALTH_STATUS", "TEMP1", "TEMP2",0.0) }.to raise_error(/Invalid number of arguments/)
      end

      it "overrides raw values" do
        expect(@api.tlm_raw("INST", "HEALTH_STATUS", "TEMP1")).to eql(0)
        @api.override_tlm("INST", "HEALTH_STATUS", "TEMP1", 5.0, type: :RAW)
        expect(@api.tlm_raw("INST", "HEALTH_STATUS", "TEMP1")).to eql(5.0)
        @api.set_tlm("INST", "HEALTH_STATUS", "TEMP1", 10.0, type: :RAW)
        expect(@api.tlm_raw("INST", "HEALTH_STATUS", "TEMP1")).to eql(5.0)
      end

      it "overrides converted values" do
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1")).to eql(-100.0)
        @api.override_tlm("INST", "HEALTH_STATUS", "TEMP1", 60.0)
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1")).to eql(60.0)
        @api.override_tlm("INST", "HEALTH_STATUS", "TEMP1", 50.0, type: :CONVERTED)
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1")).to eql(50.0)
        @api.set_tlm("INST", "HEALTH_STATUS", "TEMP1", 10.0)
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1")).to eql(50.0)
      end

      it "overrides formatted values" do
        expect(@api.tlm_formatted("INST", "HEALTH_STATUS", "TEMP1")).to eql('-100.000')
        @api.override_tlm("INST", "HEALTH_STATUS", "TEMP1", '5.000', type: :FORMATTED)
        expect(@api.tlm_formatted("INST", "HEALTH_STATUS", "TEMP1")).to eql('5.000')
        @api.set_tlm("INST", "HEALTH_STATUS", "TEMP1", '10.000', type: :FORMATTED)
        expect(@api.tlm_formatted("INST", "HEALTH_STATUS", "TEMP1")).to eql('5.000')
      end

      it "overrides with_units values" do
        expect(@api.tlm_with_units("INST", "HEALTH_STATUS", "TEMP1")).to eql('-100.000 C')
        @api.override_tlm("INST", "HEALTH_STATUS", "TEMP1", '5.00 C', type: :WITH_UNITS)
        expect(@api.tlm_with_units("INST", "HEALTH_STATUS", "TEMP1")).to eql('5.00 C')
        @api.set_tlm("INST", "HEALTH_STATUS", "TEMP1", 10.0, type: :WITH_UNITS)
        expect(@api.tlm_with_units("INST", "HEALTH_STATUS", "TEMP1")).to eql('5.00 C')
      end
    end

    describe "normalize_tlm" do
      it "complains about unknown targets, commands, and parameters" do
        expect { @api.normalize_tlm("BLAH HEALTH_STATUS COLLECTS") }.to raise_error(/does not exist/)
        expect { @api.normalize_tlm("INST UNKNOWN COLLECTS") }.to raise_error(/does not exist/)
        expect { @api.normalize_tlm("INST HEALTH_STATUS BLAH") }.to raise_error(/does not exist/)
        expect { @api.normalize_tlm("BLAH", "HEALTH_STATUS", "COLLECTS") }.to raise_error(/does not exist/)
        expect { @api.normalize_tlm("INST", "UNKNOWN", "COLLECTS") }.to raise_error(/does not exist/)
        expect { @api.normalize_tlm("INST", "HEALTH_STATUS", "BLAH") }.to raise_error(/does not exist/)
      end

      it "complains with too many parameters" do
        expect { @api.normalize_tlm("INST", "HEALTH_STATUS", "TEMP1",0.0) }.to raise_error(/Invalid number of arguments/)
      end

      it "clears all overrides" do
        @api.override_tlm("INST", "HEALTH_STATUS", "TEMP1", 5.0, type: 'RAW')
        @api.override_tlm("INST", "HEALTH_STATUS", "TEMP1", 50.0, type: 'CONVERTED')
        @api.override_tlm("INST", "HEALTH_STATUS", "TEMP1", '50.00', type: 'FORMATTED')
        @api.override_tlm("INST", "HEALTH_STATUS", "TEMP1", '50.00 F', type: 'WITH_UNITS')
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1", type: 'RAW')).to eql(5.0)
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1", type: 'CONVERTED')).to eql(50.0)
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1", type: 'FORMATTED')).to eql('50.00')
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1", type: 'WITH_UNITS')).to eql('50.00 F')
        @api.normalize_tlm("INST", "HEALTH_STATUS", "TEMP1")
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1", type: 'RAW')).to eql(0)
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1", type: 'CONVERTED')).to eql(-100.0)
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1", type: 'FORMATTED')).to eql('-100.000')
        expect(@api.tlm("INST", "HEALTH_STATUS", "TEMP1", type: 'WITH_UNITS')).to eql('-100.000 C')
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

    describe "get_all_telemetry" do
      it "raises if the target does not exist" do
        expect { @api.get_all_telemetry("BLAH", scope: "DEFAULT") }.to raise_error("Target 'BLAH' does not exist")
      end

      it "returns an array of all packet hashes" do
        pkts = @api.get_all_telemetry("INST", scope: "DEFAULT")
        expect(pkts).to be_a Array
        names = []
        pkts.each do |pkt|
          expect(pkt).to be_a Hash
          expect(pkt['target_name']).to eql "INST"
          names << pkt['packet_name']
        end
        expect(names).to include("ADCS", "HEALTH_STATUS", "PARAMS", "IMAGE", "MECH")
      end
    end

    describe "get_telemetry" do
      it "raises if the target or packet do not exist" do
        expect { @api.get_telemetry("BLAH", "HEALTH_STATUS", scope: "DEFAULT") }.to raise_error("Packet 'BLAH HEALTH_STATUS' does not exist")
        expect { @api.get_telemetry("INST", "BLAH", scope: "DEFAULT") }.to raise_error("Packet 'INST BLAH' does not exist")
      end

      it "returns a packet hash" do
        pkt = @api.get_telemetry("INST", "HEALTH_STATUS", scope: "DEFAULT")
        expect(pkt).to be_a Hash
        expect(pkt['target_name']).to eql "INST"
        expect(pkt['packet_name']).to eql "HEALTH_STATUS"
      end
    end

    describe "get_item" do
      it "raises if the target or packet or item do not exist" do
        expect { @api.get_item("BLAH", "HEALTH_STATUS", "CCSDSVER", scope: "DEFAULT") }.to raise_error("Packet 'BLAH HEALTH_STATUS' does not exist")
        expect { @api.get_item("INST", "BLAH", "CCSDSVER", scope: "DEFAULT") }.to raise_error("Packet 'INST BLAH' does not exist")
        expect { @api.get_item("INST", "HEALTH_STATUS", "BLAH", scope: "DEFAULT") }.to raise_error("Item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "returns an item hash" do
        item = @api.get_item("INST", "HEALTH_STATUS", "CCSDSVER", scope: "DEFAULT")
        expect(item).to be_a Hash
        expect(item['name']).to eql "CCSDSVER"
        expect(item['bit_offset']).to eql 0
      end
    end

    describe "get_tlm_packet" do
      it "complains about non-existant targets" do
        expect { @api.get_tlm_packet("BLAH", "HEALTH_STATUS") }.to raise_error(RuntimeError, "Packet 'BLAH HEALTH_STATUS' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_tlm_packet("INST", "BLAH") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains using LATEST" do
        expect { @api.get_tlm_packet("INST", "LATEST") }.to raise_error(RuntimeError, "Packet 'INST LATEST' does not exist")
      end

      it "complains about non-existant value_types" do
        expect { @api.get_tlm_packet("INST", "HEALTH_STATUS", type: :MINE) }.to raise_error(/Unknown type 'MINE'/)
      end

      it "reads all telemetry items as CONVERTED with their limits states" do
        vals = @api.get_tlm_packet("INST", "HEALTH_STATUS")
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
        vals = @api.get_tlm_packet("INST", "HEALTH_STATUS", type: :RAW)
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
        vals = @api.get_tlm_packet("INST", "HEALTH_STATUS", type: :FORMATTED)
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
        vals = @api.get_tlm_packet("INST", "HEALTH_STATUS", type: :WITH_UNITS)
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
        expect { @api.get_tlm_values(["BLAH__HEALTH_STATUS__TEMP1__CONVERTED"]) }.to raise_error(RuntimeError, "Packet 'BLAH HEALTH_STATUS' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_tlm_values(["INST__BLAH__TEMP1__CONVERTED"]) }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.get_tlm_values(["INST__HEALTH_STATUS__BLAH__CONVERTED"]) }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
        expect { @api.get_tlm_values(["INST__LATEST__BLAH__CONVERTED"]) }.to raise_error(RuntimeError, "Item 'INST LATEST BLAH' does not exist")
      end

      it "complains about non-existant value_types" do
        expect { @api.get_tlm_values(["INST__HEALTH_STATUS__TEMP1__MINE"]) }.to raise_error(RuntimeError, /Unknown value type MINE/)
      end

      it "complains about bad arguments" do
        expect { @api.get_tlm_values() }.to raise_error(ArgumentError)
        expect { @api.get_tlm_values([]) }.to raise_error(ArgumentError, /items must be array of strings/)
        expect { @api.get_tlm_values([["INST", "HEALTH_STATUS", "TEMP1"]]) }.to raise_error(ArgumentError, /items must be array of strings/)
        expect { @api.get_tlm_values(["INST", "HEALTH_STATUS", "TEMP1"]) }.to raise_error(ArgumentError, /items must be formatted/)
      end

      it "reads all the specified items" do
        items = []
        items << 'INST__HEALTH_STATUS__TEMP1__CONVERTED'
        items << 'INST__LATEST__TEMP2__CONVERTED'
        items << 'INST__HEALTH_STATUS__TEMP3__CONVERTED'
        items << 'INST__LATEST__TEMP4__CONVERTED'
        items << 'INST__HEALTH_STATUS__DURATION__CONVERTED'
        vals = @api.get_tlm_values(items)
        expect(vals[0][0]).to eql(-100.0)
        expect(vals[1][0]).to eql(-100.0)
        expect(vals[2][0]).to eql(-100.0)
        expect(vals[3][0]).to eql(-100.0)
        expect(vals[4][0]).to eql(0.0)
        expect(vals[0][1]).to eql :RED_LOW
        expect(vals[1][1]).to eql :RED_LOW
        expect(vals[2][1]).to eql :RED_LOW
        expect(vals[3][1]).to eql :RED_LOW
        expect(vals[4][1]).to be_nil
      end

      it "reads all the specified raw items" do
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

    describe "subscribe_packets, get_packet" do
      it "streams packets since the subscription was created" do
        # Write an initial packet that should not be returned
        packet = System.telemetry.packet("INST", "HEALTH_STATUS")
        packet.received_time = Time.now.sys
        packet.write("DURATION", 1.0)
        TelemetryDecomTopic.write_packet(packet, scope: "DEFAULT")
        sleep(0.01)

        id = @api.subscribe_packets([["INST","HEALTH_STATUS"],["INST","ADCS"]])
        sleep(0.01)

        # Write some packets that should be returned and one that will not
        packet.received_time = Time.now.sys
        packet.write("DURATION", 2.0)
        TelemetryDecomTopic.write_packet(packet, scope: "DEFAULT")
        packet.received_time = Time.now.sys
        packet.write("DURATION", 3.0)
        TelemetryDecomTopic.write_packet(packet, scope: "DEFAULT")
        packet = System.telemetry.packet("INST", "ADCS")
        packet.received_time = Time.now.sys
        TelemetryDecomTopic.write_packet(packet, scope: "DEFAULT")
        packet = System.telemetry.packet("INST", "IMAGE") # Not subscribed
        packet.received_time = Time.now.sys
        TelemetryDecomTopic.write_packet(packet, scope: "DEFAULT")

        index = 0
        @api.get_packet(id) do |hash|
          expect(hash['target_name']).to eql "INST"
          case index
          when 0
            expect(hash['packet_name']).to eql "HEALTH_STATUS"
            expect(hash['DURATION']).to eql 2.0
          when 1
            expect(hash['packet_name']).to eql "HEALTH_STATUS"
            expect(hash['DURATION']).to eql 3.0
          when 2
            expect(hash['packet_name']).to eql "ADCS"
          else
            raise "Found too many packets"
          end
          index += 1
        end
      end
    end

    describe "get_tlm_cnt" do
      it "complains about non-existant targets" do
        expect { @api.get_tlm_cnt("BLAH", "ABORT") }.to raise_error("Packet 'BLAH ABORT' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_tlm_cnt("INST", "BLAH") }.to raise_error("Packet 'INST BLAH' does not exist")
      end

      it "returns the receive count" do
        start = @api.get_tlm_cnt("INST", "HEALTH_STATUS")

        packet = System.telemetry.packet("INST", "HEALTH_STATUS").clone
        packet.received_time = Time.now.sys
        packet.received_count += 1
        TelemetryTopic.write_packet(packet, scope: "DEFAULT")

        count = @api.get_tlm_cnt("INST", "HEALTH_STATUS")
        expect(count).to eql start + 1
      end
    end

    describe "get_all_tlm_info" do
      it "returns receive count for all packets" do
        packet = System.telemetry.packet("INST", "ADCS").clone
        packet.received_time = Time.now.sys
        packet.received_count = 100 # This is what is used in the result
        TelemetryTopic.write_packet(packet, scope: "DEFAULT")
        info = @api.get_all_tlm_info()
        expect(info[0][0]).to eql "INST"
        expect(info[0][1]).to eql "ADCS"
        expect(info[0][2]).to eql 100
      end
    end

    describe "get_packet_derived_items" do
      it "complains about non-existant targets" do
        expect { @api.get_packet_derived_items("BLAH", "ABORT") }.to raise_error("Packet 'BLAH ABORT' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_packet_derived_items("INST", "BLAH") }.to raise_error("Packet 'INST BLAH' does not exist")
      end

      it "returns the packet derived items" do
        items = @api.get_packet_derived_items("INST", "HEALTH_STATUS")
        expect(items).to include("RECEIVED_TIMESECONDS", "RECEIVED_TIMEFORMATTED", "RECEIVED_COUNT")
      end
    end
  end
end
