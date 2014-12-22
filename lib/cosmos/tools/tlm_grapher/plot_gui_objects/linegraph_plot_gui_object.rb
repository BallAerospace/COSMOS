# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/line_graph/line_graph'
require 'cosmos/tools/tlm_grapher/data_objects/linegraph_data_object'

module Cosmos

  # Represents the entire line graph plot in the graphing system. This class
  # extends LineGraph by implementing callbacks and the update methods which
  # are called by higher level classes.
  class LinegraphPlotGuiObject < LineGraph

    # Color of a linegraph frame when selected
    SELECTED_FRAME_COLOR = 'lightgreen'

    def initialize(parent, tab, plot, tabbed_plots)
      # Add new line graph
      super(parent)
      @plot = plot
      @paused = nil

      update()

      # Setup callbacks for multi-graph mouse-overs
      self.draw_cursor_line_callback = lambda do |calling_line_graph, x, left_button_pressed|
        tab.plots.each do |current_plot|
          current_plot.gui_object.remote_draw_cursor_line_at_x(x, left_button_pressed) if current_plot.gui_object != calling_line_graph and current_plot.gui_object.respond_to? :remote_draw_cursor_line_at_x
        end
      end
      self.mouse_leave_callback = lambda do |calling_line_graph|
        tab.plots.each do |current_plot|
          current_plot.gui_object.remote_draw_cursor_line_at_x(nil, false) if current_plot.gui_object != calling_line_graph and current_plot.gui_object.respond_to? :remote_draw_cursor_line_at_x
        end
      end

      # Setup callbacks for viewing errors
      self.pre_error_callback = lambda do |calling_line_graph|
        @paused = tabbed_plots.paused?
        tabbed_plots.pause
      end
      self.post_error_callback = lambda do |calling_line_graph|
        tabbed_plots.resume unless @paused
      end
      show()
    end # def initialize

    # Update the GraphView object properties
    def update(redraw_needed = false)
      self.title = @plot.title
      self.x_axis_title = @plot.x_axis_title
      self.left_y_axis_title = @plot.left_y_axis_title
      self.right_y_axis_title = @plot.right_y_axis_title
      self.show_x_grid_lines = @plot.show_x_grid_lines
      self.show_y_grid_lines = @plot.show_y_grid_lines
      self.point_size = @plot.point_size
      self.show_lines = @plot.show_lines
      self.show_legend = @plot.show_legend
      if @plot.manual_left_y_scale
        self.manual_scale_y(*(@plot.manual_left_y_scale))
      else
        self.auto_scale_y(:LEFT)
      end
      if @plot.manual_right_y_scale
        self.manual_scale_y(*(@plot.manual_right_y_scale))
      else
        self.auto_scale_y(:RIGHT)
      end
      self.manual_x_grid_line_scale = @plot.manual_x_grid_line_scale
      self.manual_y_grid_line_scale = @plot.manual_y_grid_line_scale
      self.unix_epoch_x_values = @plot.unix_epoch_x_values

      # Update horizontal lines
      self.clear_horizontal_lines
      @plot.data_objects.each do |data_object|
        if data_object.kind_of? LinegraphDataObject
          axis = data_object.y_axis
          data_object.horizontal_lines.each do |y_value, color|
            self.add_horizontal_line(y_value, color, axis)
          end
          if data_object.kind_of?(HousekeepingDataObject) && data_object.show_limits_lines
            axis = data_object.y_axis
            data_object.limits_lines.each do |y_value, color|
              self.add_horizontal_line(y_value, color, axis)
            end
          end
        end
      end

      redraw() if redraw_needed
    end

    # Update the overview graph associated with the line graph
    def update_overview(points_plotted, overview_graph)
      @plot.data_objects.each do |data_object|
        begin
          overview_graph.add_line(data_object.name, data_object.y_values, data_object.x_values, nil, nil, nil, nil, data_object.color, :LEFT, points_plotted) unless data_object.y_values.empty?
        rescue Exception => error
          # Ignore errors in overview graph
          raise error if error.class == NoMemoryError
        end
      end
    end

    # Update the GraphView lines
    def update_plot(points_plotted, min_x_value, max_x_value)
      self.clear_lines
      self.manual_scale_x(min_x_value, max_x_value, false)
      @plot.data_objects.each do |data_object|
        unless data_object.x_values.empty?
          begin
            raise "GraphView x data must be Numeric" unless data_object.x_values[0].kind_of?(Numeric)
            range = data_object.x_values.range_within(min_x_value, max_x_value)
            x_values = data_object.x_values[range]
            if x_values[0] and x_values[0] >= min_x_value and x_values[0] <= max_x_value
              y_values = data_object.y_values[range]
              formatted_x_values = nil
              formatted_x_values = data_object.formatted_x_values[range] unless data_object.formatted_x_values.empty?
              self.add_line(data_object.name, y_values, x_values, nil, formatted_x_values, data_object.y_states, data_object.x_states, data_object.color, data_object.y_axis, points_plotted) unless y_values.empty?
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

    # Indicates if the plot is selected
    def selected?
      self.frame_color == SELECTED_FRAME_COLOR
    end

    # Selects the plot
    def select
      if self.frame_color != SELECTED_FRAME_COLOR
        self.frame_color = SELECTED_FRAME_COLOR
        self.frame_size = 3
        redraw()
      end
    end

    # Unselects plot
    def unselect
      if self.frame_color == SELECTED_FRAME_COLOR
        self.frame_color = 'black'
        self.frame_size = 0
        redraw()
      end
    end

    # Redraws the line graph
    def redraw
      self.graph
    end

  end # class LinegraphPlotGuiObject

end # module Cosmos
