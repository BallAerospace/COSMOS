# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation and TrendbarWidget class.   This class
# implements a limitsbar widget with and additional horizontal trendline
# indicating previous values and general trending.

require 'cosmos/tools/tlm_viewer/widgets/limitsbar_widget'

module Cosmos

  class TrendbarWidget < LimitsbarWidget

    MAX_TREND_SECONDS = 3600.0

    def initialize (parent_layout, target_name, packet_name, item_name, value_type = :CONVERTED, trend_seconds = 60.0, width = 160, height = 25, trend_value_handle = nil)
      #  @trend_seconds needs to be set before super because super will call get_tooltip_text
      @trend_seconds = trend_seconds.to_f
      @trend_seconds = MAX_TREND_SECONDS if @trend_seconds > MAX_TREND_SECONDS
      super(parent_layout, target_name, packet_name, item_name, value_type, width, height)
      @trend_value_handle = ConfigParser.handle_nil(trend_value_handle)

      # Track the total number of samples received.  This will help us to know how many
      # trendlines to plot before we reach the maximum.
      @samples_received = 0

      # The actual difference (delta) between the current value and the desired trend value.
      @trend_delta = nil
      @trend_points = 1
      @trend_data = [0]
    end

    def polling_period=(polling_period)
      super(polling_period)
      adjust_trend_points_and_data()
    end

    def value= (data)
      @value = data.to_f

      @samples_received += 1

      # Remove the oldest value off the end (right) and insert on the
      # front (left) of the array.
      @trend_data.pop
      @trend_data.insert(0, @value)

      update()
    end

    def adjust_trend_points_and_data
      @trend_points = ((1.0 / @polling_period.to_f) * @trend_seconds).to_i + 1
      # Time history of TLM item values with oldest -> newest reading left[0]
      # -> right[max_trend_points - 1]
      @trend_data = [0] * @trend_points

      # Subtract one since we'll use this as an array index and will precompute so we don't have
      # to take a computation hit at every data update.
      @trend_points -= 1
      @trend_points = 0 if @trend_points < 0
    end

    def get_tooltip_text
      tooltip_text  = super()
      tooltip_text += "\nTrending Value = (Current Value) - (Value #{@trend_seconds} Seconds Ago)"
      return tooltip_text
    end

    def additional_drawing (dc)
      trendline_pos = (@x_pad + ((@trend_data[@trend_points]) - @low_value) / @bar_scale * @bar_width).to_i
      trendline_pos = @x_pad if trendline_pos < @x_pad
      trendline_pos = @bar_width + @x_pad if trendline_pos > @x_pad + @bar_width

      # Create the horizontal trendline and circle indicating the trend value.
      # The desired diameter of the circle is 0.35 * bar_height.
      bar_y_mid = @height / 2
      radius = 0.175 * @bar_height

      if @samples_received > @trend_points

        # Set the value for the widget that displays the trend_delta
        if @trend_value_handle
          trend_val = @value - @trend_data[@trend_points]

          # Round to 2 digits
          @trend_value_handle.setText(sprintf("%0.2f", trend_val))
        end

        dc.addLineColor(trendline_pos, bar_y_mid, @line_pos, bar_y_mid)

        # Put a circle in the middle of the bar at the trendline point.
        #
        # Note: The documentation claims the (x, y) given is the center of the
        # circle but it doesn't seem right => we shift the circle (x,y) to what
        # looks correct experimentally since this is just a rough visual indicator.
        #~ dc.fillCircle(trendline_pos + radius/2, bar_y_mid + radius/2, radius)
        dc.addEllipseColorFill(trendline_pos - 2, bar_y_mid - radius/2, radius*2, radius*2)
      end
    end

    def process_settings
      super()

      # Handle the global TREND_SECONDS setting which will do a global change of
      # all widgets of this type in a given screen definition file.
      # Usage (in screen def file):
      #                  GLOBAL_SETTING TRENDLIMITSBAR TREND_SECONDS <num_seconds>
      if @settings.include?('TREND_SECONDS')
        @trend_seconds = @settings['TREND_SECONDS'][0].to_f

        # Make sure maximum is still enforced
        if @trend_seconds > MAX_TREND_SECONDS
          @trend_seconds = MAX_TREND_SECONDS
        end

        adjust_trend_points_and_data()
      end
    end

  end

end # module Cosmos

