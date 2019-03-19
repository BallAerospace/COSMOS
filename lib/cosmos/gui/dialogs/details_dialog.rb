# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/script'

module Cosmos
  # Creates a dialog showing the details about a given command or telemetry
  # item. This class is a base class and should not be instantiated. Use
  # CmdDetailsDialog or TlmDetailsDialog.
  class DetailsDialog < Qt::Dialog
    # @return [Array<DetailsDialog>] Instances of the details dialog
    @@instances = []

    # @param parent [Qt::Dialog] Parent for the dialog
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @param item_name [String] Name of the item
    def initialize(parent, target_name, packet_name, item_name)
      super(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)

      @target_name = target_name
      @packet_name = packet_name
      @item_name = item_name
      @limits_layout = nil
      @limits_labels = {}

      @@instances << self
    end

    def update_limits_checking
      return unless @limits_checking_enabled_label
      begin
        limits_enabled = limits_enabled?(@target_name, @packet_name, @item_name)
      rescue RuntimeError
        # Error most likely due to LATEST packet - Ignore
        limits_enabled = nil
      end
      # Check for nil because true and false are both valid values
      unless limits_enabled.nil?
        @limits_checking_enabled_label.setText("#{show_nil(limits_enabled)}")
      end
    end

    protected

    # Creates and populates the layout for the dialog
    def build_details_layout(item, cmd_tlm)
      details_layout = Qt::FormLayout.new
      details_layout.addRow("Bit Offset:", Qt::Label.new("#{show_nil(item.bit_offset)}"))
      details_layout.addRow("Bit Size:", Qt::Label.new("#{show_nil(item.bit_size)}"))
      details_layout.addRow("Data Type:", Qt::Label.new("#{show_data_type(item.data_type)}"))
      details_layout.addRow("Array Size:", Qt::Label.new("#{show_nil(item.array_size)}"))
      if cmd_tlm == :CMD
        if item.range
          details_layout.addRow("Minimum:", Qt::Label.new(item.range.first.to_s))
          details_layout.addRow("Maximum:", Qt::Label.new(item.range.last.to_s))
        end
        details_layout.addRow("Default:", Qt::Label.new("#{show_nil(item.default)}")) if item.default
      end
      details_layout.addRow("Format String:", Qt::Label.new("#{show_nil(item.format_string)}"))
      details_layout.addRow("Read_Conversion:", Qt::Label.new("#{show_conversion(item.read_conversion)}"))
      details_layout.addRow("Write_Conversion:", Qt::Label.new("#{show_conversion(item.write_conversion)}"))
      details_layout.addRow("Id Value:", Qt::Label.new("#{show_nil(item.id_value)}"))
      details_layout.addRow("Description:", Qt::Label.new("#{show_nil(item.description)}"))
      details_layout.addRow("Units Full:", Qt::Label.new("#{show_nil(item.units_full)}"))
      details_layout.addRow("Units Abbreviation:", Qt::Label.new("#{show_nil(item.units)}"))
      details_layout.addRow("Endianness:", Qt::Label.new("#{show_endianness(item.endianness)}"))
      if item.states
        details_layout.addRow(build_states_details(item))
      else
        details_layout.addRow("States:", Qt::Label.new("None"))
      end
      if cmd_tlm == :CMD
        details_layout.addRow("Required:", Qt::Label.new(item.required.to_s))
      else
        limits = item.limits.values
        if limits
          details_layout.addRow(build_limits_details(limits))
        else
          details_layout.addRow("Limits:", Qt::Label.new("None"))
        end
        if limits || item.state_colors
          @limits_checking_enabled_label = Qt::Label.new("#{show_nil(item.limits.enabled)}")
          details_layout.addRow("Limits Checking Enabled:", @limits_checking_enabled_label)
        end
        if limits
          details_layout.addRow("Limits Persistence Setting:", Qt::Label.new("#{show_nil(item.limits.persistence_setting)}"))
          details_layout.addRow("Limits Persistence Count:", Qt::Label.new("#{show_nil(item.limits.persistence_count)}"))
        end
        if item.meta.empty?
          details_layout.addRow("Meta:", Qt::Label.new("None"))
        else
          item.meta.each do |key, value|
            details_layout.addRow("Meta[#{key}]:", Qt::Label.new(value.to_s))
          end
        end
      end
      details_layout
    end

    # Create the states details layout
    def build_states_details(item)
      states_details = Qt::GroupBox.new("States")
      scroll_layout = Qt::VBoxLayout.new
      states_details.setLayout(scroll_layout)
      scroll_area = Qt::ScrollArea.new
      scroll_area.setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff)
      scroll_layout.addWidget(scroll_area)
      scroll_widget = Qt::Widget.new
      scroll_area.setWidget(scroll_widget)
      states_layout = Qt::FormLayout.new
      scroll_widget.setLayout(states_layout)
      item.states.sort {|a, b| a[1].to_i <=> b[1].to_i }.each do |state_name, state_value|
        if item.state_colors
          states_layout.addRow("#{state_name}:", Qt::Label.new("#{state_value} #{item.state_colors[state_name]}"))
        else
          states_layout.addRow("#{state_name}:", Qt::Label.new("#{state_value}"))
        end
      end
      # Figure out the how big the states layout wants to be and set the
      # scroll area to this height if possible. Otherwise limit it to 200px.
      if states_layout.minimumSize.height > 200
        scroll_area.setMinimumHeight(200)
      else
        scroll_area.setMinimumHeight(states_layout.minimumSize.height + 5)
      end
      scroll_widget.adjustSize
      states_details
    end

    # Create the limits details layout
    def build_limits_details(limits)
      limits_details = Qt::GroupBox.new("Limits")
      @limits_layout = Qt::FormLayout.new
      limits.each do |limits_set_name, limits_settings|
        if limits_settings[4] && limits_settings[5]
          label = Qt::Label.new("RL/#{limits_settings[0]} YL/#{limits_settings[1]} YH/#{limits_settings[2]} RH/#{limits_settings[3]} GL/#{limits_settings[4]} GH/#{limits_settings[5]}")
        else
          label = Qt::Label.new("RL/#{limits_settings[0]} YL/#{limits_settings[1]} YH/#{limits_settings[2]} RH/#{limits_settings[3]}")
        end
        @limits_labels[limits_set_name] = label
        @limits_layout.addRow("#{limits_set_name}:", label)
      end
      limits_details.setLayout(@limits_layout)
      limits_details
    end

    def show_nil(object, show_as = 'nil')
      if object.nil?
        return show_as
      else
        return object
      end
    end

    def show_data_type(data_type)
      case data_type
      when nil
        return 'nil'
      when :INT, :UINT, :FLOAT, :STRING, :BLOCK, :DERIVED
        return data_type.to_s
      else
        return "INVALID (#{data_type})"
      end
    end

    def show_endianness(endianness)
      case endianness
      when :BIG_ENDIAN
        return 'BIG_ENDIAN'
      else
        return 'LITTLE_ENDIAN'
      end
    end

    def show_conversion(object)
      if object.nil?
        return 'nil'
      else
        return object.to_s
      end
    end

    def reject
      super()
      @@instances.delete(self)
      self.dispose
    end

    def closeEvent(event)
      super(event)
      @@instances.delete(self)
      self.dispose
    end
  end
end
