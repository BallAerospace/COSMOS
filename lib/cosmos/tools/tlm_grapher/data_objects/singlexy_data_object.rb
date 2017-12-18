# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_grapher/data_objects/xy_data_object'

module Cosmos
  # Represents a data object on an SinglxyGraph for two telemetry items
  class SinglexyDataObject < XyDataObject
    def initialize
      super()
    end
  end
end
