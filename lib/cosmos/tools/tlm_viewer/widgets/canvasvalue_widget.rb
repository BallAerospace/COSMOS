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

  class CanvasvalueWidget
    include Widget

    def initialize(parent_layout, target_name, packet_name, item_name, value_type = :RAW)
      super(target_name, packet_name, item_name, value_type)
      @comparison = 'EQ'
      @comparison_value = 1
      @items = []
      @item_settings = [['and', '==', 1]] # set the default settings
      @values = [0] # initialize to a value
      @items << [@target_name, @packet_name, @item_name] # grab the default item
      @parent_layout = parent_layout
      parent_layout.add_repaint(self)
    end

    def self.takes_value?
      return true
    end

    def value=(data)
      # If we have multiple items then we need to explicitly get all the items
      if @items.length > 1
        values, _, _, _ = get_tlm_values(@items, @value_type)
        if values != @values
          @values = values
          @parent_layout.update_widget
        end
      # If we only have one item we just use the passed in data
      else
        if @values[0] != data
          @values[0] = data
          @parent_layout.update_widget
        end
      end
    end

    def paint(painter)
      eval_string = "1"
      # This code uses the booleans set by the process_settings function and evaluates it to logically determine
      # if the item should be drawn on the canvas as "on" or "off".
      begin
        @item_settings.each_with_index do |item,index|
          eval_string << " " << item[0].to_s << " (" << @values[index].to_s << " " << item[1].to_s << " " << item[2].to_s << ")"
        end
        on = eval(eval_string)
      rescue => err
        Cosmos.handle_fatal_exception(err)
      end
      draw_widget(painter, on)
    end

    # This is an abstract function which must be overriden
    def draw_widget(draw_context, on_state)
      raise 'Override draw_widget to make this class work!'
    end

    def process_settings
      super
      @settings.each do |setting_name, setting_values|
        begin
          case setting_name
          when 'VALUE_EQ'
            @item_settings[0] = ['and', '==', setting_values[0]]
          when 'VALUE_GT'
            @item_settings[0] = ['and', '>', setting_values[0]]
          when 'VALUE_GTEQ'
            @item_settings[0] = ['and', '>=', setting_values[0]]
          when 'VALUE_LT'
            @item_settings[0] = ['and', '<', setting_values[0]]
          when 'VALUE_LTEQ'
            @item_settings[0] = ['and', '<=', setting_values[0]]
          # TLM_AND allows a telemetry item to be dependant on another item for its state
          when 'TLM_AND'
            @items << [setting_values[0], setting_values[1], setting_values[2]]
            @values << 0
            set_item_settings('and', setting_values[3], setting_values[4])
          # TLM_OR allows a telemetry item to be dependant on another item for its state
          when 'TLM_OR'
            @items << [setting_values[0], setting_values[1], setting_values[2]]
            @values << 0
            set_item_settings('or', setting_values[3], setting_values[4])
          end
        rescue => err
          puts "Error Processing Settings!: #{err}"
        end
      end
    end

    def set_item_settings(and_or_string, type, value)
      # Handle nil or empty input variables
      and_or_string = 'and' if and_or_string.nil? or and_or_string.empty?
      value = 1 if value.nil? or value.empty?
      type = 'VALUE_EQ' if type.nil? or type.empty?

      case type
        when 'VALUE_EQ'
          @item_settings << [and_or_string, '==',value]
        when 'VALUE_GT'
          @item_settings << [and_or_string, '>',value]
        when 'VALUE_GTEQ'
          @item_settings << [and_or_string, '>=',value]
        when 'VALUE_LT'
          @item_settings << [and_or_string, '<',value]
        when 'VALUE_LTEQ'
          @item_settings << [and_or_string, '<=',value]
      end
    end
  end

end # module Cosmos
