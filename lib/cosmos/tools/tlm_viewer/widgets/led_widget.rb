# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'ostruct'
require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos
  # This class implements a LED which changes color based on telemetry values.
  # By default TRUE is green and FALSE is red and all other values are black.
  # Additional values can be added by using the LED_COLOR setting. For example:
  #   LED INST PARAMS VALUE3 RAW
  #     SETTING LED_COLOR 0 GREEN
  #     SETTING LED_COLOR 1 RED
  #     SETTING LED_COLOR ANY ORANGE # All other values are ORANGE
  class LedWidget < Qt::Label
    include Widget

    def self.takes_value?
      return true
    end

    @@brushes = {}

    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :CONVERTED, width = 15, height = 15)
      super(target_name, packet_name, item_name, value_type)
      @width = width.to_i
      @height = height.to_i
      # Add some sensible defaults, all others must be added using settings
      @colors = {"TRUE" => "green", "FALSE" => "red"}
      @painter = nil
      @color = nil
      @brush = nil
      setFixedSize(width.to_i + 3, height.to_i + 3)
      parent_layout.addWidget(self) if parent_layout
    end

    # Override set_setting so we can deconflict the LED_COLOR settings
    # and allow the user to use it multiple times. By default each time
    # a SETTING name is used it overrides the previous setting.
    def set_setting(setting_name, setting_values)
      if setting_name.upcase == 'LED_COLOR'
        @settings["#{setting_name.upcase}_#{setting_values.join('_')}"] = setting_values
      else
        super(setting_name, setting_values)
      end
    end

    def process_settings
      super
      @settings.each do |setting_name, setting_values|
        begin
          if setting_name =~ /^LED_COLOR/
            @colors[setting_values[0]] = setting_values[1]
          end
        rescue => err
          puts "Error Processing Settings!: #{err}"
        end
      end
    end

    def value=(data)
      super(data)
      @color = @colors[data.to_s] # Returns nil if not found
      @color = @colors['ANY'] unless @color # Check for ANY value
      @color = @color ? Cosmos::getColor(@color) : Cosmos::BLACK # default to black
      @brush = @@brushes[@color]
      unless @brush
        gradient = Qt::RadialGradient.new(5, 5, 50, 5, 5)
        gradient.setColorAt(0, @color)
        gradient.setColorAt(1, Cosmos::BLACK)
        @brush = Qt::Brush.new(gradient)
        @@brushes[@color] = @brush
      end
      update() # Fire the paintEvent handler
    end

    def paintEvent(event)
      begin
        return if @painter
        @painter = Qt::Painter.new(self)
        @painter.setRenderHint(Qt::Painter::Antialiasing, true)
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

    protected

    def paint_implementation(painter)
      painter.setPen(Qt::NoPen)
      painter.setBrush(@brush)
      painter.drawEllipse(1, 1, @width, @height)
    end
  end
end
