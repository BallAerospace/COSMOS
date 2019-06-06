# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos
  # Creates a Qt::SpacerItem which affects the positioning of other
  # widgets around it. The width and height must be given and the
  # size policy follows. See the Qt documentation for more details.
  class SpacerWidget < Qt::Widget
    include Widget

    def initialize(parent_layout, width, height, hpolicy="MINIMUM", vpolicy="MINIMUM")
      super()
      if parent_layout
        spacer_item = Qt::SpacerItem.new(width.to_i,
                                         height.to_i,
                                         size_policy(hpolicy),
                                         size_policy(vpolicy))
        parent_layout.addItem(spacer_item)
      end
    end

    def size_policy(str)
      case str.upcase
        when 'FIXED'
          return Qt::SizePolicy::Fixed
        when 'MINIMUM'
          return Qt::SizePolicy::Minimum
        when 'MAXIMUM'
          return Qt::SizePolicy::Maximum
        when 'PREFERRED'
          return Qt::SizePolicy::Preferred
        when 'EXPANDING'
          return Qt::SizePolicy::Expanding
        when 'MINIMUMEXPANDING'
          return Qt::SizePolicy::MinimumExpanding
        when 'IGNORED'
          return Qt::SizePolicy::Ignored
        else
          return Qt::SizePolicy::Minimum
      end
    end
  end
end
