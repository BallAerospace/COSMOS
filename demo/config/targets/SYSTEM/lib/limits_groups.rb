# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/cmd_tlm_server/limits_groups_background_task'

module Cosmos
  class LimitsGroups < LimitsGroupsBackgroundTask
    def initialize(initial_delay)
      super(initial_delay)
      @temp1_enable_code = Proc.new do
        enable_limits_group('GROUND')
      end
      @temp1_disable_code = Proc.new do
        disable_limits_group('GROUND')
      end
    end

    def check_temp1
      process_group(3, @temp1_enable_code, @temp1_disable_code) do
        tlm("INST HEALTH_STATUS TEMP1") > 0
      end
    end

    def check_temp234
      process_group(5) do
        (tlm("INST HEALTH_STATUS TEMP2") > 0) ||
        (tlm("INST HEALTH_STATUS TEMP3") > 0) ||
        (tlm("INST HEALTH_STATUS TEMP4") > 0)
      end
    end
  end
end
