# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'

module Cosmos

  module AgingWidget

    attr_accessor :coloring

    def setup_aging
      @previous_value = 0
      @gray_level = 255
      @enable_aging = true
      @min_gray = 200
      @gray_rate = 3
      @gray_tolerance = nil
      @colorblind = false
      @coloring = true
      @foreground = Cosmos::BLACK
      @background = Cosmos::WHITE
    end

    module ClassMethods
      def takes_value?
        return true
      end
    end
    def self.included(base)
      base.extend(ClassMethods)
    end

    def value=(data, text = nil)
      text = data.to_s unless text

      if @coloring
        case @limits_state
        when :RED, :RED_HIGH
          @foreground = Cosmos::RED
          text << ' (R)' if @colorblind
        when :RED_LOW
          @foreground = Cosmos::RED
          text << ' (r)' if @colorblind
        when :YELLOW, :YELLOW_HIGH
          @foreground = Cosmos::YELLOW
          text << ' (Y)' if @colorblind
        when :YELLOW_LOW
          @foreground = Cosmos::YELLOW
          text << ' (y)' if @colorblind
        when :GREEN, :GREEN_HIGH
          @foreground = Cosmos::GREEN
          text << ' (G)' if @colorblind
        when :GREEN_LOW
          @foreground = Cosmos::GREEN
          text << ' (g)' if @colorblind
        when :BLUE
          @foreground = Cosmos::BLUE
          text << ' (B)' if @colorblind
        when :STALE
          @foreground = Cosmos::PURPLE
          text << ' ($)' if @colorblind
        else
          @foreground = Cosmos::BLACK
        end
      end

      # Implement Telemetry Aging
      if @enable_aging
        if (@previous_value == data) ||
          (@gray_tolerance && ((@previous_value.to_f - data.to_f).abs <= @gray_tolerance))
          @gray_level -= @gray_rate
          @gray_level = @min_gray if @gray_level < @min_gray
        else
          @gray_level = 255
        end
        @background = Cosmos::getColor(@gray_level, @gray_level, @gray_level)
        @previous_value = data
      end
      text
    end

    def process_aging_settings
      @settings.each do |setting_name, setting_values|
        case setting_name.upcase
        when 'GRAY_RATE', 'GREY_RATE'
          gray_rate = settings_values[0].to_i
          @gray_rate = gray_rate
        when 'MIN_GRAY', 'MIN_GREY'
          gray = setting_values[0].to_i
          @min_gray = gray unless gray < 0
        when 'ENABLE_AGING'
          enable_aging = ConfigParser::handle_true_false(setting_values[0])
          @enable_aging = enable_aging
        when 'COLORBLIND'
          @colorblind = ConfigParser::handle_true_false(setting_values[0])
        end
      end
    end

  end

end # module Cosmos
