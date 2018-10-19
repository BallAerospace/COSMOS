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
  class CanvasimagevalueWidget #< CanvasvalueWidget
    include Widget
    include CanvasClickable

    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :CONVERTED, default_image = nil, x = nil, y = nil)
      super(target_name, packet_name, item_name, value_type)
      @images = []
      @target_screen_dir = File.join(::Cosmos::USERPATH, 'config', 'targets', target_name.upcase, 'screens')
      @cosmos_data_dir = File.join(::Cosmos::USERPATH, 'config', 'data')

      if default_image
        @default_image = get_image(default_image)
        @default_x = Integer(x)
        @default_y = Integer(y)
      end

      @parent_layout = parent_layout
      @parent_layout.add_repaint(self)
    end

    def self.takes_value?
      return true
    end

    def paint(painter)
      eval(@eval)
    end

    def dispose
      super()
      @images.each {|image| image.dispose }
      @default_image.dispose if @default_image
    end

    def set_setting(setting_name, setting_values)
      if setting_name.upcase == 'RAW'
        @settings['RAW'] = [@settings['RAW'][0] + setting_values[0]]
      # Allow for multiple IMAGE settings by deconflicting the hash key by appending the value
      elsif setting_name.upcase == 'IMAGE'
        @settings["#{setting_name.to_s.upcase}_#{setting_values[0]}"] = setting_values
      else
        @settings[setting_name.to_s.upcase] = setting_values
      end
    end

    def process_settings
      super
      @eval = 'case @value;'
      @settings.each do |setting_name, setting_values|
        begin
          case setting_name
          when /IMAGE/
            @images << get_image(setting_values[1])
            value_string = setting_values[0]
            value = nil
            begin
              value = Integer(value_string)
            rescue
              if value_string.include?('..') # Range
                value = Range.new(*value_string.split("..").map(&:to_i))
              else
                value = "'#{value_string}'"
              end
            end
            @eval << "when #{value} then painter.drawImage(#{setting_values[2]}, #{setting_values[3]}, @images[#{@images.length-1}]);"
          end
        rescue => err
          puts "Error Processing Settings!: #{err}"
        end
      end
      if @default_image
        @eval << "else painter.drawImage(@default_x, @default_y, @default_image);"
      end
      @eval << "end"
    end

    protected

    def get_image(image_name)
      if File.exist?(File.join(@target_screen_dir, image_name))
        return Qt::Image.new(File.join(@target_screen_dir, image_name))
      elsif File.exist?(File.join(@cosmos_data_dir, image_name))
        return Qt::Image.new(File.join(@cosmos_data_dir, image_name))
      else
        raise "Can't find the file #{image_name} in #{@target_screen_dir} or #{@cosmos_data_dir}"
      end
    end
  end
end
