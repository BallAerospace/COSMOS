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

module Cosmos

  class TlmDetailsDialog < DetailsDialog
    slots 'value_update_timeout()'

    VALUE_UPDATE_PERIOD_MS = 1000
    VALUE_TYPES = [:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS]

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
        layout.addWidget(Qt::Label.new(tr("#{target_name} #{packet_name} #{item_name}")))

        # Display the item values
        item_values = Qt::GroupBox.new(tr("Item Values"))

        values_layout = Qt::FormLayout.new
        @raw_value = Qt::LineEdit.new
        @raw_value.setReadOnly(true)
        values_layout.addRow(tr("Raw Value:"), @raw_value)
        @hex_raw_value = nil
        @hex_raw_num_digits = 0
        case item.data_type
        when :INT, :UINT
          if item.bit_size >= 0
            @hex_raw_value = Qt::LineEdit.new
            @hex_raw_value.setReadOnly(true)
            @hex_raw_num_digits = (((item.bit_size - 1) / 8) + 1) * 2
            values_layout.addRow(tr("Hex Raw Value:"), @hex_raw_value)
          end
        end
        @converted_value = Qt::LineEdit.new
        @converted_value.setReadOnly(true)
        values_layout.addRow(tr("Converted Value:"), @converted_value)
        @formatted_value = Qt::LineEdit.new
        @formatted_value.setReadOnly(true)
        values_layout.addRow(tr("Formatted Value:"), @formatted_value)
        @formatted_with_units_value = Qt::LineEdit.new
        @formatted_with_units_value.setReadOnly(true)
        values_layout.addRow(tr("Formatted with Units Value:"), @formatted_with_units_value)
        @limits_state = Qt::LineEdit.new
        @limits_state.setReadOnly(true)
        values_layout.addRow(tr("Limits State:"), @limits_state)

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
        item_details = Qt::GroupBox.new(tr("Item Details"))
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
      # Check to see that the server is still running. If the user shut down
      # the underlying tool (like PacketViewer for example) the $cmd_tlm_server
      # will be nil.
      unless $cmd_tlm_server
        @timer.stop
        return
      end
      begin
        # Gather updated values
        values, limits_states, limits_settings, limits_set = get_tlm_values(@item_array, VALUE_TYPES)
        if limits_settings[0]
          if @limits_labels[limits_set]
            if limits_settings[0][4] and limits_settings[0][5]
              @limits_labels[limits_set].text = "RL/#{limits_settings[0][0]} YL/#{limits_settings[0][1]} YH/#{limits_settings[0][2]} RH/#{limits_settings[0][3]} GL/#{limits_settings[0][4]} GH/#{limits_settings[0][5]}"
            else
              @limits_labels[limits_set].text = "RL/#{limits_settings[0][0]} YL/#{limits_settings[0][1]} YH/#{limits_settings[0][2]} RH/#{limits_settings[0][3]}"
            end
          elsif @limits_layout
            if limits_settings[0][4] and limits_settings[0][5]
              label = Qt::Label.new("RL/#{limits_settings[0][0]} YL/#{limits_settings[0][1]} YH/#{limits_settings[0][2]} RH/#{limits_settings[0][3]} GL/#{limits_settings[0][4]} GH/#{limits_settings[0][5]}")
            else
              label = Qt::Label.new("RL/#{limits_settings[0][0]} YL/#{limits_settings[0][1]} YH/#{limits_settings[0][2]} RH/#{limits_settings[0][3]}")
            end
            @limits_labels[limits_set] = label
            @limits_layout.addRow(tr("#{limits_set}:"), label)
          end
        end

        # Determine color
        color = nil
        case limits_states[0]
        when :RED, :RED_HIGH
          color = Cosmos::RED
        when :RED_LOW
          color = Cosmos::RED
        when :YELLOW, :YELLOW_HIGH
          color = Cosmos::YELLOW
        when :YELLOW_LOW
          color = Cosmos::YELLOW
        when :GREEN, :GREEN_HIGH
          color = Cosmos::GREEN
        when :GREEN_LOW
          color = Cosmos::GREEN
        when :BLUE
          color = Cosmos::BLUE
        when :STALE
          color = Cosmos::PURPLE
        else
          color = Cosmos::BLACK
        end

        # Update text fields
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
        @limits_state.text = limits_states[0].to_s
      rescue DRb::DRbConnError
        # Just do nothing
      end
    end

    def set_hex_value(value)
      if Array === value
        text = "["
        value[0..-2].each do |part|
          text << sprintf("0x%0#{@hex_raw_num_digits}X, ", part.to_i)
        end
        text << sprintf("0x%0#{@hex_raw_num_digits}X", value[-1].to_i) if values[-1]
        text << "]"
        @hex_raw_value.text = text
      else
        @hex_raw_value.text = sprintf("0x%0#{@hex_raw_num_digits}X", value.to_i)
      end
    end

  end # class TlmDetailsDialog

end # module Cosmos
