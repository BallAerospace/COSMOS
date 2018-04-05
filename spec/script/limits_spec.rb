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

    describe "get_out_of_limits" do
      it "gets all out of limits items" do
        set_tlm_raw("INST HEALTH_STATUS TEMP1 = 0")
        expect(get_out_of_limits).to include(["INST","HEALTH_STATUS","TEMP1",:RED_LOW])
      end
    end

    describe "get_overall_limits_state" do
      it "gets the overall limits state of the system" do
        set_tlm_raw("INST HEALTH_STATUS TEMP1 = 0")
        expect(get_overall_limits_state).to eql :RED
      end

      it "ignores specified items" do
        ignore = []
        ignore << %w(INST HEALTH_STATUS TEMP1)
        ignore << %w(INST HEALTH_STATUS TEMP2)
        ignore << %w(INST HEALTH_STATUS TEMP3)
        ignore << %w(INST HEALTH_STATUS TEMP4)
        ignore << %w(INST HEALTH_STATUS GROUND1STATUS)
        ignore << %w(INST HEALTH_STATUS GROUND2STATUS)
        expect(get_overall_limits_state(ignore)).to eql :STALE
      end
    end

    describe "limits_enabled?, disable_limits, enable_limits" do
      it "enables, disable, and check limits for an item" do
        expect(limits_enabled?("INST HEALTH_STATUS TEMP1")).to be true
        disable_limits("INST HEALTH_STATUS TEMP1")
        expect(limits_enabled?("INST HEALTH_STATUS TEMP1")).to be false
        enable_limits("INST HEALTH_STATUS TEMP1")
        expect(limits_enabled?("INST HEALTH_STATUS TEMP1")).to be true
      end
    end

    describe "get_limits, set_limits" do
      it "gets and set limits for an item" do
        expect(get_limits("INST", "HEALTH_STATUS", "TEMP1")).to eql [:DEFAULT, 1, true, -80.0, -70.0, 60.0, 80.0, -20.0, 20.0]
        expect(set_limits("INST", "HEALTH_STATUS", "TEMP1", 1, 2, 5, 6, 3, 4)).to eql [:CUSTOM, 1, true, 1.0, 2.0, 5.0, 6.0, 3.0, 4.0]
      end
    end

    describe "get_limits_groups, enable_limits_group, disable_limits_group" do
      it "enables, disable, and get groups" do
        expect(get_limits_groups).to include("FIRST")
        enable_limits_group("FIRST")
        disable_limits_group("FIRST")
      end
    end

    describe "get_limits_sets, enable_limits_set, disable_limits_set" do
      it "enables, disable, and get sets CTS-16" do
        if get_limits_sets.include?(:CUSTOM)
          expect(get_limits_sets).to eql [:DEFAULT,:TVAC,:CUSTOM]
        else
          expect(get_limits_sets).to eql [:DEFAULT,:TVAC]
        end
        set_limits_set(:TVAC)
        expect(get_limits_set).to eql :TVAC
        set_limits_set(:DEFAULT)
        expect(get_limits_set).to eql :DEFAULT
      end
    end

    describe "subscribe_limits_events, get_limits_event, unsubscribe_limits_events" do
      it "raises an error if non_block and the queue is empty" do
        id = subscribe_limits_events
        expect { get_limits_event(id, true) }.to raise_error(ThreadError, "queue empty")
        unsubscribe_limits_events(id)
      end

      it "subscribes and get limits change events" do
        id = subscribe_limits_events
        CmdTlmServer.instance.post_limits_event(:LIMITS_CHANGE, ['TGT','PKT','ITEM',:YELLOW,:RED])
        result = get_limits_event(id, true)
        expect(result[0]).to eql :LIMITS_CHANGE
        unsubscribe_limits_events(id)
      end

      it "subscribes and get limits settings events" do
        id = subscribe_limits_events
        CmdTlmServer.instance.post_limits_event(:LIMITS_SETTINGS, ['TGT','PKT','ITEM',:DEFAULT])
        result = get_limits_event(id, true)
        expect(result[0]).to eql :LIMITS_SETTINGS
        unsubscribe_limits_events(id)
      end

      it "handles unknown limits events" do
        id = subscribe_limits_events
        CmdTlmServer.instance.post_limits_event(:UNKNOWN, "This is a test")
        result = get_limits_event(id, true)
        expect(result[0]).to eql :UNKNOWN
        unsubscribe_limits_events(id)
      end
    end

  end
end
