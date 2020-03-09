# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos
  # Creates a clickable point on the canvas which opens another screen.
  # Add to canvas by using the SCREEN setting. For example:
  #   SETTING SCREEN "INST HS" 100 100
  module CanvasClickable
    # Requires @x, @y, @x_end, and @y_end to be defined
    def on_click(event, x, y)
      return false unless @screen_settings
      if (x < @x_end) && (x > @x) && (y < @y_end) && (y > @y)
        display(@screen_settings[0], @screen_settings[1].to_i, @screen_settings[2].to_i)
        true # We handled the click so return true
      else
        false # Allow other widgets to handle the on_click
      end
    end

    # Requires @x, @y, @x_end, and @y_end to be defined
    def on_move(event, x, y)
      return false unless @screen_settings
      if (x < @x_end) && (x > @x) && (y < @y_end) && (y > @y)
        Qt::Application.setOverrideCursor(Cosmos.getCursor(Qt::PointingHandCursor))
      else
        Qt::Application.setOverrideCursor(Cosmos.getCursor(Qt::ArrowCursor))
      end
      false # Allow other widgets to handle on_move
    end

    def set_setting(setting_name, setting_values)
      case setting_name.upcase
      when 'SCREEN'
        @screen_settings = setting_values
      else
        super(setting_name, setting_values)
      end
    end
  end
end
