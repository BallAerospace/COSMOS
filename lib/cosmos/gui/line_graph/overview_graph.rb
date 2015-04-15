# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/line_graph/line_graph'

module Cosmos

  class OverviewGraph < LineGraph
    DEFAULT_ZOOM_FACTOR = 0.1 # 10 percent
    DEFAULT_PAN_FACTOR  = 0.1 # 10 percent

    # Minimum allowed size of the window in seconds plotted
    attr_accessor :window_min_size
    # Maximum allowed size of the window in seconds plotted
    attr_accessor :window_max_size
    # Callback called when the window changes
    attr_accessor :callback
    # Window size in seconds plotted
    attr_reader :window_size
    # Minimum x value in window
    attr_reader :window_min_x
    # Maximum x value in window
    attr_reader :window_max_x

    def initialize(parent)
      super(parent)
      setMaximumHeight(50)
      setFocusPolicy(Qt::StrongFocus)

      @qt_back_color = Cosmos::getColor(@back_color)

      @point_size = 0

      # Adjust minimum height for overview
      @minimum_height = 50
      @size_hint = Qt::Size.new(0, @minimum_height)
      # Size of the window in value space
      @window_size = 100.0
      # Minimum size of the window
      @window_min_size = 0.0
      # Maximum size of the window
      @window_max_size = nil
      # Minimum window x value
      @window_min_x = 0
      # Maximum window x value
      @window_max_x = 0
      # Flag to indicate if we are currently dragging the window
      @drag_window = false
      # Cursor position at start of drag
      @drag_start_x = nil
      # Variable to hold callback function that indicates the window position
      @callback = nil
      # window_min_x in graph coordinates
      @window_min_start = 0
      # window_max_x in graph coordinates
      @window_max_start = 0
      # Flag to indicate if we are currently dragging the bar
      @drag_bar = false
      # Flag to indicate if the cursor is in the selection window
      @cursor_in_window = false
      # The true maximum x value
      @true_max_x = 0
      @show_cursor_and_popups = false
      @window_left_x = 0
      @window_right_x = 0
    end

    def sizeHint
      return @size_hint
    end

    def set_window_size(new_window_size, use_callback)
      @window_size = new_window_size
      @window_size = @window_min_size if @window_min_size and @window_size < @window_min_size
      @window_size = @window_max_size if @window_max_size and @window_size > @window_max_size
      if @lines.empty?
        @window_max_x = 1.0
        @window_min_x = -1.0
      else
        @window_min_x = @window_max_x - @window_size
      end
      graph(false)
      @callback.call(self) if use_callback and @callback
    end

    # Sets the window size
    def window_size=(new_window_size)
      set_window_size(new_window_size, true)
    end

    def set_window_pos(window_min_x, window_max_x, use_callback)
      @window_min_x = window_min_x
      @window_max_x = window_max_x
      @callback.call(self) if use_callback and @callback
    end

    def drag_window(x)
      @cursor = Qt::Cursor.new(Qt::ClosedHandCursor)
      self.setCursor(@cursor)

      # Calculate the movement in terms of the graph coordinates (not the x values)
      temp_min = (@window_min_start + (x - @drag_start_x))
      temp_max = (@window_max_start + (x - @drag_start_x))

      # Only graph if the user hasn't dragged the window outside the graph
      if temp_min >= @graph_left_x and temp_max <= @graph_right_x
        #Now convert the graph coordinates back to the x values
        @window_min_x = scale_graph_to_value_x(temp_min)
        @window_max_x = scale_graph_to_value_x(temp_max)
      else # The user dragged outside the allowable area
        if temp_min < @graph_left_x
          @window_min_x = @x_min
          @window_max_x = @x_min + @window_size
        elsif temp_max > @graph_right_x
          @window_max_x = scale_graph_to_value_x(@graph_right_x)
          @window_min_x = @window_max_x - @window_size
        end
      end
      @window_min_x = @x_min if @window_min_x < @x_min
      @window_max_x = @x_max if @window_max_x > @x_max
      @redraw_needed = true
      graph()
    end

    def drag_bar(x)
      if @cursor_on_bar == :LEFT
        temp_min = (@window_min_start + (x - @drag_start_x))
        temp_max = @window_max_start
      else
        temp_min = @window_min_start
        temp_max = (@window_max_start + (x - @drag_start_x))
      end

      value_temp_min = scale_graph_to_value_x(temp_min)
      value_temp_max = scale_graph_to_value_x(temp_max)

      # Verify the left bar hasn't moved past the minimum size
      if value_temp_min > (@window_max_x - @window_min_size)
        @window_min_x = @window_max_x - @window_min_size
      # Verify the left bar hasn't moved past the maximum size
      elsif @window_max_size and value_temp_min < (@window_max_x - @window_max_size)
        @window_min_x = @window_max_x - @window_max_size
      else
        @window_min_x = value_temp_min
      end

      # Verify the left bar hasn't been moved past the end
      if scale_value_to_graph_x(@window_min_x) < @graph_left_x
        @window_min_x = @x_min
      end

      # Verify the right bar hasn't moved past the minimum size
      if value_temp_max < (@window_min_x + @window_min_size)
        @window_max_x = @window_min_x + @window_min_size
      # Verify the right bar hasn't moved past the maximum size
      elsif @window_max_size and value_temp_max > (@window_min_x + @window_max_size)
        @window_max_x = @window_min_x + @window_max_size
      else
        @window_max_x = value_temp_max
      end

      # Verify the right bar hasn't been moved past the end
      if scale_value_to_graph_x(@window_max_x) > @graph_right_x
        @window_max_x = @x_max
      end

      # Update window size
      @window_min_x = @x_min if @window_min_x < @x_min
      @window_max_x = @x_max if @window_max_x > @x_max
      @window_size = @window_max_x - @window_min_x

      @redraw_needed = true
      graph()
    end

    def drag_lasso(x)
      if (x - @drag_start_x).abs > 5
        @drag_bar = true
        @window_min_start = @drag_start_x
        @window_max_start = @drag_start_x
        if x > @drag_start_x
          @cursor_on_bar = :RIGHT
        else
          @cursor_on_bar = :LEFT
        end
      end
    end

    def show_cursor(x)
      # Initially set the variables so the cursor isn't anywhere special
      @cursor_on_bar = nil
      @cursor_in_window = false

      # Figure out if the mouse is inside the graph so we show the Hand cursor
      gx = scale_graph_to_value_x(x)

      # Allow the user to drag the white window bars to increase the main view width
      if (scale_value_to_graph_x(@window_min_x) - x).abs < 5
        @cursor = Qt::Cursor.new(Qt::SizeHorCursor)
        self.setCursor(@cursor)
        @cursor_on_bar = :LEFT
      elsif (scale_value_to_graph_x(@window_max_x) - x).abs < 5
        @cursor = Qt::Cursor.new(Qt::SizeHorCursor)
        self.setCursor(@cursor)
        @cursor_on_bar = :RIGHT
      elsif (@window_min_x) < gx and gx < (@window_max_x)
        @cursor = Qt::Cursor.new(Qt::OpenHandCursor)
        self.setCursor(@cursor)
        @cursor_in_window = true
      else
        self.unsetCursor()
      end
    end

    # Handles the mouse moving over the overview graph
    def mouseMoveEvent(event)
      super(event)
      # Get the cursor position
      x = mapFromGlobal(self.cursor.pos).x

      if @drag_window
        drag_window(x)
      elsif @drag_bar # We're in the middle of moving one of the window bars
        drag_bar(x)
      elsif @drag_start_x # Lasso start
        drag_lasso(x)
      else # We're not dragging the window, the user just moused around so show the right cursor
        show_cursor(x)
      end
    end

    # Handler for leaveEvent
    def leaveEvent(event)
      super(event)
      self.unsetCursor()
      @cursor_in_window = false
      @cursor_on_bar = nil
      @drag_start_x = nil
      @drag_bar = false
      @drag_window = false
    end # def leaveEvent

    # Handles the left button being pressed in the overview graph
    def mousePressEvent(event)
      super(event)

      # Store off the mouse click x coordinate on the graph and the window x coordinates
      @drag_start_x = mapFromGlobal(self.cursor.pos).x
      @window_min_start = scale_value_to_graph_x(@window_min_x)
      @window_max_start = scale_value_to_graph_x(@window_max_x)
      @drag_window = true if @cursor_in_window
      @drag_bar = true if @cursor_on_bar
    end

    # Handles the left button being released
    def mouseReleaseEvent(event)
      self.unsetCursor()
      if !(@drag_bar or @drag_window) and @drag_start_x
        # Figure out what x value the click corresponds to
        xpoint = scale_graph_to_value_x(@drag_start_x)

        # Move the window values to make them equidistant from the click
        @window_min_x = xpoint - @window_size / 2
        @window_max_x = xpoint + @window_size / 2

        # Ensure we don't put the window outside the graphable points
        if @window_min_x < @x_min
          @window_min_x = @x_min
          @window_max_x = @x_min + @window_size
        elsif @window_max_x > @x_max
          @window_max_x = @x_max
          @window_min_x = @x_max - @window_size
        end

        @drag_window = true
        @redraw_needed = true
        graph()
        @drag_window = false
      end

      @drag_start_x = nil
      @drag_bar = false
      @drag_window = false
      @callback.call(self) unless @callback.nil?
    end

    # Draws the overview graph
    def graph(move_window = false)
      @move_window = move_window
      determine_graph_size()
      scale_graph()
      calculate_scaling_factors()
      calculate_window_lines()
      super()
    end

    def back_color=(value)
      super(value)
      @qt_back_color = Cosmos::getColor(@back_color)
    end

    def zoom(zoom_factor)
      @window_size = @window_size * zoom_factor
      @window_size = @window_min_size if @window_min_size and @window_size < @window_min_size
      @window_size = @window_max_size if @window_max_size and @window_size > @window_max_size
      if @lines.empty?
        @window_max_x = 1.0
        @window_min_x = -1.0
      else
        center = (@window_max_x + @window_min_x) / 2
        @window_min_x = center - @window_size / 2
        @window_max_x = center + @window_size / 2
      end
      @window_min_x = @x_min if @window_min_x < @x_min
      @window_max_x = @x_max if @window_max_x > @x_max
      @drag_window = true
      @redraw_needed = true
      graph()
      @drag_window = false
      @callback.call(self) if @callback
    end

    def zoom_in
      zoom(1 - DEFAULT_ZOOM_FACTOR)
    end

    def zoom_out
      zoom(1 + DEFAULT_ZOOM_FACTOR)
    end

    def pan(amount)
      # Move the window values to make them equidistant from the click
      new_window_min_x = @window_min_x + amount
      new_window_max_x = @window_max_x + amount

      # Ensure we don't put the window outside the graphable points
      if new_window_min_x >= @x_min and new_window_max_x <= @x_max
        @window_min_x = new_window_min_x
        @window_max_x = new_window_max_x
      elsif new_window_min_x < @x_min
        @window_min_x = @x_min
        @window_max_x = @x_min + @window_size
      else
        @window_min_x = @x_max - @window_size
        @window_max_x = @x_max
      end
      @window_min_x = @x_min if @window_min_x < @x_min
      @window_max_x = @x_max if @window_max_x > @x_max

      @drag_window = true
      @redraw_needed = true
      graph()
      @drag_window = false
      @callback.call(self) unless @callback.nil?
    end

    def pan_left
      pan(-@window_size * DEFAULT_PAN_FACTOR)
    end

    def pan_right
      pan(@window_size * DEFAULT_PAN_FACTOR)
    end

    def keyPressEvent(event)
      case event.key
      when Qt::Key_Up
        zoom_in()
      when Qt::Key_Down
        zoom_out()
      when Qt::Key_Left
        pan_left()
      when Qt::Key_Right
        pan_right()
      end
      super(event)
    end

    def focusInEvent(event)
      self.frame_color = 'gray'
      update()
    end

    def focusOutEvent(event)
      self.frame_color = 'black'
      update()
    end

    protected

    # Draws the graph lines into a buffer

    def draw_graph_into_back_buffer
      # Draw overall graph and origin lines and graph lines
      draw_graph_background(@painter)
      draw_origin_lines(@painter)
      draw_lines(@painter, :LEFT)

      draw_selection_window(@painter)
      draw_frame(@painter)
    end

    # Determines the size of the displayed graph
    def determine_graph_size
      @graph_left_x = GRAPH_SPACER
      @graph_right_x = width - GRAPH_SPACER - 1
      @graph_top_y = GRAPH_SPACER
      @graph_bottom_y = height - GRAPH_SPACER - 1
    end

    # Draws the selection window
    def draw_selection_window(dc)
      # Draw window area without stipple
      dc.addRectColor(@graph_left_x, 1, @window_left_x - @graph_left_x, height() - 2, @qt_back_color)
      dc.addRectColor(@window_right_x, 1, @graph_right_x - @window_right_x, height() - 2, @qt_back_color)

      # Draw window lines
      dc.addLineColor(@window_left_x,  0, @window_left_x,  height(), @label_and_border_color)
      dc.addLineColor(@window_right_x, 0, @window_right_x, height(), @label_and_border_color)
    end

    def calculate_window_lines
      # Determine positions of window lines
      # If we're dragging the window then we draw the lines exactly as they have been
      # set by the mouse click and mouse drag event handler
      if @drag_window or @drag_bar or not @move_window
        # The window lines are in terms of the graph x values so convert to the graph coordinate system
        @window_left_x = scale_value_to_graph_x(@window_min_x)
        @window_left_x = @graph_left_x if @window_left_x < @graph_left_x
        @window_left_x = @graph_right_x if @window_left_x > @graph_right_x
        @window_right_x = scale_value_to_graph_x(@window_max_x)
        @window_right_x = @graph_right_x if @window_right_x > @graph_right_x
        @window_right_x = @graph_left_x if @window_right_x < @graph_left_x
      else # If we're not dragging the window we want to adjust the window lines automatically
        @window_max_x = @x_max

        # Graph the right window bounds line
        @window_right_x = scale_value_to_graph_x(@window_max_x)
        @window_right_x = @graph_right_x if @window_right_x > @graph_right_x

        # Graph the left window bounds line
        if @x_min == @x_max
          @window_min_x = @x_min - 1.0
          @window_max_x = @x_max + 1.0
        end
        if (@x_max - @x_min) > @window_size
          # Once we have enough points the left line trails the right by the size of the window
          @window_min_x = @window_max_x - @window_size
          @window_left_x = scale_value_to_graph_x(@window_min_x)
          @window_left_x = @graph_left_x if @window_left_x < @graph_left_x
        else # Initially we don't have enough points so the left line is at the GRAPH_SPACER
          @window_min_x = @x_min
          @window_max_x = @x_max
          @window_left_x = GRAPH_SPACER
        end
      end
    end

  end # class OverviewGraph

end # module Cosmos
