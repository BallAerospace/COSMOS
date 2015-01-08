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

    describe "cmd" do
      it "should send a command" do
        capture_io do |stdout|
          cmd("INST ABORT")
          stdout.string.should match /cmd\(\'INST ABORT\'\)/ #'
        end
      end

      it "should check parameter ranges" do
        expect { cmd("INST COLLECT with TYPE NORMAL, DURATION 20") }.to raise_error(/Command parameter 'INST COLLECT DURATION' = 20 not in valid range/)
      end

      it "should prompt for a hazardous command" do
        capture_io do |stdout|
          expect(self).to receive(:gets) { 'y' } # Send hazardous command
          cmd("INST COLLECT with TYPE SPECIAL")

          stdout.string.should match "Warning: Command INST COLLECT is Hazardous"
          stdout.string.should match /cmd\(\'INST COLLECT/
          stdout.rewind

          expect(self).to receive(:gets) { 'n' } # Don't send hazardous
          expect(self).to receive(:gets) { 'n' } # Don't stop running script
          cmd("INST COLLECT with TYPE SPECIAL")
          stdout.string.should match "Warning: Command INST COLLECT is Hazardous"
          stdout.string.should match "WARN: Hazardous command not sent"
        end
      end
    end

    describe "cmd_no_range_check" do
      it "should send an out of range command" do
        expect { cmd_no_range_check("INST COLLECT with TYPE NORMAL, DURATION 20") }.to_not raise_error
      end

      it "should prompt for a hazardous command" do
        capture_io do |stdout|
          expect(self).to receive(:gets) { 'y' } # Send hazardous command
          cmd_no_range_check("INST COLLECT with TYPE SPECIAL")

          stdout.string.should match "Warning: Command INST COLLECT is Hazardous"
          stdout.string.should match /cmd\(\'INST COLLECT/
          stdout.rewind

          expect(self).to receive(:gets) { 'n' } # Don't send hazardous
          expect(self).to receive(:gets) { 'n' } # Don't stop running script
          cmd_no_range_check("INST COLLECT with TYPE SPECIAL")
          stdout.string.should match "Warning: Command INST COLLECT is Hazardous"
          stdout.string.should match "WARN: Hazardous command not sent"
        end
      end
    end

    describe "cmd_no_hazardous_check" do
      it "should check parameter ranges" do
        expect { cmd_no_hazardous_check("INST COLLECT with TYPE SPECIAL, DURATION 20") }.to raise_error(/Command parameter 'INST COLLECT DURATION' = 20 not in valid range/)
      end

      it "should send a hazardous command without prompting" do
        capture_io do |stdout|
          cmd_no_hazardous_check("INST COLLECT with TYPE SPECIAL")

          stdout.string.should match "Command INST COLLECT being sent ignoring hazardous warnings"
          stdout.string.should match /cmd\(\'INST COLLECT/
        end
      end
    end

    describe "cmd_no_checks" do
      it "should send an out of range hazardous command without prompting" do
        capture_io do |stdout|
          cmd_no_checks("INST COLLECT with TYPE SPECIAL, DURATION 20")

          stdout.string.should match "Command INST COLLECT being sent ignoring hazardous warnings"
          stdout.string.should match /cmd\(\'INST COLLECT/
        end
      end
    end

    describe "cmd_raw" do
      it "should send a command" do
        capture_io do |stdout|
          cmd_raw("INST ABORT")
          stdout.string.should match /cmd_raw\(\'INST ABORT\'\)/
        end
      end

      it "should check parameter ranges" do
        expect { cmd_raw("INST COLLECT with TYPE 0, DURATION 20") }.to raise_error(/Command parameter 'INST COLLECT DURATION' = 20 not in valid range/) #'
      end

      it "should prompt for a hazardous command" do
        capture_io do |stdout|
          expect(self).to receive(:gets) { 'y' } # Send hazardous command
          cmd_raw("INST COLLECT with TYPE 1")

          stdout.string.should match "Warning: Command INST COLLECT is Hazardous"
          stdout.string.should match /cmd_raw\(\'INST COLLECT/
          stdout.rewind

          expect(self).to receive(:gets) { 'n' } # Don't send hazardous
          expect(self).to receive(:gets) { 'n' } # Don't stop running script
          cmd_raw("INST COLLECT with TYPE 1")
          stdout.string.should match "Warning: Command INST COLLECT is Hazardous"
          stdout.string.should match "WARN: Hazardous command not sent"
        end
      end
    end

    describe "cmd_raw_no_range_check" do
      it "should send an out of range command" do
        expect { cmd_raw_no_range_check("INST COLLECT with TYPE 0, DURATION 20") }.to_not raise_error
      end

      it "should prompt for a hazardous command" do
        capture_io do |stdout|
          expect(self).to receive(:gets) { 'y' } # Send hazardous command
          cmd_raw_no_range_check("INST COLLECT with TYPE 1")

          stdout.string.should match "Warning: Command INST COLLECT is Hazardous"
          stdout.string.should match /cmd_raw\(\'INST COLLECT/
          stdout.rewind

          expect(self).to receive(:gets) { 'n' } # Don't send hazardous
          expect(self).to receive(:gets) { 'n' } # Don't stop running script
          cmd_raw_no_range_check("INST COLLECT with TYPE 1")
          stdout.string.should match "Warning: Command INST COLLECT is Hazardous"
          stdout.string.should match "WARN: Hazardous command not sent"
        end
      end
    end

    describe "cmd_raw_no_hazardous_check" do
      it "should check parameter ranges" do
        expect { cmd_raw_no_hazardous_check("INST COLLECT with TYPE 1, DURATION 20") }.to raise_error(/Command parameter 'INST COLLECT DURATION' = 20 not in valid range/)
      end

      it "should send a hazardous command without prompting" do
        capture_io do |stdout|
          cmd_raw_no_hazardous_check("INST COLLECT with TYPE 1")
          stdout.string.should match "Command INST COLLECT being sent ignoring hazardous warnings"
          stdout.string.should match /cmd_raw\(\'INST COLLECT/ #'
        end
      end
    end

    describe "cmd_raw_no_checks" do
      it "should send an out of range hazardous command without prompting" do
        capture_io do |stdout|
          cmd_raw_no_checks("INST COLLECT with TYPE 1, DURATION 20")
          stdout.string.should match "Command INST COLLECT being sent ignoring hazardous warnings"
          stdout.string.should match /cmd_raw\(\'INST COLLECT/ #'
        end
      end
    end

    describe "send_raw" do
      it "should send data to the write_raw interface method" do
        expect_any_instance_of(Interface).to receive(:write_raw).with('\x00')
        send_raw('INST_INT', '\x00')
      end
    end

    describe "send_raw_file" do
      it "should send file data to the write_raw interface method" do
        file = File.open('raw_test_file.bin','wb')
        file.write '\x00\x01\x02\x03'
        file.close

        expect_any_instance_of(Interface).to receive(:write_raw).with('\x00\x01\x02\x03')

        send_raw_file('INST_INT', 'raw_test_file.bin')

        File.delete('raw_test_file.bin')
      end
    end

    describe "get_cmd_list" do
      it "should return all the target commands" do
        list = get_cmd_list("INST")
        # Only check for the collect command to make this test list dependent
        # on the demo INST command definition file
        list.should include(["COLLECT", "Starts a collect on the instrument"])
      end
    end

    describe "get_cmd_param_list" do
      it "should return all the parameters for a command" do
        list = get_cmd_param_list("INST", "COLLECT")
        list.should include(["TYPE", 0, {"NORMAL"=>0, "SPECIAL"=>1}, "Collect type", nil, nil, true])
      end
    end

    describe "get_cmd_hazardous" do
      it "should return whether a command is hazardous" do
        get_cmd_hazardous("INST", "COLLECT", {"TYPE"=>"NORMAL"}).should be_falsey
        get_cmd_hazardous("INST", "COLLECT", {"TYPE"=>"SPECIAL"}).should be_truthy
      end
    end

    describe "tlm, tlm_raw, tlm_formatted, tlm_with_units, tlm_variable, set_tlm, set_tlm_raw" do
      it "should pass through to the cmd_tlm_server" do
        expect {
          tlm("INST HEALTH_STATUS TEMP1").should eql -100.0
          tlm_raw("INST HEALTH_STATUS TEMP1").should eql 0
          tlm_formatted("INST HEALTH_STATUS TEMP1").should eql "-100.000"
          tlm_with_units("INST HEALTH_STATUS TEMP1").should eql "-100.000 C"
          tlm_variable("INST HEALTH_STATUS TEMP1", :RAW).should eql 0
          set_tlm("INST HEALTH_STATUS TEMP1 = 1")
          set_tlm_raw("INST HEALTH_STATUS TEMP1 = 0")
        }.to_not raise_error
      end
    end

    describe "get_tlm_packet" do
      it "should get the packet values" do
        get_tlm_packet("INST", "HEALTH_STATUS", :RAW).should include(["TEMP1", 0, :RED_LOW])
      end
    end

    describe "get_tlm_values" do
      it "should get the given values" do
        vals = get_tlm_values([["INST", "HEALTH_STATUS", "TEMP1"], ["INST", "HEALTH_STATUS", "TEMP2"]])
        vals[0][0].should eql -100.0
        vals[1][0].should eql :RED_LOW
        vals[2][0].should eql [-80.0, -70.0, 60.0, 80.0, -20.0, 20.0]
        vals[3].should eql :DEFAULT
      end
    end

    describe "get_tlm_list" do
      it "should get packets for a given target" do
        get_tlm_list("INST").should include(["HEALTH_STATUS", "Health and status from the instrument"])
      end
    end

    describe "get_tlm_item_list" do
      it "should get telemetry for a given packet" do
        get_tlm_item_list("INST", "HEALTH_STATUS").should include(["TEMP1",nil,"Temperature #1"])
      end
    end

    describe "get_tlm_details" do
      it "should get telemetry for a given packet" do
        details = get_tlm_details([["INST", "HEALTH_STATUS", "TEMP1"], ["INST", "HEALTH_STATUS", "TEMP2"]])
        details[0]["name"].should eql "TEMP1"
        details[1]["name"].should eql "TEMP2"
      end
    end

    describe "get_out_of_limits" do
      it "should get all out of limits items" do
        get_out_of_limits.should include(["INST","HEALTH_STATUS","TEMP1",:RED_LOW])
      end
    end

    describe "limits_enabled?, disable_limits, enable_limits" do
      it "should enable, disable, and check limits for an item" do
        limits_enabled?("INST HEALTH_STATUS TEMP1").should be_truthy
        disable_limits("INST HEALTH_STATUS TEMP1")
        limits_enabled?("INST HEALTH_STATUS TEMP1").should be_falsey
        enable_limits("INST HEALTH_STATUS TEMP1")
        limits_enabled?("INST HEALTH_STATUS TEMP1").should be_truthy
      end
    end

    describe "get_limits, set_limits" do
      it "should get and set limits for an item" do
        get_limits("INST", "HEALTH_STATUS", "TEMP1").should eql [:DEFAULT, 1, true, -80.0, -70.0, 60.0, 80.0, -20.0, 20.0]
        set_limits("INST", "HEALTH_STATUS", "TEMP1", 1, 2, 5, 6, 3, 4).should eql [:CUSTOM, 1, true, 1.0, 2.0, 5.0, 6.0, 3.0, 4.0]
      end
    end

    describe "get_limits_groups, enable_limits_group, disable_limits_group" do
      it "should enable, disable, and get groups" do
        get_limits_groups.should include("FIRST")
        enable_limits_group("FIRST")
        disable_limits_group("FIRST")
      end
    end

    describe "get_limits_sets, enable_limits_set, disable_limits_set" do
      it "should enable, disable, and get sets CTS-16" do
        if get_limits_sets.include?(:CUSTOM)
          get_limits_sets.should eql [:DEFAULT,:TVAC,:CUSTOM]
        else
          get_limits_sets.should eql [:DEFAULT,:TVAC]
        end
        set_limits_set(:TVAC)
        get_limits_set.should eql :TVAC
        set_limits_set(:DEFAULT)
        get_limits_set.should eql :DEFAULT
      end
    end

    describe "get_target_list" do
      it "should return the list of targets" do
        get_target_list.should include("INST")
      end
    end

    describe "subscribe_limits_events, get_limits_event, unsubscribe_limits_events" do
      it "should raise an error if non_block and the queue is empty" do
        id = subscribe_limits_events
        expect { get_limits_event(id, true) }.to raise_error(ThreadError, "queue empty")
        unsubscribe_limits_events(id)
      end

      it "should subscribe and get limits change events" do
        id = subscribe_limits_events
        CmdTlmServer.instance.post_limits_event(:LIMITS_CHANGE, ['TGT','PKT','ITEM',:YELLOW,:RED])
        result = get_limits_event(id, true)
        result[0].should eql :LIMITS_CHANGE
        unsubscribe_limits_events(id)
      end

      it "should subscribe and get limits settings events" do
        id = subscribe_limits_events
        CmdTlmServer.instance.post_limits_event(:LIMITS_SETTINGS, ['TGT','PKT','ITEM',:DEFAULT])
        result = get_limits_event(id, true)
        result[0].should eql :LIMITS_SETTINGS
        unsubscribe_limits_events(id)
      end
    end

    describe "subscribe_packet_data, get_packet, unsubscribe_packet_data" do
      it "should raise an error if non_block and the queue is empty" do
        id = subscribe_packet_data([["INST","HEALTH_STATUS"]])
        expect { get_packet(id, true) }.to raise_error(ThreadError, "queue empty")
        unsubscribe_packet_data(id)
      end

      it "should subscribe and get limits events" do
        id = subscribe_packet_data([["INST","HEALTH_STATUS"]])
        CmdTlmServer.instance.post_packet(System.telemetry.packet("INST","HEALTH_STATUS"))
        packet = get_packet(id, true)
        packet.target_name.should eql "INST"
        packet.packet_name.should eql "HEALTH_STATUS"
        unsubscribe_packet_data(id)
      end
    end

    describe "status_bar" do
      it "should set the ScriptRunner status bar" do
        class ScriptRunner; end
        sc = ScriptRunner.new
        expect(sc).to receive(:script_set_status).with("HI")
        status_bar("HI")
      end
    end

    describe "ask_string, ask" do
      it "should get user input" do
        $stdout = StringIO.new
        expect(self).to receive(:gets) { '10' }
        ask_string("").should eql '10'
        expect(self).to receive(:gets) { '10' }
        ask("").should eql 10
        $stdout = STDOUT
      end
    end

    describe "prompt, prompt_message_box" do
      it "should prompt the user for input" do
        $stdout = StringIO.new
        expect(self).to receive(:gets) { 'message' }
        prompt("").should eql 'message'
        expect(self).to receive(:gets) { 'b1' }
        message_box("",["b1","b2"]).should eql 'b1'
        $stdout = STDOUT
      end
    end

    describe "check, check_formatted, check_with_units, check_raw" do
      it "should check a telemetry item vs a condition" do
        capture_io do |stdout|
          check("INST HEALTH_STATUS TEMP1 == -100")
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 == -100 success"
          stdout.rewind

          check("INST","HEALTH_STATUS","TEMP1","== -100")
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 == -100 success"
          stdout.rewind

          check_formatted("INST HEALTH_STATUS TEMP1 == '-100.000'")
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 == '-100.000' success"
          stdout.rewind

          check_formatted("INST","HEALTH_STATUS","TEMP1","== '-100.000'")
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 == '-100.000' success"
          stdout.rewind

          check_with_units("INST HEALTH_STATUS TEMP1 == '-100.000 C'")
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 == '-100.000 C' success"
          stdout.rewind

          check_with_units("INST","HEALTH_STATUS","TEMP1","== '-100.000 C'")
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 == '-100.000 C' success"
          stdout.rewind

          check_raw("INST HEALTH_STATUS TEMP1")
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 == 0"
        end

        check("INST HEALTH_STATUS TEMP1 < 0")
        expect { check("INST HEALTH_STATUS TEMP1 > 0") }.to raise_error(Cosmos::CheckError)
      end
    end

    describe "check_tolerance, check_tolerance_raw" do
      it "should check a telemetry item vs tolerance" do
        capture_io do |stdout|
          check_tolerance("INST HEALTH_STATUS TEMP1", -100.0, 1)
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 was within range"
          stdout.rewind

          expect { check_tolerance("INST HEALTH_STATUS TEMP1", -200.0, 1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 failed to be within range/)
          stdout.rewind

          check_tolerance_raw("INST HEALTH_STATUS TEMP1", 0, 1)
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 was within range"
          stdout.rewind

          expect { check_tolerance_raw("INST HEALTH_STATUS TEMP1", 100, 1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 failed to be within range/)
          stdout.rewind
        end
      end
    end

    describe "check_expression" do
      it "should check an arbitrary expression" do
        capture_io do |stdout|
          check_expression("true == true")
          stdout.string.should match "CHECK: true == true is TRUE"
      end

        expect { check_expression("true == false") }.to raise_error(CheckError, "CHECK: true == false is FALSE")
      end
    end

    describe "wait, wait_raw, wait_tolerance, wait_tolerance_raw" do
      it "should wait for telemetry check to be true" do
        capture_io do |stdout|
          # Success
          wait("INST HEALTH_STATUS TEMP1 == -100.0", 5)
          stdout.string.should match "WAIT: INST HEALTH_STATUS TEMP1 == -100.0"
          stdout.rewind
          wait_raw("INST HEALTH_STATUS TEMP1 == 0", 5)
          stdout.string.should match "WAIT: INST HEALTH_STATUS TEMP1 == 0"
          stdout.rewind
          wait_tolerance("INST HEALTH_STATUS TEMP1", -100.0, 1, 5)
          stdout.string.should match "WAIT: INST HEALTH_STATUS TEMP1 was within"
          stdout.rewind
          wait_tolerance_raw("INST HEALTH_STATUS TEMP1", 0, 1, 5)
          stdout.string.should match "WAIT: INST HEALTH_STATUS TEMP1 was within"
          stdout.rewind

          # Failure
          wait("INST HEALTH_STATUS TEMP1 == -200.0", 0.1)
          stdout.string.should match "WAIT: INST HEALTH_STATUS TEMP1 == -200.0 failed"
          stdout.rewind
          wait_raw("INST HEALTH_STATUS TEMP1 == 100", 0.1)
          stdout.string.should match "WAIT: INST HEALTH_STATUS TEMP1 == 100 failed"
          stdout.rewind
          wait_tolerance("INST HEALTH_STATUS TEMP1", -200.0, 1, 0.1)
          stdout.string.should match "WAIT: INST HEALTH_STATUS TEMP1 failed to be within"
          stdout.rewind
          wait_tolerance_raw("INST HEALTH_STATUS TEMP1", 100, 1, 0.1)
          stdout.string.should match "WAIT: INST HEALTH_STATUS TEMP1 failed to be within"
          stdout.rewind
        end
      end
    end

    describe "wait_expression" do
      it "should wait for an expression to be true" do
        capture_io do |stdout|
          # Success
          wait_expression("true == true", 5)
          stdout.string.should match "WAIT: true == true is TRUE"
          stdout.rewind

          # Failure
          wait_expression("true == false", 0.1)
          stdout.string.should match "WAIT: true == false is FALSE"
          stdout.rewind
        end
      end
    end

    describe "wait_check, wait_check_raw, wait_check_tolerance, wait_check_tolerance_raw" do
      it "should wait for telemetry check to be true" do
        capture_io do |stdout|
          # Success
          wait_check("INST HEALTH_STATUS TEMP1 == -100.0", 5)
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 == -100.0"
          stdout.rewind
          wait_check_raw("INST HEALTH_STATUS TEMP1 == 0", 5)
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 == 0"
          stdout.rewind
          wait_check_tolerance("INST HEALTH_STATUS TEMP1", -100.0, 1, 5)
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 was within"
          stdout.rewind
          wait_check_tolerance_raw("INST HEALTH_STATUS TEMP1", 0, 1, 5)
          stdout.string.should match "CHECK: INST HEALTH_STATUS TEMP1 was within"
          stdout.rewind
        end

        # Failure
        expect { wait_check("INST HEALTH_STATUS TEMP1 == -200.0", 0.1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 == -200.0 failed/)
        expect { wait_check_raw("INST HEALTH_STATUS TEMP1 == 100", 0.1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 == 100 failed/)
        expect { wait_check_tolerance("INST HEALTH_STATUS TEMP1", -200.0, 1, 0.1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 failed to be within/)

        expect { wait_check_tolerance_raw("INST HEALTH_STATUS TEMP1", 100, 1, 0.1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 failed to be within/)

      end
    end

    describe "wait_check_expression" do
      it "should wait for an expression to be true" do
        capture_io do |stdout|
          # Success
          wait_check_expression("true == true", 5)
          stdout.string.should match "CHECK: true == true is TRUE"
          stdout.rewind
        end

        # Failure
        expect { wait_check_expression("true == false", 0.1) }.to raise_error(CheckError, /CHECK: true == false is FALSE/)
      end
    end

    describe "wait_packet, wait_check_packet" do
      it "should wait for a certain number of packets" do
        capture_io do |stdout|
          wait_packet("INST","HEALTH_STATUS",1,0.1)
        end

        expect { wait_check_packet("INST","HEALTH_STATUS",1,0.1) }.to raise_error(CheckError, /INST HEALTH_STATUS expected to be received 1 times but only received 0 times/)
      end
    end

    describe "get_interface_names" do
      it "should return all interfaces" do
        get_interface_names.should include("INST_INT")
      end
    end

    describe "connect_interface, disconnect_interface, interface_state" do
      it "should connect, disconnect and return the state of the interface CTS-3" do
        connect_interface("INST_INT")
        interface_state("INST_INT").should eql "CONNECTED"
        disconnect_interface("INST_INT")
      end
    end

    describe "map_target_to_interface" do
      it "should map a target name to an interface" do
        map_target_to_interface("INST","INST_INT")
      end
    end

    describe "connect_router, disconnect_router, get_router_names, router_state" do
      it "should return connect, disconnect, and list the routers CTS-11" do
        get_router_names.should include("PREIDENTIFIED_ROUTER")
        connect_router("PREIDENTIFIED_ROUTER")
        router_state("PREIDENTIFIED_ROUTER").should eql "CONNECTED"
        disconnect_router("PREIDENTIFIED_ROUTER")
      end
    end

    describe "logging methods" do
      it "should start and stop logging and get filenames CTS-14" do
        start_logging
        stop_logging
        get_cmd_log_filename
        get_tlm_log_filename
        start_cmd_log
        start_tlm_log
        get_cmd_log_filename
        get_tlm_log_filename
        stop_cmd_log
        stop_tlm_log
        get_cmd_log_filename
        get_tlm_log_filename
        start_raw_logging_interface
        start_raw_logging_router
        stop_raw_logging_interface
        stop_raw_logging_router

        start_new_server_message_log
        sleep 0.1
        filename = get_server_message_log_filename
        filename.should match /server_messages.txt/
      end
    end

  end
end

