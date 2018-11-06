# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/conversions/limits_group_conversion'

module Cosmos
  describe LimitsGroupConversion do
    describe "call" do
      it "returns the overall limits state of the group" do
        lgc = LimitsGroupConversion.new([%w(INST HEALTH_STATUS TEMP1)])
        expect(lgc.call(0,0,0)).to eql 0 # Stale

        # Limits definition in the spec/install/config/targets/INST/cmd_tlm/inst_tlm.txt for TEMP1
        # LIMITS DEFAULT 1 ENABLED -80.0 -70.0 60.0 80.0 -20.0 20.0

        System.telemetry.set_value("INST", "HEALTH_STATUS", "TEMP1", 0)
        System.telemetry.packet("INST","HEALTH_STATUS").check_limits
        expect(lgc.call(0,0,0)).to eql 1 # Operational

        System.telemetry.set_value("INST", "HEALTH_STATUS", "TEMP1", 50)
        System.telemetry.packet("INST","HEALTH_STATUS").check_limits
        expect(lgc.call(0,0,0)).to eql 2 # Green

        System.telemetry.set_value("INST", "HEALTH_STATUS", "TEMP1", 70)
        System.telemetry.packet("INST","HEALTH_STATUS").check_limits
        expect(lgc.call(0,0,0)).to eql 3 # Yellow

        System.telemetry.set_value("INST", "HEALTH_STATUS", "TEMP1", 90)
        System.telemetry.packet("INST","HEALTH_STATUS").check_limits
        expect(lgc.call(0,0,0)).to eql 4 # Red

        System.telemetry.set_value("INST", "HEALTH_STATUS", "TEMP1", 0)
        System.telemetry.packet("INST","HEALTH_STATUS").check_limits
        expect(lgc.call(0,0,0)).to eql 1 # Operational
      end
    end
  end
end

