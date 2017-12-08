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
require 'cosmos/script/script'
require 'tempfile'

module Cosmos

  describe Script do

    before(:all) do
      cts = File.join(Cosmos::USERPATH,'config','tools','cmd_tlm_server','cmd_tlm_server.txt')
      FileUtils.mkdir_p(File.dirname(cts))
      File.open(cts,'w') do |file|
        file.puts 'INTERFACE INST_INT interface.rb'
        file.puts 'TARGET INST'
      end
      System.class_eval('@@instance = nil')

      require 'cosmos/script'
    end

    after(:all) do
      clean_config()
      FileUtils.rm_rf File.join(Cosmos::USERPATH,'config','tools')
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

    describe "require cosmos/script.rb" do
      it "should raise when inside CmdTlmServer" do
        save = $0
        $0 = "CmdTlmServer"
        expect { load 'cosmos/script.rb' }.to raise_error(/must not be required/)
        $0 = save
      end

      it "should raise when inside Replay" do
        save = $0
        $0 = "Replay"
        expect { load 'cosmos/script.rb' }.to raise_error(/must not be required/)
        $0 = save
      end
    end

    describe "cmd" do
      it "sends a command" do
        capture_io do |stdout|
          cmd("INST ABORT")
          expect(stdout.string).to match(/cmd\(\"INST ABORT\"\)/) #"
          stdout.rewind
          cmd("INST", "ABORT")
          expect(stdout.string).to match(/cmd\(\"INST ABORT\"\)/) #"
        end
      end

      it "checks parameter ranges" do
        expect { cmd("INST COLLECT with TYPE NORMAL, DURATION 20") }.to raise_error(/Command parameter 'INST COLLECT DURATION' = 20 not in valid range/)
      end

      it "prompts for a hazardous command" do
        capture_io do |stdout|
          expect(self).to receive(:gets) { 'y' } # Send hazardous command
          cmd("INST COLLECT with TYPE SPECIAL")

          expect(stdout.string).to match(/cmd\(\"INST COLLECT/) #"
          expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
          expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring range checks")
          expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring hazardous warnings")
          stdout.rewind

          expect(self).to receive(:gets) { 'n' } # Don't send hazardous
          expect(self).to receive(:gets) { 'y' } # Stop running script
          cmd("INST COLLECT with TYPE SPECIAL")
          expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
        end
      end
    end

    describe "cmd_no_range_check" do
      it "sends an out of range command" do
        expect { cmd_no_range_check("INST COLLECT with TYPE NORMAL, DURATION 20") }.to_not raise_error
      end

      it "prompts for a hazardous command" do
        capture_io do |stdout|
          expect(self).to receive(:gets) { 'y' } # Send hazardous command
          cmd_no_range_check("INST COLLECT with TYPE SPECIAL")

          expect(stdout.string).to match(/cmd\(\"INST COLLECT/) #"
          expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
          expect(stdout.string).to match("Command INST COLLECT being sent ignoring range checks")
          expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring hazardous warnings")
          stdout.rewind

          expect(self).to receive(:gets) { 'n' } # Don't send hazardous
          expect(self).to receive(:gets) { 'y' } # Stop running script
          cmd_no_range_check("INST COLLECT with TYPE SPECIAL")
          expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
        end
      end
    end

    describe "cmd_no_hazardous_check" do
      it "checks parameter ranges" do
        expect { cmd_no_hazardous_check("INST COLLECT with TYPE SPECIAL, DURATION 20") }.to raise_error(/Command parameter 'INST COLLECT DURATION' = 20 not in valid range/)
      end

      it "sends a hazardous command without prompting" do
        capture_io do |stdout|
          cmd_no_hazardous_check("INST COLLECT with TYPE SPECIAL")

          expect(stdout.string).to match(/cmd\(\"INST COLLECT/) #"
          expect(stdout.string).to_not match("Warning: Command INST COLLECT is Hazardous")
          expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring range checks")
          expect(stdout.string).to match("Command INST COLLECT being sent ignoring hazardous warnings")
        end
      end
    end

    describe "cmd_no_checks" do
      it "sends an out of range hazardous command without prompting" do
        capture_io do |stdout|
          cmd_no_checks("INST COLLECT with TYPE SPECIAL, DURATION 20")

          expect(stdout.string).to match(/cmd\(\"INST COLLECT/) #"
          expect(stdout.string).to_not match("Warning: Command INST COLLECT is Hazardous")
          expect(stdout.string).to match("Command INST COLLECT being sent ignoring range checks")
          expect(stdout.string).to match("Command INST COLLECT being sent ignoring hazardous warnings")
        end
      end
    end

    describe "cmd_raw" do
      it "sends a command" do
        capture_io do |stdout|
          cmd_raw("INST ABORT")
          expect(stdout.string).to match(/cmd_raw\(\"INST ABORT\"\)/) #"
        end
      end

      it "checks parameter ranges" do
        expect { cmd_raw("INST COLLECT with TYPE 0, DURATION 20") }.to raise_error(/Command parameter 'INST COLLECT DURATION' = 20 not in valid range/)
      end

      it "prompts for a hazardous command" do
        capture_io do |stdout|
          expect(self).to receive(:gets) { 'y' } # Send hazardous command
          cmd_raw("INST COLLECT with TYPE 1")

          expect(stdout.string).to match(/cmd_raw\(\"INST COLLECT/) #"
          expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
          expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring range checks")
          expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring hazardous warnings")
          stdout.rewind

          expect(self).to receive(:gets) { 'n' } # Don't send hazardous
          expect(self).to receive(:gets) { 'y' } # Stop running script
          cmd_raw("INST COLLECT with TYPE 1")
          expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
        end
      end
    end

    describe "cmd_raw_no_range_check" do
      it "sends an out of range command" do
        expect { cmd_raw_no_range_check("INST COLLECT with TYPE 0, DURATION 20") }.to_not raise_error
      end

      it "prompts for a hazardous command" do
        capture_io do |stdout|
          expect(self).to receive(:gets) { 'y' } # Send hazardous command
          cmd_raw_no_range_check("INST COLLECT with TYPE 1")

          expect(stdout.string).to match(/cmd_raw\(\"INST COLLECT/) #"
          expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
          expect(stdout.string).to match("Command INST COLLECT being sent ignoring range checks")
          expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring hazardous warnings")
          stdout.rewind

          expect(self).to receive(:gets) { 'n' } # Don't send hazardous
          expect(self).to receive(:gets) { 'y' } # Stop running script
          cmd_raw_no_range_check("INST COLLECT with TYPE 1")
          expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
        end
      end
    end

    describe "cmd_raw_no_hazardous_check" do
      it "checks parameter ranges" do
        expect { cmd_raw_no_hazardous_check("INST COLLECT with TYPE 1, DURATION 20") }.to raise_error(/Command parameter 'INST COLLECT DURATION' = 20 not in valid range/)
      end

      it "sends a hazardous command without prompting" do
        capture_io do |stdout|
          cmd_raw_no_hazardous_check("INST COLLECT with TYPE 1")
          expect(stdout.string).to match(/cmd_raw\(\"INST COLLECT/) #"
          expect(stdout.string).to_not match("Warning: Command INST COLLECT is Hazardous")
          expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring range checks")
          expect(stdout.string).to match("Command INST COLLECT being sent ignoring hazardous warnings")
        end
      end
    end

    describe "cmd_raw_no_checks" do
      it "sends an out of range hazardous command without prompting" do
        capture_io do |stdout|
          cmd_raw_no_checks("INST COLLECT with TYPE 1, DURATION 20")
          expect(stdout.string).to match(/cmd_raw\(\"INST COLLECT/) #"
          expect(stdout.string).to_not match("Warning: Command INST COLLECT is Hazardous")
          expect(stdout.string).to match("Command INST COLLECT being sent ignoring range checks")
          expect(stdout.string).to match("Command INST COLLECT being sent ignoring hazardous warnings")
        end
      end
    end

    describe "send_raw" do
      it "sends data to the write_raw interface method" do
        expect_any_instance_of(Interface).to receive(:write_raw).with('\x00')
        send_raw('INST_INT', '\x00')
      end
    end

    describe "send_raw_file" do
      it "sends file data to the write_raw interface method" do
        file = File.open('raw_test_file.bin','wb')
        file.write '\x00\x01\x02\x03'
        file.close

        expect_any_instance_of(Interface).to receive(:write_raw).with('\x00\x01\x02\x03')

        send_raw_file('INST_INT', 'raw_test_file.bin')

        File.delete('raw_test_file.bin')
      end
    end

    describe "get_cmd_list" do
      it "returns all the target commands" do
        list = get_cmd_list("INST")
        # Only check for the collect command to make this test list dependent
        # on the demo INST command definition file
        expect(list).to include(["COLLECT", "Starts a collect on the instrument"])
      end
    end

    describe "get_cmd_param_list" do
      it "returns all the parameters for a command" do
        list = get_cmd_param_list("INST", "COLLECT")
        expect(list).to include(["TYPE", 0, {"NORMAL"=>0, "SPECIAL"=>1}, "Collect type", nil, nil, true, "UINT"])
      end
    end

    describe "get_cmd_hazardous" do
      it "returns whether a command is hazardous" do
        expect(get_cmd_hazardous("INST", "COLLECT", {"TYPE"=>"NORMAL"})).to be false
        expect(get_cmd_hazardous("INST", "COLLECT", {"TYPE"=>"SPECIAL"})).to be true
      end
    end

    describe "get_cmd_value, get_cmd_time, get_cmd_buffer" do
      it "passes through to the cmd_tlm_server" do
        expect {
          get_cmd_value("INST", "COLLECT", "TYPE")
          get_cmd_value("INST", "COLLECT", "RECEIVED_TIMEFORMATTED")
          get_cmd_value("INST", "COLLECT", "RECEIVED_TIMESECONDS")
          get_cmd_value("INST", "COLLECT", "RECEIVED_COUNT")
          get_cmd_time("INST", "COLLECT")
          get_cmd_time("INST")
          get_cmd_time()
          get_cmd_buffer("INST", "COLLECT")
        }.to_not raise_error
      end
    end

  end
end

