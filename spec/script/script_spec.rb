# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/script'
require 'tempfile'

module Cosmos
  describe Script do
    describe "require cosmos/script.rb" do
      it "should require cosmos/script/script" do
        save = $0
        $0 = "Test"
        expect { load 'cosmos/script.rb' }.to_not raise_error()
        $0 = save
      end

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

    describe "set_disconnected_targets, get_disconnected_targets, clear_disconnected_targets" do
      it "should set, get, and clear disconnected targets" do
        set_disconnected_targets(['INST'])
        expect($disconnected_targets).to include('INST')
        expect(get_disconnected_targets()).to eq ['INST']
        clear_disconnected_targets()
        expect(get_disconnected_targets()).to be_nil
        shutdown_cmd_tlm()
      end

      it "should handle any type of request when disconnected" do
        initialize_script_module()
        set_disconnected_targets(['INST'])
        # Try some simple cmd, tlm requests which route to the disconnected
        disconnected = $cmd_tlm_server.instance_variable_get(:@disconnected)
        expect(disconnected).to receive(:cmd).and_call_original
        cmd("INST ABORT")
        expect(disconnected).to receive(:tlm).and_call_original
        tlm("INST HEALTH_STATUS TEMP1")
        # SYSTEM isn't disconnected so these should not go to disconnected
        expect(disconnected).not_to receive(:cmd)
        expect { cmd("SYSTEM STARTLOGGING with LABEL 'TEST'") }.to raise_error(DRb::DRbConnError)
        expect(disconnected).not_to receive(:tlm)
        expect { tlm("SYSTEM META COSMOS_VERSION") }.to raise_error(DRb::DRbConnError)

        # The rest should pass through to the JsonDRbObject
        cosmos_script_sleep(0.1)
        expect { get_limits_groups() }.to raise_error(DRb::DRbConnError)
        expect { set_limits_set("DEFAULT") }.to raise_error(DRb::DRbConnError)
        ignore = []
        ignore << %w(INST HEALTH_STATUS TEMP1)
        ignore << %w(INST HEALTH_STATUS TEMP2)
        ignore << %w(INST HEALTH_STATUS GROUND2STATUS)
        expect { get_overall_limits_state(ignore) }.to raise_error(DRb::DRbConnError)

        clear_disconnected_targets()
        shutdown_cmd_tlm()
      end
    end

  end
end
