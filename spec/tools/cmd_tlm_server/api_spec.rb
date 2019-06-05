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
      # Save cmd_tlm_server.txt
      @cts = File.join(Cosmos::USERPATH,'config','tools','cmd_tlm_server','cmd_tlm_server.txt')
      FileUtils.mv @cts, Cosmos::USERPATH

      FileUtils.mkdir_p(File.dirname(@cts))
      File.open(@cts,'w') do |file|
        file.puts 'INTERFACE INST_INT interface.rb'
        file.puts '  TARGET INST'
        file.puts '  PROTOCOL READ_WRITE OverrideProtocol'
        file.puts 'ROUTER ROUTE interface.rb'
        file.puts 'BACKGROUND_TASK example_background_task1.rb'
        file.puts 'BACKGROUND_TASK example_background_task2.rb'
      end
      @background1 = File.join(Cosmos::USERPATH,'lib','example_background_task1.rb')
      File.open(@background1,'w') do |file|
        file.write <<-DOC
require 'cosmos/tools/cmd_tlm_server/background_task'
module Cosmos
  class ExampleBackgroundTask1 < BackgroundTask
    def initialize
      super()
      @name = 'Example Background Task1'
      @status = "This is example one"
      @sleeper = Sleeper.new
    end
    def call
      return if @sleeper.sleep(0.3)
    end
    def stop
      @sleeper.cancel
    end
  end
end
DOC
      end
      @background2 = File.join(Cosmos::USERPATH,'lib','example_background_task2.rb')
      File.open(@background2,'w') do |file|
        file.write <<-DOC
require 'cosmos/tools/cmd_tlm_server/background_task'
module Cosmos
  class ExampleBackgroundTask2 < BackgroundTask
    def initialize
      super()
      @name = 'Example Background Task2'
      @status = "This is example two"
      @sleeper = Sleeper.new
    end
    def call
      loop do
        return if @sleeper.sleep(1)
      end
    end
    def stop
      @sleeper.cancel
    end
  end
