# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
Cosmos.catch_fatal_exception do
  require 'cosmos/tools/cmd_sender/cmd_param_table_item_delegate'
  require 'cosmos/gui/dialogs/cmd_details_dialog'
end

module Cosmos
  # Builds a command parameter widget for use in Command Sender and Command Sequence.
  # The main method is update_cmd_params which builds all the widgets. It can take
  # existing values for use in populating the command parameter widgets.
  class CmdParams < Qt::Widget
    # Class instance variables which apply to all command parameters
    @states_in_hex = false
    @show_ignored = false
    class << self
      attr_accessor :states_in_hex, :show_ignored
    end
    MANUALLY = CmdParamTableItemDelegate::MANUALLY
    # Emit the modified signal to allow changes to propagate upwards
    signals 'modified()'

    def initialize
      super()
      @param_widgets = []
      @table = nil
      @packet = nil
      @file_dir = System.paths['LOGS']
    end

    # Changes the display of items with states to hex if checked is true.
    # Otherwise state values are displayed as decimal.
    # @param checked [Boolean] Whether to display state values in hex
    def states_in_hex(checked)
      CmdParams.states_in_hex = checked
      @param_widgets.each do |_, _, state_value_item|
        next unless state_value_item
        text = state_value_item.text
        quotes_removed = text.remove_quotes
        if text == quotes_removed
          if checked
            if text.is_int?
              @table.blockSignals(true)
              state_value_item.text = sprintf("0x%X", text.to_i)
              @table.blockSignals(false)
            end
          else
            if text.is_hex?
              @table.blockSignals(true)
              state_value_item.text = Integer(text).to_s
              @table.blockSignals(false)
            end
          end
        end
      end
    end

    # @return [Hash] Hash keyed by parameter name with String formatted value
    def params_text(raw = false)
      params = {}
      Qt.execute_in_main_thread do
        @param_widgets.each do |packet_item, value_item, state_value_item|
          text = value_item.text
          text = state_value_item.text if state_value_item && (text == MANUALLY or raw)
          quotes_removed = text.remove_quotes
          if text == quotes_removed
            if (packet_item.data_type == :STRING or packet_item.data_type == :BLOCK) and text.upcase.start_with?("0X")
              params[packet_item.name] = text.hex_to_byte_string
            else
              params[packet_item.name] = text.convert_to_value
            end
          else
            params[packet_item.name] = quotes_removed
          end
          Kernel.raise "#{packet_item.name} is required." if quotes_removed == '' && packet_item.required
        end
      end
      params
    end

    # Primary method which builds the command parameter table. The passed in command packet
    # is used to get all the command parameters to build. Existing parameters can be passed
    # in to set the initial values for all command parameters. You can also specify whether
    # to display the ignored parameters when building the command parameter table. Note that
    # each time this method is called the TableWidget is disposed and rebuilt.
    #
    # @param packet [Packet] The command packet to build a parameter list for
    # @param existing [Hash] Hash keyed by parameter name with text values.
    #   These values will be used as the defaults for all command parameters.
    # @param show_ignored [Boolean] Whether to display the ignored
    #   parameters. Pass nil (the default) to keep the existing setting.
    def update_cmd_params(packet, existing: nil, show_ignored: nil)
      @packet = packet
      old_params = {}
      old_params = get_params(show_ignored) if !show_ignored.nil?
      old_params = set_existing(packet, existing) if existing

      # Determine which items to display
      target = System.targets[packet.target_name]
      packet_items = packet.sorted_items
      shown_packet_items = []
      packet_items.each do |packet_item|
        next if target && target.ignored_parameters.include?(packet_item.name) && !CmdParams.show_ignored
        shown_packet_items << packet_item
      end

      # Destroy the old table widget and parameters
      @table.dispose if @table
      @table = nil
      @param_widgets = []
      row = 0
      shown_packet_items.each do |packet_item|
        value_item = nil
        state_value_item = nil
        @table = create_table(shown_packet_items.length) unless @table

        # Parameter Name
        item = Qt::TableWidgetItem.new("#{packet_item.name}:")
        item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
        @table.setItem(row, 0, item)

        # Parameter Value
        if packet_item.states
          value_item, state_value_item = create_state_item(packet_item, old_params, row)
        else
          value_item = create_item(packet_item, old_params, row)
        end

        # Units
        item = Qt::TableWidgetItem.new(packet_item.units.to_s)
        item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
        @table.setItem(row, 3, item)

        # Description
        item = Qt::TableWidgetItem.new(packet_item.description.to_s)
        item.setTextAlignment(Qt::AlignLeft | Qt::AlignVCenter)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
        @table.setItem(row, 4, item)

        @param_widgets << [packet_item, value_item, state_value_item]
        row += 1
      end

      connect_table_item_changed() if @table
      @table
    end

    # If the user right clicks over a table item, this method displays a context
    # menu with various options.
    # @param point [Qt::Point] Point to display the context menu
    def context_menu(point)
      item = @table.itemAt(point)
      if item
        target_name = @packet.target_name
        packet_name = @packet.packet_name
        item_name = @table.item(item.row, 0).text[0..-2] # Remove :
        if target_name.length > 0 && packet_name.length > 0 && item_name.length > 0
          menu = Qt::Menu.new()

          details_action = Qt::Action.new("Details #{target_name} #{packet_name} #{item_name}", self)
          details_action.statusTip = "Popup details about #{target_name} #{packet_name} #{item_name}"
          details_action.connect(SIGNAL('triggered()')) do
            CmdDetailsDialog.new(nil, target_name, packet_name, item_name)
          end
          menu.addAction(details_action)

          file_chooser_action = Qt::Action.new("Insert Filename", self)
          file_chooser_action.statusTip = "Select a file and place its name into this parameter"
          file_chooser_action.connect(SIGNAL('triggered()')) do
            filename = Qt::FileDialog::getOpenFileName(self, "Insert Filename:", @file_dir, "All Files (*)")
            if filename && !filename.empty?
              @file_dir = File.dirname(filename)
              _, value_item, state_value_item = @param_widgets[item.row]
              if state_value_item
                state_value_item.setText(filename)
              elsif value_item
                value_item.setText(filename)
              end
            end
          end
          menu.addAction(file_chooser_action)

          menu.exec(@table.mapToGlobal(point))
          menu.dispose
        end
      end
    end

    private

    def get_params(show_ignored)
      params = {}
      CmdParams.show_ignored = show_ignored
      # Save parameter values
      @param_widgets.each do |packet_item, value_item, state_value_item|
        text = value_item.text
        if state_value_item
          params[packet_item.name] = [text, state_value_item.text]
        else
          params[packet_item.name] = text
        end
      end
      params
    end

    def set_existing(packet, existing)
      params = {}
      existing.each do |param_name, param_value|
        packet_item = packet.items[param_name]
        if packet_item.states
          state_value = packet_item.states[param_value]
          unless state_value # If we couldn't lookup the value by the name it's manual
            state_value = param_value
            param_value = MANUALLY
          end
          params[param_name] = [param_value.to_s, state_value.to_s]
        else
          params[param_name] = param_value.to_s
        end
      end
      params
    end

    def create_table(length)
      table = Qt::TableWidget.new()
      table.setSizePolicy(Qt::SizePolicy::Expanding, Qt::SizePolicy::Expanding)
      table.setWordWrap(true)
      table.setRowCount(length)
      table.setColumnCount(5)
      table.setHorizontalHeaderLabels(['Name', '         Value or State         ', '         ', 'Units', 'Description'])
      table.horizontalHeader.setStretchLastSection(true)
      table.verticalHeader.setVisible(false)
      table.setItemDelegate(CmdParamTableItemDelegate.new(table, @param_widgets, @production))
      table.setContextMenuPolicy(Qt::CustomContextMenu)
      table.verticalHeader.setResizeMode(Qt::HeaderView::ResizeToContents)
      table.setEditTriggers(Qt::AbstractItemView::DoubleClicked | Qt::AbstractItemView::SelectedClicked | Qt::AbstractItemView::AnyKeyPressed)
      table.setSelectionMode(Qt::AbstractItemView::NoSelection)
      table.connect(SIGNAL('customContextMenuRequested(const QPoint&)')) {|point| context_menu(point) }
      table.connect(SIGNAL('itemClicked(QTableWidgetItem*)')) do |item|
        table.editItem(item) if (item.flags & Qt::ItemIsEditable) != 0
      end
      return table
    end

    def create_state_item(packet_item, old_params, row)
      default_state = packet_item.states.key(packet_item.default)
      if old_params[packet_item.name]
        value_item = Qt::TableWidgetItem.new(old_params[packet_item.name][0])
      else
        if default_state
          value_item = Qt::TableWidgetItem.new(default_state.to_s)
        elsif @production
          value_item = Qt::TableWidgetItem.new(packet_item.states.keys[0])
        else
          value_item = Qt::TableWidgetItem.new(MANUALLY)
        end
      end
      value_item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
      value_item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
      @table.setItem(row, 1, value_item)

      state_value = packet_item.default.to_s
      if old_params[packet_item.name]
        state_value = old_params[packet_item.name][1]
      end
      is_integer = Integer(state_value) rescue false
      if CmdParams.states_in_hex && is_integer
        state_value_item = Qt::TableWidgetItem.new(sprintf("0x%X", state_value))
      else
        if state_value.is_printable?
          state_value_item = Qt::TableWidgetItem.new(state_value)
        else
          state_value_item = Qt::TableWidgetItem.new("0x" + state_value.simple_formatted)
        end
      end
      state_value_item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
      if @production
        state_value_item.setFlags(Qt::NoItemFlags)
      else
        state_value_item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
      end
      @table.setItem(row, 2, state_value_item)

      # If the parameter is required clear the combobox and
      # clear the value field so they have to choose something
      if packet_item.required && !old_params[packet_item.name]
        value_item.setText('')
        state_value_item.setText('')
      end
      return [value_item, state_value_item]
    end

    def create_item(packet_item, old_params, row)
      if old_params[packet_item.name]
        value_text = old_params[packet_item.name]
      elsif packet_item.required
        value_text = ''
      else
        if packet_item.format_string
          begin
            value_text = sprintf(packet_item.format_string, packet_item.default)
          rescue
            # Oh well - Don't use the format string
            value_text = packet_item.default.to_s
          end
        else
          value_text = packet_item.default.to_s
        end
      end
      if !value_text.is_printable?
        value_text = "0x" + value_text.simple_formatted
      # Add quotes around STRING or BLOCK defaults so they are interpreted correctly
      elsif (packet_item.data_type == :STRING or packet_item.data_type == :BLOCK)
        value_text = "'#{value_text}'"
      end
      value_item = Qt::TableWidgetItem.new(value_text)
      value_item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
      value_item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
      @table.setItem(row, 1, value_item)
      @table.setSpan(row, 1, 1, 2)
      return value_item
    end

    def connect_table_item_changed
      @table.connect(SIGNAL('itemChanged(QTableWidgetItem*)')) do |item|
        packet_item, value_item, state_value_item = @param_widgets[item.row]
        if item.column == 1
          if packet_item.states
            value = packet_item.states[value_item.text]
            if packet_item.hazardous.key?(value_item.text)
              desc = packet_item.hazardous[value]
              # Hazardous states aren't required to have a description so use the item description
              desc = packet_item.description unless desc
              @table.item(item.row, 4).setText("(Hazardous) #{desc}")
            else
              @table.item(item.row, 4).setText(packet_item.description)
            end
            @table.blockSignals(true)
            if CmdParams.states_in_hex && value.kind_of?(Integer)
              state_value_item.setText(sprintf("0x%X", value))
            else
              state_value_item.setText(value.to_s)
            end
            @table.blockSignals(false)
          end
        elsif item.column == 2
          @table.blockSignals(true)
          @table.item(item.row, 1).setText(MANUALLY)
          @table.blockSignals(false)
        end
        calculate_height()
        emit modified()
      end
      calculate_height()
    end

    def calculate_height
      @table.resizeColumnsToContents()
      @table.resizeRowsToContents()
      height = @table.horizontalHeader.height + 2 # 2 = Header frame?
      @table.rowCount.times do |i|
        # TODO: rowHeight does not reflect word wrapping ... it's always 37
        height += @table.rowHeight(i)
        # NOTE: Checking the fontMetrics boundingRect also does not refect word wrapping
        #   e.g. Cosmos.getFontMetrics(@table.font).boundingRect(@table.item(x,y).text).height
      end
      @table.setMaximumHeight(height)
      @table.setMinimumHeight(height)
    end
  end
end
