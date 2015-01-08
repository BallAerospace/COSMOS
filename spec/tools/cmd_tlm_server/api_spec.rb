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
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'
require 'cosmos/tools/cmd_tlm_server/api'

module Cosmos

  describe Api do

    before(:all) do
      cts = File.join(Cosmos::USERPATH,'config','tools','cmd_tlm_server','cmd_tlm_server.txt')
      FileUtils.mkdir_p(File.dirname(cts))
      File.open(cts,'w') do |file|
        file.puts 'INTERFACE INT interface.rb'
        file.puts 'ROUTER ROUTE interface.rb'
      end
    end

    before(:each) do
      @api = CmdTlmServer.new
      config = @api.interfaces.instance_variable_get(:@config)
      # Stub interfaces and routers.  Do this like this so that they can still be used in an after hook
      config.interfaces.each do |interface_name, i|
        if i.class == Cosmos::Interface
          def i.connected?(*args)
          end
          def i.connect(*args)
          end
          def i.disconnect(*args)
          end
          def i.write_raw(*args)
          end
          def i.read(*args)
          end
        end
      end
      config.routers.each do |router_name, i|
        if i.class == Cosmos::Interface
          def i.connected?(*args)
          end
          def i.connect(*args)
          end
          def i.disconnect(*args)
          end
          def i.write_raw(*args)
          end
          def i.read(*args)
          end
        end
      end
      allow(@api.commanding).to receive(:send_command_to_target)
    end

    after(:each) do
      @api.stop
      sleep(0.2)
    end

    after(:all) do
      clean_config()
      FileUtils.rm_rf File.join(Cosmos::USERPATH,'config','tools')
    end

    def test_cmd_unknown(method)
      expect { @api.send(method,"BLAH COLLECT with TYPE NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method,"INST UNKNOWN with TYPE NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method,"INST COLLECT with BLAH NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method,"BLAH","COLLECT","TYPE"=>"NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method,"INST","UNKNOWN","TYPE"=>"NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method,"INST","COLLECT","BLAH"=>"NORMAL") }.to raise_error(/does not exist/)
    end

    describe "cmd" do
      it "should complain about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd)
        sleep(0.5)
      end

      it "should process a string" do
        target_name, cmd_name, params = @api.cmd("INST COLLECT with TYPE NORMAL, DURATION 5")
        target_name.should eql 'INST'
        cmd_name.should eql 'COLLECT'
        params.should include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "should complain if parameters are not separated by commas" do
        expect { @api.cmd("INST COLLECT with TYPE NORMAL DURATION 5") }.to raise_error(/Missing comma/)
      end

      it "should complain if parameters don't have values" do
        expect { @api.cmd("INST COLLECT with TYPE") }.to raise_error(/Missing value/)
      end

      it "should process parameters" do
        target_name, cmd_name, params = @api.cmd("INST","COLLECT","TYPE"=>"NORMAL","DURATION"=>5)
        target_name.should eql 'INST'
        cmd_name.should eql 'COLLECT'
        params.should include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "should process commands without parameters" do
        target_name, cmd_name, params = @api.cmd("INST","ABORT")
        target_name.should eql 'INST'
        cmd_name.should eql 'ABORT'
        params.should be {}
      end

      it "should complain about too many parameters" do
        expect { @api.cmd("INST","COLLECT","TYPE","DURATION") }.to raise_error(/Invalid number of arguments/)
      end

      it "should warn about required parameters" do
        expect { @api.cmd("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "should warn about out of range parameters" do
        expect { @api.cmd("INST COLLECT with TYPE NORMAL, DURATION 1000") }.to raise_error(/not in valid range/)
      end

      it "should warn about hazardous parameters" do
        expect { @api.cmd("INST COLLECT with TYPE SPECIAL") }.to raise_error(/Hazardous/)
      end

      it "should warn about hazardous commands" do
        expect { @api.cmd("INST CLEAR") }.to raise_error(/Hazardous/)
      end
    end

    describe "cmd_no_range_check" do
      it "should complain about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_no_range_check)
      end

      it "should process a string" do
        target_name, cmd_no_range_check_name, params = @api.cmd_no_range_check("INST COLLECT with TYPE NORMAL, DURATION 5")
        target_name.should eql 'INST'
        cmd_no_range_check_name.should eql 'COLLECT'
        params.should include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "should process parameters" do
        target_name, cmd_no_range_check_name, params = @api.cmd_no_range_check("INST","COLLECT","TYPE"=>"NORMAL","DURATION"=>5)
        target_name.should eql 'INST'
        cmd_no_range_check_name.should eql 'COLLECT'
        params.should include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "should warn about required parameters" do
        expect { @api.cmd_no_range_check("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "should not warn about out of range parameters" do
        expect { @api.cmd_no_range_check("INST COLLECT with TYPE NORMAL, DURATION 1000") }.to_not raise_error
      end

      it "should warn about hazardous parameters" do
        expect { @api.cmd_no_range_check("INST COLLECT with TYPE SPECIAL") }.to raise_error(/Hazardous/)
      end

      it "should warn about hazardous commands" do
        expect { @api.cmd_no_range_check("INST CLEAR") }.to raise_error(/Hazardous/)
      end
    end

    describe "cmd_no_hazardous_check" do
      it "should complain about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_no_hazardous_check)
      end

      it "should process a string" do
        target_name, cmd_no_hazardous_check_name, params = @api.cmd_no_hazardous_check("INST COLLECT with TYPE NORMAL, DURATION 5")
        target_name.should eql 'INST'
        cmd_no_hazardous_check_name.should eql 'COLLECT'
        params.should include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "should process parameters" do
        target_name, cmd_no_hazardous_check_name, params = @api.cmd_no_hazardous_check("INST","COLLECT","TYPE"=>"NORMAL","DURATION"=>5)
        target_name.should eql 'INST'
        cmd_no_hazardous_check_name.should eql 'COLLECT'
        params.should include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "should process parameters that are strings" do
        target_name, cmd_name, params = @api.cmd_no_hazardous_check("INST ASCIICMD with STRING 'ARM LASER'")
        target_name.should eql 'INST'
        cmd_name.should eql 'ASCIICMD'
        params.should include('STRING'=>'ARM LASER')
      end

      it "should warn about required parameters" do
        expect { @api.cmd_no_hazardous_check("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "should warn about out of range parameters" do
        expect { @api.cmd_no_hazardous_check("INST COLLECT with TYPE NORMAL, DURATION 1000") }.to raise_error(/not in valid range/)
      end

      it "should not warn about hazardous parameters" do
        expect { @api.cmd_no_hazardous_check("INST COLLECT with TYPE SPECIAL") }.to_not raise_error
      end

      it "should not warn about hazardous commands" do
        expect { @api.cmd_no_hazardous_check("INST CLEAR") }.to_not raise_error
      end
    end

    describe "cmd_no_checks" do
      it "should complain about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_no_checks)
      end

      it "should process a string" do
        target_name, cmd_no_checks_name, params = @api.cmd_no_checks("INST COLLECT with TYPE NORMAL, DURATION 5")
        target_name.should eql 'INST'
        cmd_no_checks_name.should eql 'COLLECT'
        params.should include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "should process parameters" do
        target_name, cmd_no_checks_name, params = @api.cmd_no_checks("INST","COLLECT","TYPE"=>"NORMAL","DURATION"=>5)
        target_name.should eql 'INST'
        cmd_no_checks_name.should eql 'COLLECT'
        params.should include('TYPE'=>'NORMAL', 'DURATION'=>5)
      end

      it "should warn about required parameters" do
        expect { @api.cmd_no_checks("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "should not warn about out of range parameters" do
        expect { @api.cmd_no_checks("INST COLLECT with TYPE NORMAL, DURATION 1000") }.to_not raise_error
      end

      it "should not warn about hazardous parameters" do
        expect { @api.cmd_no_checks("INST COLLECT with TYPE SPECIAL") }.to_not raise_error
      end

      it "should not warn about hazardous commands" do
        expect { @api.cmd_no_checks("INST CLEAR") }.to_not raise_error
      end
    end

    describe "cmd_raw" do
      it "should complain about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_raw)
      end

      it "should process a string" do
        target_name, cmd_name, params = @api.cmd_raw("INST COLLECT with TYPE 0, DURATION 5")
        target_name.should eql 'INST'
        cmd_name.should eql 'COLLECT'
        params.should include('TYPE'=>0, 'DURATION'=>5)
      end

      it "should complain if parameters are not separated by commas" do
        expect { @api.cmd_raw("INST COLLECT with TYPE 0 DURATION 5") }.to raise_error(/Missing comma/)
      end

      it "should complain if parameters don't have values" do
        expect { @api.cmd_raw("INST COLLECT with TYPE") }.to raise_error(/Missing value/)
      end

      it "should process parameters" do
        target_name, cmd_name, params = @api.cmd_raw("INST","COLLECT","TYPE"=>0,"DURATION"=>5)
        target_name.should eql 'INST'
        cmd_name.should eql 'COLLECT'
        params.should include('TYPE'=>0, 'DURATION'=>5)
      end

      it "should process commands without parameters" do
        target_name, cmd_name, params = @api.cmd_raw("INST","ABORT")
        target_name.should eql 'INST'
        cmd_name.should eql 'ABORT'
        params.should be {}
      end

      it "should complain about too many parameters" do
        expect { @api.cmd_raw("INST","COLLECT","TYPE","DURATION") }.to raise_error(/Invalid number of arguments/)
      end

      it "should warn about required parameters" do
        expect { @api.cmd_raw("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "should warn about out of range parameters" do
        expect { @api.cmd_raw("INST COLLECT with TYPE 0, DURATION 1000") }.to raise_error(/not in valid range/)
      end

      it "should warn about hazardous parameters" do
        expect { @api.cmd_raw("INST COLLECT with TYPE 1") }.to raise_error(/Hazardous/)
      end

      it "should warn about hazardous commands" do
        expect { @api.cmd_raw("INST CLEAR") }.to raise_error(/Hazardous/)
      end
    end

    describe "cmd_no_range_check" do
      it "should complain about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_raw_no_range_check)
      end

      it "should process a string" do
        target_name, cmd_no_range_check_name, params = @api.cmd_raw_no_range_check("INST COLLECT with TYPE 0, DURATION 5")
        target_name.should eql 'INST'
        cmd_no_range_check_name.should eql 'COLLECT'
        params.should include('TYPE'=>0, 'DURATION'=>5)
      end

      it "should process parameters" do
        target_name, cmd_no_range_check_name, params = @api.cmd_raw_no_range_check("INST","COLLECT","TYPE"=>0,"DURATION"=>5)
        target_name.should eql 'INST'
        cmd_no_range_check_name.should eql 'COLLECT'
        params.should include('TYPE'=>0, 'DURATION'=>5)
      end

      it "should warn about required parameters" do
        expect { @api.cmd_raw_no_range_check("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "should not warn about out of range parameters" do
        expect { @api.cmd_raw_no_range_check("INST COLLECT with TYPE 0, DURATION 1000") }.to_not raise_error
      end

      it "should warn about hazardous parameters" do
        expect { @api.cmd_raw_no_range_check("INST COLLECT with TYPE 1") }.to raise_error(/Hazardous/)
      end

      it "should warn about hazardous commands" do
        expect { @api.cmd_raw_no_range_check("INST CLEAR") }.to raise_error(/Hazardous/)
      end
    end

    describe "cmd_raw_no_hazardous_check" do
      it "should complain about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_raw_no_hazardous_check)
      end

      it "should process a string" do
        target_name, cmd_no_hazardous_check_name, params = @api.cmd_raw_no_hazardous_check("INST COLLECT with TYPE 0, DURATION 5")
        target_name.should eql 'INST'
        cmd_no_hazardous_check_name.should eql 'COLLECT'
        params.should include('TYPE'=>0, 'DURATION'=>5)
      end

      it "should process parameters" do
        target_name, cmd_no_hazardous_check_name, params = @api.cmd_raw_no_hazardous_check("INST","COLLECT","TYPE"=>0,"DURATION"=>5)
        target_name.should eql 'INST'
        cmd_no_hazardous_check_name.should eql 'COLLECT'
        params.should include('TYPE'=>0, 'DURATION'=>5)
      end

      it "should process parameters that are strings" do
        target_name, cmd_name, params = @api.cmd_raw_no_hazardous_check("INST ASCIICMD with STRING 'ARM LASER'")
        target_name.should eql 'INST'
        cmd_name.should eql 'ASCIICMD'
        params.should include('STRING'=>'ARM LASER')
      end

      it "should warn about required parameters" do
        expect { @api.cmd_raw_no_hazardous_check("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "should warn about out of range parameters" do
        expect { @api.cmd_raw_no_hazardous_check("INST COLLECT with TYPE 0, DURATION 1000") }.to raise_error(/not in valid range/)
      end

      it "should not warn about hazardous parameters" do
        expect { @api.cmd_raw_no_hazardous_check("INST COLLECT with TYPE 1") }.to_not raise_error
      end

      it "should not warn about hazardous commands" do
        expect { @api.cmd_raw_no_hazardous_check("INST CLEAR") }.to_not raise_error
      end
    end

    describe "cmd_raw_no_checks" do
      it "should complain about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd_raw_no_checks)
      end

      it "should process a string" do
        target_name, cmd_no_checks_name, params = @api.cmd_raw_no_checks("INST COLLECT with TYPE 0, DURATION 5")
        target_name.should eql 'INST'
        cmd_no_checks_name.should eql 'COLLECT'
        params.should include('TYPE'=>0, 'DURATION'=>5)
      end

      it "should process parameters" do
        target_name, cmd_no_checks_name, params = @api.cmd_raw_no_checks("INST","COLLECT","TYPE"=>0,"DURATION"=>5)
        target_name.should eql 'INST'
        cmd_no_checks_name.should eql 'COLLECT'
        params.should include('TYPE'=>0, 'DURATION'=>5)
      end

      it "should warn about required parameters" do
        expect { @api.cmd_raw_no_checks("INST COLLECT with DURATION 5") }.to raise_error(/Required/)
      end

      it "should not warn about out of range parameters" do
        expect { @api.cmd_raw_no_checks("INST COLLECT with TYPE 0, DURATION 1000") }.to_not raise_error
      end

      it "should not warn about hazardous parameters" do
        expect { @api.cmd_raw_no_checks("INST COLLECT with TYPE 1") }.to_not raise_error
      end

      it "should not warn about hazardous commands" do
        expect { @api.cmd_raw_no_checks("INST CLEAR") }.to_not raise_error
      end
    end

    describe "get_cmd_list" do
      it "should return command names sorted" do
        result = @api.get_cmd_list("INST")
        result.sort.should eql result
      end

      it "should complain with a unknown target" do
        expect { @api.get_cmd_list("BLAH") }.to raise_error(/does not exist/)
      end

      it "should return command names and descriptions for a given target" do
        result = @api.get_cmd_list("INST")
        result[0][0].should eql "ABORT"
        # The second parameter is the description ... only test one
        result[0][1].should eql "Aborts a collect on the instrument"
        result[1][0].should eql "ARYCMD"
        result[2][0].should eql "ASCIICMD"
        result[3][0].should eql "CLEAR"
        result[4][0].should eql "COLLECT"
        result[5][0].should eql "COSMOS_ERROR_HANDLE"
        result[6][0].should eql "COSMOS_ERROR_IGNORE"
        result[7][0].should eql "COSMOS_HANDSHAKE_DS"
        result[8][0].should eql "COSMOS_HANDSHAKE_EN"
        result[9][0].should eql "FLTCMD"
        result[10][0].should eql "LINC_COMMAND"
        result[11][0].should eql "SETPARAMS"
        result[12][0].should eql "SLRPNLDEPLOY"
        result[13][0].should eql "SLRPNLRESET"
      end
    end

    describe "get_cmd_param_list" do
      it "should return parameters for the command" do
        result = @api.get_cmd_param_list("INST","COLLECT")
        # Each element in the results array contains:
        #   name, default, states, description, full units, units, required
        result.should include ['TYPE',0,{"NORMAL"=>0,"SPECIAL"=>1},'Collect type',nil,nil,true]
        result.should include ['TEMP',0.0,nil,'Collect temperature','Celcius','C',false]
      end

      it "should return array parameters for the command" do
        result = @api.get_cmd_param_list("INST","ARYCMD")
        # Each element in the results array contains:
        #   name, default, states, description, full units, units, required
        result.should include ['ARRAY',[],nil,'Array parameter',nil,nil,false]
      end
    end

    describe "get_cmd_hazardous" do
      it "should return whether the command with parameters is hazardous" do
        @api.get_cmd_hazardous("INST","COLLECT",{"TYPE"=>"NORMAL"}).should be_falsey
        @api.get_cmd_hazardous("INST","COLLECT",{"TYPE"=>"SPECIAL"}).should be_truthy
      end

      it "should return whether the command is hazardous" do
        @api.get_cmd_hazardous("INST","CLEAR").should be_truthy
      end
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
      it "should complain about unknown targets, commands, and parameters" do
        test_tlm_unknown(:tlm)
      end

      it "should process a string" do
        value = @api.tlm("INST HEALTH_STATUS TEMP1")
        value.should eql -100.0
      end

      it "should process parameters" do
        value = @api.tlm("INST","HEALTH_STATUS","TEMP1")
      end

      it "should complain if too many parameters" do
        expect { @api.tlm("INST","HEALTH_STATUS","TEMP1","TEMP2") }.to raise_error(/Invalid number of arguments/)
      end
    end

    describe "tlm_raw" do
      it "should complain about unknown targets, commands, and parameters" do
        test_tlm_unknown(:tlm_raw)
      end

      it "should process a string" do
        @api.tlm_raw("INST HEALTH_STATUS TEMP1").should eql 0
      end

      it "should return the value using LATEST" do
        @api.tlm_raw("INST LATEST TEMP1").should eql 0
      end

      it "should process parameters" do
        @api.tlm_raw("INST","HEALTH_STATUS","TEMP1").should eql 0
      end
    end

    describe "tlm_formatted" do
      it "should complain about unknown targets, commands, and parameters" do
        test_tlm_unknown(:tlm_formatted)
      end

      it "should process a string" do
        @api.tlm_formatted("INST HEALTH_STATUS TEMP1").should eql "-100.000"
      end

      it "should return the value using LATEST" do
        @api.tlm_formatted("INST LATEST TEMP1").should eql "-100.000"
      end

      it "should process parameters" do
        @api.tlm_formatted("INST","HEALTH_STATUS","TEMP1").should eql "-100.000"
      end
    end

    describe "tlm_with_units" do
      it "should complain about unknown targets, commands, and parameters" do
        test_tlm_unknown(:tlm_with_units)
      end

      it "should process a string" do
        @api.tlm_with_units("INST HEALTH_STATUS TEMP1").should eql "-100.000 C"
      end

      it "should return the value using LATEST" do
        @api.tlm_with_units("INST LATEST TEMP1").should eql "-100.000 C"
      end

      it "should process parameters" do
        @api.tlm_with_units("INST","HEALTH_STATUS","TEMP1").should eql "-100.000 C"
      end
    end

    describe "tlm_variable" do
      it "should complain about unknown targets, commands, and parameters" do
        expect { @api.tlm_variable("BLAH HEALTH_STATUS COLLECTS",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("INST UNKNOWN COLLECTS",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("INST HEALTH_STATUS BLAH",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("BLAH","HEALTH_STATUS","COLLECTS",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("INST","UNKNOWN","COLLECTS",:RAW) }.to raise_error(/does not exist/)
        expect { @api.tlm_variable("INST","HEALTH_STATUS","BLAH",:RAW) }.to raise_error(/does not exist/)
      end

      it "should process a string" do
        @api.tlm_variable("INST HEALTH_STATUS TEMP1",:CONVERTED).should eql -100.0
        @api.tlm_variable("INST HEALTH_STATUS TEMP1",:RAW).should eql 0
        @api.tlm_variable("INST HEALTH_STATUS TEMP1",:FORMATTED).should eql "-100.000"
        @api.tlm_variable("INST HEALTH_STATUS TEMP1",:WITH_UNITS).should eql "-100.000 C"
      end

      it "should return the value using LATEST" do
        @api.tlm_variable("INST LATEST TEMP1",:CONVERTED).should eql -100.0
        @api.tlm_variable("INST LATEST TEMP1",:RAW).should eql 0
        @api.tlm_variable("INST LATEST TEMP1",:FORMATTED).should eql "-100.000"
        @api.tlm_variable("INST LATEST TEMP1",:WITH_UNITS).should eql "-100.000 C"
      end

      it "should process parameters" do
        @api.tlm_variable("INST","HEALTH_STATUS","TEMP1",:CONVERTED).should eql -100.0
        @api.tlm_variable("INST","HEALTH_STATUS","TEMP1",:RAW).should eql 0
        @api.tlm_variable("INST","HEALTH_STATUS","TEMP1",:FORMATTED).should eql "-100.000"
        @api.tlm_variable("INST","HEALTH_STATUS","TEMP1",:WITH_UNITS).should eql "-100.000 C"
      end

      it "should complain with too many parameters" do
        expect { @api.tlm_variable("INST","HEALTH_STATUS","TEMP1","TEMP2",:CONVERTED) }.to raise_error(/Invalid number of arguments/)
      end
    end

    describe "set_tlm" do
      it "should complain about unknown targets, commands, and parameters" do
        expect { @api.set_tlm("BLAH HEALTH_STATUS COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm("INST UNKNOWN COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm("INST HEALTH_STATUS BLAH = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm("BLAH","HEALTH_STATUS","COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.set_tlm("INST","UNKNOWN","COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.set_tlm("INST","HEALTH_STATUS","BLAH",1) }.to raise_error(/does not exist/)
      end

      it "should process a string" do
        @api.set_tlm("INST HEALTH_STATUS TEMP1 = 0.0")
        @api.tlm("INST HEALTH_STATUS TEMP1").should be_within(0.00001).of(-0.05759)
      end

      it "should process parameters" do
        @api.set_tlm("INST","HEALTH_STATUS","TEMP1", 0.0)
        @api.tlm("INST HEALTH_STATUS TEMP1").should be_within(0.00001).of(-0.05759)
      end

      it "should complain with too many parameters" do
        expect { @api.set_tlm("INST","HEALTH_STATUS","TEMP1","TEMP2",0.0) }.to raise_error(/Invalid number of arguments/)
      end
    end

    describe "set_tlm_raw" do
      it "should complain about unknown targets, commands, and parameters" do
        expect { @api.set_tlm_raw("BLAH HEALTH_STATUS COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm_raw("INST UNKNOWN COLLECTS = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm_raw("INST HEALTH_STATUS BLAH = 1") }.to raise_error(/does not exist/)
        expect { @api.set_tlm_raw("BLAH","HEALTH_STATUS","COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.set_tlm_raw("INST","UNKNOWN","COLLECTS",1) }.to raise_error(/does not exist/)
        expect { @api.set_tlm_raw("INST","HEALTH_STATUS","BLAH",1) }.to raise_error(/does not exist/)
      end

      it "should process a string" do
        @api.set_tlm_raw("INST HEALTH_STATUS TEMP1 = 0.0")
        @api.tlm("INST HEALTH_STATUS TEMP1").should eql -100.0
      end

      it "should process parameters" do
        @api.set_tlm_raw("INST","HEALTH_STATUS","TEMP1", 0.0)
        @api.tlm("INST HEALTH_STATUS TEMP1").should eql -100.0
      end
    end

    describe "get_tlm_packet" do
      it "should complain about non-existant targets" do
        expect { @api.get_tlm_packet("BLAH","HEALTH_STATUS") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @api.get_tlm_packet("INST","BLAH") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "should complain using LATEST" do
        expect { @api.get_tlm_packet("INST","LATEST") }.to raise_error(RuntimeError, "Telemetry packet 'INST LATEST' does not exist")
      end

      it "should complain about non-existant value_types" do
        expect { @api.get_tlm_packet("INST","HEALTH_STATUS",:MINE) }.to raise_error(ArgumentError, "Unknown value type on read: MINE")
      end

      it "should read all telemetry items with their limits states" do
        vals = @api.get_tlm_packet("INST","HEALTH_STATUS")
        vals[0][0].should eql "RECEIVED_TIMESECONDS"
        vals[0][1].should eql 0.0
        vals[0][2].should be_nil
        vals[1][0].should eql "RECEIVED_TIMEFORMATTED"
        vals[1][1].should eql "No Packet Received Time"
        vals[1][2].should be_nil
        vals[2][0].should eql "RECEIVED_COUNT"
        vals[2][1].should eql 0
        vals[2][2].should be_nil
        # Spot check a few more
        vals[22][0].should eql "TEMP1"
        vals[22][1].should eql -100.0
        vals[22][2].should eql :RED_LOW
        vals[23][0].should eql "TEMP2"
        vals[23][1].should eql -100.0
        vals[23][2].should eql :RED_LOW
        vals[24][0].should eql "TEMP3"
        vals[24][1].should eql -100.0
        vals[24][2].should eql :RED_LOW
        vals[25][0].should eql "TEMP4"
        vals[25][1].should eql -100.0
        vals[25][2].should eql :RED_LOW
      end
    end

    describe "get_tlm_values" do
      it "should handle an empty request" do
        @api.get_tlm_values([]).should eql [[], [], [], :DEFAULT]
      end

      it "should complain about non-existant targets" do
        expect { @api.get_tlm_values([["BLAH","HEALTH_STATUS","TEMP1"]]) }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @api.get_tlm_values([["INST","BLAH","TEMP1"]]) }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "should complain about non-existant items" do
        expect { @api.get_tlm_values([["INST","LATEST","BLAH"]]) }.to raise_error(RuntimeError, "Telemetry item 'INST LATEST BLAH' does not exist")
      end

      it "should complain about non-existant value_types" do
        expect { @api.get_tlm_values([["INST","HEALTH_STATUS","TEMP1"]],:MINE) }.to raise_error(ArgumentError, "Unknown value type on read: MINE")
      end

      it "should complain about bad arguments" do
        expect { @api.get_tlm_values("INST",:MINE) }.to raise_error(ArgumentError, /item_array must be nested array/)
        expect { @api.get_tlm_values(["INST","HEALTH_STATUS","TEMP1"],:MINE) }.to raise_error(ArgumentError, /item_array must be nested array/)
        expect { @api.get_tlm_values([["INST","HEALTH_STATUS","TEMP1"]],10) }.to raise_error(ArgumentError, /value_types must be a single symbol or array of symbols/)
        expect { @api.get_tlm_values([["INST","HEALTH_STATUS","TEMP1"]],[10]) }.to raise_error(ArgumentError, /value_types must be a single symbol or array of symbols/)
      end

      it "should read all the specified items" do
        items = []
        items << %w(INST HEALTH_STATUS TEMP1)
        items << %w(INST HEALTH_STATUS TEMP2)
        items << %w(INST HEALTH_STATUS TEMP3)
        items << %w(INST HEALTH_STATUS TEMP4)
        vals = @api.get_tlm_values(items)
        vals[0][0].should eql -100.0
        vals[0][1].should eql -100.0
        vals[0][2].should eql -100.0
        vals[0][3].should eql -100.0
        vals[1][0].should eql :RED_LOW
        vals[1][1].should eql :RED_LOW
        vals[1][2].should eql :RED_LOW
        vals[1][3].should eql :RED_LOW
        vals[2][0].should eql [-80.0, -70.0, 60.0, 80.0, -20.0, 20.0]
        vals[2][1].should eql [-60.0, -55.0, 30.0, 35.0]
        vals[2][2].should eql [-25.0, -10.0, 50.0, 55.0]
        vals[2][3].should eql [-80.0, -70.0, 60.0, 80.0]
        vals[3].should eql :DEFAULT
      end

      it "should read all the specified items with one conversion" do
        items = []
        items << %w(INST HEALTH_STATUS TEMP1)
        items << %w(INST HEALTH_STATUS TEMP2)
        items << %w(INST HEALTH_STATUS TEMP3)
        items << %w(INST HEALTH_STATUS TEMP4)
        vals = @api.get_tlm_values(items, :RAW)
        vals[0][0].should eql 0
        vals[0][1].should eql 0
        vals[0][2].should eql 0
        vals[0][3].should eql 0
        vals[1][0].should eql :RED_LOW
        vals[1][1].should eql :RED_LOW
        vals[1][2].should eql :RED_LOW
        vals[1][3].should eql :RED_LOW
        vals[2][0].should eql [-80.0, -70.0, 60.0, 80.0, -20.0, 20.0]
        vals[2][1].should eql [-60.0, -55.0, 30.0, 35.0]
        vals[2][2].should eql [-25.0, -10.0, 50.0, 55.0]
        vals[2][3].should eql [-80.0, -70.0, 60.0, 80.0]
        vals[3].should eql :DEFAULT
      end

      it "should read all the specified items with different conversions" do
        items = []
        items << %w(INST HEALTH_STATUS TEMP1)
        items << %w(INST HEALTH_STATUS TEMP2)
        items << %w(INST HEALTH_STATUS TEMP3)
        items << %w(INST HEALTH_STATUS TEMP4)
        vals = @api.get_tlm_values(items, [:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS])
        vals[0][0].should eql 0
        vals[0][1].should eql -100.0
        vals[0][2].should eql "-100.000"
        vals[0][3].should eql "-100.000 C"
        vals[1][0].should eql :RED_LOW
        vals[1][1].should eql :RED_LOW
        vals[1][2].should eql :RED_LOW
        vals[1][3].should eql :RED_LOW
        vals[2][0].should eql [-80.0, -70.0, 60.0, 80.0, -20.0, 20.0]
        vals[2][1].should eql [-60.0, -55.0, 30.0, 35.0]
        vals[2][2].should eql [-25.0, -10.0, 50.0, 55.0]
        vals[2][3].should eql [-80.0, -70.0, 60.0, 80.0]
        vals[3].should eql :DEFAULT
      end

      it "should complain if items length != conversions length" do
        items = []
        items << %w(INST HEALTH_STATUS TEMP1)
        items << %w(INST HEALTH_STATUS TEMP2)
        items << %w(INST HEALTH_STATUS TEMP3)
        items << %w(INST HEALTH_STATUS TEMP4)
        expect { @api.get_tlm_values(items, [:RAW, :CONVERTED]) }.to raise_error(ArgumentError, "Passed 4 items but only 2 value types")
      end
    end

    describe "get_tlm_list" do
      it "should complain about non-existant targets" do
        expect { @api.get_tlm_list("BLAH") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "should return the sorted packet names for a target" do
        pkts = @api.get_tlm_list("INST")
        pkts[0][0].should eql "ADCS"
        pkts[1][0].should eql "ERROR"
        pkts[2][0].should eql "HANDSHAKE"
        pkts[3][0].should eql "HEALTH_STATUS"
        pkts[4][0].should eql "IMAGE"
        pkts[5][0].should eql "MECH"
        pkts[6][0].should eql "PARAMS"
      end
    end

    describe "get_tlm_item_list" do
      it "should complain about non-existant targets" do
        expect { @api.get_tlm_item_list("BLAH","HEALTH_STATUS") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @api.get_tlm_item_list("INST","BLAH") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "should return all the items for a target/packet" do
        items = @api.get_tlm_item_list("INST","HEALTH_STATUS")
        items[0][0].should eql "RECEIVED_TIMESECONDS"
        items[1][0].should eql "RECEIVED_TIMEFORMATTED"
        items[2][0].should eql "RECEIVED_COUNT"
        # Spot check a few more
        items[22][0].should eql "TEMP1"
        items[22][1].should be_nil
        items[22][2].should eql "Temperature #1"
        items[28][0].should eql "COLLECT_TYPE"
        items[28][1].should include("NORMAL"=>0, "SPECIAL"=>1)
        items[28][2].should eql "Most recent collect type"
      end
    end

    describe "get_tlm_details" do
      it "should complain about non-existant targets" do
        expect { @api.get_tlm_details([["BLAH","HEALTH_STATUS","TEMP1"]]) }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @api.get_tlm_details([["INST","BLAH","TEMP1"]]) }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "should complain about non-existant items" do
        expect { @api.get_tlm_details([["INST","LATEST","BLAH"]]) }.to raise_error(RuntimeError, "Telemetry item 'INST LATEST BLAH' does not exist")
      end

      it "should complain about bad parameters" do
        expect { @api.get_tlm_details("INST") }.to raise_error(ArgumentError, /item_array must be nested array/)
        expect { @api.get_tlm_details(["INST","LATEST","BLAH"]) }.to raise_error(ArgumentError, /item_array must be nested array/)
      end

      it "should read all the specified items" do
        items = []
        items << %w(INST HEALTH_STATUS TEMP1)
        items << %w(INST HEALTH_STATUS TEMP2)
        items << %w(INST HEALTH_STATUS TEMP3)
        items << %w(INST HEALTH_STATUS TEMP4)
        details = @api.get_tlm_details(items)
        details.length.should eql 4
        details[0]["name"].should eql "TEMP1"
        details[1]["name"].should eql "TEMP2"
        details[2]["name"].should eql "TEMP3"
        details[3]["name"].should eql "TEMP4"
      end
    end

    describe "get_out_of_limits" do
      it "should return all out of limits items" do
        items = @api.get_out_of_limits
        (0..3).each do |i|
          items[i][0].should eql "INST"
          items[i][1].should eql "HEALTH_STATUS"
          items[i][2].should eql "TEMP#{i+1}"
          items[i][3].should eql :RED_LOW
        end
      end
    end

    describe "limits_enabled?" do
      it "should complain about non-existant targets" do
        expect { @api.limits_enabled?("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @api.limits_enabled?("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "should complain about non-existant items" do
        expect { @api.limits_enabled?("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Packet item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "should return whether limits are enable for an item" do
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP1").should be_truthy
      end
    end

    describe "enable_limits" do
      it "should complain about non-existant targets" do
        expect { @api.enable_limits("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @api.enable_limits("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "should complain about non-existant items" do
        expect { @api.enable_limits("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Packet item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "should enable limits for an item" do
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP1").should be_truthy
        @api.disable_limits("INST","HEALTH_STATUS","TEMP1")
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP1").should be_falsey
        @api.enable_limits("INST","HEALTH_STATUS","TEMP1")
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP1").should be_truthy
      end
    end

    describe "disable_limits" do
      it "should complain about non-existant targets" do
        expect { @api.disable_limits("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @api.disable_limits("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "should complain about non-existant items" do
        expect { @api.disable_limits("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Packet item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "should disable limits for an item" do
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP1").should be_truthy
        @api.disable_limits("INST","HEALTH_STATUS","TEMP1")
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP1").should be_falsey
        @api.enable_limits("INST","HEALTH_STATUS","TEMP1")
      end
    end

    describe "get_limits" do
      it "should complain about non-existant targets" do
        expect { @api.get_limits("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @api.get_limits("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "should complain about non-existant items" do
        expect { @api.get_limits("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Packet item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "should get limits for an item" do
        @api.get_limits("INST","HEALTH_STATUS","TEMP1").should eql([:DEFAULT, 1, true, -80.0, -70.0, 60.0, 80.0, -20.0, 20.0])
        @api.get_limits("INST","HEALTH_STATUS","TEMP1",:TVAC).should eql([:TVAC, 1, true, -80.0, -30.0, 30.0, 80.0, nil, nil])
      end
    end

    describe "set_limits" do
      it "should complain about non-existant targets" do
        expect { @api.set_limits("BLAH","HEALTH_STATUS","TEMP1",0.0,10.0,20.0,30.0) }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "should complain about non-existant packets" do
        expect { @api.set_limits("INST","BLAH","TEMP1",0.0,10.0,20.0,30.0) }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "should complain about non-existant items" do
        expect { @api.set_limits("INST","HEALTH_STATUS","BLAH",0.0,10.0,20.0,30.0) }.to raise_error(RuntimeError, "Packet item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "should get limits for an item" do
        @api.set_limits("INST","HEALTH_STATUS","TEMP1",0.0,10.0,20.0,30.0).should eql([:CUSTOM, 1, true, 0.0, 10.0, 20.0, 30.0, nil, nil])
        @api.set_limits("INST","HEALTH_STATUS","TEMP1",0.0,10.0,20.0,30.0,12.0,15.0,:CUSTOM2,2,false).should eql([:CUSTOM2, 2, false, 0.0, 10.0, 20.0, 30.0, 12.0, 15.0])
        @api.set_limits("INST","HEALTH_STATUS","TEMP1",0.0,10.0,20.0,30.0,12.0,15.0,:CUSTOM,1,true).should eql([:CUSTOM, 1, true, 0.0, 10.0, 20.0, 30.0, 12.0, 15.0])
      end
    end

    describe "get_limits_groups" do
      it "should return all the limits groups" do
        @api.get_limits_groups.should eql %w(FIRST SECOND)
      end
    end

    describe "enable_limits_group" do
      it "should complain about undefined limits groups" do
        expect { @api.enable_limits_group("MINE") }.to raise_error(RuntimeError, "LIMITS_GROUP MINE undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP MINE")
      end

      it "should enable limits for all items in the group" do
        @api.disable_limits("INST","HEALTH_STATUS","TEMP1")
        @api.disable_limits("INST","HEALTH_STATUS","TEMP3")
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP1").should be_falsey
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP3").should be_falsey
        @api.enable_limits_group("FIRST")
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP1").should be_truthy
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP3").should be_truthy
      end
    end

    describe "disable_limits_group" do
      it "should complain about undefined limits groups" do
        expect { @api.disable_limits_group("MINE") }.to raise_error(RuntimeError, "LIMITS_GROUP MINE undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP MINE")
      end

      it "should disable limits for all items in the group" do
        @api.enable_limits("INST","HEALTH_STATUS","TEMP1")
        @api.enable_limits("INST","HEALTH_STATUS","TEMP3")
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP1").should be_truthy
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP3").should be_truthy
        @api.disable_limits_group("FIRST")
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP1").should be_falsey
        @api.limits_enabled?("INST","HEALTH_STATUS","TEMP3").should be_falsey
      end
    end

    describe "get_limits_sets, get_limits_set, set_limits_set" do
      it "should get and set the active limits set" do
        if @api.get_limits_sets.include?(:CUSTOM)
          @api.get_limits_sets.should eql [:DEFAULT,:TVAC, :CUSTOM, :CUSTOM2]
        else
          @api.get_limits_sets.should eql [:DEFAULT,:TVAC]
        end
        @api.set_limits_set("TVAC")
        @api.get_limits_set.should eql "TVAC"
        @api.set_limits_set("DEFAULT")
        @api.get_limits_set.should eql "DEFAULT"
      end
    end

    describe "get_target_list" do
      it "should return all target names" do
        @api.get_target_list.should eql %w(COSMOS INST META SYSTEM)
      end
    end

    describe "subscribe_limits_events" do
      it "should call CmdTlmServer" do
        stub_const("Cosmos::CmdTlmServer::DEFAULT_LIMITS_EVENT_QUEUE_SIZE", 100)
        expect(CmdTlmServer).to receive(:subscribe_limits_events)
        @api.subscribe_limits_events
      end
    end

    describe "unsubscribe_limits_events" do
      it "should call CmdTlmServer" do
        expect(CmdTlmServer).to receive(:unsubscribe_limits_events)
        @api.unsubscribe_limits_events(0)
      end
    end

    describe "get_limits_event" do
      it "should get a limits event" do
        expect(CmdTlmServer).to receive(:get_limits_event)
        @api.get_limits_event(0)
      end
    end

    describe "subscribe_packet_data" do
      it "should call CmdTlmServer" do
        stub_const("Cosmos::CmdTlmServer::DEFAULT_PACKET_DATA_QUEUE_SIZE", 100)
        expect(CmdTlmServer).to receive(:subscribe_packet_data)
        @api.subscribe_packet_data([["TGT","PKT1"],["TGT","PKT2"]])
      end
    end

    describe "unsubscribe_packet_datas" do
      it "should call CmdTlmServer" do
        expect(CmdTlmServer).to receive(:unsubscribe_packet_data)
        @api.unsubscribe_packet_data(10)
      end
    end

    describe "get_packet_data" do
      it "should call CmdTlmServer" do
        expect(CmdTlmServer).to receive(:get_packet_data)
        @api.get_packet_data(10)
      end
    end

    # All these methods simply pass through directly to CmdTlmServer without
    # adding any functionality. Thus we just test that they are are received
    # by the CmdTlmServer.
    describe "CmdTlmServer pass-throughs" do
      it "should call through to the CmdTlmServer" do
        @api.get_interface_names
        @api.connect_interface("INT")
        @api.disconnect_interface("INT")
        @api.interface_state("INT")
        @api.map_target_to_interface("INST", "INT")
        @api.get_router_names
        @api.connect_router("ROUTE")
        @api.disconnect_router("ROUTE")
        @api.router_state("ROUTE")
        @api.send_raw("INT","\x00\x01")
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
      end
    end

  end
end

