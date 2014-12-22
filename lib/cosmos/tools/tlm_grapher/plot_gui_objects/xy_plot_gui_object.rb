# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_grapher/plot_gui_objects/linegraph_plot_gui_object'

module Cosmos

  # Represents a X-Y graph plot in the graphing system. This class
  # extends LinegraphPlotGuiObject by re-implementing the update methods.
  class XyPlotGuiObject < LinegraphPlotGuiObject

    # Updates the linegraph to new settings
    def update(redraw_needed = false)
      if @plot.manual_x_scale
        self.manual_scale_x(*(@plot.manual_x_scale))
      else
        self.auto_scale_x
      end
      self.ordered_x_values = false
      self.show_popup_x_y = true
      super(redraw_needed)
    end

    # Update the overview graph with this plots data
    def update_overview(points_plotted, overview_graph)
      @plot.data_objects.each do |data_object|
        begin
          overview_graph.add_line(data_object.name, data_object.y_values, data_object.time_values, nil, nil, nil, nil, data_object.color, :LEFT, points_plotted) unless data_object.y_values.empty?
        rescue Exception => error
          # Ignore errors in overview graph
          raise error if error.class == NoMemoryError
        end
      end
    end

    # Updates the lines on the plot
    def update_plot(points_plotted, min_x_value, max_x_value, single = false)
      self.clear_lines
      @plot.data_objects.each do |data_object|
        unless data_object.time_values.empty?
          begin
            raise "LineGraph time data must be Numeric" unless data_object.time_values[0].kind_of?(Numeric)
            range = data_object.time_values.range_within(min_x_value, max_x_value)
            range = (range.last)..(range.last) if single
            time_values = data_object.time_values[range]
            if time_values[0] and time_values[0] >= min_x_value and time_values[0] <= max_x_value
              x_values = data_object.x_values[range]
              y_values = data_object.y_values[range]
              self.add_line(data_object.name, y_values, x_values, nil, nil, data_object.y_states, data_object.x_states, data_object.color, :LEFT, points_plotted) unless y_values.empty?
            end
          rescue Exception => error
            raise error if error.class == NoMemoryError
            self.error = error unless self.error
          end
        end
        if data_object.error
          self.error = data_object.error
          data_object.error = nil
        end
      end
      @plot.redraw_needed = false
    end

  end # class XyPlotGuiObject

end # module Cosmos
