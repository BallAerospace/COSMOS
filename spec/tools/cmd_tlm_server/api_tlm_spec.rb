# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/tools/cmd_tlm_server/api'
require 'cosmos/microservices/interface_microservice'
require 'cosmos/microservices/decom_microservice'

module Cosmos
  describe Api do
    class ApiTest
      include Api
    end

    before(:each) do
      @redis = configure_store()

      # Create an Interface we can use in the InterfaceTlmHandlerThread
      interface = Interface.new
      interface.name = "INST_INT"
      interface.target_names = %w[INST]
      allow(interface).to receive(:connected?).and_return(true)
      @thread = InterfaceTlmHandlerThread.new(interface)
      Store.instance.set_interface(interface, initialize: true)
      @cmd_thread = InterfaceCmdHandlerThread.new(interface, @thread)

      # Mock out some stuff in Microservice initialize() to allow us to use DecomMicroservice
      dbl = double("AwsS3Client").as_null_object
      allow(Aws::S3::Client).to receive(:new).and_return(dbl)
      allow(Zip::File).to receive(:open).and_return(true)
      @decom = DecomMicroservice.new("DECOM__#{interface.name}")
      @process = true

      # Wrap xadd to allow us to process telemetry like the decom microservice
      # would in the real system.
      allow(@redis).to receive(:xadd).and_wrap_original do |m, *args|
        puts "xadd args[0]:#{args[0]}"
        result = m.call(*args)
        # Run the DecomMicroservice to process the telemetry packet
        # This will populate the individual telemetry items
        if @process && args[0] =~ /^TELEMETRY/
          thread = Thread.new { @decom.run }
          # thread.report_on_exception = false
          sleep 0.1 # Allow the thread to run
          thread.kill
          sleep 0.1 # Wait for the thread to be killed
        elsif @process && args[0] =~ /^CMDINTERFACE/
          thread = Thread.new { @cmd_thread.run }
          # thread.report_on_exception = false
          sleep 0.1 # Allow the thread to run
          thread.kill
          sleep 0.1 # Wait for the thread to be killed
        end

        result
      end

      # Setup INST HEALTH_STATUS TEMP1 like the DECOM and CVT would do
      # json_hash = {}
      # json_hash['TEMP1']    = JSON.generate(0.as_json)
      # json_hash['TEMP1__C'] = JSON.generate(-100.0.as_json)
      # json_hash['TEMP1__F'] = JSON.generate("-100.000".as_json)
      # json_hash['TEMP1__U'] = JSON.generate("-100.000 C".as_json)
      # json_hash['TEMP1__L'] = JSON.generate(:RED_LOW.as_json)
      # @redis.mapped_hmset("tlm__INST__HEALTH_STATUS", json_hash)
      @api = ApiTest.new
    end

    def test_tlm_unknown(method)
      expect { @api.send(method,"BLAH HEALTH_STATUS COLLECTS") }.to raise_error(/does not exist/)
      expect { @api.send(method,"INST UNKNOWN COLLECTS") }.to raise_error(/does not exist/)
      expect { @api.send(method,"INST HEALTH_STATUS BLAH") }.to raise_error(/does not exist/)
      expect { @api.send(method,"BLAH","HEALTH_STATUS","COLLECTS") }.to raise_error(/does not exist/)
      expect { @api.send(method,"INST","UNKNOWN","COLLECTS") }.to raise_error(/does not exist/)
      expect { @api.send(method,"INST","HEALTH_STATUS","BLAH") }.to raise_error(/does not exist/)
    end

    describe "tlm" do
      it "complains about unknown targets, commands, and parameters" do
        test_tlm_unknown(:tlm)
      end

      it "processes a string" do
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql -100.0
      end

      xit "returns the value using LATEST" do
        expect(@api.tlm("INST LATEST TEMP1")).to eql -100.0
      end

      it "processes parameters" do
        expect(@api.tlm("INST","HEALTH_STATUS","TEMP1")).to eql -100.0
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

      xit "returns the value using LATEST" do
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

      xit "returns the value using LATEST" do
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

      xit "returns the value using LATEST" do
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
        expect(@api.tlm_variable("INST HEALTH_STATUS TEMP1",:CONVERTED)).to eql -100.0
        expect(@api.tlm_variable("INST HEALTH_STATUS TEMP1",:RAW)).to eql 0
        expect(@api.tlm_variable("INST HEALTH_STATUS TEMP1",:FORMATTED)).to eql "-100.000"
        expect(@api.tlm_variable("INST HEALTH_STATUS TEMP1",:WITH_UNITS)).to eql "-100.000 C"
      end

      xit "returns the value using LATEST" do
        expect(@api.tlm_variable("INST LATEST TEMP1",:CONVERTED)).to eql -100.0
        expect(@api.tlm_variable("INST LATEST TEMP1",:RAW)).to eql 0
        expect(@api.tlm_variable("INST LATEST TEMP1",:FORMATTED)).to eql "-100.000"
        expect(@api.tlm_variable("INST LATEST TEMP1",:WITH_UNITS)).to eql "-100.000 C"
      end

      it "processes parameters" do
        expect(@api.tlm_variable("INST","HEALTH_STATUS","TEMP1",:CONVERTED)).to eql -100.0
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
      it "complains about non-existant targets" do
        expect { @api.inject_tlm("BLAH","HEALTH_STATUS") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.inject_tlm("INST","BLAH") }.to raise_error(RuntimeError, "Packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.inject_tlm("INST","HEALTH_STATUS",{BLAH: 0}) }.to raise_error(RuntimeError, "Item 'INST HEALTH_STATUS BLAH' does not exist")
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
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to be_within(0.1).of(10.0)
        expect(@api.tlm("INST HEALTH_STATUS TEMP2")).to be_within(0.1).of(20.0)
        @api.inject_tlm("INST","HEALTH_STATUS",{TEMP1: 0, TEMP2: 0}, :RAW, true, true, false)
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql -100.0
        expect(@api.tlm("INST HEALTH_STATUS TEMP2")).to eql -100.0
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
      xit "returns a telemetry packet buffer" do
        # TODO Should inject_tlm still work to set the packet? I think so ...
        @api.inject_tlm("INST","HEALTH_STATUS",{TIMESEC: 0xDEADBEEF})
        expect(@api.get_tlm_buffer("INST", "HEALTH_STATUS")[6..10].unpack("N")[0]).to eq 0xDEADBEEF
      end
    end

    describe "get_tlm_packet" do
      before(:each) do
        packet = System.telemetry.packet("INST", "HEALTH_STATUS")
        msg_hash = {}
        json_hash = {}
        packet.sorted_items.each do |item|
          json_hash[item.name] = packet.read_item(item, :RAW)
          json_hash[item.name + "__C"] = packet.read_item(item, :CONVERTED) if item.read_conversion or item.states
          json_hash[item.name + "__F"] = packet.read_item(item, :FORMATTED) if item.format_string
          json_hash[item.name + "__U"] = packet.read_item(item, :WITH_UNITS) if item.units
          limits_state = item.limits.state
          json_hash[item.name + "__L"] = limits_state if limits_state
        end
        msg_hash['json_data'] = JSON.generate(json_hash.as_json)
        Store.instance.write_topic("DECOM__INST__HEALTH_STATUS", msg_hash)
      end

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

      xit "reads all telemetry items with their limits states" do
        # Call inject_tlm to ensure the limits are set
        @api.inject_tlm("INST","HEALTH_STATUS",{TEMP1: 0, TEMP2: 0, TEMP3: 0, TEMP4: 0}, :RAW)

        vals = @api.get_tlm_packet("INST","HEALTH_STATUS")
        expect(vals[0][0]).to eql "PACKET_TIMESECONDS"
        expect(vals[0][1]).to be > 0
        expect(vals[0][2]).to be_nil
        expect(vals[1][0]).to eql "PACKET_TIMEFORMATTED"
        expect(vals[1][1].split(' ')[0]).to eql Time.now.formatted.split(' ')[0]
        expect(vals[1][2]).to be_nil
        expect(vals[2][0]).to eql "RECEIVED_TIMESECONDS"
        expect(vals[2][1]).to be > 0
        expect(vals[2][2]).to be_nil
        expect(vals[3][0]).to eql "RECEIVED_TIMEFORMATTED"
        expect(vals[3][1].split(' ')[0]).to eql Time.now.formatted.split(' ')[0]
        expect(vals[3][2]).to be_nil
        expect(vals[4][0]).to eql "RECEIVED_COUNT"
        expect(vals[4][1]).to be > 0
        expect(vals[4][2]).to be_nil
        # Spot check a few more
        expect(vals[24][0]).to eql "TEMP1"
        expect(vals[24][1]).to eql -100.0
        expect(vals[24][2]).to eql :RED_LOW
        expect(vals[25][0]).to eql "TEMP2"
        expect(vals[25][1]).to eql -100.0
        expect(vals[25][2]).to eql :RED_LOW
        expect(vals[26][0]).to eql "TEMP3"
        expect(vals[26][1]).to eql -100.0
        expect(vals[26][2]).to eql :RED_LOW
        expect(vals[27][0]).to eql "TEMP4"
        expect(vals[27][1]).to eql -100.0
        expect(vals[27][2]).to eql :RED_LOW
      end
    end

    describe "get_tlm_values" do
      before(:each) do
        (2..4).each do |x|
          json_hash = {}
          json_hash["TEMP#{x}"]    = JSON.generate(0.as_json)
          json_hash["TEMP#{x}__C"] = JSON.generate(-100.0.as_json)
          json_hash["TEMP#{x}__F"] = JSON.generate("-100.000".as_json)
          json_hash["TEMP#{x}__U"] = JSON.generate("-100.000 C".as_json)
          json_hash["TEMP#{x}__L"] = JSON.generate(:RED_LOW.as_json)
          @redis.mapped_hmset("tlm__INST__HEALTH_STATUS", json_hash)
        end
      end

      it "handles an empty request" do
        expect(@api.get_tlm_values([])).to eql [[], []]
      end

      it "complains about non-existant targets" do
        expect { @api.get_tlm_values([["BLAH","HEALTH_STATUS","TEMP1"]]) }.to raise_error(RuntimeError, "Item 'BLAH HEALTH_STATUS TEMP1' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_tlm_values([["INST","BLAH","TEMP1"]]) }.to raise_error(RuntimeError, "Item 'INST BLAH TEMP1' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.get_tlm_values([["INST","LATEST","BLAH"]]) }.to raise_error(RuntimeError, "Item 'INST LATEST BLAH' does not exist")
      end

      it "complains about non-existant value_types" do
        expect { @api.get_tlm_values([["INST","HEALTH_STATUS","TEMP1"]],:MINE) }.to raise_error(ArgumentError, "Unknown value type: MINE")
      end

      it "complains about bad arguments" do
        expect { @api.get_tlm_values("INST",:MINE) }.to raise_error(ArgumentError, /item_array must be nested array/)
        expect { @api.get_tlm_values(["INST","HEALTH_STATUS","TEMP1"],:MINE) }.to raise_error(ArgumentError, /item_array must be nested array/)
        expect { @api.get_tlm_values([["INST","HEALTH_STATUS","TEMP1"]],10) }.to raise_error(ArgumentError, /value_types must be a single symbol or array of symbols/)
        expect { @api.get_tlm_values([["INST","HEALTH_STATUS","TEMP1"]],[10]) }.to raise_error(ArgumentError, /value_types must be a single symbol or array of symbols/)
      end

      it "reads all the specified items" do
        items = []
        items << %w(INST HEALTH_STATUS TEMP1)
        items << %w(INST HEALTH_STATUS TEMP2)
        items << %w(INST HEALTH_STATUS TEMP3)
        items << %w(INST HEALTH_STATUS TEMP4)
        vals = @api.get_tlm_values(items)
        expect(vals[0][0]).to eql -100.0
        expect(vals[0][1]).to eql -100.0
        expect(vals[0][2]).to eql -100.0
        expect(vals[0][3]).to eql -100.0
        expect(vals[1][0]).to eql :RED_LOW
        expect(vals[1][1]).to eql :RED_LOW
        expect(vals[1][2]).to eql :RED_LOW
        expect(vals[1][3]).to eql :RED_LOW
      end

      it "reads all the specified items with one conversion" do
        items = []
        items << %w(INST HEALTH_STATUS TEMP1)
        items << %w(INST HEALTH_STATUS TEMP2)
        items << %w(INST HEALTH_STATUS TEMP3)
        items << %w(INST HEALTH_STATUS TEMP4)
        vals = @api.get_tlm_values(items, :RAW)
        expect(vals[0][0]).to eql 0
        expect(vals[0][1]).to eql 0
        expect(vals[0][2]).to eql 0
        expect(vals[0][3]).to eql 0
        expect(vals[1][0]).to eql :RED_LOW
        expect(vals[1][1]).to eql :RED_LOW
        expect(vals[1][2]).to eql :RED_LOW
        expect(vals[1][3]).to eql :RED_LOW
      end

      it "reads all the specified items with different conversions" do
        items = []
        items << %w(INST HEALTH_STATUS TEMP1)
        items << %w(INST HEALTH_STATUS TEMP2)
        items << %w(INST HEALTH_STATUS TEMP3)
        items << %w(INST HEALTH_STATUS TEMP4)
        vals = @api.get_tlm_values(items, [:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS])
        expect(vals[0][0]).to eql 0
        expect(vals[0][1]).to eql -100.0
        expect(vals[0][2]).to eql "-100.000"
        expect(vals[0][3]).to eql "-100.000 C"
        expect(vals[1][0]).to eql :RED_LOW
        expect(vals[1][1]).to eql :RED_LOW
        expect(vals[1][2]).to eql :RED_LOW
        expect(vals[1][3]).to eql :RED_LOW
      end

      it "complains if items length != conversions length" do
        items = []
        items << %w(INST HEALTH_STATUS TEMP1)
        items << %w(INST HEALTH_STATUS TEMP2)
        items << %w(INST HEALTH_STATUS TEMP3)
        items << %w(INST HEALTH_STATUS TEMP4)
        expect { @api.get_tlm_values(items, [:RAW, :CONVERTED]) }.to raise_error(ArgumentError, "Passed 4 items but only 2 value types")
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

    describe "get_tlm_details" do
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
