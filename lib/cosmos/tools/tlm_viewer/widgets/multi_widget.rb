# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'

module Cosmos

  # The MultiWidget module must be included after the Widget module by all widget
  # classes that consist of multiple other COSMOS widgets. It overrides methods
  # in the Widget module to support setting all the subwidgets that comprise
  # the top level widget.
  module MultiWidget
    attr_accessor :widgets

    def initialize(target_name = nil, packet_name = nil, item_name = nil, value_type = :CONVERTED, *args)
      super(target_name, packet_name, item_name, value_type, *args)
      @widgets = []
    end

    def value=(data)
      super(data)
      @widgets.each do |widget|
        widget.value = data
      end
    end

    def screen=(screen)
      super(screen)
      @widgets.each do |widget|
        widget.screen = screen
      end
    end

    def polling_period=(polling_period)
      super(polling_period)
      @widgets.each do |widget|
        widget.polling_period = polling_period
      end
    end

    def limits_state=(limits_state)
      super(limits_state)
      @widgets.each do |widget|
        widget.limits_state = limits_state
      end
    end

    def limits_set=(limits_set)
      super(limits_set)
      @widgets.each do |widget|
        widget.limits_set = limits_set
      end
    end

    def set_setting(setting_name, setting_values)
      super(setting_name, setting_values)
      case setting_name.upcase
      when 'GRAY_RATE', 'GREY_RATE', 'MIN_GRAY', 'MIN_GREY',
        'GRAY_TOLERANCE', 'GREY_TOLERANCE', 'ENABLE_AGING', 'COLORBLIND',
        'TREND_SECONDS'
        # Automatically pass these down to all subwidgets
        @widgets.each do |widget|
          widget.set_setting(setting_name, setting_values)
          if widget.respond_to? :widgets
            widget.widgets.each {|subwidget| subwidget.set_setting(setting_name, setting_values) }
          end
        end
      end
    end

    def set_subsetting(widget_index, setting_name, setting_values)
      if widget_index.to_s.upcase == 'ALL'
        @widgets.each do |widget|
          widget.set_setting(setting_name, setting_values)
          if widget.respond_to? :widgets
            widget.widgets.each {|subwidget| subwidget.set_setting(setting_name, setting_values) }
          end
        end
      else
        # Accessing multiwidget subwidgets of widgets is through colon separated indexes
        indexes = widget_index.split(':')
        widget_index = Integer(indexes[0])
        widget = @widgets[widget_index]
        if widget
          case indexes.length
          when 1
            # If there is a single index we just set this widget
            widget.set_setting(setting_name, setting_values)
          when 2
            # If there are exactly 2 indexes we set the subwidget directly
            widget.widgets[Integer(indexes[1])].set_setting(setting_name, setting_values)
          else
            # If there were more than 2 values we need to pass them down together
            # and let recursion push them to the individual widgets
            widget.widgets[Integer(indexes[1])].set_subsetting(indexes[2..-1].join(':'), setting_name, setting_values)
          end
        end
      end
    end

    def process_settings
      super()
      @widgets.each do |widget|
        widget.process_settings
      end
    end
  end

end # module Cosmos
