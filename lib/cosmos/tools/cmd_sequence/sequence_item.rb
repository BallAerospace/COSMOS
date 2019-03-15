# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'time'
require 'cosmos'
Cosmos.catch_fatal_exception do
  require 'cosmos/script'
  require 'cosmos/gui/dialogs/calendar_dialog'
  require 'cosmos/gui/dialogs/cmd_details_dialog'
  require 'cosmos/tools/cmd_sender/cmd_param_table_item_delegate'
end

module Cosmos
  # Widget that represents an individual command that is sent as part of a
  # sequence. Items can have absolute execution times or a relative delay from
  # the previous item.
  class SequenceItem < Qt::Frame # Inherit from Frame so we can use setFrameStyle
    # Emit the modified signal to allow changes to propagate upwards
    signals 'modified()'
    MANUALLY = "MANUALLY ENTERED"

    # Parse a time and command string into a SequenceItem which is returned
    # @param time [String] Time (absolute or relative delay). Supports a single
    #   float value (relative delay) or a absolute time specified as
    #   "YYYY/MM/DD HH:MM:SS.MS"
    # @param command [String] Command String which should not be
    #   quoted and is everything inside the quotes of a command.
    #   For example: TGT PKT with STRING 'HI', VALUE 12. Parse errors are
    #   raised as execptions which must be handled by higher level code.
    # @return [SequenceItem] SequenceItem which the line represents
    def self.parse(time, command)
      tgt_name, pkt_name, cmd_params = extract_fields_from_cmd_text(command)
      packet = System.commands.packet(tgt_name, pkt_name).dup
      packet.restore_defaults
      cmd_params.each do |param_name, param_value|
        packet.write(param_name, param_value)
      end
      SequenceItem.new(packet, time)
    end

    # Create a new SequenceItem based on the given command with the given delay
    # @param command [Packet] Command packet
    # @param time [String] Absolute time in YYYY/MM/DD HH:MM:SS format or a
    #   single float value representing the delta delay time
    def initialize(command, time = nil)
      super()
      @command = command
      @table = nil
      @param_widgets = []
      @show_ignored = false
      @states_in_hex = false
      @expanded = false
      @file_dir = System.paths['LOGS']

      setAutoFillBackground(true)
      setPalette(Cosmos.getPalette("black", "white"))
      setFrameStyle(Qt::Frame::Box)

      top_layout = Qt::VBoxLayout.new
      top_layout.setContentsMargins(2, 0, 0, 0)
      setLayout(top_layout)
      top_layout.addLayout(create_cmd_layout(command, time))
      top_layout.addWidget(create_parameters())
      update_cmd_params()
      set_cmd_name_info()
    end

    # Set or clear read only status on the item
    # @param bool [Boolean] Whether to make the item read only
    def read_only(bool)
      @time.setReadOnly(bool)
    end

    # Show or hide ignored parameters
    # @param bool [Boolean] Whether to show ignored command items
    def show_ignored(bool)
      @show_ignored = bool
      update_cmd_params(bool)
    end

    # Display state values in hex (or decimal)
    # @param bool [Boolean] Whether to display state values in hex
    def states_in_hex(bool)
      @states_in_hex = bool
      @param_widgets.each do |_, _, state_value_item|
        next unless state_value_item
        text = state_value_item.text
        quotes_removed = text.remove_quotes
        if text == quotes_removed
          if bool
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

    # Show the command parameters part of the GUI
    def expand
      @expanded = true
      @parameters.show
    end

    # Hide the command parameters part of the GUI
    def collapse
      @expanded = false
      @parameters.hide
    end

    # @return [Hash] All the parameter item values keyed by their name
    def command_params
      params = {}
      @param_widgets.each do |packet_item, value_item, state_value_item|
        text = ''
        Qt.execute_in_main_thread do
          text = value_item.text
          text = state_value_item.text if state_value_item && (text == MANUALLY)
        end
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
        raise "#{packet_item.name} is required" if quotes_removed == '' && packet_item.required
      end
      params
    end

    # @return [String] Command to be executed with no quotes or other decorations
    def command_string
      output_string =  System.commands.build_cmd_output_string(@command.target_name, @command.packet_name, command_params(), false)
      if output_string =~ /[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\xFF]/
        output_string = output_string.inspect.remove_quotes
      end
      output_string[5..-3]
    end

    # @return [String] Absolute or relative time
    def time
      time = ''
      Qt.execute_in_main_thread { time = @time.text }
      time
    end

    def command
      System.commands.build_cmd(@command.target_name, @command.packet_name, command_params(), false)
    end

    # @return [String] Time and command string
    def save
      "COMMAND \"#{time}\" \"#{command_string}\""
    end

    # Handles showing and hiding the command parameters. Must be part of the
    # public API.
    def mouseReleaseEvent(event)
      super(event)
      if event.button == Qt::LeftButton
        @expanded = !@expanded
        if @expanded
          @parameters.show
        else
          @parameters.hide
        end
      end
    end

    protected

    # Create the command layout which holds the command name, information,
    # and the delete button to remove the sequence item.
    # @param command [Packet] Command packet
    # @param time [String] Execution delay in absolute or relative time
    def create_cmd_layout(command, time)
      cmd_layout = Qt::HBoxLayout.new
      cmd_layout.setContentsMargins(0, 0, 0, 0)
      cmd_layout.addWidget(create_time_edit(time))

      @cmd_name = Qt::Label.new("#{command.target_name} #{command.packet_name}")
      cmd_layout.addWidget(@cmd_name)
      @cmd_info = Qt::Label.new("") # Label for the hazardous designation
      cmd_layout.addWidget(@cmd_info)
      cmd_layout.addStretch()

      delete = Qt::PushButton.new
      delete.setFixedSize(25, 25)
      delete_icon = Cosmos.get_icon('delete.png')
      delete.setIcon(delete_icon)
      delete.connect(SIGNAL('clicked()')) do
        emit modified() # Tell the higher level that we're gone
        self.dispose
      end
      cmd_layout.addWidget(delete)
      cmd_layout
    end

    # Creates the time edit widget which holds the time delay. The widget is
    # a normal LineEdit which is edited as usual to enter a relative delay.
    # If the widget is right clicked it launches a CalendarDialog to allow the
    # user to select and absolute time to execute the sequence item.
    # @param time [String] The initial value for the time delay
    def create_time_edit(time)
      @time = Qt::LineEdit.new(Time.now.sys.formatted)
      fm = @time.fontMetrics
      # Set the width to support an absolute time
      @time.setFixedWidth(fm.boundingRect(Time.now.sys.formatted).width + 10)
      @time.text = time ? time : "0.00"
      # Setting the absolute time is via a Right-Click custom context menu
      @time.setContextMenuPolicy(Qt::CustomContextMenu)
      @time.connect(SIGNAL('customContextMenuRequested(const QPoint&)')) do
        dialog = CalendarDialog.new(@time, "Select Absolute Execution Time:", Time.now.sys, true)
        case dialog.exec
        when Qt::Dialog::Accepted
          @time.text = dialog.time.formatted
        end
      end
      @time.connect(SIGNAL('textChanged(const QString&)')) { emit modified }
      @time
    end

    # Create the parameters widget which holds the command description and
    # the table which contains all the command parameters
    def create_parameters
      @parameters = Qt::Widget.new
      parameters_layout = Qt::VBoxLayout.new
      # Command Description Label
      dec_label = Qt::Label.new("Description:")
      description = Qt::Label.new(@command.description)
      description.setWordWrap(true)
      desc_layout = Qt::HBoxLayout.new
      desc_layout.addWidget(dec_label)
      desc_layout.addWidget(description, 1)
      parameters_layout.addLayout(desc_layout)

      param_label = Qt::Label.new("Parameters:")
      parameters_layout.addWidget(param_label)
      @table_layout = Qt::VBoxLayout.new
      parameters_layout.addLayout(@table_layout, 500)
      @parameters.setLayout(parameters_layout)
      @parameters.hide
      @parameters
    end

    # Update the command parameters table for the given command
    # @param ignored_toggle [Boolean] Whether to display the ignored
    #   parameters. Pass nil (the default) to keep the existing setting.
    def update_cmd_params(ignored_toggle = nil)
      old_params = {}
      if !ignored_toggle.nil?
        # Save parameter values
        @param_widgets.each do |packet_item, value_item, state_value_item|
          text = value_item.text
          if state_value_item
            old_params[packet_item.name] = [text, state_value_item.text]
          else
            old_params[packet_item.name] = text
          end
        end
      end

      target = System.targets[@command.target_name]
      packet_items = @command.sorted_items
      shown_packet_items = []
      packet_items.each do |packet_item|
        if target && target.ignored_parameters.include?(packet_item.name) && !@show_ignored
          if @param_widgets.empty? # First time rendering the parameters
            if packet_item.states
              # Skip this if the default matches the saved value
              next if @command.read_item(packet_item, :RAW) == packet_item.default
            else
              # Skip this if the default matches the saved value
              next if @command.read_item(packet_item) == packet_item.default
            end
          else # Check the current values
            result = @param_widgets.select {|item,_,_| item == packet_item }
            next if result.empty?
            _, value_item, state_value_item = result[0]
            value = state_value_item ? state_value_item.text : value_item.text
            # Skip this if the default matches the current value
            next if packet_item.default.to_s == value
          end
        end
        shown_packet_items << packet_item
      end

      @table.dispose if @table
      @table = nil

      # Update Parameters
      @param_widgets = []
      drawn_header = false

      row = 0
      shown_packet_items.each do |packet_item|
        value_item = nil
        state_value_item = nil

        unless drawn_header
          @table = Qt::TableWidget.new()
          @table.setSizePolicy(Qt::SizePolicy::Expanding, Qt::SizePolicy::Expanding)
          @table.setWordWrap(true)
          @table.setRowCount(shown_packet_items.length)
          @table.setColumnCount(5)
          @table.setHorizontalHeaderLabels(['Name', '         Value or State         ', '         ', 'Units', 'Description'])
          @table.verticalHeader.setVisible(false)
          @table.setItemDelegate(CmdParamTableItemDelegate.new(@table, @param_widgets))
          @table.setEditTriggers(Qt::AbstractItemView::DoubleClicked | Qt::AbstractItemView::SelectedClicked | Qt::AbstractItemView::AnyKeyPressed)
          @table.setSelectionMode(Qt::AbstractItemView::NoSelection)
          @table.setContextMenuPolicy(Qt::CustomContextMenu)
          @table.connect(SIGNAL('customContextMenuRequested(const QPoint&)')) do |point|
            context_menu(point)
          end
          drawn_header = true
        end

        # Parameter Name
        item = Qt::TableWidgetItem.new("#{packet_item.name}:")
        item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
        @table.setItem(row, 0, item)

        if packet_item.states
          default = @command.read_item(packet_item, :RAW)
          default_state = packet_item.states.key(default)
          if old_params[packet_item.name]
            value_item = Qt::TableWidgetItem.new(old_params[packet_item.name][0])
          else
            if default_state
              value_item = Qt::TableWidgetItem.new(default_state.to_s)
            else
              value_item = Qt::TableWidgetItem.new(MANUALLY)
            end
          end
          value_item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
          value_item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
          @table.setItem(row, 1, value_item)

          if old_params[packet_item.name]
            state_value_item = Qt::TableWidgetItem.new(old_params[packet_item.name][1])
          else
            if @states_in_hex && packet_item.default.kind_of?(Integer)
              state_value_item = Qt::TableWidgetItem.new(sprintf("0x%X", default))
            else
              default_str = default.to_s
              if default_str.is_printable?
                state_value_item = Qt::TableWidgetItem.new(default_str)
              else
                state_value_item = Qt::TableWidgetItem.new("0x" + default_str.simple_formatted)
              end
            end
          end
          state_value_item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
          state_value_item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
          @table.setItem(row, 2, state_value_item)
        else # Parameter Value
          if old_params[packet_item.name]
            value_item = Qt::TableWidgetItem.new(old_params[packet_item.name])
          else
            default = @command.read_item(packet_item)
            if packet_item.format_string
              begin
                value_text = sprintf(packet_item.format_string, default)
              rescue
                # Oh well - Don't use the format string
                value_text = default.to_s
              end
            else
              value_text = default.to_s
            end
            if !value_text.is_printable?
              value_text = "0x" + value_text.simple_formatted
            end
            value_item = Qt::TableWidgetItem.new(value_text)
          end
          value_item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
          value_item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
          @table.setItem(row, 1, value_item)
          @table.setSpan(row, 1, 1, 2)
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

      if @table
        connect_table_item_changed()
        @table.setSizePolicy(Qt::SizePolicy.Minimum, Qt::SizePolicy.Minimum)
        @table.setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOff)
        @table.setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff)
        @table.resizeColumnsToContents()
        @table.resizeRowsToContents()
        @table.setFixedSize(@table.horizontalHeader.length + @table.verticalHeader.width,
                            2 + @table.verticalHeader.length + @table.horizontalHeader.height)
        @table_layout.addWidget(@table)
      end
    end

    # Sets the @cmd_name label to the command that will be sent. Also udpates
    # the @cmd_info with whether this command is hazardous or not.
    def set_cmd_name_info
      @cmd_name.text = command_string
      hazardous, _ = System.commands.cmd_hazardous?(@command.target_name, @command.packet_name, command_params())
      if hazardous
        @cmd_info.text = "(Hazardous)"
      else
        @cmd_info.text = ""
      end
    rescue => error
      @cmd_info.text = "(Error)"
      Qt::MessageBox.warning(self, 'Error', error.message)
    end

    # If the user right clicks over a table item, this method displays a context
    # menu with various options.
    # @param point [Qt::Point] Point to display the context menu
    def context_menu(point)
      target_name = @command.target_name
      packet_name = @command.packet_name
      item = @table.itemAt(point)
      if item
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
      end # if item
    end

    # Connect the itemChanged signal to the table so we can handle user edits
    # of the table parameters. This method emits the modified signal.
    def connect_table_item_changed
      @table.connect(SIGNAL('itemChanged(QTableWidgetItem*)')) do |item|
        packet_item, value_item, state_value_item = @param_widgets[item.row]
        if item.column == 1
          if packet_item.states
            value = packet_item.states[value_item.text]
            @table.blockSignals(true)
            if @states_in_hex && value.kind_of?(Integer)
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
        set_cmd_name_info()
        emit modified # Tell the higher level that something changed
      end
    end
  end
end
