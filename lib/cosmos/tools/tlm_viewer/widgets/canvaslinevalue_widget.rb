# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the CanvaslinevalueWidget class.  This
# widget displays a line within a CanvasWidget.  The color of the line depends
# on the telemetry point value of 1 or 0 for 'on' or 'off' respectively.

require 'cosmos/tools/tlm_viewer/widgets/canvasvalue_widget'

module Cosmos
  # Draws a line on the canvas that changes color based on the value of the
  # given telemetry point. Typically used to either show to hide the line
  # by drawing it as the same color as the canvas. For example:
  #   CANVASLINEVALUE INST HEALTH_STATUS GROUND1STATUS 420 135 240 330 green white 3
  class CanvaslinevalueWidget < CanvasvalueWidget
    def initialize(parent_layout, target_name, packet_name, item_name, x1, y1, x2, y2, color_on = 'green', color_off = 'blue', width = 3, connector = 'NO_CONNECTOR', value_type = :RAW)
      super(parent_layout, target_name, packet_name, item_name, value_type)
      @x1 = x1.to_i
      @y1 = y1.to_i
      @x2 = x2.to_i
      @y2 = y2.to_i
      @point = Qt::Point.new(@x2, @y2)
      if connector.to_s.upcase == 'CONNECTOR'
        @connector = true
      else
        @connector = false
      end
      @color_on = Cosmos::getColor(color_on)
      @color_off = Cosmos::getColor(color_off)
      @pen_on = Cosmos::getPen(color_on)
      @pen_off = Cosmos::getPen(color_off)
      @width = width.to_i
    end

    def draw_widget(painter, on_state)
      painter.save
      if (on_state == true)
        pen = @pen_on
        color = @color_on
      else
        pen = @pen_off
        color = @color_off
      end

      pen.setWidth(@width)
      painter.setPen(pen)
      painter.drawLine(@x1, @y1, @x2, @y2)
      if (@connector == true)
        painter.setBrush(color)
        painter.drawEllipse(@point, @width, @width)
      end
      painter.restore
    end

    def dispose
      super()
      @point.dispose
    end
  end
end
