# encoding: ascii-8bit

# Copyright 2015 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos
  # Displays a circle indicating the given telemetry point's limit state
  # (red, yellow, green, blue). The circle is followed by the telemetry
  # item name unless nil is passed to the full_label_display.
  class LimitscolorWidget < Qt::Label
    include Widget

    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :CONVERTED, radius = 10, full_label_display = false)
      super(target_name, packet_name, item_name, value_type)
      @value_type = :CONVERTED if @value_type == :WITH_UNITS
      full_label_display = ConfigParser::handle_true_false_nil(full_label_display)
      @painter = nil
      @foreground = Cosmos::BLACK
      parent_layout.addWidget(self) if parent_layout
      @font = font()
      metrics = Cosmos.getFontMetrics(@font)
      if full_label_display
        @item_text = "#{@target_name} #{@packet_name} #{@item_name}"
        text_width = metrics.width(@item_text)
      elsif full_label_display == false
        @item_text = @item_name
        text_width = metrics.width(@item_text)
      else # no label
        @item_text = nil
        text_width = 0
      end
      @radius = radius.to_i
      @diameter = @radius * 2
      @text_height = @font.pointSize
      @left_offset = @diameter + 5
      if @text_height > @diameter
        @text_baseline = @text_height
        setFixedSize(text_width + @left_offset, @text_height + 2)
      else
        @text_baseline = @text_height + ((@diameter - @text_height) / 2)
        setFixedSize(text_width + @left_offset, @diameter + 2)
      end
    end

    def self.takes_value?
      return true
    end

    def value=(data)
      super(data)
      case @limits_state
      when :RED, :RED_HIGH, :RED_LOW
        @foreground = 'red'
      when :YELLOW, :YELLOW_HIGH, :YELLOW_LOW
        @foreground = 'yellow'
      when :GREEN, :GREEN_HIGH, :GREEN_LOW
        @foreground = 'lime'
      when :BLUE
        @foreground = 'dodgerblue'
      when :STALE
        @foreground = Cosmos::PURPLE
      else
        @foreground = Cosmos::BLACK
      end
      update()
    end

    def paintEvent(event)
      begin
        super(event)
        return if @painter
        @painter = Qt::Painter.new(self)
        # Seems like on initialization sometimes we get some weird bad conditions so check for them
        if @painter.isActive and @painter.paintEngine
          paint_implementation(@painter)
        end
        @painter.dispose
        @painter = nil
      rescue Exception => err
        Cosmos.handle_fatal_exception(err)
      end
    end

    def paint_implementation(dc)
      dc.setBrush(Cosmos.getBrush(@foreground))
      dc.drawEllipse(0, 0, @diameter, @diameter)
      if @item_text
        dc.setBrush(Cosmos.getBrush(Cosmos::BLACK))
        dc.drawText(@left_offset, @text_baseline, @item_text)
      end
      # Additional drawing for subclasses
      additional_drawing(dc)
    end

    protected

    def additional_drawing(dc)
      # Do nothing
    end
  end
end