end
DOC
      end
    end

    after(:all) do
      FileUtils.rm_rf @background1
      FileUtils.rm_rf @background2
      # Restore cmd_tlm_server.txt
      FileUtils.mv File.join(Cosmos::USERPATH, 'cmd_tlm_server.txt'),
      File.join(Cosmos::USERPATH,'config','tools','cmd_tlm_server')
    end

    before(:each) do
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

    def test_cmd_unknown(method)
      expect { @api.send(method,"BLAH COLLECT with TYPE NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method,"INST UNKNOWN with TYPE NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method,"INST COLLECT with BLAH NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method,"BLAH","COLLECT","TYPE"=>"NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method,"INST","UNKNOWN","TYPE"=>"NORMAL") }.to raise_error(/does not exist/)
      expect { @api.send(method,"INST","COLLECT","BLAH"=>"NORMAL") }.to raise_error(/does not exist/)
    end

    describe "cmd" do
      it "complains about unknown targets, commands, and parameters" do
        test_cmd_unknown(:cmd)
        sleep(0.5)
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
      it "returns a command packet buffer" do
        @api.cmd("INST ABORT")
        expect(@api.get_cmd_buffer("INST", "ABORT")[6..7].unpack("n")[0]).to eq 2
        @api.cmd("INST COLLECT with TYPE NORMAL, DURATION 5")
        expect(@api.get_cmd_buffer("INST", "COLLECT")[6..7].unpack("n")[0]).to eq 1
      end
    end

    describe "get_cmd_list" do
      it "returns command names sorted" do
        result = @api.get_cmd_list("INST")
        expect(result.sort).to eql result
      end

      it "complains with a unknown target" do
        expect { @api.get_cmd_list("BLAH") }.to raise_error(/does not exist/)
      end

      it "returns command names and descriptions for a given target" do
        result = @api.get_cmd_list("INST")
        expect(result[0][0]).to eql "ABORT"
        # The second parameter is the description ... only test one
        expect(result[0][1]).to eql "Aborts a collect on the instrument"
        expect(result[1][0]).to eql "ARYCMD"
        expect(result[2][0]).to eql "ASCIICMD"
        expect(result[3][0]).to eql "CLEAR"
        expect(result[4][0]).to eql "COLLECT"
        expect(result[5][0]).to eql "COSMOS_ERROR_HANDLE"
        expect(result[6][0]).to eql "COSMOS_ERROR_IGNORE"
        expect(result[7][0]).to eql "COSMOS_HANDSHAKE_DS"
        expect(result[8][0]).to eql "COSMOS_HANDSHAKE_EN"
        expect(result[9][0]).to eql "FLTCMD"
        expect(result[10][0]).to eql "LINC_COMMAND"
        expect(result[11][0]).to eql "SETPARAMS"
        expect(result[12][0]).to eql "SLRPNLDEPLOY"
        expect(result[13][0]).to eql "SLRPNLRESET"
      end
    end

    describe "get_cmd_param_list" do
      it "returns parameters for the command" do
        result = @api.get_cmd_param_list("INST","COLLECT")
        # Each element in the results array contains:
        #   name, default, states, description, full units, units, required
        expect(result).to include ['TYPE',0,{"NORMAL"=>0,"SPECIAL"=>1},'Collect type',nil,nil,true,"UINT"]
        expect(result).to include ['TEMP',0.0,nil,'Collect temperature','Celsius','C',false,"FLOAT"]
      end

      it "returns array parameters for the command" do
        result = @api.get_cmd_param_list("INST","ARYCMD")
        # Each element in the results array contains:
        #   name, default, states, description, full units, units, required
        expect(result).to include ['ARRAY',[],nil,'Array parameter',nil,nil,false,"FLOAT"]
        # Since ARRAY2 has a format string the default is in quotes
        expect(result).to include ['ARRAY2',"[]",nil,'Array parameter',nil,nil,false,"UINT"]
      end
    end

    describe "get_cmd_hazardous" do
      it "returns whether the command with parameters is hazardous" do
        expect(@api.get_cmd_hazardous("INST","COLLECT",{"TYPE"=>"NORMAL"})).to be false
        expect(@api.get_cmd_hazardous("INST","COLLECT",{"TYPE"=>"SPECIAL"})).to be true
      end

      it "returns whether the command is hazardous" do
        expect(@api.get_cmd_hazardous("INST","CLEAR")).to be true
      end
    end

    describe "get_cmd_value" do
      it "returns command values" do
        time = Time.now
        packet = System.commands.packet("INST", "COLLECT")
        packet.received_time = time
        packet.restore_defaults
        packet.received_count = 5
        expect(@api.get_cmd_value("INST", "COLLECT", "TYPE")).to eql 'NORMAL'
        expect(@api.get_cmd_value("INST", "COLLECT", "RECEIVED_TIMEFORMATTED")).to eql time.formatted
        expect(@api.get_cmd_value("INST", "COLLECT", "RECEIVED_TIMESECONDS")).to eql time.to_f
        expect(@api.get_cmd_value("INST", "COLLECT", "RECEIVED_COUNT")).to eql 5
      end

      it "returns special values for time if time isn't set" do
        packet = System.commands.packet("INST", "COLLECT")
        packet.received_time = nil
        packet.restore_defaults
        packet.received_count = 5
        expect(@api.get_cmd_value("INST", "COLLECT", "TYPE")).to eql 'NORMAL'
        expect(@api.get_cmd_value("INST", "COLLECT", "RECEIVED_TIMEFORMATTED")).to eql "No Packet Received Time"
        expect(@api.get_cmd_value("INST", "COLLECT", "RECEIVED_TIMESECONDS")).to eql 0.0
        expect(@api.get_cmd_value("INST", "COLLECT", "RECEIVED_COUNT")).to eql 5
      end
    end

    describe "get_cmd_time" do
      it "returns command times" do
        time = Time.now
        time2 = Time.now + 2
        collect_cmd = System.commands.packet("INST", "COLLECT")
        collect_cmd.received_time = time
        abort_cmd = System.commands.packet("INST", "ABORT")
        abort_cmd.received_time = time + 1
        packet2 = System.commands.packet("SYSTEM", "STARTLOGGING")
        packet2.received_time = time2
        expect(@api.get_cmd_time()).to eql ['SYSTEM', 'STARTLOGGING', time2.tv_sec, time2.tv_usec]
        expect(@api.get_cmd_time('INST')).to eql ['INST', 'ABORT', time.tv_sec + 1, time.tv_usec]
        expect(@api.get_cmd_time('SYSTEM')).to eql ['SYSTEM', 'STARTLOGGING', time2.tv_sec, time2.tv_usec]
        expect(@api.get_cmd_time('INST', 'COLLECT')).to eql ['INST', 'COLLECT', time.tv_sec, time.tv_usec]
        expect(@api.get_cmd_time('SYSTEM', 'STARTLOGGING')).to eql ['SYSTEM', 'STARTLOGGING', time2.tv_sec, time2.tv_usec]
      end

      it "returns nil if no times are set" do
        System.commands.packets("INST").each { |name, pkt| pkt.received_time = nil }
        expect(@api.get_cmd_time("INST")).to eql [nil, nil, nil, nil]
        expect(@api.get_cmd_time("INST", "ABORT")).to eql ["INST", "ABORT", nil, nil]
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
      it "complains about unknown targets, commands, and parameters" do
        test_tlm_unknown(:tlm)
      end

      it "processes a string" do
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql -100.0
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
        expect(@api.tlm_variable("INST HEALTH_STATUS TEMP1",:CONVERTED)).to eql -100.0
        expect(@api.tlm_variable("INST HEALTH_STATUS TEMP1",:RAW)).to eql 0
        expect(@api.tlm_variable("INST HEALTH_STATUS TEMP1",:FORMATTED)).to eql "-100.000"
        expect(@api.tlm_variable("INST HEALTH_STATUS TEMP1",:WITH_UNITS)).to eql "-100.000 C"
      end

      it "returns the value using LATEST" do
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

      it "sets SYSTEM META command as well as tlm" do
        cmd = System.commands.packet("SYSTEM", "META")
        tlm = System.telemetry.packet("SYSTEM", "META")
        @api.set_tlm("SYSTEM META RUBY_VERSION = 1.8.0")
        expect(cmd.read("RUBY_VERSION")).to eq("1.8.0")
        expect(tlm.read("RUBY_VERSION")).to eq("1.8.0")
      end

      it "processes a string" do
        @api.set_tlm("INST HEALTH_STATUS TEMP1 = 0.0")
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to be_within(0.00001).of(-0.05759)
      end

      it "processes parameters" do
        @api.set_tlm("INST","HEALTH_STATUS","TEMP1", 0.0)
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to be_within(0.00001).of(-0.05759)
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
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql -100.0
      end

      it "processes parameters" do
        @api.set_tlm_raw("INST","HEALTH_STATUS","TEMP1", 0.0)
        expect(@api.tlm("INST HEALTH_STATUS TEMP1")).to eql -100.0
      end
    end

    describe "inject_tlm" do
      it "complains about non-existant targets" do
        expect { @api.inject_tlm("BLAH","HEALTH_STATUS") }.to raise_error(RuntimeError, "Unknown target: BLAH")
      end

      it "complains about non-existant packets" do
        expect { @api.inject_tlm("INST","BLAH") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.inject_tlm("INST","HEALTH_STATUS",{BLAH: 0}) }.to raise_error(RuntimeError, "Packet item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "logs errors writing routers" do
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

      it "writes to routers and logs even if the packet has no interface" do
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

      it "complains if the target has no interface" do
        expect { @api.override_tlm("SYSTEM META PKTID = 1") }.to raise_error(/Target 'SYSTEM' has no interface/)
      end

      it "complains if the target doesn't have OVERRIDE protocol" do
        interface = OpenStruct.new
        interface.name = "SYSTEM_INT"
        System.targets["SYSTEM"].interface = interface # Set a dummy interface
        expect { @api.override_tlm("SYSTEM META PKTID = 1") }.to raise_error(/Interface SYSTEM_INT does not have override/)
        System.targets["SYSTEM"].interface = nil
      end

      it "complains with too many parameters" do
        expect { @api.override_tlm("INST","HEALTH_STATUS","TEMP1","TEMP2",0.0) }.to raise_error(/Invalid number of arguments/)
      end

      it "calls _override_tlm in the interface" do
        int = System.targets["INST"].interface
        expect(int).to receive("_override_tlm").with("INST","HEALTH_STATUS","TEMP1",100.0)
        @api.override_tlm("INST HEALTH_STATUS TEMP1 = 100.0")
        expect(int).to receive("_override_tlm").with("INST","HEALTH_STATUS","TEMP2",50.0)
        @api.override_tlm("INST","HEALTH_STATUS","TEMP2", 50.0)
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

      it "complains if the target has no interface" do
        expect { @api.override_tlm_raw("SYSTEM META PKTID = 1") }.to raise_error(/Target 'SYSTEM' has no interface/)
      end

      it "complains with too many parameters" do
        expect { @api.override_tlm_raw("INST","HEALTH_STATUS","TEMP1","TEMP2",0.0) }.to raise_error(/Invalid number of arguments/)
      end

      it "calls _override_tlm_raw in the interface" do
        int = System.targets["INST"].interface
        expect(int).to receive("_override_tlm_raw").with("INST","HEALTH_STATUS","TEMP1",100.0)
        @api.override_tlm_raw("INST HEALTH_STATUS TEMP1 = 100.0")
        expect(int).to receive("_override_tlm_raw").with("INST","HEALTH_STATUS","TEMP2",50.0)
        @api.override_tlm_raw("INST","HEALTH_STATUS","TEMP2", 50.0)
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

      it "complains if the target has no interface" do
        expect { @api.normalize_tlm("SYSTEM META PKTID") }.to raise_error(/Target 'SYSTEM' has no interface/)
      end

      it "complains with too many parameters" do
        expect { @api.normalize_tlm("INST","HEALTH_STATUS","TEMP1",0.0) }.to raise_error(/Invalid number of arguments/)
      end

      it "calls _normalize_tlm in the interface" do
        int = System.targets["INST"].interface
        expect(int).to receive("_normalize_tlm").with("INST","HEALTH_STATUS","TEMP1")
        @api.normalize_tlm("INST HEALTH_STATUS TEMP1")
        expect(int).to receive("_normalize_tlm").with("INST","HEALTH_STATUS","TEMP2")
        @api.normalize_tlm("INST","HEALTH_STATUS","TEMP2")
      end
    end

    describe "get_tlm_buffer" do
      it "returns a telemetry packet buffer" do
        @api.inject_tlm("INST","HEALTH_STATUS",{TIMESEC: 0xDEADBEEF})
        expect(@api.get_tlm_buffer("INST", "HEALTH_STATUS")[6..10].unpack("N")[0]).to eq 0xDEADBEEF
      end
    end

    describe "get_tlm_packet" do
      it "complains about non-existant targets" do
        expect { @api.get_tlm_packet("BLAH","HEALTH_STATUS") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_tlm_packet("INST","BLAH") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "complains using LATEST" do
        expect { @api.get_tlm_packet("INST","LATEST") }.to raise_error(RuntimeError, "Telemetry packet 'INST LATEST' does not exist")
      end

      it "complains about non-existant value_types" do
        expect { @api.get_tlm_packet("INST","HEALTH_STATUS",:MINE) }.to raise_error(ArgumentError, "Unknown value type on read: MINE")
      end

      it "reads all telemetry items with their limits states" do
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
      it "handles an empty request" do
        expect(@api.get_tlm_values([])).to eql [[], [], [], :DEFAULT]
      end

      it "complains about non-existant targets" do
        expect { @api.get_tlm_values([["BLAH","HEALTH_STATUS","TEMP1"]]) }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_tlm_values([["INST","BLAH","TEMP1"]]) }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.get_tlm_values([["INST","LATEST","BLAH"]]) }.to raise_error(RuntimeError, "Telemetry item 'INST LATEST BLAH' does not exist")
      end

      it "complains about non-existant value_types" do
        expect { @api.get_tlm_values([["INST","HEALTH_STATUS","TEMP1"]],:MINE) }.to raise_error(ArgumentError, "Unknown value type on read: MINE")
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
        expect(vals[2][0]).to eql [-80.0, -70.0, 60.0, 80.0, -20.0, 20.0]
        expect(vals[2][1]).to eql [-60.0, -55.0, 30.0, 35.0]
        expect(vals[2][2]).to eql [-25.0, -10.0, 50.0, 55.0]
        expect(vals[2][3]).to eql [-80.0, -70.0, 60.0, 80.0]
        expect(vals[3]).to eql :DEFAULT
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
        expect(vals[2][0]).to eql [-80.0, -70.0, 60.0, 80.0, -20.0, 20.0]
        expect(vals[2][1]).to eql [-60.0, -55.0, 30.0, 35.0]
        expect(vals[2][2]).to eql [-25.0, -10.0, 50.0, 55.0]
        expect(vals[2][3]).to eql [-80.0, -70.0, 60.0, 80.0]
        expect(vals[3]).to eql :DEFAULT
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
        expect(vals[2][0]).to eql [-80.0, -70.0, 60.0, 80.0, -20.0, 20.0]
        expect(vals[2][1]).to eql [-60.0, -55.0, 30.0, 35.0]
        expect(vals[2][2]).to eql [-25.0, -10.0, 50.0, 55.0]
        expect(vals[2][3]).to eql [-80.0, -70.0, 60.0, 80.0]
        expect(vals[3]).to eql :DEFAULT
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
        expect { @api.get_tlm_list("BLAH") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
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
        expect { @api.get_tlm_item_list("BLAH","HEALTH_STATUS") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_tlm_item_list("INST","BLAH") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "returns all the items for a target/packet" do
        items = @api.get_tlm_item_list("INST","HEALTH_STATUS")
        expect(items[0][0]).to eql "PACKET_TIMESECONDS"
        expect(items[1][0]).to eql "PACKET_TIMEFORMATTED"
        expect(items[2][0]).to eql "RECEIVED_TIMESECONDS"
        expect(items[3][0]).to eql "RECEIVED_TIMEFORMATTED"
        expect(items[4][0]).to eql "RECEIVED_COUNT"
        # Spot check a few more
        expect(items[24][0]).to eql "TEMP1"
        expect(items[24][1]).to be_nil
        expect(items[24][2]).to eql "Temperature #1"
        expect(items[30][0]).to eql "COLLECT_TYPE"
        expect(items[30][1]).to include("NORMAL"=>0, "SPECIAL"=>1)
        expect(items[30][2]).to eql "Most recent collect type"
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

    describe "get_out_of_limits" do
      it "returns all out of limits items" do
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
      it "returns the overall system limits state" do
        @api.inject_tlm("INST","HEALTH_STATUS",{TEMP1: 0, TEMP2: 0, TEMP3: 0, TEMP4: 0}, :RAW)
        expect(@api.get_overall_limits_state).to eq :RED
      end
    end

    describe "limits_enabled?" do
      it "complains about non-existant targets" do
        expect { @api.limits_enabled?("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.limits_enabled?("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.limits_enabled?("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Packet item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "returns whether limits are enable for an item" do
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
      end
    end

    describe "enable_limits" do
      it "complains about non-existant targets" do
        expect { @api.enable_limits("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.enable_limits("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.enable_limits("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Packet item 'INST HEALTH_STATUS BLAH' does not exist")
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
        expect { @api.disable_limits("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.disable_limits("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.disable_limits("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Packet item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "disables limits for an item" do
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
        @api.disable_limits("INST","HEALTH_STATUS","TEMP1")
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be false
        @api.enable_limits("INST","HEALTH_STATUS","TEMP1")
      end
    end

    describe "get_stale" do
      it "complains about non-existant targets" do
        expect { @api.get_stale(false,"BLAH") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "gets stale packets for the specified target" do
        # By calling check_limits we make HEALTH_STATUS not stale
        System.telemetry.packet("INST","HEALTH_STATUS").check_limits
        stale = @api.get_stale(false,"INST").sort
        inst_pkts = []
        System.telemetry.packets("INST").each do |name, pkt|
          next if name == "HEALTH_STATUS" # not stale
          inst_pkts << ["INST", name]
        end
        expect(stale).to eq inst_pkts.sort

        # Passing true only gets packets with limits items
        stale = @api.get_stale(true,"INST").sort
        expect(stale).to eq [["INST","PARAMS"]]
      end
    end

    describe "get_limits" do
      it "complains about non-existant targets" do
        expect { @api.get_limits("BLAH","HEALTH_STATUS","TEMP1") }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.get_limits("INST","BLAH","TEMP1") }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.get_limits("INST","HEALTH_STATUS","BLAH") }.to raise_error(RuntimeError, "Packet item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "gets limits for an item" do
        expect(@api.get_limits("INST","HEALTH_STATUS","TEMP1")).to eql([:DEFAULT, 1, true, -80.0, -70.0, 60.0, 80.0, -20.0, 20.0])
        expect(@api.get_limits("INST","HEALTH_STATUS","TEMP1",:TVAC)).to eql([:TVAC, 1, true, -80.0, -30.0, 30.0, 80.0, nil, nil])
      end
    end

    describe "set_limits" do
      it "complains about non-existant targets" do
        expect { @api.set_limits("BLAH","HEALTH_STATUS","TEMP1",0.0,10.0,20.0,30.0) }.to raise_error(RuntimeError, "Telemetry target 'BLAH' does not exist")
      end

      it "complains about non-existant packets" do
        expect { @api.set_limits("INST","BLAH","TEMP1",0.0,10.0,20.0,30.0) }.to raise_error(RuntimeError, "Telemetry packet 'INST BLAH' does not exist")
      end

      it "complains about non-existant items" do
        expect { @api.set_limits("INST","HEALTH_STATUS","BLAH",0.0,10.0,20.0,30.0) }.to raise_error(RuntimeError, "Packet item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "gets limits for an item" do
        expect(@api.set_limits("INST","HEALTH_STATUS","TEMP1",0.0,10.0,20.0,30.0)).to eql([:CUSTOM, 1, true, 0.0, 10.0, 20.0, 30.0, nil, nil])
        expect(@api.set_limits("INST","HEALTH_STATUS","TEMP1",0.0,10.0,20.0,30.0,12.0,15.0,:CUSTOM2,2,false)).to eql([:CUSTOM2, 2, false, 0.0, 10.0, 20.0, 30.0, 12.0, 15.0])
        expect(@api.set_limits("INST","HEALTH_STATUS","TEMP1",0.0,10.0,20.0,30.0,12.0,15.0,:CUSTOM,1,true)).to eql([:CUSTOM, 1, true, 0.0, 10.0, 20.0, 30.0, 12.0, 15.0])
      end
    end

    describe "get_limits_groups" do
      it "returns all the limits groups" do
        expect(@api.get_limits_groups).to eql %w(FIRST SECOND)
      end
    end

    describe "enable_limits_group" do
      it "complains about undefined limits groups" do
        expect { @api.enable_limits_group("MINE") }.to raise_error(RuntimeError, "LIMITS_GROUP MINE undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP MINE")
      end

      it "enables limits for all items in the group" do
        @api.disable_limits("INST","HEALTH_STATUS","TEMP1")
        @api.disable_limits("INST","HEALTH_STATUS","TEMP3")
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be false
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP3")).to be false
        @api.enable_limits_group("FIRST")
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP3")).to be true
      end
    end

    describe "disable_limits_group" do
      it "complains about undefined limits groups" do
        expect { @api.disable_limits_group("MINE") }.to raise_error(RuntimeError, "LIMITS_GROUP MINE undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP MINE")
      end

      it "disables limits for all items in the group" do
        @api.enable_limits("INST","HEALTH_STATUS","TEMP1")
        @api.enable_limits("INST","HEALTH_STATUS","TEMP3")
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be true
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP3")).to be true
        @api.disable_limits_group("FIRST")
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP1")).to be false
        expect(@api.limits_enabled?("INST","HEALTH_STATUS","TEMP3")).to be false
      end
    end

    describe "get_limits_sets, get_limits_set, set_limits_set" do
      it "gets and set the active limits set" do
        if @api.get_limits_sets.include?(:CUSTOM)
          expect(@api.get_limits_sets).to eql [:DEFAULT,:TVAC, :CUSTOM, :CUSTOM2]
        else
          expect(@api.get_limits_sets).to eql [:DEFAULT,:TVAC]
        end
        @api.set_limits_set("TVAC")
        expect(@api.get_limits_set).to eql "TVAC"
        @api.set_limits_set("DEFAULT")
        expect(@api.get_limits_set).to eql "DEFAULT"
      end
    end

    describe "get_target_list" do
      it "returns all target names" do
        expect(@api.get_target_list).to eql %w(INST SYSTEM)
      end
    end

    describe "subscribe_limits_events" do
      it "calls CmdTlmServer" do
        stub_const("Cosmos::CmdTlmServer::DEFAULT_LIMITS_EVENT_QUEUE_SIZE", 100)
        expect(CmdTlmServer).to receive(:subscribe_limits_events)
        @api.subscribe_limits_events
      end
    end

    describe "unsubscribe_limits_events" do
      it "calls CmdTlmServer" do
        expect(CmdTlmServer).to receive(:unsubscribe_limits_events)
        @api.unsubscribe_limits_events(0)
      end
    end

    describe "get_limits_event" do
      it "gets a limits event" do
        expect(CmdTlmServer).to receive(:get_limits_event)
        @api.get_limits_event(0)
      end
    end

    describe "subscribe_packet_data" do
      it "calls CmdTlmServer" do
        stub_const("Cosmos::CmdTlmServer::DEFAULT_PACKET_DATA_QUEUE_SIZE", 100)
        expect(CmdTlmServer).to receive(:subscribe_packet_data)
        @api.subscribe_packet_data([["TGT","PKT1"],["TGT","PKT2"]])
      end
    end

    describe "unsubscribe_packet_datas" do
      it "calls CmdTlmServer" do
        expect(CmdTlmServer).to receive(:unsubscribe_packet_data)
        @api.unsubscribe_packet_data(10)
      end
    end

    describe "get_packet_data" do
      it "calls CmdTlmServer" do
        expect(CmdTlmServer).to receive(:get_packet_data)
        @api.get_packet_data(10)
      end
    end

    describe "get_packet" do
      it "creates a packet out of the get_packet_data" do
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
      it "calls CmdTlmServer" do
        stub_const("Cosmos::CmdTlmServer::DEFAULT_SERVER_MESSAGES_QUEUE_SIZE", 100)
        expect(CmdTlmServer).to receive(:subscribe_server_messages)
        @api.subscribe_server_messages
      end
    end

    describe "unsubscribe_server_messages" do
      it "calls CmdTlmServer" do
        expect(CmdTlmServer).to receive(:unsubscribe_server_messages)
        @api.unsubscribe_server_messages(0)
      end
    end

    describe "get_server_message" do
      it "gets a server message" do
        expect(CmdTlmServer).to receive(:get_server_message)
        @api.get_server_message(0)
      end
    end

    describe "get_interface_targets" do
      it "returns the targets associated with an interface" do
        expect(@api.get_interface_targets("INST_INT")).to eql ["INST"]
      end
    end

    describe "get_background_tasks" do
      it "gets background task details" do
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
        expect(status[1]).to eql 7777
        expect(status[2]).to eql 0
        expect(status[3]).to eql 0
        expect(status[4]).to eql 0.0
        expect(status[5]).to be > 10
      end
    end

    describe "get_target_info" do
      it "complains about non-existant targets" do
        expect { @api.get_target_info("BLAH") }.to raise_error(RuntimeError, "Unknown target: BLAH")
      end

      it "gets target cmd tlm count" do
        cmd1, tlm1 = @api.get_target_info("INST")
        @api.cmd("INST ABORT")
        @api.inject_tlm("INST","HEALTH_STATUS")
        cmd2, tlm2 = @api.get_target_info("INST")
        expect(cmd2 - cmd1).to eq 1
        expect(tlm2 - tlm1).to eq 1
      end
    end

    describe "get_all_target_info" do
      it "gets target name, interface name, cmd & tlm count" do
        @api.cmd("INST ABORT")
        @api.inject_tlm("INST","HEALTH_STATUS")
        info = @api.get_all_target_info().sort
        expect(info[0][0]).to eq "INST"
        expect(info[0][1]).to eq "INST_INT"
        expect(info[0][2]).to be > 0
        expect(info[0][3]).to be > 0
        expect(info[1][0]).to eq "SYSTEM"
        expect(info[1][1]).to eq "" # No interface
      end
    end

    describe "get_interface_info" do
      it "complains about non-existant interfaces" do
        expect { @api.get_interface_info("BLAH") }.to raise_error(RuntimeError, "Unknown interface: BLAH")
      end

      it "gets interface info" do
        info = @api.get_interface_info("INST_INT")
        expect(info[0]).to eq "ATTEMPTING"
        expect(info[1..-1]).to eq [0,0,0,0,0,0,0]
      end
    end

    describe "get_all_interface_info" do
      it "gets interface name and all info" do
        info = @api.get_all_interface_info.sort
        expect(info[0][0]).to eq "INST_INT"
      end
    end

    describe "get_router_names" do
      it "returns all router names" do
        expect(@api.get_router_names.sort).to eq %w(PREIDENTIFIED_CMD_ROUTER PREIDENTIFIED_ROUTER ROUTE)
      end
    end

    describe "get_router_info" do
      it "complains about non-existant routers" do
        expect { @api.get_router_info("BLAH") }.to raise_error(RuntimeError, "Unknown router: BLAH")
      end

      it "gets router info" do
        info = @api.get_router_info("ROUTE")
        expect(info[0]).to eq "ATTEMPTING"
        expect(info[1..-1]).to eq [0,0,0,0,0,0,0]
      end
    end

    describe "get_all_router_info" do
      it "gets router name and all info" do
        info = @api.get_all_router_info.sort
        expect(info[0][0]).to eq "PREIDENTIFIED_CMD_ROUTER"
        expect(info[1][0]).to eq "PREIDENTIFIED_ROUTER"
        expect(info[2][0]).to eq "ROUTE"
      end
    end

    describe "get_cmd_cnt" do
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

      it "gets the telemetry packet count" do
        cnt1 = @api.get_tlm_cnt("INST", "ADCS")
        @api.inject_tlm("INST","ADCS")
        cnt2 = @api.get_tlm_cnt("INST", "ADCS")
        expect(cnt2 - cnt1).to eq 1
      end
    end

    describe "get_all_cmd_info" do
      it "gets tgt, pkt, rx cnt for all commands" do
        total = 1 # Unknown is 1
        System.commands.target_names.each do |tgt|
          total += System.commands.packets(tgt).keys.length
        end
        info = @api.get_all_cmd_info.sort
        expect(info.length).to eq total
        expect(info[0][0]).to eq "INST"
        expect(info[0][1]).to eq "ABORT"
        expect(info[0][2]).to be >= 0
        expect(info[-1][0]).to eq "UNKNOWN"
        expect(info[-1][1]).to eq "UNKNOWN"
        expect(info[-1][2]).to eq 0
      end
    end

    describe "get_all_tlm_info" do
      it "gets tgt, pkt, rx cnt for all telemetry" do
        total = 1 # Unknown is 1
        System.telemetry.target_names.each do |tgt|
          total += System.telemetry.packets(tgt).keys.length
        end
        info = @api.get_all_tlm_info.sort
        expect(info.length).to eq total
        expect(info[0][0]).to eq "INST"
        expect(info[0][1]).to eq "ADCS"
        expect(info[0][2]).to be >= 0
        expect(info[-1][0]).to eq "UNKNOWN"
        expect(info[-1][1]).to eq "UNKNOWN"
        expect(info[-1][2]).to eq 0
      end
    end

    describe "get_packet_logger_info" do
      it "complains about non-existant loggers" do
        expect { @api.get_packet_logger_info("BLAH") }.to raise_error(RuntimeError, "Unknown packet log writer: BLAH")
      end

      it "gets packet logger info" do
        info = @api.get_packet_logger_info("DEFAULT")
        expect(info[0]).to eq ["INST_INT"]
      end
    end

    describe "get_all_packet_logger_info" do
      it "gets all packet loggers info" do
        info = @api.get_all_packet_logger_info.sort
        expect(info[0][0]).to eq "DEFAULT"
        expect(info[0][1]).to eq ["INST_INT"]
      end
    end

    describe "background_task apis" do
      it "starts, gets into, and stops background tasks" do
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
    describe "CmdTlmServer pass-throughs" do
      it "calls through to the CmdTlmServer" do
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
