# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_grapher/data_object_editors/linegraph_data_object_editor'
require 'cosmos/gui/choosers/telemetry_chooser'
require 'cosmos/gui/choosers/combobox_chooser'
require 'cosmos/gui/choosers/integer_chooser'
require 'cosmos/tools/tlm_grapher/data_objects/housekeeping_data_object'

module Cosmos

  # Provides dialog box content to create/edit housekeeping data objects.
  class HousekeepingDataObjectEditor < LinegraphDataObjectEditor

    def initialize(parent)
      super(parent)
    end

    def set_data_object(data_object)
      if data_object
        # We are editing data, so make a copy
        data_object = data_object.copy
      else
        # We are creating a new data object
        data_object = HousekeepingDataObject.new

        # Default item to first available in system definition
        packet = System.telemetry.first_non_hidden
        item_name = packet.sorted_items[0].name
        data_object.set_item(packet.target_name, packet.packet_name, item_name)
      end

      local_layout = Qt::VBoxLayout.new
      local_layout.setContentsMargins(0,0,0,0)

      # Telemetry Chooser for housekeeping item
      @telemetry_chooser = TelemetryChooser.new(self, Qt::Vertical, true, false, true)
      @telemetry_chooser.update
      @telemetry_chooser.set_item(data_object.target_name, data_object.packet_name, data_object.item_name)
      @telemetry_chooser.target_changed_callback = method(:target_packet_changed_callback)
      @telemetry_chooser.packet_changed_callback = method(:target_packet_changed_callback)
      @telemetry_chooser.item_changed_callback = method(:item_changed_callback)
      @telemetry_chooser.target_label.text = '*Target:'
      @telemetry_chooser.packet_label.text = '*Packet:'
      @telemetry_chooser.item_label.text   = '*Item:'
      local_layout.addWidget(@telemetry_chooser)

      # Chooser for time item
      time_item_names = @telemetry_chooser.item_names
      @time_item_name = ComboboxChooser.new(self, '*Time Item:', time_item_names)
      if data_object.time_item_name
        @time_item_name.set_current(data_object.time_item_name)
      else
        @time_item_name.set_current('RECEIVED_TIMESECONDS')
      end
      local_layout.addWidget(@time_item_name)

      # Chooser for formatted time item
      formatted_time_item_names = @telemetry_chooser.item_names
      formatted_time_item_names.unshift(' ')
      @formatted_time_item_name = ComboboxChooser.new(self, '*Formatted Time Item:', formatted_time_item_names)
      if data_object.formatted_time_item_name
        @formatted_time_item_name.set_current(data_object.formatted_time_item_name)
      else
        @formatted_time_item_name.set_current(' ')
      end
      local_layout.addWidget(@formatted_time_item_name)

      # Chooser for value type
      @value_type = ComboboxChooser.new(self, '*Value Type:', HousekeepingDataObject::VALUE_TYPES.map {|x| x.to_s})
      @value_type.set_current(data_object.value_type.to_s) if data_object.value_type
      local_layout.addWidget(@value_type)

      # Chooser for analysis type
      @analysis = ComboboxChooser.new(self, '*Analysis Type:', HousekeepingDataObject::ANALYSIS_TYPES.map {|x| x.to_s})
      @analysis.set_current(data_object.analysis.to_s) if data_object.analysis
      local_layout.addWidget(@analysis)

      # Integer Field for analysis samples
      @analysis_samples = IntegerChooser.new(self, '*Analysis Samples:', 0, 2)
      @analysis_samples.value = data_object.analysis_samples if data_object.analysis_samples
      local_layout.addWidget(@analysis_samples)
      @layout.addLayout(local_layout)

      packet, item = System.telemetry.packet_and_item(data_object.target_name,
                                                      data_object.packet_name,
                                                      data_object.item_name)
      if item.limits.values
        choices = ['TRUE', 'FALSE']
        @show_limits_lines = ComboboxChooser.new(self, 'Show Limits Lines:', choices)
        @show_limits_lines.set_current(data_object.show_limits_lines.to_s.upcase)
        @show_limits_lines.sel_command_callback = method(:handle_show_limits_lines_changed)
        local_layout.addWidget(@show_limits_lines)

        @limits_lines = Qt::ColorListWidget.new(self)
        data_object.limits_lines.each do |value, color|
          @limits_lines.addItemColor(value, color)
        end
        @limits_lines.set_read_only
        @limits_lines.resize_to_contents
        @limits_lines.hide unless data_object.show_limits_lines
        @layout.addWidget(@limits_lines)
      else
        @show_limits_lines = nil
        @limits_lines = nil
      end

      super(data_object)
    end

    # Get the data object from the editor
    def get_data_object
      data_object = super()
      data_object.set_item(@telemetry_chooser.target_name,
                           @telemetry_chooser.packet_name,
                           @telemetry_chooser.item_name)
      data_object.time_item_name = @time_item_name.string
      formatted_time_item_name = @formatted_time_item_name.string
      if formatted_time_item_name.strip.empty?
        data_object.formatted_time_item_name = nil
      else
        data_object.formatted_time_item_name = formatted_time_item_name
      end
      data_object.value_type = @value_type.symbol
      data_object.analysis = @analysis.symbol
      data_object.analysis_samples = @analysis_samples.value
      if @show_limits_lines
        data_object.show_limits_lines = ConfigParser.handle_true_false(@show_limits_lines.string)
      else
        data_object.show_limits_lines = false
      end
      data_object
    end

    # Handle the show limits line item changing
    def handle_show_limits_lines_changed(choice)
      if choice == 'TRUE'
        @limits_lines.show
      else
        @limits_lines.hide
      end
    end

    protected

    # Handle the target changing
    def target_packet_changed_callback(target = nil, packet = nil)
      time_item_names = @telemetry_chooser.item_names
      data_object = get_data_object()
      if data_object.time_item_name
        time_item_names.unshift(data_object.time_item_name) if time_item_names.delete(data_object.time_item_name)
      end
      @time_item_name.update_items(time_item_names, false)
      data_object.set_item(@telemetry_chooser.target_name, @telemetry_chooser.packet_name, @telemetry_chooser.item_name)
      value_types = HousekeepingDataObject::VALUE_TYPES.map {|x| x.to_s}
      value_types.delete(data_object.value_type.to_s)
      value_types.unshift(data_object.value_type.to_s)
      @value_type.update_items(value_types, false)
    end

    # Handle the item name changing
    def item_changed_callback(target_name, packet_name, item_name)
      data_object = get_data_object()
      data_object.set_item(@telemetry_chooser.target_name, @telemetry_chooser.packet_name, @telemetry_chooser.item_name)
      value_types = HousekeepingDataObject::VALUE_TYPES.map {|x| x.to_s}
      value_types.delete(data_object.value_type.to_s)
      value_types.unshift(data_object.value_type.to_s)
      @value_type.update_items(value_types, false)
    end

  end # class HousekeepingDataObjectEditor

end # module Cosmos
