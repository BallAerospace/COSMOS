# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_grapher/plots/plot'

module Cosmos

  # Represents a line graph plot in a plots definition
  class LinegraphPlot < Plot

    # Title of the line graph
    attr_accessor :title

    # X Axis Title
    attr_accessor :x_axis_title

    # Left Y Axis Title
    attr_accessor :left_y_axis_title

    # Right Y Axis Title
    attr_accessor :right_y_axis_title

    # Show absolute X grid labels
    attr_accessor :show_abs_x_grid_labels

    # Show x gridlines
    attr_accessor :show_x_grid_lines

    # Show y gridlines
    attr_accessor :show_y_grid_lines

    # Size of points on graph
    attr_accessor :point_size

    # Show lines on graph
    attr_accessor :show_lines

    # Show legend of data objects
    attr_accessor :show_legend

    # Manual left y scale array of y_min and y_max
    attr_accessor :manual_left_y_scale

    # Manual right  y scale array of y_min and y_max
    attr_accessor :manual_right_y_scale

    # Manual x grid line scale
    attr_accessor :manual_x_grid_line_scale

    # Manual y grid line scale
    attr_accessor :manual_y_grid_line_scale

    # Interpret x values as unix epoch timestamps
    attr_accessor :unix_epoch_x_values

    # Display x values as UTC time
    attr_accessor :utc_time

    def initialize
      super()
      @title = nil
      @x_axis_title = 'Time (Seconds)'
      @left_y_axis_title = nil
      @right_y_axis_title = nil
      @show_abs_x_grid_labels = true
      @show_x_grid_lines = false
      @show_y_grid_lines = true
      @point_size = 5
      @show_lines = true
      @show_legend = true
      @manual_left_y_scale = nil
      @manual_right_y_scale = nil
      @manual_x_grid_line_scale = nil
      @manual_y_grid_line_scale = nil
      @unix_epoch_x_values = true
      @utc_time = false
    end # def initialize

    # Handles plot specific keywords
    def handle_keyword(parser, keyword, parameters)
      case keyword
      when 'TITLE'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "TITLE <Title Text>")
        @title = parameters[0]

      when 'X_AXIS_TITLE'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "X_AXIS_LABEL <Label Text>")
        @x_axis_title = parameters[0]

      when 'Y_AXIS_TITLE'
        # Expect 1 or 2 parameters
        parser.verify_num_parameters(1, 2, "Y_AXIS_LABEL <Label Text> <LEFT or RIGHT (optional)>")
        if parameters[1] and parameters[1].upcase == 'RIGHT'
          @right_y_axis_title = parameters[0]
        else
          @left_y_axis_title = parameters[0]
        end

      when 'SHOW_ABS_X_GRID_LABELS'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "SHOW_ABS_X_GRID_LABELS <TRUE or FALSE>")
        @show_abs_x_grid_labels = ConfigParser.handle_true_false(parameters[0])

      when 'SHOW_X_GRID_LINES'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "SHOW_X_GRID_LINES <TRUE or FALSE>")
        @show_x_grid_lines = ConfigParser.handle_true_false(parameters[0])

      when 'SHOW_Y_GRID_LINES'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "SHOW_Y_GRID_LINES <TRUE or FALSE>")
        @show_y_grid_lines = ConfigParser.handle_true_false(parameters[0])

      when 'POINT_SIZE'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "POINT_SIZE <0 or more>")
        @point_size = Integer(parameters[0])

      when 'SHOW_LINES'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "SHOW_LINES <TRUE or FALSE>")
        @show_lines = ConfigParser.handle_true_false(parameters[0])

      when 'SHOW_LEGEND'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "SHOW_LEGEND <TRUE or FALSE>")
        @show_legend = ConfigParser.handle_true_false(parameters[0])

      when 'MANUAL_Y_AXIS_SCALE'
        # Expect 2 or 3 parameters
        parser.verify_num_parameters(2, 3, "MANUAL_Y_AXIS_SCALE <Y Min> <Y Max> <LEFT or RIGHT (optional)>")
        manual_scale    = []
        manual_scale[0] = parameters[0].to_f
        manual_scale[1] = parameters[1].to_f
        if manual_scale[0] >= manual_scale[1]
          raise parser.error("#{keyword} minimum #{manual_scale[0]} not less than maximum #{manual_scale[1]}")
        else
          if parameters[2] and parameters[2].upcase == 'RIGHT'
            manual_scale[2] = :RIGHT
            @manual_right_y_scale = manual_scale
          else
            manual_scale[2] = :LEFT
            @manual_left_y_scale = manual_scale
          end
        end

      when 'MANUAL_X_GRID_LINE_SCALE'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "MANUAL_X_GRID_LINE_SCALE <Scale Value>")
        @manual_x_grid_line_scale = parameters[0].to_f

      when 'MANUAL_Y_GRID_LINE_SCALE'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "MANUAL_Y_GRID_LINE_SCALE <Scale Value>")
        @manual_y_grid_line_scale = parameters[0].to_f

      when 'UNIX_EPOCH_X_VALUES'
        # Expect 1 parameter
        parser.verify_num_parameters(1, 1, "UNIX_EPOCH_X_VALUES <TRUE or FALSE>")
        @unix_epoch_x_values = ConfigParser.handle_true_false(parameters[0])

      when 'UTC_TIME'
        @utc_time = true

      else
        # Unknown keywords are passed to parent data object
        super(parser, keyword, parameters)

      end # case keyword

    end # def handle_keyword

    protected

    # Returns the configuration lines used to create this plot
    def plot_configuration_string
      string = super()
      string << "    TITLE \"#{@title}\"\n" if @title
      string << "    X_AXIS_TITLE \"#{@x_axis_title}\"\n" if @x_axis_title
      string << "    Y_AXIS_TITLE \"#{@left_y_axis_title}\" LEFT\n" if @left_y_axis_title
      string << "    Y_AXIS_TITLE \"#{@right_y_axis_title}\" RIGHT\n" if @right_y_axis_title
      string << "    SHOW_ABS_X_GRID_LABELS #{@show_abs_x_grid_labels.to_s.upcase}\n"
      string << "    SHOW_X_GRID_LINES #{@show_x_grid_lines.to_s.upcase}\n"
      string << "    SHOW_Y_GRID_LINES #{@show_y_grid_lines.to_s.upcase}\n"
      string << "    POINT_SIZE #{@point_size}\n"
      string << "    SHOW_LINES #{@show_lines.to_s.upcase}\n"
      string << "    SHOW_LEGEND #{@show_legend.to_s.upcase}\n"
      string << "    MANUAL_Y_AXIS_SCALE #{@manual_left_y_scale[0]} #{@manual_left_y_scale[1]} LEFT\n" if @manual_left_y_scale
      string << "    MANUAL_Y_AXIS_SCALE #{@manual_right_y_scale[0]} #{@manual_right_y_scale[1]} RIGHT\n" if @manual_right_y_scale
      string << "    MANUAL_X_GRID_LINE_SCALE #{@manual_x_grid_line_scale}\n" if @manual_x_grid_line_scale
      string << "    MANUAL_Y_GRID_LINE_SCALE #{@manual_y_grid_line_scale}\n" if @manual_y_grid_line_scale
      string << "    UNIX_EPOCH_X_VALUES #{@unix_epoch_x_values.to_s.upcase}\n"
      string << "    UTC_TIME\n" if @utc_time
      string
    end # def plot_configuration_string

  end # class LinegraphPlot

end # module Cosmos
