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
  # Widget which creates a horizontally laid out label, and combobox.
  # A callback can be specified which is called once the combobox is changed.
  class ComboboxChooser < Qt::Widget
    # Width of the button in the combobox
    COMBOBOX_BUTTON_WIDTH = 30
    # Optional callback for when the combobox value changes
    attr_accessor :sel_command_callback

    # @param parent [Qt::Widget] Widget to parent this widget to
    # @param label_text [String] Text to place in the label
    # @param items [Array<#to_s>] Array of items to add to the combobox
    # @param allow_user_entry [Boolean] Whether to allow the user to enter an
    #   arbitrary string in the combobox
    # @param compact_combobox [Boolean] Whether to fix the size of the combobox
    #   or let it expand to fill the space
    # @param color_chooser [Boolean] Whether to create a rectangular color
    #   swatch based on each item name
    def initialize(
      parent, label_text, items, # required
      allow_user_entry: false, compact_combobox: true, color_chooser: false
    )
      super(parent)
      layout = Qt::HBoxLayout.new(self)
      layout.setContentsMargins(0, 0, 0, 0)
      @combo_label = Qt::Label.new(label_text)
      @combo_label.setSizePolicy(Qt::SizePolicy::Fixed, Qt::SizePolicy::Fixed) unless compact_combobox
      layout.addWidget(@combo_label)
      @combo_value = Qt::ComboBox.new
      @combo_value.setEditable(allow_user_entry)
      string_items = items.map {|item| item.to_s }
      @combo_value.addItems(string_items)
      @color_chooser = color_chooser
      set_colors(string_items) if @color_chooser
      @combo_value.connect(SIGNAL('currentIndexChanged(int)')) {|index| handle_combobox_sel_command(index) }
      if items.length < 20
        @combo_value.setMaxVisibleItems(items.length)
      else
        @combo_value.setMaxVisibleItems(20)
      end
      layout.addStretch if compact_combobox
      layout.addWidget(@combo_value)

      setLayout(layout)
      @sel_command_callback = nil
    end

    # Clears the combobox and adds new items
    # @param items [Array<String>] Items to add to the combobox
    # @param include_blank [Boolean] Whether to add a blank item as the first
    #   combobox item. This is typically done to indicate to the user that a
    #   value must be selected.
    def update_items(items, include_blank = true)
      @combo_value.clearItems
      @combo_value.addItem(' ') if include_blank
      string_items = items.map {|item| item.to_s }
      @combo_value.addItems(string_items)
      set_colors(string_items) if @color_chooser
      if items.length < 20
        @combo_value.setMaxVisibleItems(items.length)
      else
        @combo_value.setMaxVisibleItems(20)
      end
    end

    # @param text [String] Text to set in the current combobox item
    def set_current(text)
      @combo_value.setCurrentText(text.to_s)
    end

    # @return [Integer] Current item as an integer
    def integer
      Integer(@combo_value.currentText)
    end

    # @return [Float] Current item as a float
    def float
      @combo_value.currentText.to_f if @combo_value.currentText
    end

    # @return [String] Current item as a string
    def string
      @combo_value.currentText
    end

    # @return [Symbol] Current item as a symbol
    def symbol
      @combo_value.currentText.intern if @combo_value.currentText
    end

    protected

    # Calls the combobox selection changed callback if it exists
    def handle_combobox_sel_command(index)
      if index >= 0
        @sel_command_callback.call(string()) if @sel_command_callback
      end
      0
    end

    # Creates a rectangle of color based on the combobox item name
    def set_colors(string_items)
      # Create an image we can draw into
      img = Qt::Image.new(16, 16, Qt::Image::Format_RGB32)
      # Grab a rectangle offset by 1 pixel inside the image
      rect = img.rect().adjusted(1, 1, -1, -1)
      p = Qt::Painter.new
      # Start painting on the image
      p.begin(img)
      # Fill the original image with black (this paints the outline)
      p.fillRect(img.rect(), Qt::black)

      string_items.each_with_index do |string_item, index|
        unless string_item.strip.empty?
          # Fill the offsetted rectangle with the color
          p.fillRect(rect, Cosmos.getColor(string_item))
          # Create a variant from the image pixmap
          variant = Qt::Variant.fromValue(Qt::Pixmap::fromImage(img))
          @combo_value.setItemData(index, variant, Qt::DecorationRole)
          variant.dispose
        end
      end
      p.end # Stop painting
      rect.dispose
      img.dispose
      p.dispose
    end
  end
end
