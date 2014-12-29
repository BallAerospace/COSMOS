# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_grapher/plot_editors/plot_editor'
require 'cosmos/gui/choosers/combobox_chooser'
require 'cosmos/gui/choosers/string_chooser'
require 'cosmos/gui/choosers/float_chooser'
require 'cosmos/gui/choosers/integer_chooser'
require 'cosmos/tools/tlm_grapher/plots/linegraph_plot'

module Cosmos

  # Widget which lays out the options for editing a plot
  class LinegraphPlotEditor < PlotEditor

    def initialize(parent, plot = nil)
      super(parent, plot)
      @layout = Qt::VBoxLayout.new

      # Make sure we have a plot to edit
      @plot = LinegraphPlot.new unless plot

      # String Chooser for Title
      @title = StringChooser.new(self, 'Title:', @plot.title.to_s)
      @layout.addWidget(@title)

      # String Chooser for X Axis Title
      @x_axis_title = StringChooser.new(self, 'X Axis Title:', @plot.x_axis_title.to_s)
      @layout.addWidget(@x_axis_title)

      # String Choosers for Y Axis Titles
      @left_y_axis_title  = StringChooser.new(self, 'Left Y Axis Title:', @plot.left_y_axis_title.to_s)
      @layout.addWidget(@left_y_axis_title)
      @right_y_axis_title = StringChooser.new(self, 'Right Y Axis Title:', @plot.right_y_axis_title.to_s)
      @layout.addWidget(@right_y_axis_title)

      # Combobox Choosers for show items
      choices = ['TRUE', 'FALSE']
      choices.delete(@plot.show_x_grid_lines.to_s.upcase)
      choices.unshift(@plot.show_x_grid_lines.to_s.upcase)
      @show_x_grid_lines = ComboboxChooser.new(self, 'Show X Grid Lines:', choices)
      @layout.addWidget(@show_x_grid_lines)
      choices = ['TRUE', 'FALSE']
      choices.delete(@plot.show_y_grid_lines.to_s.upcase)
      choices.unshift(@plot.show_y_grid_lines.to_s.upcase)
      @show_y_grid_lines = ComboboxChooser.new(self, 'Show Y Grid Lines:', choices)
      @layout.addWidget(@show_y_grid_lines)
      @point_size = IntegerChooser.new(self, 'Point Size:', @plot.point_size)
      @layout.addWidget(@point_size)
      choices = ['TRUE', 'FALSE']
      choices.delete(@plot.show_lines.to_s.upcase)
      choices.unshift(@plot.show_lines.to_s.upcase)
      @show_lines  = ComboboxChooser.new(self, 'Show Lines:', choices)
      @layout.addWidget(@show_lines)
      choices = ['TRUE', 'FALSE']
      choices.delete(@plot.show_legend.to_s.upcase)
      choices.unshift(@plot.show_legend.to_s.upcase)
      @show_legend  = ComboboxChooser.new(self, 'Show Legend:', choices)
      @layout.addWidget(@show_legend)

      # Float Choosers for Manual Scaling
      manual_left_y_scale_min = nil
      manual_left_y_scale_min = @plot.manual_left_y_scale[0] if @plot.manual_left_y_scale
      @manual_left_y_scale_min  = FloatChooser.new(self, 'Manual Left Y Axis Minimum:', manual_left_y_scale_min.to_s)
      @layout.addWidget(@manual_left_y_scale_min)
      manual_left_y_scale_max = nil
      manual_left_y_scale_max = @plot.manual_left_y_scale[1] if @plot.manual_left_y_scale
      @manual_left_y_scale_max  = FloatChooser.new(self, 'Manual Left Y Axis Maximum:', manual_left_y_scale_max.to_s)
      @layout.addWidget(@manual_left_y_scale_max)
      manual_right_y_scale_min = nil
      manual_right_y_scale_min = @plot.manual_right_y_scale[0] if @plot.manual_right_y_scale
      @manual_right_y_scale_min = FloatChooser.new(self, 'Manual Right Y Axis Minimum:', manual_right_y_scale_min.to_s)
      @layout.addWidget(@manual_right_y_scale_min)
      manual_right_y_scale_max = nil
      manual_right_y_scale_max = @plot.manual_right_y_scale[1] if @plot.manual_right_y_scale
      @manual_right_y_scale_max = FloatChooser.new(self, 'Manual Right Y Axis Maximum:', manual_right_y_scale_max.to_s)
      @layout.addWidget(@manual_right_y_scale_max)
      manual_x_grid_line_scale = nil
      manual_x_grid_line_scale = @plot.manual_x_grid_line_scale if @plot.manual_x_grid_line_scale
      @manual_x_grid_line_scale = FloatChooser.new(self, 'Manual X Grid Line Scale:', manual_x_grid_line_scale.to_s)
      @layout.addWidget(@manual_x_grid_line_scale)
      manual_y_grid_line_scale = nil
      manual_y_grid_line_scale = @plot.manual_y_grid_line_scale if @plot.manual_y_grid_line_scale
      @manual_y_grid_line_scale = FloatChooser.new(self, 'Manual Y Grid Line Scale:', manual_y_grid_line_scale.to_s)
      @layout.addWidget(@manual_y_grid_line_scale)

      # Combobox Chooser
      choices = ['TRUE', 'FALSE']
      choices.delete(@plot.unix_epoch_x_values.to_s.upcase)
      choices.unshift(@plot.unix_epoch_x_values.to_s.upcase)
      @unix_epoch_x_values = ComboboxChooser.new(self, 'Unix Epoch X Values:', choices)
      @layout.addWidget(@unix_epoch_x_values)

      setLayout(@layout)
    end # def initialize

    # Returns the plot
    def plot
      plot = super()
      title = @title.string
      if title.strip.empty?
        plot.title = nil
      else
        plot.title = title
      end
      x_axis_title = @x_axis_title.string
      if x_axis_title.strip.empty?
        plot.x_axis_title = nil
      else
        plot.x_axis_title = x_axis_title
      end
      left_y_axis_title = @left_y_axis_title.string
      if left_y_axis_title.strip.empty?
        plot.left_y_axis_title = nil
      else
        plot.left_y_axis_title = left_y_axis_title
      end
      right_y_axis_title = @right_y_axis_title.string
      if right_y_axis_title.strip.empty?
        plot.right_y_axis_title = nil
      else
        plot.right_y_axis_title = right_y_axis_title
      end
      plot.show_x_grid_lines = ConfigParser.handle_true_false(@show_x_grid_lines.string)
      plot.show_y_grid_lines = ConfigParser.handle_true_false(@show_y_grid_lines.string)
      plot.point_size = @point_size.value
      plot.show_lines = ConfigParser.handle_true_false(@show_lines.string)
      plot.show_legend = ConfigParser.handle_true_false(@show_legend.string)
      manual_left_y_scale_max = @manual_left_y_scale_max.string.strip
      manual_left_y_scale_min = @manual_left_y_scale_min.string.strip
      if not manual_left_y_scale_max.empty? or not manual_left_y_scale_min.empty?
        if manual_left_y_scale_max.to_f > manual_left_y_scale_min.to_f
          plot.manual_left_y_scale = [manual_left_y_scale_min.to_f, manual_left_y_scale_max.to_f, :LEFT]
        elsif manual_left_y_scale_min.to_f > manual_left_y_scale_max.to_f
          plot.manual_left_y_scale = [manual_left_y_scale_max.to_f, manual_left_y_scale_min.to_f, :LEFT]
        else
          plot.manual_left_y_scale = nil
        end
      else
        plot.manual_left_y_scale = nil
      end
      manual_right_y_scale_max = @manual_right_y_scale_max.string.strip
      manual_right_y_scale_min = @manual_right_y_scale_min.string.strip
      if not manual_right_y_scale_max.empty? or not manual_right_y_scale_min.empty?
        if manual_right_y_scale_max.to_f > manual_right_y_scale_min.to_f
          plot.manual_right_y_scale = [manual_right_y_scale_min.to_f, manual_right_y_scale_max.to_f, :RIGHT]
        elsif manual_right_y_scale_min.to_f > manual_right_y_scale_max.to_f
          plot.manual_right_y_scale = [manual_right_y_scale_max.to_f, manual_right_y_scale_min.to_f, :RIGHT]
        else
          plot.manual_right_y_scale = nil
        end
      else
        plot.manual_right_y_scale = nil
      end
      manual_x_grid_line_scale = @manual_x_grid_line_scale.string.strip
      unless manual_x_grid_line_scale.empty?
        plot.manual_x_grid_line_scale = manual_x_grid_line_scale.to_f
      else
        plot.manual_x_grid_line_scale = nil
      end
      manual_y_grid_line_scale = @manual_y_grid_line_scale.string.strip
      unless manual_y_grid_line_scale.empty?
        plot.manual_y_grid_line_scale = manual_y_grid_line_scale.to_f
      else
        plot.manual_y_grid_line_scale = nil
      end
      plot.unix_epoch_x_values = ConfigParser.handle_true_false(@unix_epoch_x_values.string)
      plot
    end

  end # class LinegraphPlotEditor

end # module Cosmos
