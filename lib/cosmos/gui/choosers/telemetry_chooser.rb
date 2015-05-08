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
require 'cosmos/system/system'

module Cosmos

  # Provides dropdowns to select from all the defined Targets, Packets, and
  # Items. Callbacks can be added when any of the dropdown values are changed
  # as well as when the select button is pressed. Provides an option to orient
  # the dropdowns horizontally or vertically.
  class TelemetryChooser < Qt::Widget

    # Width of the button in the Combobox
    COMBOBOX_BUTTON_WIDTH = 30

    # Callback called when the target is changed - call(target_name)
    attr_accessor :target_changed_callback

    # Callback called when the packet is changed - call(target_name, packet_name)
    attr_accessor :packet_changed_callback

    # Callback called when the item is changed - call(target_name, packet_name, item_name)
    attr_accessor :item_changed_callback

    # Callback called when the select button is pressed - call(target_name, packet_name, item_name)
    attr_accessor :select_button_callback

    # Label for the target
    attr_accessor :target_label

    # Label for the packet
    attr_accessor :packet_label

    # Label for the item
    attr_accessor :item_label

    # @param parent [Qt::Widget] Parent of this widget
    # @param orientation [Integer] Must be Qt::Horizontal or Qt::Vertical
    # @param choose_item [Boolean] Whether to allow choosing items. Choosing
    #   targets and packets are alway enabled.
    # @param select_button [Boolean] Whether to display the "Select" button.
    #   You can disable the button if you just want to implement the dropdown
    #   change callbacks.
    # @param support_latest [Boolean] Whether to add LATEST to the list of packets
    def initialize(
      parent,
      orientation = Qt::Horizontal,
      choose_item = true,
      select_button = true,
      support_latest = false,
      fill = false
    )

      super(parent)
      if orientation == Qt::Horizontal
        # Horizontal Frame for overall widget
        @overall_frame = Qt::HBoxLayout.new(self)
      else
        # Vertical Frame for overall widget
        @overall_frame = Qt::VBoxLayout.new(self)
      end
      @overall_frame.setContentsMargins(0,0,0,0)

      # Target Selection
      @target_layout = Qt::HBoxLayout.new
      @target_label = Qt::Label.new('Target:')
      @target_label.setSizePolicy(Qt::SizePolicy::Fixed, Qt::SizePolicy::Fixed) if fill
      @target_layout.addWidget(@target_label)
      @target_layout.addStretch unless fill
      @target_combobox = Qt::ComboBox.new
      # This allows the comboboxes to automatically adjust when we change the contents - awesome!
      @target_combobox.setSizeAdjustPolicy(Qt::ComboBox::AdjustToContents)
      @target_combobox.connect(SIGNAL('activated(int)')) do
        update_packets()
        @target_changed_callback.call(target_name()) if @target_changed_callback
      end
      @target_layout.addWidget(@target_combobox)
      @overall_frame.addLayout(@target_layout)

      # Packet Selection
      @packet_layout = Qt::HBoxLayout.new
      @packet_label = Qt::Label.new('Packet:')
      @packet_label.setSizePolicy(Qt::SizePolicy::Fixed, Qt::SizePolicy::Fixed) if fill
      @packet_layout.addWidget(@packet_label)
      @packet_layout.addStretch unless fill
      @packet_combobox = Qt::ComboBox.new
      @packet_combobox.setSizeAdjustPolicy(Qt::ComboBox::AdjustToContents)
      @packet_combobox.connect(SIGNAL('activated(int)')) do
        update_items()
        @packet_changed_callback.call(target_name(), packet_name()) if @packet_changed_callback
      end
      @packet_layout.addWidget(@packet_combobox)
      @overall_frame.addLayout(@packet_layout)

      @item_combobox = nil
      if choose_item
        # Item Selection
        @item_layout = Qt::HBoxLayout.new
        @item_label = Qt::Label.new('Item:')
        @item_label.setSizePolicy(Qt::SizePolicy::Fixed, Qt::SizePolicy::Fixed) if fill
        @item_layout.addWidget(@item_label)
        @item_layout.addStretch unless fill
        @item_combobox = Qt::ComboBox.new
        @item_combobox.setSizeAdjustPolicy(Qt::ComboBox::AdjustToContents)
        @item_combobox.connect(SIGNAL('activated(int)')) do
          @item_changed_callback.call(target_name(), packet_name(), item_name()) if @item_changed_callback
        end
        @item_layout.addWidget(@item_combobox)
        @overall_frame.addLayout(@item_layout)
      end

      if select_button
        # Select Button
        #@overall_frame.addStretch()
        @select_button = Qt::PushButton.new('Select')
        @select_button.connect(SIGNAL('clicked()')) do
          @select_button_callback.call(target_name(), packet_name(), item_name()) if @select_button_callback
        end
        @overall_frame.addWidget(@select_button)
      end

      # Initialize instance variables
      @target_changed_callback = nil
      @packet_changed_callback = nil
      @item_changed_callback = nil
      @select_button_callback = nil
      @support_latest = support_latest
    end

    # Update items
    def update
      current_target_name = target_name()
      current_packet_name = packet_name()
      current_item_name = item_name()
      update_targets()
      if current_target_name and current_packet_name and (current_item_name or !@item_combobox)
        begin
          set_item(current_target_name, current_packet_name, current_item_name)
        rescue Exception
          # Oh well - Tried to keep the same item
        end
      end
    end

    # Set the text of the button
    def button_text=(button_text)
      @select_button.setText(button_text)
    end

    # Returns the selected target name
    def target_name
      @target_combobox.text
    end

    # Returns the selected packet name
    def packet_name
      @packet_combobox.text
    end

    # Returns the selected item name
    def item_name
      if @item_combobox
        @item_combobox.text
      else
        nil
      end
    end

    # Returns the list of all target names in the target combobox
    def target_names
      target_names_array = []
      @target_combobox.each {|item_text, item_data| target_names_array << item_text}
      target_names_array
    end

    # Returns the list of all packet names in the packet combobox
    def packet_names
      packet_names_array = []
      @packet_combobox.each {|item_text, item_data| packet_names_array << item_text}
      packet_names_array
    end

    # Returns the list of all item names in the item combobox
    def item_names
      item_names_array = []
      if @item_combobox
        @item_combobox.each {|item_text, item_data| item_names_array << item_text}
      end
      item_names_array
    end

    # Sets the current packet
    def set_packet(target_name, packet_name)
      # Select desired target
      index = 0
      found = false
      @target_combobox.each do |item_text, item_data|
        if target_name.upcase == item_text.upcase
          found = true
          break
        end
        index += 1
      end
      Kernel.raise "TelemetryChooser unknown target_name #{target_name}" unless found
      @target_combobox.setCurrentIndex(index)
      update_packets()

      # Select desired packet
      index = 0
      found = false
      @packet_combobox.each do |item_text, item_data|
        if packet_name.upcase == item_text.upcase
          found = true
          break
        end
        index += 1
      end
      Kernel.raise "TelemetryChooser unknown packet_name #{packet_name}" unless found
      @packet_combobox.setCurrentIndex(index)
      update_items()
    end

    # Sets the current item
    def set_item(target_name, packet_name, item_name)
      # Set the desired packet
      set_packet(target_name, packet_name)

      # Select desired item
      if @item_combobox
        index = 0
        found = false
        @item_combobox.each do |item_text, item_data|
          if item_name.upcase == item_text.upcase
            found = true
            break
          end
          index += 1
        end
        Kernel.raise "TelemetryChooser unknown item_name #{item_name}" unless found
        @item_combobox.setCurrentIndex(index)
      end
    end

    protected

    # Updates all comboboxs based on a change
    def update_targets
      @target_combobox.clearItems()
      target_names = System.telemetry.target_names

      # Delete targets with only hidden packets
      target_names_to_delete = []
      target_names.each do |target_name|
        packets = System.telemetry.packets(target_name)
        has_non_hidden = false
        packets.each do |packet_name, packet|
          has_non_hidden = true unless packet.hidden
        end
        target_names_to_delete << target_name unless has_non_hidden
      end
      target_names_to_delete.each do |target_name|
        target_names.delete(target_name)
      end

      target_names.each do |name|
        @target_combobox.addItem(name)
      end
      if target_names.length > 20
        @target_combobox.setMaxVisibleItems(20)
      else
        @target_combobox.setMaxVisibleItems(target_names.length)
      end
      update_packets()
    end

    # Updates the packet names and item names based on a change
    def update_packets
      return unless target_name()
      @packet_combobox.clearItems()
      packets = System.telemetry.packets(target_name())
      packet_names = []
      packets.each { |packet_name, packet| packet_names << packet.packet_name unless packet.hidden }
      packet_names << Telemetry::LATEST_PACKET_NAME if @support_latest
      packet_names.sort!
      packet_names.each do |name|
        @packet_combobox.addItem(name)
      end
      if packet_names.length > 20
        @packet_combobox.setMaxVisibleItems(20)
      else
        @packet_combobox.setMaxVisibleItems(packet_names.length)
      end
      update_items()
    end

    # Updates the item names based on a change
    def update_items
      return unless target_name() and packet_name()
      if @item_combobox
        @item_combobox.clearItems()
        item_names = System.telemetry.item_names(target_name(), packet_name())
        item_names.sort!
        item_names.each do |name|
          @item_combobox.addItem(name)
        end
        if item_names.length > 20
          @item_combobox.setMaxVisibleItems(20)
        else
          @item_combobox.setMaxVisibleItems(item_names.length)
        end
      end
    end

  end # class TelemetryChooser

end # module Cosmos
