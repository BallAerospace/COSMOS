# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos
  module CanvasClickable
    # Requires @x, @y, @x_end, and @y_end to be defined
    def on_click(event, x, y)
      return false unless @screen_settings
      if (x < @x_end) && (x > @x) && (y < @y_end) && (y > @y)
        display(@screen_settings[0], @screen_settings[1].to_i, @screen_settings[2].to_i)
        true
      else
        false
      end
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
