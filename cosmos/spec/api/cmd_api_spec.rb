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
require 'cosmos/api/cmd_api'
require 'cosmos/microservices/interface_microservice'
require 'cosmos/script/extract'
require 'cosmos/utilities/authorization'

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
      require 'cosmos/models/target_model'
      model = TargetModel.new(folder_name: 'INST', name: 'INST', scope: "DEFAULT")
      model.create
      model.update_store(File.join(SPEC_DIR, 'install', 'config', 'targets'))
      model = InterfaceModel.new(name: "INST_INT", scope: "DEFAULT", target_names: ["INST"], config_params: ["interface.rb"])
      model.create
      model = InterfaceStatusModel.new(name: "INST_INT", scope: "DEFAULT", state: "ACTIVE")
      model.create

      # Create an Interface we can use in the InterfaceCmdHandlerThread
      # It has to have a valid list of target_names as that is what 'receive_commands'
      # in the Store uses to determine which topics to read
      interface = Interface.new
      interface.name = "INST_INT"
      interface.target_names = %w[INST]
      # Stub to make the InterfaceCmdHandlerThread happy
      @interface_data = ''
      allow(interface).to receive(:connected?).and_return(true)
      allow(interface).to receive(:write_interface) { |data| @interface_data = data }
      @thread = InterfaceCmdHandlerThread.new(interface, nil, scope: 'DEFAULT')
      @process = true # Allow the command to be processed or not

      allow(redis).to receive(:xread).and_wrap_original do |m, *args|
        # Only use the first two arguments as the last argument is keyword block:
        result = m.call(*args[0..1]) if @process
        # Create a slight delay to simulate the blocking call
        sleep 0.001 if result and result.length == 0
        result
      end

      @int_thread = Thread.new { @thread.run }
      sleep 0.01 # Allow thread to spin up
      @api = ApiTest.new
    end

    after(:each) do
      @int_thread.kill
      count = 0
      while (@int_thread.alive? or count < 100) do
        sleep 0.01
        count += 1
      end
    end

    def test_cmd_unknown(method)
      expect { @api.send(method, "BLAH COLLECT with TYPE NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method, "INST UNKNOWN with TYPE NORMAL") }.to raise_error(/does not exist/)
      # expect { @api.send(method, "INST COLLECT with BLAH NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method, "BLAH", "COLLECT", "TYPE"=>"NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method, "INST", "UNKNOWN", "TYPE"=>"NORMAL") }.to raise_error(/does not exist/)
      # expect { @api.send(method, "INST", "COLLECT", "BLAH"=>"NORMAL") }.to raise_error(/does not exist/)
    end

    describe "cmd" do
      it "complains about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd)
      end

      it "processes a string" do
        target_name, cmd_name, params = @api.cmd("INST COLLECT with TYPE NORMAL, DURATION 5")
        expect(target_name).to eql 'INST'
        expect(cmd_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "complains if parameters are not separated by commas" do
        expect { @api.cmd("INST COLLECT with TYPE NORMAL DURATION 5") }.to raise_error(/Missing comma/)
      end

      it "complains if parameters don't have values" do
        expect { @api.cmd("INST COLLECT with TYPE") }.to raise_error(/Missing value/)
      end

      it "processes parameters" do
        target_name, cmd_name, params = @api.cmd("INST","COLLECT","TYPE"=>"NORMAL","DURATION"=>5)
        expect(target_name).to eql 'INST'
        expect(cmd_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "processes commands without parameters" do
        target_name, cmd_name, params = @api.cmd("INST","ABORT")
        expect(target_name).to eql 'INST'
        expect(cmd_name).to eql 'ABORT'
        expect(params).to be {}
      end

      it "complains about too many parameters" do
        expect { @api.cmd("INST","COLLECT","TYPE","DURATION") }.to raise_error(/Invalid number of arguments/)
      end

      it "warns about required parameters" do
        expect { @api.cmd("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "warns about out of range parameters" do
        expect { @api.cmd("INST COLLECT with TYPE NORMAL, DURATION 1000") }.to raise_error(/not in valid range/)
      end

      it "warns about hazardous parameters" do
        expect { @api.cmd("INST COLLECT with TYPE SPECIAL") }.to raise_error(/Hazardous/)
      end

      it "warns about hazardous commands" do
        expect { @api.cmd("INST CLEAR") }.to raise_error(/Hazardous/)
      end

      it "times out if the interface does not process the command" do
        @process = false
        expect { @api.cmd("INST","ABORT") }.to raise_error("Timeout waiting for cmd ack")
      end
    end

    describe "cmd_no_range_check" do
      it "complains about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_no_range_check)
      end

      it "processes a string" do
        target_name, cmd_no_range_check_name, params = @api.cmd_no_range_check("INST COLLECT with TYPE NORMAL, DURATION 5")
        expect(target_name).to eql 'INST'
        expect(cmd_no_range_check_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "processes parameters" do
        target_name, cmd_no_range_check_name, params = @api.cmd_no_range_check("INST","COLLECT","TYPE"=>"NORMAL","DURATION"=>5)
        expect(target_name).to eql 'INST'
        expect(cmd_no_range_check_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "warns about required parameters" do
        expect { @api.cmd_no_range_check("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "does not warn about out of range parameters" do
        expect { @api.cmd_no_range_check("INST COLLECT with TYPE NORMAL, DURATION 1000") }.to_not raise_error
      end

      it "warns about hazardous parameters" do
        expect { @api.cmd_no_range_check("INST COLLECT with TYPE SPECIAL") }.to raise_error(/Hazardous/)
      end

      it "warns about hazardous commands" do
        expect { @api.cmd_no_range_check("INST CLEAR") }.to raise_error(/Hazardous/)
      end
    end

    describe "cmd_no_hazardous_check" do
      it "complains about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_no_hazardous_check)
      end

      it "processes a string" do
        target_name, cmd_no_hazardous_check_name, params = @api.cmd_no_hazardous_check("INST COLLECT with TYPE NORMAL, DURATION 5")
        expect(target_name).to eql 'INST'
        expect(cmd_no_hazardous_check_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "processes parameters" do
        target_name, cmd_no_hazardous_check_name, params = @api.cmd_no_hazardous_check("INST","COLLECT","TYPE"=>"NORMAL","DURATION"=>5)
        expect(target_name).to eql 'INST'
        expect(cmd_no_hazardous_check_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "processes parameters that are strings" do
        target_name, cmd_name, params = @api.cmd_no_hazardous_check("INST ASCIICMD with STRING 'ARM LASER'")
        expect(target_name).to eql 'INST'
        expect(cmd_name).to eql 'ASCIICMD'
        expect(params).to include('STRING'=>'ARM LASER')
      end

      it "warns about required parameters" do
        expect { @api.cmd_no_hazardous_check("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "warns about out of range parameters" do
        expect { @api.cmd_no_hazardous_check("INST COLLECT with TYPE NORMAL, DURATION 1000") }.to raise_error(/not in valid range/)
      end

      it "does not warn about hazardous parameters" do
        expect { @api.cmd_no_hazardous_check("INST COLLECT with TYPE SPECIAL") }.to_not raise_error
      end

      it "does not warn about hazardous commands" do
        expect { @api.cmd_no_hazardous_check("INST CLEAR") }.to_not raise_error
      end
    end

    describe "cmd_no_checks" do
      it "complains about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_no_checks)
      end

      it "processes a string" do
        target_name, cmd_no_checks_name, params = @api.cmd_no_checks("INST COLLECT with TYPE NORMAL, DURATION 5")
        expect(target_name).to eql 'INST'
        expect(cmd_no_checks_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "processes parameters" do
        target_name, cmd_no_checks_name, params = @api.cmd_no_checks("INST","COLLECT","TYPE"=>"NORMAL","DURATION"=>5)
        expect(target_name).to eql 'INST'
        expect(cmd_no_checks_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "warns about required parameters" do
        expect { @api.cmd_no_checks("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "does not warn about out of range parameters" do
        expect { @api.cmd_no_checks("INST COLLECT with TYPE NORMAL, DURATION 1000") }.to_not raise_error
      end

      it "does not warn about hazardous parameters" do
        expect { @api.cmd_no_checks("INST COLLECT with TYPE SPECIAL") }.to_not raise_error
      end

      it "does not warn about hazardous commands" do
        expect { @api.cmd_no_checks("INST CLEAR") }.to_not raise_error
      end
    end

    describe "cmd_raw" do
      it "complains about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_raw)
      end

      it "processes a string" do
        target_name, cmd_name, params = @api.cmd_raw("INST COLLECT with TYPE 0, DURATION 5")
        expect(target_name).to eql 'INST'
        expect(cmd_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>0, 'DURATION'=>5)
      end

      it "complains if parameters are not separated by commas" do
        expect { @api.cmd_raw("INST COLLECT with TYPE 0 DURATION 5") }.to raise_error(/Missing comma/)
      end

      it "complains if parameters don't have values" do
        expect { @api.cmd_raw("INST COLLECT with TYPE") }.to raise_error(/Missing value/)
      end

      it "processes parameters" do
        target_name, cmd_name, params = @api.cmd_raw("INST","COLLECT","TYPE"=>0,"DURATION"=>5)
        expect(target_name).to eql 'INST'
        expect(cmd_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>0, 'DURATION'=>5)
      end

      it "processes commands without parameters" do
        target_name, cmd_name, params = @api.cmd_raw("INST","ABORT")
        expect(target_name).to eql 'INST'
        expect(cmd_name).to eql 'ABORT'
        expect(params).to be {}
      end

      it "complains about too many parameters" do
        expect { @api.cmd_raw("INST","COLLECT","TYPE","DURATION") }.to raise_error(/Invalid number of arguments/)
      end

      it "warns about required parameters" do
        expect { @api.cmd_raw("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "warns about out of range parameters" do
        expect { @api.cmd_raw("INST COLLECT with TYPE 0, DURATION 1000") }.to raise_error(/not in valid range/)
      end

      it "warns about hazardous parameters" do
        expect { @api.cmd_raw("INST COLLECT with TYPE 1") }.to raise_error(/Hazardous/)
      end

      it "warns about hazardous commands" do
        expect { @api.cmd_raw("INST CLEAR") }.to raise_error(/Hazardous/)
      end
    end

    describe "cmd_no_range_check" do
      it "complains about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_raw_no_range_check)
      end

      it "processes a string" do
        target_name, cmd_no_range_check_name, params = @api.cmd_raw_no_range_check("INST COLLECT with TYPE 0, DURATION 5")
        expect(target_name).to eql 'INST'
        expect(cmd_no_range_check_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>0, 'DURATION'=>5)
      end

      it "processes parameters" do
        target_name, cmd_no_range_check_name, params = @api.cmd_raw_no_range_check("INST","COLLECT","TYPE"=>0,"DURATION"=>5)
        expect(target_name).to eql 'INST'
        expect(cmd_no_range_check_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>0, 'DURATION'=>5)
      end

      it "warns about required parameters" do
        expect { @api.cmd_raw_no_range_check("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "does not warn about out of range parameters" do
        expect { @api.cmd_raw_no_range_check("INST COLLECT with TYPE 0, DURATION 1000") }.to_not raise_error
      end

      it "warns about hazardous parameters" do
        expect { @api.cmd_raw_no_range_check("INST COLLECT with TYPE 1") }.to raise_error(/Hazardous/)
      end

      it "warns about hazardous commands" do
        expect { @api.cmd_raw_no_range_check("INST CLEAR") }.to raise_error(/Hazardous/)
      end
    end

    describe "cmd_raw_no_hazardous_check" do
      it "complains about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_raw_no_hazardous_check)
      end

      it "processes a string" do
        target_name, cmd_no_hazardous_check_name, params = @api.cmd_raw_no_hazardous_check("INST COLLECT with TYPE 0, DURATION 5")
        expect(target_name).to eql 'INST'
        expect(cmd_no_hazardous_check_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>0, 'DURATION'=>5)
      end

      it "processes parameters" do
        target_name, cmd_no_hazardous_check_name, params = @api.cmd_raw_no_hazardous_check("INST","COLLECT","TYPE"=>0,"DURATION"=>5)
        expect(target_name).to eql 'INST'
        expect(cmd_no_hazardous_check_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>0, 'DURATION'=>5)
      end

      it "processes parameters that are strings" do
        target_name, cmd_name, params = @api.cmd_raw_no_hazardous_check("INST ASCIICMD with STRING 'ARM LASER'")
        expect(target_name).to eql 'INST'
        expect(cmd_name).to eql 'ASCIICMD'
        expect(params).to include('STRING'=>'ARM LASER')
      end

      it "warns about required parameters" do
        expect { @api.cmd_raw_no_hazardous_check("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "warns about out of range parameters" do
        expect { @api.cmd_raw_no_hazardous_check("INST COLLECT with TYPE 0, DURATION 1000") }.to raise_error(/not in valid range/)
      end

      it "does not warn about hazardous parameters" do
        expect { @api.cmd_raw_no_hazardous_check("INST COLLECT with TYPE 1") }.to_not raise_error
      end

      it "does not warn about hazardous commands" do
        expect { @api.cmd_raw_no_hazardous_check("INST CLEAR") }.to_not raise_error
      end
    end

    describe "cmd_raw_no_checks" do
      it "complains about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_raw_no_checks)
      end

      it "processes a string" do
        target_name, cmd_no_checks_name, params = @api.cmd_raw_no_checks("INST COLLECT with TYPE 0, DURATION 5")
        expect(target_name).to eql 'INST'
        expect(cmd_no_checks_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>0, 'DURATION'=>5)
      end

      it "processes parameters" do
        target_name, cmd_no_checks_name, params = @api.cmd_raw_no_checks("INST","COLLECT","TYPE"=>0,"DURATION"=>5)
        expect(target_name).to eql 'INST'
        expect(cmd_no_checks_name).to eql 'COLLECT'
        expect(params).to include('TYPE'=>0, 'DURATION'=>5)
      end

      it "warns about required parameters" do
        expect { @api.cmd_raw_no_checks("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "does not warn about out of range parameters" do
        expect { @api.cmd_raw_no_checks("INST COLLECT with TYPE 0, DURATION 1000") }.to_not raise_error
      end

      it "does not warn about hazardous parameters" do
        expect { @api.cmd_raw_no_checks("INST COLLECT with TYPE 1") }.to_not raise_error
      end

      it "does not warn about hazardous commands" do
        expect { @api.cmd_raw_no_checks("INST CLEAR") }.to_not raise_error
      end
    end

    describe "get_cmd_buffer" do
      it "complains about unknown commands" do
        expect { @api.get_cmd_buffer("INST", "BLAH") }.to raise_error(/does not exist/)
      end

      it "returns nil if the command has not yet been sent" do
        expect(@api.get_cmd_buffer("INST", "ABORT")).to be_nil
      end

      it "returns a command packet buffer" do
        @api.cmd("INST ABORT")
        expect(@api.get_cmd_buffer("INST", "ABORT")[6..7].unpack("n")[0]).to eq 2
        @api.cmd("INST COLLECT with TYPE NORMAL, DURATION 5")
        expect(@api.get_cmd_buffer("INST", "COLLECT")[6..7].unpack("n")[0]).to eq 1
      end
    end

    describe "send_raw" do
      it "raises on unknown interfaces" do
        expect { @api.send_raw("BLAH_INT", "\x00\x01\x02\x03") }.to raise_error("Interface 'BLAH_INT' does not exist")
      end

      it "sends raw data to an interface" do
        @api.send_raw("INST_INT", "\x00\x01\x02\x03")
        sleep 0.1
        expect(@interface_data).to eql "\x00\x01\x02\x03"
      end
    end

    describe 'get_all_commands' do
      it "complains with a unknown target" do
        expect { @api.get_all_commands("BLAH") }.to raise_error(/does not exist/)
      end

      it "returns an array of commands as hashes" do
        result = @api.get_all_commands("INST")
        expect(result).to be_a Array
        result.each do |command|
          expect(command).to be_a Hash
          expect(command['target_name']).to eql("INST")
          expect(command.keys).to include(*%w(target_name packet_name description endianness items))
        end
      end
    end

    describe "get_parameter" do
      it "returns parameter hash for state parameter" do
        result = @api.get_parameter("INST","COLLECT","TYPE")
        expect(result['name']).to eql "TYPE"
        expect(result['states'].keys.sort).to eql %w[NORMAL SPECIAL]
        expect(result['states']['NORMAL']).to include("value" => 0)
        expect(result['states']['SPECIAL']).to include("value" => 1, "hazardous" => "")
      end

      it "returns parameter hash for array parameter" do
        result = @api.get_parameter("INST","ARYCMD","ARRAY")
        expect(result['name']).to eql "ARRAY"
        expect(result['bit_size']).to eql 64
        expect(result['array_size']).to eql 640
        expect(result['data_type']).to eql "FLOAT"
      end
    end

    describe 'get_command' do
      it "returns hash for the command and parameters" do
        result = @api.get_command("INST","COLLECT")
        expect(result).to be_a Hash
        expect(result['target_name']).to eql "INST"
        expect(result['packet_name']).to eql "COLLECT"
        result['items'].each do |parameter|
          expect(parameter).to be_a Hash
          if Packet::RESERVED_ITEM_NAMES.include?(parameter['name'])
            # Reserved items don't have default, min, max
            expect(parameter.keys).to include(*%w(name bit_offset bit_size data_type description endianness overflow))
          else
            expect(parameter.keys).to include(*%w(name bit_offset bit_size data_type description default minimum maximum endianness overflow))
          end

          # Check a few of the parameters
          if parameter['name'] == 'TYPE'
            expect(parameter['default']).to eql 0
            expect(parameter['data_type']).to eql "UINT"
            expect(parameter['states']).to eql({ "NORMAL" => { "value" => 0 }, "SPECIAL" => { "value" => 1, "hazardous" => "" }})
            expect(parameter['description']).to eql "Collect type"
            expect(parameter['required']).to be true
            expect(parameter['units']).to be_nil
          end
          if parameter['name'] == 'TEMP'
            expect(parameter['default']).to eql 0.0
            expect(parameter['data_type']).to eql "FLOAT"
            expect(parameter['states']).to be_nil
            expect(parameter['description']).to eql "Collect temperature"
            expect(parameter['units_full']).to eql "Celsius"
            expect(parameter['units']).to eql "C"
            expect(parameter['required']).to be false
          end
        end
      end
    end

    describe "get_cmd_hazardous" do
      it "returns whether the command with parameters is hazardous" do
        expect(@api.get_cmd_hazardous("INST COLLECT with TYPE NORMAL")).to be false
        expect(@api.get_cmd_hazardous("INST COLLECT with TYPE SPECIAL")).to be true

        expect(@api.get_cmd_hazardous("INST","COLLECT",{"TYPE"=>"NORMAL"})).to be false
        expect(@api.get_cmd_hazardous("INST","COLLECT",{"TYPE"=>"SPECIAL"})).to be true
        expect(@api.get_cmd_hazardous("INST","COLLECT",{"TYPE"=>0})).to be false
        expect(@api.get_cmd_hazardous("INST","COLLECT",{"TYPE"=>1})).to be true
      end

      it "returns whether the command is hazardous" do
        expect(@api.get_cmd_hazardous("INST CLEAR")).to be true
        expect(@api.get_cmd_hazardous("INST","CLEAR")).to be true
      end

      it "raises with the wrong number of arguments" do
        expect { @api.get_cmd_hazardous("INST", "COLLECT", "TYPE", "SPECIAL") }.to raise_error(/Invalid number of arguments/)
      end
    end

    describe "get_cmd_value" do
      it "returns command values" do
        time = Time.now
        @api.cmd("INST COLLECT with TYPE NORMAL, DURATION 5")
        sleep 0.1
        expect(@api.get_cmd_value("INST", "COLLECT", "TYPE")).to eql 'NORMAL'
        expect(@api.get_cmd_value("INST", "COLLECT", "DURATION")).to eql 5.0
        expect(@api.get_cmd_value("INST", "COLLECT", "RECEIVED_TIMESECONDS")).to be_within(0.01).of(time.to_f)
        expect(@api.get_cmd_value("INST", "COLLECT", "PACKET_TIMESECONDS")).to be_within(0.01).of(time.to_f)
        expect(@api.get_cmd_value("INST", "COLLECT", "RECEIVED_COUNT")).to eql 1

        @api.cmd("INST COLLECT with TYPE NORMAL, DURATION 7")
        sleep 0.1
        expect(@api.get_cmd_value("INST", "COLLECT", "RECEIVED_COUNT")).to eql 2
        expect(@api.get_cmd_value("INST", "COLLECT", "DURATION")).to eql 7.0
      end
    end

    describe "get_cmd_time" do
      it "returns command times" do
        time = Time.now
        @api.cmd("INST COLLECT with TYPE NORMAL, DURATION 5")
        sleep 0.1
        result = @api.get_cmd_time("INST", "COLLECT")
        expect(result[0]).to eq("INST")
        expect(result[1]).to eq("COLLECT")
        expect(result[2]).to be_within(1).of(time.tv_sec) # Allow 1s for rounding
        expect(result[3]).to be_within(50_000).of(time.tv_usec) # Allow 50ms

        result = @api.get_cmd_time("INST")
        expect(result[0]).to eq("INST")
        expect(result[1]).to eq("COLLECT")
        expect(result[2]).to be_within(1).of(time.tv_sec) # Allow 1s for rounding
        expect(result[3]).to be_within(50_000).of(time.tv_usec) # Allow 50ms

        result = @api.get_cmd_time()
        expect(result[0]).to eq("INST")
        expect(result[1]).to eq("COLLECT")
        expect(result[2]).to be_within(1).of(time.tv_sec) # Allow 1s for rounding
        expect(result[3]).to be_within(50_000).of(time.tv_usec) # Allow 50ms

        time = Time.now
        @api.cmd("INST ABORT")
        sleep 0.1
        result = @api.get_cmd_time("INST")
        expect(result[0]).to eq("INST")
        expect(result[1]).to eq("ABORT") # New latest is ABORT
        expect(result[2]).to be_within(1).of(time.tv_sec) # Allow 1s for rounding
        expect(result[3]).to be_within(50_000).of(time.tv_usec) # Allow 50ms

        result = @api.get_cmd_time()
        expect(result[0]).to eq("INST")
        expect(result[1]).to eq("ABORT")
        expect(result[2]).to be_within(1).of(time.tv_sec) # Allow 1s for rounding
        expect(result[3]).to be_within(50_000).of(time.tv_usec) # Allow 50ms
      end

      it "returns 0 if no times are set" do
        expect(@api.get_cmd_time("INST", "ABORT")).to eql ["INST", "ABORT", 0, 0]
        expect(@api.get_cmd_time("INST")).to eql [nil, nil, 0, 0]
        expect(@api.get_cmd_time()).to eql [nil, nil, 0, 0]
      end
    end

    describe "get_cmd_cnt" do
      it "complains about non-existant targets" do
        expect { @api.get_cmd_cnt("BLAH", "ABORT") }.to raise_error("Packet 'BLAH ABORT' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_cmd_cnt("INST", "BLAH") }.to raise_error("Packet 'INST BLAH' does not exist")
      end

      it "returns the transmit count" do
        start = @api.get_cmd_cnt("INST", "COLLECT")
        @api.cmd("INST COLLECT with TYPE NORMAL, DURATION 5")
        # Send unrelated commands to ensure specific command count
        @api.cmd("INST ABORT")
        @api.cmd_no_hazardous_check("INST CLEAR")
        sleep 0.1

        count = @api.get_cmd_cnt("INST", "COLLECT")
        expect(count).to eql start + 1
      end
    end

    describe "get_all_cmd_info" do
      it "returns transmit count for all commands" do
        @api.cmd("INST ABORT")
        @api.cmd("INST COLLECT with TYPE NORMAL, DURATION 5")
        sleep 0.1
        baseline = @api.get_all_cmd_info()
        @api.cmd("INST ABORT")
        @api.cmd("INST ABORT")
        @api.cmd("INST COLLECT with TYPE NORMAL, DURATION 5")
        sleep 0.1
        info = @api.get_all_cmd_info()
        expect(info[0][0]).to eql "INST"
        expect(info[0][1]).to eql "ABORT"
        expect(info[0][2]).to eql baseline[0][2] + 2
        expect(info[1][0]).to eql "INST"
        expect(info[1][1]).to eql "COLLECT"
        expect(info[1][2]).to eql baseline[1][2] + 1
      end
    end
  end
end
