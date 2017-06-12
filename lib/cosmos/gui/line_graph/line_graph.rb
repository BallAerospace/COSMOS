# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/ext/line_graph'
require 'cosmos/gui/qt'
require 'cosmos/gui/dialogs/exception_dialog'
require 'cosmos/gui/line_graph/lines'
require 'cosmos/gui/line_graph/line_graph_drawing'
require 'cosmos/gui/line_graph/line_graph_scaling'
require 'cosmos/gui/line_graph/line_graph_popups'

module Cosmos
  # Widget which displays a line graph. Graph provides decorations such as
  # titles, labels, grid lines, and a legend. Mouse tracking is provided to allow
  # popups on graph values. Automatic scaling is provided to scale the X and Y
  # axis according to the data values.
  class LineGraph < Qt::Widget
    # Create attr_accessors that automatically set the redraw_needed flag when
    # they are set
    def self.attr_accessor_with_redraw(*symbols)
     symbols.each do |name|
        self.class_eval("def #{name}; @#{name}; end")
        self.class_eval(%Q{
          def #{name}=(value)
            @#{name} = value
            @redraw_needed = true
          end
        })
      end
    end

    # Max seconds between clicks for a double click
    DOUBLE_CLICK_SECONDS = 0.2

    #########################################################################
    # Configurable Attributes which when set result in a redraw needed
    #########################################################################

    # Draw a small square at each data point of this size
    attr_accessor_with_redraw :point_size
    # Draws the lines between points - true/false
    attr_accessor_with_redraw :show_lines
    # Show x and y gridlines - true/false
    attr_accessor_with_redraw :show_x_grid_lines, :show_y_grid_lines
    # Manual distance between x and y gridlines
    # Note that right y grid lines are slave to left y grid lines
    # unless there are only right lines
    attr_accessor_with_redraw :manual_x_grid_line_scale, :manual_y_grid_line_scale
    # Draw Legend - true/false
    attr_accessor_with_redraw :show_legend
    # Draw cursor / popups - true/false
    attr_accessor_with_redraw :show_cursor_and_popups
    # Overall frame color and size in pixels
    attr_accessor_with_redraw :frame_color, :frame_size
    # Canvas and graph background color
    attr_accessor_with_redraw :back_color, :graph_back_color
    # Label and Border Text Color
    attr_accessor_with_redraw :label_and_border_color
    # Graph Title Text
    attr_accessor_with_redraw :title
    # X axis and left and right Y axis text
    attr_accessor_with_redraw :x_axis_title, :left_y_axis_title, :right_y_axis_title
    # Maximum number of characters to show for a x and y axis label
    attr_accessor_with_redraw :max_x_characters, :max_y_characters
    # Minimum width and height of graph
    attr_accessor_with_redraw :minimum_width, :minimum_height
    # Error associated with the graph
    attr_accessor_with_redraw :error
    # Flag indicating if x data is ordered or not
    attr_accessor_with_redraw :ordered_x_values
    # Flag indicating if popups should always show both x and y values
    attr_accessor_with_redraw :show_popup_x_y
    # Use x_value as floating point UTC timestamp with unix epoch
    attr_accessor_with_redraw :unix_epoch_x_values
    # Display x_value as UTC timestamp
    attr_accessor_with_redraw :utc_time
    # Display legend on bottom or right side
    attr_accessor_with_redraw :legend_position

    #########################################################################
    # Callback attributes
    #########################################################################

    # Callback called when a cursor line is drawn - call(self, graph_x, @left_button_pressed)
    attr_accessor :draw_cursor_line_callback
    # Callback called when the mouse leaves a graph - call(self)
    attr_accessor :mouse_leave_callback
    # Callback called when the mouse left button is pressed - call(self)
    attr_accessor :mouse_left_button_press_callback
    # Callback called before exception popup is displayed - call(self)
    attr_accessor :pre_error_callback
    # Callback called after exception popup is displayed - call(self)
    attr_accessor :post_error_callback

    #########################################################################
    # Readable Attributes
    #########################################################################

    # Minimum and maximum shown x values
    attr_reader :x_min, :x_max
    # Minimum and maximum shown x value label
    attr_reader :x_min_label, :x_max_label
    # Minimm and maximum shown left y value
    attr_reader :left_y_min, :left_y_max
    # Minimum and maximum shown right y value
    attr_reader :right_y_min, :right_y_max
    # Extra horizontal lines
    attr_reader :horizontal_lines

    #########################################################################
    # Public Interface Methods
    #########################################################################

    def initialize(parent = nil)
      super(parent)

      #######################################################################
      # Initialize configurable attributes to default values
      #######################################################################
      @point_size = 5
      @show_lines = true
      @show_x_grid_lines = false
      @manual_x_grid_line_scale = nil
      @show_y_grid_lines = false
      @manual_y_grid_line_scale = nil
      @show_legend = false
      @show_cursor_and_popups = true
      @frame_color = 'black'
      @frame_size = 0
      @back_color = 'white'
      @graph_back_color = 'grey'
      @label_and_border_color = 'black'
      @title = nil
      @x_axis_title = nil
      @left_y_axis_title = nil
      @right_y_axis_title = nil
      @max_x_characters = 15
      @max_y_characters = 8
      @minimum_width = 250
      @minimum_height = 100
      @error = nil
      @ordered_x_values = true
      @show_popup_x_y = false
      @unix_epoch_x_values = true
      @utc_time = false
      @legend_position = :bottom # :bottom or :right

      # Initialize the callbacks
      @draw_cursor_line_callback = nil
      @mouse_leave_callback = nil
      @mouse_left_button_press_callback = nil
      @pre_error_callback = nil
      @post_error_callback = nil

      #######################################################################
      # Initialize read-only attributes to default values
      #######################################################################

      @x_max = 1
      @x_min = -1
      @x_max_label = nil
      @x_min_label = nil
      @left_y_max = 1
      @left_y_min = -1
      @right_y_max = 1
      @right_y_min = -1
      @horizontal_lines = []

      ###########################
      # Initialize internal state
      ###########################

      # Create line data
      @lines = Lines.new

      # Painter to do all the drawing with
      @painter = nil

      # Value used to scale a x value to a x graph coordinate
      @x_scale = 0

      # Value used to scale a left y value to a y graph coordinate
      @left_y_scale = 0

      # Value used to scale a right y value to a y graph coordinate
      @right_y_scale = 0

      # Size of the font used to display text
      @font_size = 10

      # The font class used to display text
      @font = Cosmos.getFont("Helvetica", @font_size)

      # The font class used for titles
      @title_font = Cosmos.getFont("Helvetica", @font_size + 4, Qt::Font::Bold)

      # Auto scale left y-axis setting
      @left_y_auto_scale = true

      # Auto scale right y-axis setting
      @right_y_auto_scale = true

      # Auto scale x-axis setting
      @x_auto_scale = true

      # Values of x gridlines
      @x_grid_lines = []

      # Values of y gridlines on left x-axis unless no left lines
      @y_grid_lines = []

      # Distance between gridlines on the left y-axis unless no left lines
      @y_grid_line_scale = 0.1

      # Distance between gridlines on the x-axis
      @x_grid_line_scale = 0.1

      # Flag to note if the mouse in the the graph window
      @mouse_in_window = false

      # Graph right boundary in window coordinates
      @graph_right_x = 0

      # Graph left boundary in window coordinates
      @graph_left_x = 0

      # Graph top boundary in window coordinates
      @graph_top_y = 0

      # Graph bottom boundary in window coordinates
      @graph_bottom_y = 0

      # Array containing popup information
      @popups = []

      # Position of cursor line
      @cursor_line_x = nil

      # Indicates state of left mouse button
      @left_button_pressed = false

      # Flag to prevent recursion in update_graph_size
      @in_update_graph_size = false

      # Time of previous left button release
      @previous_left_button_release_time = Time.now.sys

      # List of line colors to use
      @color_list = ['blue','red','green','darkorange', 'gold', 'purple', 'hotpink', 'lime', 'cornflowerblue', 'brown', 'coral', 'crimson', 'indigo', 'tan', 'lightblue', 'cyan', 'peru', 'maroon','orange','navy','teal','black']

      @redraw_needed = true

      setContentsMargins(0,0,0,0)

      #setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff)
      #setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOff)

      # Cause this widget to have a white background which we don't have to worry about painting
      # This may leak memory - but it is only in initialize so that is ok.
      p = palette()
      p.setBrush(Qt::Palette::Active, Qt::Palette::Window, Cosmos.getBrush(Qt::white))
      setPalette(p)
      setBackgroundRole(Qt::Palette::Window)
      setAutoFillBackground(true)

      update_graph_size()

      setMouseTracking(true) # enable mouseMoveEvents even when the mouse isn't pressed
    end # def initialize

    # Once a GraphicsView is displayed the size hint it set based on the initial display size.
    # This causes a single GraphicsView in a layout takes to take a very large size hint.
    # If this GraphicsView is then added to a new layout it will continue to remember that size hint
    # and force other Widgets in that layout to be smaller than we want.
    # Thus we set the sizeHint to 0 and allow the layout manager to do the right thing
    #~ def sizeHint
      #~ return Qt::Size.new(100, 100)
    #~ end

    # Handler for leaveEvent
    def leaveEvent(event)
      # Note that the mouse is no longer in the window
      @mouse_in_window = false

      # Clear cursor line
      @cursor_line_x = nil

      # Redraw the graph (to remove popups and cursor line)
      graph()

      # Call mouse_leave_callback so that cursor lines can be removed from
      # other line graphs if needed
      @mouse_leave_callback.call(self) if @mouse_leave_callback
    end # def leaveEvent

    # Handler for mouseMoveEvent
    def mouseMoveEvent(event)
      # Note that the mouse is in the window
      @mouse_in_window = true

      # Redraw the graph (to update popups and cursor line)
      graph()
    end # def mouseMoveEvent

    # Handler for mousePressEvent
    def mousePressEvent(event)
      # Note that the left button is pressed
      @left_button_pressed = true

      @mouse_left_button_press_callback.call(self) if @mouse_left_button_press_callback

      # Redraw the graph (to update popups)
      graph()
    end # def mousePressEvent

    def mouseReleaseEvent(event)
      left_button_release_time = Time.now.sys

      if @error and ((left_button_release_time - @previous_left_button_release_time) < DOUBLE_CLICK_SECONDS)
        @pre_error_callback.call(self) if @pre_error_callback
        if @error.is_a? FatalError
          ExceptionDialog.new(self, @error, 'LineGraph', false, false) # don't log it, it is known
        else
          ExceptionDialog.new(self, @error, 'LineGraph', false, true) # log the error
        end
        @post_error_callback.call(self) if @post_error_callback
        @error = nil
      end

      # Note that the left button is not pressed
      @left_button_pressed = false

      # Redraw the graph (to update popups)
      graph()

      # Update Previous left button release time
      @previous_left_button_release_time = left_button_release_time
    end

    # Handler for paintEvent
    def paintEvent(event)
      return if @painter
      @painter = Qt::Painter.new(self)
      @painter.setFont(@font)
      # Seems like on initialization sometimes we get some weird bad conditions so check for them
      if @painter.isActive and @painter.paintEngine
        draw_graph_into_back_buffer() if @redraw_needed
        draw_graph_to_screen()
      end
      @painter.dispose
      @painter = nil
    end

    # Handler for ResizeEvent
    def resizeEvent(event)
      # Update internal buffer to new graph size
      update_graph_size()

      # Force a complete redraw of the graph to handle the new size
      @redraw_needed = true
      graph()
    end # def resizeEvent

    # Clears all knowledge of line data - the graph is a clean slate
    def clear_lines
      @lines.clear
      @redraw_needed = true
    end # def clear_lines

    # Adds a line to the graph - Afterwards the graph is ready to be drawn
    #  color = 'auto' automatically determines color from index based lookup
    def add_line(legend_text, y, x = nil, y_labels = nil, x_labels = nil, y_states = nil, x_states = nil, color = 'auto', axis = :LEFT, max_points_plotted = nil)
      @unix_epoch_x_values = false unless x

      # if color specified as auto, do lookup
      if (color == 'auto')
        # If the number of lines is less than number of available colors,
        #   choose an unused color
        if (@lines.num_lines < @color_list.length)
          unused_colors = @color_list.dup
          @lines.legend.each do |name, line_color, axis|
            unused_colors.delete(line_color)
          end
          color = unused_colors[0]
        else
          # Get an index within the color list for the next line index
          line_color_idx = @lines.num_lines % (@color_list.length)
          color = @color_list[line_color_idx]
        end
      end

      @lines.add_line(legend_text, y, x, y_labels, x_labels, y_states, x_states, color, axis, max_points_plotted)

      # Adding a line implies a redraw is needed
      @redraw_needed = true
    end # def add_line

    # Draws the graph
    def graph
      method_missing(:update)
    end

    # Start auto scaling of the x axis
    def auto_scale_x
      @x_auto_scale  = true
      @redraw_needed = true
      graph()
    end # def auto_scale_x

    # Start auto scaling of the y axis
    def auto_scale_y(axis)
      if axis == :LEFT
        @left_y_auto_scale = true
      else # axis == :RIGHT
        @right_y_auto_scale = true
      end
      @redraw_needed = true
      graph()
    end # def auto_scale_y

    # Start manual scaling of x axis
    def manual_scale_x(x_min, x_max, redraw_now = true)
      if x_min <= x_max
        @x_max = x_max
        @x_min = x_min
        @x_max_label = nil
        @x_min_label = nil
        @x_auto_scale = false
      else
        Kernel.raise ArgumentError, "GraphView Manual X Max must be greater than X Min"
      end
      @redraw_needed = true
      graph() if redraw_now
    end # def manual_scale_x

    # Start manual scaling of y axis
    def manual_scale_y(y_min, y_max, axis)
      if y_min < y_max
        if axis == :LEFT
          @left_y_auto_scale = false
          @left_y_max        = y_max
          @left_y_min        = y_min
        else
          @right_y_auto_scale = false
          @right_y_max        = y_max
          @right_y_min        = y_min
        end
      else
        Kernel.raise ArgumentError, "GraphView Manual Y Max must be greater than Y Min"
      end
      @redraw_needed = true
      graph()
    end # def manual_scale_y

    # Set the cursor position remotely
    def remote_draw_cursor_line_at_x(x, left_button_pressed)
      @cursor_line_x = x
      @left_button_pressed = left_button_pressed
      graph()
    end # def remote_draw_cursor_line_at_x

    # Clears all horizontal lines on the graph
    def clear_horizontal_lines
      @horizontal_lines = []
      @redraw_needed = true
    end

    # Add a horizontal line to the graph
    def add_horizontal_line(y_value, color, axis = :LEFT)
      @horizontal_lines << [y_value, color, axis]
      @redraw_needed = true
    end
  end
end
