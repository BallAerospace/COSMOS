# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the XyDataObjectEditor class.   This class
# provides dialog box content to create/edit xy data objects.

require 'cosmos'
require 'cosmos/tools/tlm_grapher/data_object_editors/data_object_editor'
require 'cosmos/gui/choosers/float_chooser'
require 'cosmos/gui/choosers/combobox_chooser'
require 'cosmos/tools/tlm_grapher/data_objects/xy_data_object'

module Cosmos

  # Widget which creates an editor for a X-Y data object
  class XyDataObjectEditor < DataObjectEditor

    def initialize(parent)
      super(parent)
      @data_object_class = XyDataObject
    end

    def set_data_object(data_object)
      if data_object
        # We are editing data, so make a copy
        data_object = data_object.copy
      else
        # We are creating a new data object
        data_object = @data_object_class.new

        # Default items
        packet = System.telemetry.first_non_hidden
        data_object.target_name = packet.target_name
        data_object.packet_name = packet.packet_name
        data_object.y_item_name = 'RECEIVED_TIMESECONDS'
        data_object.x_item_name = 'RECEIVED_TIMESECONDS'
        data_object.time_item_name = 'RECEIVED_TIMESECONDS'
      end
      super(data_object)

      @local_layout = Qt::VBoxLayout.new
      @local_layout.setContentsMargins(0,0,0,0)

      # Telemetry Chooser for x item
      @telemetry_chooser = TelemetryChooser.new(self, Qt::Vertical, true, false)
      @telemetry_chooser.update
      @telemetry_chooser.set_item(data_object.target_name, data_object.packet_name, data_object.y_item_name)
      @telemetry_chooser.target_changed_callback = method(:target_packet_changed_callback)
      @telemetry_chooser.packet_changed_callback = method(:target_packet_changed_callback)
      @telemetry_chooser.item_changed_callback = method(:y_item_changed_callback)
      @telemetry_chooser.target_label.text = '*Target:'
      @telemetry_chooser.packet_label.text = '*Packet:'
      @telemetry_chooser.item_label.text   = '*Y Item:'
      @local_layout.addWidget(@telemetry_chooser)

      # Chooser for y item
      x_item_names = @telemetry_chooser.item_names
      if data_object.x_item_name
        x_item_names.delete(data_object.x_item_name)
        x_item_names.unshift(data_object.x_item_name)
      end
      @x_item_name = ComboboxChooser.new(self, '*X Item:', x_item_names)
      @x_item_name.sel_command_callback = method(:x_item_changed_callback)
      @local_layout.addWidget(@x_item_name)

      # Chooser for time item
      time_item_names = @telemetry_chooser.item_names
      if data_object.time_item_name
        time_item_names.delete(data_object.time_item_name)
        time_item_names.unshift(data_object.time_item_name)
      end
      @time_item_name = ComboboxChooser.new(self, '*Time Item:', time_item_names)
      @local_layout.addWidget(@time_item_name)

      # Chooser for y value type
      value_types = XyDataObject::VALUE_TYPES.clone
      @y_value_type = ComboboxChooser.new(self, '*Y Value Type:', value_types)
      @y_value_type.set_current(data_object.y_value_type.to_s) if data_object.y_value_type
      @local_layout.addWidget(@y_value_type)

      # Chooser for x value type
      value_types = XyDataObject::VALUE_TYPES.clone
      @x_value_type = ComboboxChooser.new(self, '*X Value Type:', value_types)
      @x_value_type.set_current(data_object.x_value_type.to_s) if data_object.x_value_type
      @local_layout.addWidget(@x_value_type)

      # Chooser for dart reduction
      @dart_reduction = ComboboxChooser.new(self, '*DART Reduction:', XyDataObject::DART_REDUCTIONS.map {|x| x.to_s})
      @dart_reduction.set_current(data_object.dart_reduction.to_s) if data_object.dart_reduction
      @local_layout.addWidget(@dart_reduction)

      # Chooser for dart reduced type
      @dart_reduced_type = ComboboxChooser.new(self, '*DART Reduced Type:', XyDataObject::DART_REDUCED_TYPES.map {|x| x.to_s})
      @dart_reduced_type.set_current(data_object.dart_reduced_type.to_s) if data_object.dart_reduced_type
      @local_layout.addWidget(@dart_reduced_type)

      @layout.insertLayout(0, @local_layout)
    end

    # Gets the data object from the editor
    def get_data_object
      data_object = super()
      data_object.target_name = @telemetry_chooser.target_name
      data_object.packet_name = @telemetry_chooser.packet_name
      data_object.y_item_name = @telemetry_chooser.item_name
      begin
        data_object.x_item_name = @x_item_name.string
      rescue Exception
        # No valid y_item_name - should be corrected by callback
      end
      begin
        data_object.time_item_name = @time_item_name.string if @time_item_name
      rescue Exception
        # No valid time_item_name - should be corrected by callback
      end
      data_object.y_value_type = @y_value_type.symbol
      data_object.x_value_type = @x_value_type.symbol
      data_object.dart_reduction = @dart_reduction.symbol
      data_object.dart_reduced_type = @dart_reduced_type.symbol      
      data_object
    end

    protected

    # Handles the target or packet name changing
    def target_packet_changed_callback(target = nil, packet = nil)
      x_item_names = @telemetry_chooser.item_names
      time_item_names = @telemetry_chooser.item_names
      data_object = get_data_object()
      if data_object.x_item_name
        x_item_names.unshift(data_object.x_item_name) if x_item_names.delete(data_object.x_item_name)
      end
      if data_object.time_item_name
        time_item_names.unshift(data_object.time_item_name) if time_item_names.delete(data_object.time_item_name)
      end
      @x_item_name.update_items(x_item_names, false)
      @time_item_name.update_items(time_item_names, false) if @time_item_name
      data_object.target_name = @telemetry_chooser.target_name
      data_object.packet_name = @telemetry_chooser.packet_name
      data_object.y_item_name = @telemetry_chooser.item_name
      data_object.x_item_name = x_item_names[0]
      data_object.time_item_name = time_item_names[0] if @time_item_name
      value_types = XyDataObject::VALUE_TYPES.clone
      value_types.delete(data_object.y_value_type)
      value_types.unshift(data_object.y_value_type)
      @y_value_type.update_items(value_types, false)
      value_types = XyDataObject::VALUE_TYPES.clone
      value_types.delete(data_object.x_value_type)
      value_types.unshift(data_object.x_value_type)
      @x_value_type.update_items(value_types, false)
      dart_reductions = HousekeepingDataObject::DART_REDUCTIONS.map {|x| x.to_s}
      dart_reductions.delete(data_object.dart_reduction.to_s)
      dart_reductions.unshift(data_object.dart_reduction.to_s)
      @dart_reduction.update_items(dart_reductions, false)      
      dart_reduced_types = HousekeepingDataObject::DART_REDUCED_TYPES.map {|x| x.to_s}
      dart_reduced_types.delete(data_object.dart_reduced_type.to_s)
      dart_reduced_types.unshift(data_object.dart_reduced_type.to_s)
      @dart_reduced_type.update_items(dart_reduced_types, false)        
    end

    # Handles the y item name changing
    def y_item_changed_callback(target_name, packet_name, item_name)
      data_object = get_data_object()
      data_object.target_name = @telemetry_chooser.target_name
      data_object.packet_name = @telemetry_chooser.packet_name
      data_object.y_item_name = @telemetry_chooser.item_name
      value_types = XyDataObject::VALUE_TYPES.clone
      value_types.delete(data_object.y_value_type)
      value_types.unshift(data_object.y_value_type)
      @y_value_type.update_items(value_types, false)
      dart_reductions = HousekeepingDataObject::DART_REDUCTIONS.map {|x| x.to_s}
      dart_reductions.delete(data_object.dart_reduction.to_s)
      dart_reductions.unshift(data_object.dart_reduction.to_s)
      @dart_reduction.update_items(dart_reductions, false)      
      dart_reduced_types = HousekeepingDataObject::DART_REDUCED_TYPES.map {|x| x.to_s}
      dart_reduced_types.delete(data_object.dart_reduced_type.to_s)
      dart_reduced_types.unshift(data_object.dart_reduced_type.to_s)
      @dart_reduced_type.update_items(dart_reduced_types, false)        
    end

    # Handles the x item name changing
    def x_item_changed_callback(string)
      if string and !string.empty?
        data_object = get_data_object()
        data_object.x_item_name = string
        value_types = XyDataObject::VALUE_TYPES.clone
        value_types.delete(data_object.x_value_type)
        value_types.unshift(data_object.x_value_type)
        @x_value_type.update_items(value_types, false)
        dart_reductions = XyDataObject::DART_REDUCTIONS.map {|x| x.to_s}
        dart_reductions.delete(data_object.dart_reduction.to_s)
        dart_reductions.unshift(data_object.dart_reduction.to_s)
        @dart_reduction.update_items(dart_reductions, false)      
        dart_reduced_types = XyDataObject::DART_REDUCED_TYPES.map {|x| x.to_s}
        dart_reduced_types.delete(data_object.dart_reduced_type.to_s)
        dart_reduced_types.unshift(data_object.dart_reduced_type.to_s)
        @dart_reduced_type.update_items(dart_reduced_types, false)          
      end
    end

  end # class XyDataObjectEditor

end # module Cosmos
