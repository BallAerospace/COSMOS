# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation and TlmDetailsDialog class.   This class
# is used to view a telemetry items settings typically on a right click.

require 'cosmos'
require 'cosmos/gui/dialogs/details_dialog'
require 'cosmos/packets/packet'

module Cosmos
  # Creates a dialog which shows the details of the given telemetry item.
  class TlmDetailsDialog < DetailsDialog
    slots 'value_update_timeout()'

    # Period for the update thread which updates the dialog values
    VALUE_UPDATE_PERIOD_MS = 1000

    # @param parent (see DetailsDialog#initialize)
    # @param target_name (see DetailsDialog#initialize)
    # @param packet_name (see DetailsDialog#initialize)
    # @param item_name (see DetailsDialog#initialize)
    # @param packet [Packet] If a Packet is given the dialog will read the
    #   value from the given packet and will not update. If the packet
    #   parameters is nil the value will be read continously from the System.
    def initialize(parent, target_name, packet_name, item_name, packet = nil)
      super(parent, target_name, packet_name, item_name)

      @item_array = [[@target_name, @packet_name, @item_name],
                     [@target_name, @packet_name, @item_name],
                     [@target_name, @packet_name, @item_name],
                     [@target_name, @packet_name, @item_name]]

      begin
        update = false
        if !packet
          update = true
          _, item = System.telemetry.packet_and_item(target_name, packet_name, item_name)
        else
          item = packet.get_item(item_name)
        end

        setWindowTitle("#{@target_name} #{@packet_name} #{@item_name} Details")

        layout = Qt::VBoxLayout.new
        layout.addWidget(Qt::Label.new("#{target_name} #{packet_name} #{item_name}"))

        # Display the item values
        item_values = Qt::GroupBox.new("Item Values")

        values_layout = Qt::FormLayout.new
        @raw_value = Qt::LineEdit.new
        @raw_value.setReadOnly(true)
        values_layout.addRow("Raw Value:", @raw_value)
        @hex_raw_value = nil
        @hex_raw_num_digits = 0
        case item.data_type
        when :INT, :UINT
          if item.bit_size >= 0
            @hex_raw_value = Qt::LineEdit.new
            @hex_raw_value.setReadOnly(true)
            @hex_raw_num_digits = (((item.bit_size - 1) / 8) + 1) * 2
            values_layout.addRow("Hex Raw Value:", @hex_raw_value)
          end
        end
        @converted_value = Qt::LineEdit.new
        @converted_value.setReadOnly(true)
        values_layout.addRow("Converted Value:", @converted_value)
        @formatted_value = Qt::LineEdit.new
        @formatted_value.setReadOnly(true)
        values_layout.addRow("Formatted Value:", @formatted_value)
        @formatted_with_units_value = Qt::LineEdit.new
        @formatted_with_units_value.setReadOnly(true)
        values_layout.addRow("Formatted with Units Value:", @formatted_with_units_value)
        @limits_state = Qt::LineEdit.new
        @limits_state.setReadOnly(true)
        values_layout.addRow("Limits State:", @limits_state)

        item_values.setLayout(values_layout)
        layout.addWidget(item_values)

        if update
          @timer = Qt::Timer.new
          connect(@timer, SIGNAL('timeout()'), self, SLOT('value_update_timeout()'))
          @timer.method_missing(:start, VALUE_UPDATE_PERIOD_MS)
          value_update_timeout()
        else
          raw_value = packet.read(item_name, :RAW).to_s
          @raw_value.text = raw_value
          set_hex_value(raw_value) if @hex_raw_value
          @converted_value.text = packet.read(item_name, :CONVERTED).to_s
          @formatted_value.text = packet.read(item_name, :FORMATTED).to_s
          @formatted_with_units_value.text = packet.read(item_name, :WITH_UNITS).to_s
        end

        # Display the item details
        item_details = Qt::GroupBox.new("Item Details")
        item_details.setLayout(build_details_layout(item, :TLM))
        layout.addWidget(item_details)

        # Add the OK button
        ok = Qt::PushButton.new("Ok")
        connect(ok, SIGNAL('clicked()'), self, SLOT('close()'))
        if update
          connect(self, SIGNAL('finished(int)')) do |result|
            @timer.stop
          end
        end
        layout.addWidget(ok)

        self.setLayout(layout)
        self.show
        self.raise
      rescue DRb::DRbConnError
        # Just do nothing
      end
    end

    def value_update_timeout
      # Gather updated values
      values, limits_states, limits_settings, limits_set = get_tlm_values(@item_array, Packet::VALUE_TYPES)
      update_limits_details(limits_settings, limits_set)
      update_text_fields(values, limits_states[0])
    rescue DRb::DRbConnError
      # Just do nothing
    end

    protected

    def set_hex_value(value)
      if Array === value
        text = "["
        value[0..-2].each do |part|
          text << sprintf("0x%0#{@hex_raw_num_digits}X, ", part.to_i)
        end
        text << sprintf("0x%0#{@hex_raw_num_digits}X", value[-1].to_i) if value[-1]
        text << "]"
        @hex_raw_value.text = text
      else
        @hex_raw_value.text = sprintf("0x%0#{@hex_raw_num_digits}X", value.to_i)
      end
    end

    def update_limits_details(limits_settings, limits_set)
      return unless limits_settings[0]
      label_text = "RL/#{limits_settings[0][0]} YL/#{limits_settings[0][1]} YH/#{limits_settings[0][2]} RH/#{limits_settings[0][3]}"
      if limits_settings[0][4] && limits_settings[0][5]
        label_text << " GL/#{limits_settings[0][4]} GH/#{limits_settings[0][5]}"
      end
      if @limits_labels[limits_set]
        @limits_labels[limits_set].text = label_text
      elsif @limits_layout
        label = Qt::Label.new(label_text)
        @limits_labels[limits_set] = label
        @limits_layout.addRow("#{limits_set}:", label)
      end
      update_limits_checking()
    end

    def determine_limits_color(limit_state)
      case limit_state
      when :RED, :RED_HIGH, :RED_LOW
        Cosmos::RED
      when :YELLOW, :YELLOW_HIGH, :YELLOW_LOW
        Cosmos::YELLOW
      when :GREEN, :GREEN_HIGH, :GREEN_LOW
        Cosmos::GREEN
      when :BLUE
        Cosmos::BLUE
      when :STALE
        Cosmos::PURPLE
      else
        Cosmos::BLACK
      end
    end

    def update_text_fields(values, limits_state)
      color = determine_limits_color(limits_state)
      @raw_value.setColors(color, Cosmos::WHITE)
      @raw_value.text = values[0].to_s
      if @hex_raw_value
        @hex_raw_value.setColors(color, Cosmos::WHITE)
        set_hex_value(values[0])
      end
      @converted_value.setColors(color, Cosmos::WHITE)
      @converted_value.text = values[1].to_s
      @formatted_value.setColors(color, Cosmos::WHITE)
      @formatted_value.text = values[2].to_s
      @formatted_with_units_value.setColors(color, Cosmos::WHITE)
      @formatted_with_units_value.text = values[3].to_s
      @limits_state.setColors(color, Cosmos::WHITE)
      @limits_state.text = limits_state.to_s
    end
  end
end
