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
require 'cosmos/script'
require 'tempfile'

module Cosmos
  describe Script do
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

    describe "play_wav_file" do
      it "plays a wav file if Qt is available" do
        module Qt
          def self.execute_in_main_thread(bool = true); yield; end
          class CoreApplication; def self.instance; true; end; end;
          class Sound; def self.isAvailable; true; end; end
        end
        expect(Qt::Sound).to receive(:play).with("sound.wav")
        play_wav_file("sound.wav")
      end
    end

    if RUBY_ENGINE == 'ruby'
      describe "status_bar" do
        it "sets the ScriptRunner status bar" do
          class ScriptRunner; end
          sc = ScriptRunner.new
          expect(sc).to receive(:script_set_status).with("HI")
          status_bar("HI")
        end
      end
    end

    describe "save_file_dialog, open_file_dialog, open_files_dialog, open_directory_dialog" do
      it "gets file listings" do
        capture_io do |stdout|
          expect(self).to receive(:gets) { 'file' }
          expect(save_file_dialog()).to eql 'file'
          expect(stdout.string).to include "Save File"
          stdout.rewind
          expect(self).to receive(:gets) { 'file' }
          expect(save_file_dialog(Dir.pwd, "Save Something!!!", "*.txt")).to eql 'file'
          expect(stdout.string).to include "Save Something!!!"
          stdout.rewind
          expect(self).to receive(:gets) { 'file' }
          expect(open_file_dialog()).to eql 'file'
          expect(stdout.string).to include "Open File"
          stdout.rewind
          expect(self).to receive(:gets) { 'file' }
          expect(open_file_dialog(Dir.pwd, "Test Open", "*.txt")).to eql 'file'
          expect(stdout.string).to include "Test Open"
          stdout.rewind
          expect(self).to receive(:gets) { 'file' }
          expect(open_files_dialog()).to eql 'file'
          expect(stdout.string).to include "Open File(s)"
          stdout.rewind
          expect(self).to receive(:gets) { 'file' }
          expect(open_files_dialog(Dir.pwd, "Test Open Files")).to eql 'file'
          expect(stdout.string).to include "Test Open Files"
          stdout.rewind
          expect(self).to receive(:gets) { 'dir' }
          expect(open_directory_dialog()).to eql 'dir'
          expect(stdout.string).to include "Open Directory"
          stdout.rewind
          expect(self).to receive(:gets) { 'dir' }
          expect(open_directory_dialog(Dir.pwd, "Test Dir")).to eql 'dir'
          expect(stdout.string).to include "Test Dir"
          stdout.rewind
        end
      end
    end

    describe "ask_string, ask" do
      it "gets user input" do
        $stdout = StringIO.new
        expect(self).to receive(:gets) { '10' }
        expect(ask_string("Question", 5)).to eql '10'
        expect(self).to receive(:gets) { '10' }
        expect(ask("")).to eql 10
        $stdout = STDOUT
      end
    end

    describe "prompt, message_box, vertical_message_box, combo_box" do
      it "prompts the user for input" do
        $stdout = StringIO.new
        expect(self).to receive(:gets) { 'message' }
        expect(prompt("")).to eql 'message'
        expect(self).to receive(:gets) { 'b1' }
        expect(message_box("",["b1","b2"])).to eql 'b1'
        expect(self).to receive(:gets) { 'b1' }
        expect(vertical_message_box("",["b1","b2"])).to eql 'b1'
        expect(self).to receive(:gets) { 'b1' }
        expect(combo_box("",["b1","b2"])).to eql 'b1'
        $stdout = STDOUT
      end
    end

    describe "check, check_formatted, check_with_units, check_raw" do
      it "checks the number of parameters" do
        expect { check("INST HEALTH_STATUS TEMP1", -100.0) }.to raise_error(/Invalid number of arguments/)
        expect { check("INST", "HEALTH_STATUS", "TEMP1") }.to raise_error(/Invalid number of arguments/)
      end

      it "checks a telemetry item vs a condition" do
        capture_io do |stdout|
          check("INST HEALTH_STATUS TEMP1 == -100")
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 == -100 success")
          stdout.rewind

          check("INST","HEALTH_STATUS","TEMP1","== -100")
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 == -100 success")
          stdout.rewind

          check_formatted("INST HEALTH_STATUS TEMP1 == '-100.000'")
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 == '-100.000' success")
          stdout.rewind

          check_formatted("INST","HEALTH_STATUS","TEMP1","== '-100.000'")
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 == '-100.000' success")
          stdout.rewind

          check_with_units("INST HEALTH_STATUS TEMP1 == '-100.000 C'")
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 == '-100.000 C' success")
          stdout.rewind

          check_with_units("INST","HEALTH_STATUS","TEMP1","== '-100.000 C'")
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 == '-100.000 C' success")
          stdout.rewind

          check_raw("INST HEALTH_STATUS TEMP1")
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 == 0")
        end

        check("INST HEALTH_STATUS TEMP1 < 0")
        expect { check("INST HEALTH_STATUS TEMP1 > 0") }.to raise_error(Cosmos::CheckError)
      end
    end

    describe "check_tolerance, check_tolerance_raw" do
      it "checks the number of parameters" do
        expect { check_tolerance("INST HEALTH_STATUS TEMP1", -100.0) }.to raise_error(/Invalid number of arguments/)
        expect { check_tolerance("INST", "HEALTH_STATUS", "TEMP1", -100.0, 1, 0) }.to raise_error(/Invalid number of arguments/)
      end

      it "checks a telemetry item vs tolerance" do
        capture_io do |stdout|
          check_tolerance("INST HEALTH_STATUS TEMP1", -100.0, 1)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 was within range")
          stdout.rewind

          check_tolerance("INST", "HEALTH_STATUS", "TEMP1", -100.0, 1)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 was within range")
          stdout.rewind

          expect { check_tolerance("INST HEALTH_STATUS TEMP1", -200.0, 1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 failed to be within range/)
          stdout.rewind

          check_tolerance_raw("INST HEALTH_STATUS TEMP1", 0, 1)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 was within range")
          stdout.rewind

          expect { check_tolerance_raw("INST HEALTH_STATUS TEMP1", 100, 1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 failed to be within range/)
          stdout.rewind
        end
      end

      it "handles a negative tolerance" do
        capture_io do |stdout|
          check_tolerance("INST HEALTH_STATUS TEMP1", -100.0, -1)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 was within range")
          stdout.rewind

          check_tolerance("INST", "HEALTH_STATUS", "TEMP1", -100.0, -1)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 was within range")
          stdout.rewind

          expect { check_tolerance("INST HEALTH_STATUS TEMP1", -200.0, -1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 failed to be within range/)
          stdout.rewind

          check_tolerance_raw("INST HEALTH_STATUS TEMP1", 0, -1)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 was within range")
          stdout.rewind

          expect { check_tolerance_raw("INST HEALTH_STATUS TEMP1", 100, -1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 failed to be within range/)
          stdout.rewind
        end
      end

      it "handles array items" do
        capture_io do |stdout|
          check_tolerance("INST HEALTH_STATUS ARY2", 0.0, 0.1)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[0\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[1\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[2\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[3\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[4\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[5\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[6\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[7\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[8\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[9\] was within range/)
          stdout.rewind

          check_tolerance("INST", "HEALTH_STATUS", "ARY2", 0.0, 0.1)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[0\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[1\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[2\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[3\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[4\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[5\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[6\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[7\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[8\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[9\] was within range/)
          stdout.rewind

          exp_array = Array.new(10, 0.0)
          tol_array = Array.new(10, 0.1)
          check_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[0\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[1\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[2\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[3\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[4\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[5\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[6\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[7\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[8\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[9\] was within range/)
          stdout.rewind

          exp_array = Array.new(10, 0.0)
          tol_array = Array.new(10, 0.1)
          check_tolerance_raw("INST HEALTH_STATUS ARY2", exp_array, tol_array)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[0\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[1\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[2\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[3\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[4\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[5\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[6\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[7\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[8\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[9\] was within range/)
          stdout.rewind

          exp_array[0] = 0.11
          expect { check_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS ARY2\[0\] failed to be within range/)
          stdout.rewind

          exp_array[0] = 0.0
          exp_array[9] = 0.11
          expect { check_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS ARY2\[9\] failed to be within range/)
          stdout.rewind

          exp_array = Array.new(10, 1)
          tol_array = Array.new(10, 1.1)
          tol_array[1] = 0.9
          expect { check_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS ARY2\[1\] failed to be within range/)
          stdout.rewind

        end
      end

      it "checks size of array parameters" do
        bad_array = Array.new(9, 0)
        expect { check_tolerance("INST HEALTH_STATUS ARY2", bad_array, 0.1) }.to raise_error(/Invalid array size for expected_value/)
        expect { check_tolerance("INST HEALTH_STATUS ARY2", 0.0, bad_array) }.to raise_error(/Invalid array size for tolerance/)
      end
    end

    describe "check_expression" do
      it "checks an arbitrary expression" do
        capture_io do |stdout|
          check_expression("true == true")
          expect(stdout.string).to match("CHECK: true == true is TRUE")
      end

        expect { check_expression("true == false") }.to raise_error(CheckError, "CHECK: true == false is FALSE")
      end
    end

    describe "wait, wait_raw" do
      it "checks the number of parameters" do
        expect { wait("INST", "HEALTH_STATUS", "TEMP1", -100.0) }.to raise_error(/Invalid number of arguments/)
        expect { wait("INST", "HEALTH_STATUS", "TEMP1", -100.0, 1, 5, nil) }.to raise_error(/Invalid number of arguments/)
      end

      it "waits for an infinite time" do
        expect(self).to receive(:gets) { "\n" }
        capture_io do |stdout|
          wait()
          expect(stdout.string).to match("WAIT: Indefinite for actual time")
        end
      end

      it "waits for a specified number of seconds" do
        capture_io do |stdout|
          wait(0.1)
          expect(stdout.string).to match("WAIT: 0.1 seconds with actual time")
        end
      end

      it "handles a bad wait parameter" do
        expect { wait("1") }.to raise_error(/Non-numeric wait time/)
      end

      it "waits for telemetry check to be true" do
        capture_io do |stdout|
          # Success
          wait("INST HEALTH_STATUS TEMP1 == -100.0", 5)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 == -100.0")
          stdout.rewind
          wait("INST HEALTH_STATUS TEMP1 == -100.0", 5, 0.1) # polling rate
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 == -100.0")
          stdout.rewind
          wait("INST","HEALTH_STATUS","TEMP1","== -100.0", 5)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 == -100.0")
          stdout.rewind
          wait("INST","HEALTH_STATUS","TEMP1","== -100.0", 5, 0.1)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 == -100.0")
          stdout.rewind
          wait_raw("INST HEALTH_STATUS TEMP1 == 0", 5)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 == 0")
          stdout.rewind
          wait_tolerance("INST HEALTH_STATUS TEMP1", -100.0, 1, 5)

          # Failure
          wait("INST HEALTH_STATUS TEMP1 == -200.0", 0.1)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 == -200.0 failed")
          stdout.rewind
          wait_raw("INST HEALTH_STATUS TEMP1 == 100", 0.1)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 == 100 failed")
          stdout.rewind
        end
      end
    end

    describe "wait_tolerance, wait_tolerance_raw" do
      it "checks the number of parameters" do
        expect { wait_tolerance("INST", "HEALTH_STATUS", "TEMP1", -100.0, 1, 5, 0.1, nil) }.to raise_error(/Invalid number of arguments/)
      end

      it "waits for telemetry check to be true" do
        capture_io do |stdout|
          # Success
          wait_tolerance("INST HEALTH_STATUS TEMP1", -100.0, 1, 5)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 was within")
          stdout.rewind
          wait_tolerance("INST HEALTH_STATUS TEMP1", -100.0, 1, 5, 0.1)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 was within")
          stdout.rewind
          wait_tolerance("INST","HEALTH_STATUS","TEMP1", -100.0, 1, 5)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 was within")
          stdout.rewind
          wait_tolerance("INST","HEALTH_STATUS","TEMP1", -100.0, 1, 5, 0.1)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 was within")
          stdout.rewind
          wait_tolerance_raw("INST HEALTH_STATUS TEMP1", 0, 1, 5)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 was within")
          stdout.rewind

          # Failure
          wait_tolerance("INST HEALTH_STATUS TEMP1", -200.0, 1, 0.1)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 failed to be within")
          stdout.rewind
          wait_tolerance_raw("INST HEALTH_STATUS TEMP1", 100, 1, 0.1)
          expect(stdout.string).to match("WAIT: INST HEALTH_STATUS TEMP1 failed to be within")
          stdout.rewind
        end
      end

      it "handles array items" do
        capture_io do |stdout|
          wait_tolerance("INST HEALTH_STATUS ARY2", 0.0, 0.1, 0.1)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[0\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[1\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[2\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[3\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[4\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[5\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[6\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[7\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[8\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[9\] was within range/)
          stdout.rewind

          wait_tolerance("INST", "HEALTH_STATUS", "ARY2", 0.0, 0.1, 0.1)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[0\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[1\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[2\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[3\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[4\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[5\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[6\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[7\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[8\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[9\] was within range/)
          stdout.rewind

          exp_array = Array.new(10, 0.0)
          tol_array = Array.new(10, 0.1)
          wait_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array, 0.1)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[0\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[1\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[2\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[3\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[4\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[5\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[6\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[7\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[8\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[9\] was within range/)
          stdout.rewind

          exp_array = Array.new(10, 0.0)
          tol_array = Array.new(10, 0.1)
          wait_tolerance_raw("INST HEALTH_STATUS ARY2", exp_array, tol_array, 0.1)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[0\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[1\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[2\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[3\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[4\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[5\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[6\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[7\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[8\] was within range/)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[9\] was within range/)
          stdout.rewind

          exp_array[0] = 0.11
          wait_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array, 0.1)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[0\] failed to be within range/)
          stdout.rewind

          exp_array[0] = 0.0
          exp_array[9] = 0.11
          wait_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array, 0.1)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[9\] failed to be within range/)
          stdout.rewind

          exp_array = Array.new(10, 1)
          tol_array = Array.new(10, 1.1)
          tol_array[1] = 0.9
          wait_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array, 0.1)
          expect(stdout.string).to match(/WAIT: INST HEALTH_STATUS ARY2\[1\] failed to be within range/)
          stdout.rewind
        end
      end

      it "checks size of array parameters" do
        bad_array = Array.new(9, 0)
        expect { wait_tolerance("INST HEALTH_STATUS ARY2", bad_array, 0.1, 0.1) }.to raise_error(/Invalid array size for expected_value/)
        expect { wait_tolerance("INST HEALTH_STATUS ARY2", 0.0, bad_array, 0.1) }.to raise_error(/Invalid array size for tolerance/)
      end
    end

    describe "wait_expression" do
      it "waits for an expression to be true" do
        capture_io do |stdout|
          # Success
          wait_expression("true == true", 5)
          expect(stdout.string).to match("WAIT: true == true is TRUE")
          stdout.rewind

          # Failure
          wait_expression("true == false", 0.1)
          expect(stdout.string).to match("WAIT: true == false is FALSE")
          stdout.rewind
        end
      end
    end

    describe "wait_check, wait_check_raw" do
      it "checks the number of parameters" do
        expect { wait_check("INST HEALTH_STATUS TEMP1 == -100.0") }.to raise_error(/Invalid number of arguments/)
        expect { wait_check("INST", "HEALTH_STATUS", "TEMP1", -100.0) }.to raise_error(/Invalid number of arguments/)
        expect { wait_check("INST", "HEALTH_STATUS", "TEMP1", -100.0, 5, 0.1, nil) }.to raise_error(/Invalid number of arguments/)
      end

      it "waits for telemetry check to be true" do
        capture_io do |stdout|
          # Success
          wait_check("INST HEALTH_STATUS TEMP1 == -100.0", 5)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 == -100.0")
          stdout.rewind
          wait_check("INST HEALTH_STATUS TEMP1 == -100.0", 5, 0.1)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 == -100.0")
          stdout.rewind
          wait_check("INST","HEALTH_STATUS","TEMP1", "== -100.0", 5)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 == -100.0")
          stdout.rewind
          wait_check("INST","HEALTH_STATUS","TEMP1", "== -100.0", 5, 0.1)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 == -100.0")
          stdout.rewind
          wait_check_raw("INST HEALTH_STATUS TEMP1 == 0", 5)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 == 0")
          stdout.rewind
        end

        # Failure
        expect { wait_check("INST HEALTH_STATUS TEMP1 == -200.0", 0.1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 == -200.0 failed/)
        expect { wait_check_raw("INST HEALTH_STATUS TEMP1 == 100", 0.1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 == 100 failed/)
      end
    end

    describe "wait_check_tolerance, wait_check_tolerance_raw" do
      it "checks the number of parameters" do
        expect { wait_check_tolerance("INST", "HEALTH_STATUS", "TEMP1", -100.0, 1, 5, 0.1, nil) }.to raise_error(/Invalid number of arguments/)
      end

      it "waits for telemetry check to be true" do
        capture_io do |stdout|
          # Success
          wait_check_tolerance("INST HEALTH_STATUS TEMP1", -100.0, 1, 5)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 was within")
          stdout.rewind
          wait_check_tolerance("INST","HEALTH_STATUS","TEMP1", -100.0, 1, 5)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 was within")
          stdout.rewind
          wait_check_tolerance("INST","HEALTH_STATUS","TEMP1", -100.0, 1, 5, 0.1)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 was within")
          stdout.rewind
          wait_check_tolerance_raw("INST HEALTH_STATUS TEMP1", 0, 1, 5)
          expect(stdout.string).to match("CHECK: INST HEALTH_STATUS TEMP1 was within")
          stdout.rewind
        end

        # Failure
        expect { wait_check_tolerance("INST HEALTH_STATUS TEMP1", -200.0, 1, 0.1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 failed to be within/)

        expect { wait_check_tolerance_raw("INST HEALTH_STATUS TEMP1", 100, 1, 0.1) }.to raise_error(CheckError, /CHECK: INST HEALTH_STATUS TEMP1 failed to be within/)

      end

      it "handles array items" do
        capture_io do |stdout|
          wait_check_tolerance("INST HEALTH_STATUS ARY2", 0.0, 0.1, 0.1)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[0\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[1\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[2\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[3\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[4\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[5\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[6\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[7\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[8\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[9\] was within range/)
          stdout.rewind

          wait_check_tolerance("INST", "HEALTH_STATUS", "ARY2", 0.0, 0.1, 0.1)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[0\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[1\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[2\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[3\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[4\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[5\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[6\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[7\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[8\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[9\] was within range/)
          stdout.rewind

          exp_array = Array.new(10, 0.0)
          tol_array = Array.new(10, 0.1)
          wait_check_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array, 0.1)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[0\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[1\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[2\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[3\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[4\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[5\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[6\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[7\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[8\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[9\] was within range/)
          stdout.rewind

          exp_array = Array.new(10, 0.0)
          tol_array = Array.new(10, 0.1)
          wait_check_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array, 0.1)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[0\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[1\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[2\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[3\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[4\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[5\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[6\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[7\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[8\] was within range/)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS ARY2\[9\] was within range/)
          stdout.rewind

          exp_array[0] = 0.11
          expect { wait_check_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array, 0.1) }.to raise_error(/CHECK: INST HEALTH_STATUS ARY2\[0\] failed to be within range/)
          stdout.rewind

          exp_array[0] = 0.0
          exp_array[9] = 0.11
          expect { wait_check_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array, 0.1) }.to raise_error(/CHECK: INST HEALTH_STATUS ARY2\[9\] failed to be within range/)
          stdout.rewind

          exp_array = Array.new(10, 1)
          tol_array = Array.new(10, 1.1)
          tol_array[1] = 0.9
          expect {wait_check_tolerance("INST HEALTH_STATUS ARY2", exp_array, tol_array, 0.1) }.to raise_error(/CHECK: INST HEALTH_STATUS ARY2\[1\] failed to be within range/)
          stdout.rewind
        end
      end

      it "checks size of array parameters" do
        bad_array = Array.new(9, 0)
        expect { wait_check_tolerance("INST HEALTH_STATUS ARY2", bad_array, 0.1, 0.1) }.to raise_error(/Invalid array size for expected_value/)
        expect { wait_check_tolerance("INST HEALTH_STATUS ARY2", 0.0, bad_array, 0.1) }.to raise_error(/Invalid array size for tolerance/)
      end
    end

    describe "wait_check_expression" do
      it "waits for an expression to be true" do
        capture_io do |stdout|
          # Success
          wait_check_expression("true == true", 5)
          expect(stdout.string).to match("CHECK: true == true is TRUE")
          stdout.rewind
        end

        # Failure
        expect { wait_check_expression("true == false", 0.1) }.to raise_error(CheckError, /CHECK: true == false is FALSE/)
      end
    end

    describe "wait_packet, wait_check_packet" do
      it "waits for a certain number of packets" do
        capture_io do |stdout|
          wait_packet("INST","HEALTH_STATUS",1,0.1)
        end

        expect { wait_check_packet("INST","HEALTH_STATUS",1,0.1) }.to raise_error(CheckError, /INST HEALTH_STATUS expected to be received 1 times but only received 0 times/)
      end
    end

    describe "cosmos_script_sleep" do
      it "pauses the running script inside ScriptRunnerFrame" do
        class ScriptRunnerFrame; def self.instance; true; end; end
        allow(ScriptRunnerFrame).to receive_message_chain(:instance, :pause?).and_return(true)
        expect(ScriptRunnerFrame).to receive_message_chain(:instance, :perform_pause)
        expect(ScriptRunnerFrame).to receive_message_chain(:instance, :active_script_highlight)
        cosmos_script_sleep(0.1)
      end
    end

    describe "start" do
      it "starts a script locally" do
        class ScriptRunnerFrame; def self.instance; false; end; end
        start("cosmos.rb")
      end

      it "starts a script without the .rb extension" do
        class ScriptRunnerFrame; def self.instance; false; end; end
        start("cosmos")
      end

      it "raises an error if the script can't be found" do
        class ScriptRunnerFrame; def self.instance; false; end; end
        expect { start("unknown_script.rb") }.to raise_error(LoadError)
      end

      it "starts a script within ScriptRunnerFrame" do
        class ScriptRunnerFrame
          @@instrumented_cache = {}
          @@file_cache = {}
          def self.instance; true; end
          def self.instrumented_cache; @@instrumented_cache; end
          def self.instrumented_cache=(value); @@instrumented_cache = value; end
          def self.file_cache; @@file_cache; end
          def self.file_cache=(value); @@file_cache = value; end
          def self.instrument_script(file_text, path, bool); "#"; end
        end
        start("cosmos.rb")
        # This one should use the cached version
        start("cosmos.rb")
      end
    end

    describe "load_utility" do
      it "requires a script" do
        class ScriptRunnerFrame; def self.instance; false; end; end;
        expect { load_utility("example.rb") }.to raise_error(LoadError, /Procedure not found/)
      end

      it "requires a script within ScriptRunnerFrame" do
        class ScriptRunnerFrame
          @@instrumented_cache = {}
          @@file_cache = {}
          def self.instance; true; end
          def self.instrumented_cache; @@instrumented_cache; end
          def self.instrumented_cache=(value); @@instrumented_cache = value; end
          def self.file_cache; @@file_cache; end
          def self.file_cache=(value); @@file_cache = value; end
          def self.instrument_script(file_text, path, bool); "#"; end
        end
        allow(ScriptRunnerFrame).to receive_message_chain(:instance, :use_instrumentation)
        allow(ScriptRunnerFrame).to receive_message_chain(:instance, :use_instrumentation=)
        script = File.join(Cosmos::USERPATH,'lib','example.rb')
        File.open(script, 'w') { |file| file.puts "# Example script" }
        not_cached = load_utility("example.rb")
        expect(not_cached).to eq true
        # This one should use the cached version
        not_cached = load_utility("example.rb")
        expect(not_cached).to eq false
        File.delete script
      end
    end

  end
end
