# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the CanvasimagevalueWidget class.
# The widget displays a default image but users should use the SETTING IMAGE
# option to set the images to display for a given value.

require 'cosmos/tools/tlm_viewer/widgets/canvasvalue_widget'
require 'cosmos/tools/tlm_viewer/widgets/canvas_clickable'

module Cosmos
  # Displays an image on a canvas based on a telemetry value. Multiple images
  # can be set to display by using the IMAGE setting. For example:
  #   CANVASIMAGEVALUE TGT PKT ITEM CONVERTED "ground_error.gif" 400 100
  #   SETTING IMAGE CONNECTED "ground_on.gif" 400 100
  #   SETTING IMAGE UNAVAILABLE "ground_off.gif" 400 100
  # The default image to display is error.gif. If the converted value from
  # the telemetry point named TGT PKT ITEM has a converted value of
  # 'CONNECTED' the ground_on.gif image is displayed and if the value is
  # 'UNAVAILABLE' the ground_off.git image is displayed.
  class CanvasimagevalueWidget < CanvasvalueWidget
    include CanvasClickable

    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :RAW, default_image = nil, x = nil, y = nil)
      super(parent_layout, target_name, packet_name, item_name, value_type)
      @images = []
      if default_image
        @default_image_name = default_image
        @default_x = Integer(x)
        @default_y = Integer(y)
      end
    end

    def paint(painter)
      if @values.length > 1
        eval_string = "1"
        # This code uses the booleans set by the process_settings function and evaluates it to logically determine
        # if the item should be drawn on the canvas as "on" or "off".
        @item_settings.each_with_index do |item, index|
          next if @values[index].to_f.nan? || @values[index].to_f.infinite?
          eval_string << " " << item[0].to_s << " (" << @values[index].to_s << " " << item[1].to_s << " " << item[2].to_s << ")"
        end
        @value = eval(eval_string)
      else
        @value = @values[0]
      end
      eval(@eval)
    end

    def dispose
      super()
      @images.each {|image| image.dispose }
      @default_image.dispose if @default_image
    end

    def set_setting(setting_name, setting_values)
      # Allow for multiple IMAGE settings by deconflicting the hash key by appending the value
      if setting_name.upcase == 'IMAGE'
        @settings["#{setting_name.to_s.upcase}_#{setting_values[0]}"] = setting_values
      else
        super(setting_name, setting_values)
      end
    end

    def process_settings
      super
      @eval = 'case @value;'
      @settings.each do |setting_name, setting_values|
        case setting_name
        when /IMAGE/
          value_string = setting_values[0]
          @images << get_image(setting_values[1])
          x = setting_values[2]
          y = setting_values[3]

          case value_string.upcase
          when 'TRUE'
            value = true
          when 'FALSE'
            value = false
          when /\d\.\.\d/ # Range
            value = Range.new(*value_string.split("..").map(&:to_i))
          else
            begin
              value = Float(value_string)
            rescue
              value = "'#{value_string}'"
            end
          end
          @eval << "when #{value} then painter.drawImage(#{x}, #{y}, @images[#{@images.length-1}]);"
          @eval << "@x=#{x};@y=#{y};@x_end=@x+@images[#{@images.length-1}].width;@y_end=@y+@images[#{@images.length-1}].height;"
        end
      end
      if @default_image_name
        @default_image = get_image(@default_image_name)
        @eval << "else painter.drawImage(@default_x, @default_y, @default_image);"
        @eval << "@x=@default_x;@y=@default_y;@x_end=@x+@default_image.width;@y_end=@y+@default_image.height;"
      end
      @eval << "end"
    end
  end
end
