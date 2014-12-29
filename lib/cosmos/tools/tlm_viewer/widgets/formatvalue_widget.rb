# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation and FormatValueWidget class.   This class
# implements a widget that formats its value before displaying it.  This can be
# used to format items differently than their format string or to format items
# that don't have a format string defined.

require 'cosmos'
require 'cosmos/tools/tlm_viewer/widgets/value_widget'

module Cosmos

  class FormatvalueWidget < ValueWidget

    def initialize (parent_layout, target_name, packet_name, item_name, format_string, value_type = :CONVERTED, characters = 12)
      super(parent_layout, target_name, packet_name, item_name, value_type, characters)
      @format_string = format_string
    end

    def value= (data)
      formatted_data = sprintf(@format_string, data)
      super(formatted_data)
    end

  end

end # module Cosmos
