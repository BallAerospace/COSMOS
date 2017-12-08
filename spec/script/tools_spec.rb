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

    describe "display" do
      it "displays a telemetry viewer screen" do
        allow_any_instance_of(JsonDRbObject).to receive(:display)
        display("HI")
      end

      it "complains if unable to start telemetry viewer" do
        # Avoid the needless delay by stubbing sleep
        allow_any_instance_of(Object).to receive(:sleep)
        allow_any_instance_of(Object).to receive(:cosmos_script_sleep).and_return(true)
        allow(Cosmos).to receive(:run_process)
        expect { display("HI") }.to raise_error(RuntimeError, /Could not display HI/)
      end

      it "complains if the screen doesn't exist" do
        allow_any_instance_of(JsonDRbObject).to receive(:display).and_raise(Errno::ENOENT)
        expect { display("HI") }.to raise_error(RuntimeError, /HI.txt does not exist/)
      end
    end

    describe "clear" do
      it "closes a telemetry viewer screen" do
        allow_any_instance_of(JsonDRbObject).to receive(:clear)
        clear("HI")
      end

      it "complains if unable to start telemetry viewer" do
        # Avoid the needless delay by stubbing sleep
        allow_any_instance_of(Object).to receive(:sleep)
        allow_any_instance_of(Object).to receive(:cosmos_script_sleep).and_return(true)
        allow(Cosmos).to receive(:run_process)
        expect { clear("HI") }.to raise_error(RuntimeError, /Could not clear HI/)
      end

      it "complains if the screen doesn't exist" do
        allow_any_instance_of(JsonDRbObject).to receive(:clear).and_raise(Errno::ENOENT)
        expect { clear("HI") }.to raise_error(RuntimeError, /HI.txt does not exist/)
      end
    end

    describe "clear_all" do
      it "closes all telemetry viewer screens" do
        allow_any_instance_of(JsonDRbObject).to receive(:clear_all)
        clear_all
      end

      it "complains if unable to start telemetry viewer" do
        # Avoid the needless delay by stubbing sleep
        allow_any_instance_of(Object).to receive(:sleep)
        allow_any_instance_of(Object).to receive(:cosmos_script_sleep).and_return(true)
        allow(Cosmos).to receive(:run_process)
        expect { clear_all }.to raise_error(RuntimeError, /Could not clear_all/)
      end
    end

    describe "ScriptRunnerFrame methods" do
      it "calls various ScriptRunnerFrame methods" do
        class Dummy; def method_missing(meth, *args, &block); end; end
        class ScriptRunnerFrame
          def self.method_missing(meth, *args, &block); end
          def self.instance; Dummy.new; end
        end
        set_line_delay(1.0)
        get_line_delay
        get_scriptrunner_message_log_filename
        start_new_scriptrunner_message_log
        disable_instrumentation { }
        set_stdout_max_lines(1000)
        insert_return
        step_mode
        run_mode
        show_backtrace
      end
    end

  end
end

