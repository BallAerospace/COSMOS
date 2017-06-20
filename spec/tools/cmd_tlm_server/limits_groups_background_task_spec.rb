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
require 'cosmos/tools/cmd_tlm_server/limits_groups_background_task'

module Cosmos
  describe LimitsGroupsBackgroundTask do
    describe "initialize" do
      it "initializes local variables" do
        b1 = LimitsGroupsBackgroundTask.new
        expect(b1.name).to eq "Limits Groups"
        expect(b1.thread).to be_nil
        expect(b1.status).to eq ''
        expect(b1.stopped).to eq false
        expect(b1.groups).to eq %w(FIRST SECOND)
      end
    end

    describe "call" do
      it "raises an error if the group is not defined" do
        class MyLimitsGroups1 < LimitsGroupsBackgroundTask
          def check_blah
          end
        end
        expect { MyLimitsGroups1.new.call }.to raise_error(/check_blah doesn't match a group name/)
      end

      it "processes the check methods at 1Hz" do
        class MyLimitsGroups2 < LimitsGroupsBackgroundTask
          attr_accessor :first_count, :second_count, :on_logic, :off_logic
          def initialize
            super()
            @first_count = 0
            @second_count = 0
            @on_logic = false
            @off_logic = false
            @on = Proc.new { @on_logic = true }
            @off = Proc.new { @off_logic = true }
          end
          def check_first
            @first_count += 1
            process_group(2, @on, @off) do
              @first_count <= 4 ? true : false
            end
          end
          def check_second
            @second_count += 1
            process_group { false } # Never enable
          end
        end
        my = MyLimitsGroups2.new
        thread = Thread.new do
          my.call
        end
        sleep 5 # The first 5s are to allow interfaces to start
        p = System.telemetry.packet("INST","HEALTH_STATUS")
        # Initially the groups are disabled
        expect(p.get_item("TEMP1").limits.enabled).to be false
        expect(p.get_item("TEMP3").limits.enabled).to be false
        expect(p.get_item("TEMP2").limits.enabled).to be false
        expect(p.get_item("TEMP4").limits.enabled).to be false
        expect(my.on_logic).to be false
        expect(my.off_logic).to be false
        # Things not in a group are enabled
        expect(p.get_item("GROUND1STATUS").limits.enabled).to be true
        expect(p.get_item("GROUND2STATUS").limits.enabled).to be true

        sleep 3.1 # Allow the logic to enable
        expect(p.get_item("TEMP1").limits.enabled).to be true
        expect(p.get_item("TEMP3").limits.enabled).to be true
        expect(p.get_item("TEMP2").limits.enabled).to be false
        expect(p.get_item("TEMP4").limits.enabled).to be false
        expect(my.on_logic).to be true # on logic was called
        expect(my.off_logic).to be false # off logic not yet called

        sleep 2.1 # Allow the logic to disable
        expect(p.get_item("TEMP1").limits.enabled).to be false
        expect(p.get_item("TEMP3").limits.enabled).to be false
        expect(p.get_item("TEMP2").limits.enabled).to be false
        expect(p.get_item("TEMP4").limits.enabled).to be false
        expect(my.on_logic).to be true
        expect(my.off_logic).to be true # off logic called

        Cosmos.kill_thread(self, thread)
        expect(my.first_count).to be >= 5
        expect(my.second_count).to be >= 5
      end

      it "warns if can't process check methods at 1Hz" do
        class MyLimitsGroups3 < LimitsGroupsBackgroundTask
          def check_first
            sleep 1.1
          end
        end
        message = ''
        allow(Logger).to receive(:warn) {|msg| message = msg }

        Thread.abort_on_exception = true
        my = MyLimitsGroups3.new
        thread = Thread.new do
          my.call
        end
        sleep 6.5 # The first 5s are to allow interfaces to start
        expect(message).to match /LimitsGroupsBackgroundTask took 1\.1\d+ to process check methods/
        Cosmos.kill_thread(self, thread)
      end
    end
  end
end
