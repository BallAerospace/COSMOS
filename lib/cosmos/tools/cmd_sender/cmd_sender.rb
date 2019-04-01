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
  require 'cosmos/gui/qt_tool'
  require 'cosmos/gui/text/completion'
  require 'cosmos/gui/utilities/script_module_gui'
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/gui/dialogs/cmd_details_dialog'
  require 'cosmos/gui/widgets/full_text_search_line_edit'
  require 'cosmos/tools/cmd_sender/cmd_sender_text_edit'
  require 'cosmos/tools/cmd_sender/cmd_param_table_item_delegate'
  require 'cosmos/config/config_parser'
  require 'cosmos/script'
end

module Cosmos
  Cosmos.disable_warnings do
    module Script
      def prompt_for_script_abort
        window = get_cmd_tlm_gui_window()
        window.statusBar.showMessage("Hazardous command not sent")
        return true # Aborted - Don't retry
      end
    end
  end

  $eval_binding = binding()

  # Command Sender sends commands to the COSMOS server. It gives the user
  # a drop down to select the target and then command to send.
  # It then displays all the command parameters. Once a
  # command is sent it is added to the command history window which allows the
  # user to resend the command or copy it for use in a script.
  class CmdSender < QtTool
    slots 'file_send_raw()'
    slots 'update_cmd_params(bool)'
    slots 'menu_states_in_hex(bool)'
    slots 'target_changed(const QString&)'
    slots 'cmd_changed(const QString&)'
    slots 'send_button()'
    slots 'context_menu(const QPoint&)'
    slots 'click_callback(QTableWidgetItem*)'

    MANUALLY = CmdParamTableItemDelegate::MANUALLY

    # @return [Integer] Number of commands sent
    def self.send_count
      @@send_count
    end

    # @param val [Integer] Number of commands sent
    def self.send_count=(val)
      @@send_count = val
    end

    # @return [Array<PacketItem, Qt::TableWidgetItem, Qt::TableWidgetItem>]
    #   Array of the packet item, the table widget item representing the value,
    #   and the table widget item representing states if the packet item has
    #   states.
    def self.param_widgets
      @@param_widgets
    end

    # @return [Qt::TableWidget] Table holding the command parameters. Each
    #   parameter is a separate row in the table.
    def self.table
      @@table
    end

    # Create the application by building the GUI and loading an initial target
    # and command packet. This can be passed on the command line or the first
    # target and packet will be loaded.
    # @param (see QtTool#initialize)
    def initialize(options)
      # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      super(options)
      Cosmos.load_cosmos_icon("cmd_sender.png")

      @file_dir = System.paths['LOGS']
      @message_log = MessageLog.new('cmdsender')
      @production = options.production
      @send_raw_dir = nil
      @@send_count = 0
      @@param_widgets = []
      @@table = nil

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize() # defined in qt_tool

      # Bring up slash screen for long duration tasks after creation
      Splash.execute(self) do |splash|
        # Configure CosmosConfig to interact with splash screen
        ConfigParser.splash = splash

        System.commands
        Qt.execute_in_main_thread(true) do
          update_targets()
          @target_select.setCurrentText(options.packet[0]) if options.packet
          update_commands()
          @cmd_select.setCurrentText(options.packet[1]) if options.packet
          update_cmd_params()

          # Handle searching entries
          @search_box.completion_list = System.commands.all_packet_strings(true, splash)
          @search_box.callback = lambda do |cmd|
            split_cmd = cmd.split(" ")
            if split_cmd.length == 2
              target_name = split_cmd[0].upcase
              @target_select.setCurrentText(target_name)
              update_commands()
              command_name = split_cmd[1]
              @cmd_select.setCurrentText(command_name)
              update_cmd_params()
            end
          end

        end

        # Unconfigure CosmosConfig to interact with splash screen
        ConfigParser.splash = nil
      end
    end

    # Create the File and Mode menu actions
    def initialize_actions
      super()
      # File menu actions
      @send_raw_action = Qt::Action.new(Cosmos.get_icon('send_file.png'),
                                        '&Send Raw',
                                        self)
      @send_raw_action.shortcut  = Qt::KeySequence.new('Ctrl+S')
      tip = 'Send raw data from a file'
      if @production
        tip += ' - Disabled in Production Mode'
        @send_raw_action.setEnabled(false)
      end
      @send_raw_action.statusTip = tip
      connect(@send_raw_action, SIGNAL('triggered()'), self, SLOT('file_send_raw()'))

      # Mode menu actions
      @ignore_range = Qt::Action.new('&Ignore Range Checks', self)
      tip = 'Ignore range checks when processing command'
      if @production
        tip += ' - Disabled in Production Mode'
        @ignore_range.setEnabled(false)
      end
      @ignore_range.statusTip = tip
      @ignore_range.setCheckable(true)
      @ignore_range.setChecked(false)

      @states_in_hex = Qt::Action.new('&Display State Values in Hex', self)
      @states_in_hex.statusTip = 'Display states values in hex instead of decimal'
      @states_in_hex.setCheckable(true)
      @states_in_hex.setChecked(false)
      connect(@states_in_hex, SIGNAL('toggled(bool)'), self, SLOT('menu_states_in_hex(bool)'))

      @show_ignored = Qt::Action.new('&Show Ignored Parameters', self)
      @show_ignored.statusTip = 'Show ignored parameters which are normally hidden'
      @show_ignored.setCheckable(true)
      @show_ignored.setChecked(false)
      connect(@show_ignored, SIGNAL('toggled(bool)'), self, SLOT('update_cmd_params(bool)'))

      @cmd_raw = Qt::Action.new('Disable &Parameter Conversions', self)
      tip = 'Send the command without running write or state conversions'
      if @production
        tip += ' - Disabled in Production Mode'
        @cmd_raw.setEnabled(false)
      end
      @cmd_raw.statusTip = tip
      @cmd_raw.setCheckable(true)
      @cmd_raw.setChecked(false)
    end

    # Create the File and Mode menus and initialize the help menu
    def initialize_menus
      file_menu = menuBar.addMenu('&File')
      file_menu.addAction(@send_raw_action)
      file_menu.addAction(@exit_action)
      file_menu.insertSeparator(@exit_action)

      mode_menu = menuBar.addMenu('&Mode')
      mode_menu.addAction(@ignore_range)
      mode_menu.addAction(@states_in_hex)
      mode_menu.addAction(@show_ignored)
      mode_menu.addAction(@cmd_raw)

      @about_string = "Command Sender allows the user to send any command defined in the system."
      initialize_help_menu()
    end

    # Create the GUI which consists of a split window and add the top and
    # bottom half widgets. The top half contains the command sender and the
    # bottom half contains the history.
    def initialize_central_widget
      central_widget = Qt::Widget.new
      setCentralWidget(central_widget)

      splitter = Qt::Splitter.new(central_widget)
      splitter.setOrientation(Qt::Vertical)
      splitter.addWidget(create_sender_widget)
      splitter.addWidget(create_history_widget)
      splitter.setStretchFactor(0,10)
      splitter.setStretchFactor(1,1)

      layout = Qt::VBoxLayout.new
      layout.setSpacing(1)
      layout.setContentsMargins(1, 1, 1, 1)
      layout.setSizeConstraint(Qt::Layout::SetMaximumSize)
      layout.addWidget(splitter)
      central_widget.layout = layout

      # Mark this window as the window for popups
      set_cmd_tlm_gui_window(self)
    end

    # Create the top half widget which contains target and packet combobox
    # selections that update a table of command parameters.
    def create_sender_widget
      # Create the top half of the splitter window
      sender = Qt::Widget.new

      # Create the top level vertical layout
      top_layout = Qt::VBoxLayout.new(sender)
      # Set the size constraint to always respect the minimum sizes of the child widgets
      # If this is not set then when we refresh the command parameters they'll all be squished
      top_layout.setSizeConstraint(Qt::Layout::SetMinimumSize)

      # Mnemonic Search Box
      @search_box = FullTextSearchLineEdit.new(self)
      top_layout.addWidget(@search_box)

      # Set the target combobox selection
      @target_select = Qt::ComboBox.new
      @target_select.setMaxVisibleItems(6)
      connect(@target_select, SIGNAL('activated(const QString&)'), self, SLOT('target_changed(const QString&)'))
      target_label = Qt::Label.new("&Target:")
      target_label.setBuddy(@target_select)

      # Set the comamnd combobox selection
      @cmd_select = Qt::ComboBox.new
      @cmd_select.setMaxVisibleItems(20)
      connect(@cmd_select, SIGNAL('activated(const QString&)'), self, SLOT('cmd_changed(const QString&)'))
      cmd_label = Qt::Label.new("&Command:")
      cmd_label.setBuddy(@cmd_select)

      # Button to send command
      send = Qt::PushButton.new("Send")
      connect(send, SIGNAL('clicked()'), self, SLOT('send_button()'))

      # Layout the top level selection
      select_layout = Qt::HBoxLayout.new
      select_layout.addWidget(target_label)
      select_layout.addWidget(@target_select, 1)
      select_layout.addWidget(cmd_label)
      select_layout.addWidget(@cmd_select, 1)
      select_layout.addWidget(send)
      top_layout.addLayout(select_layout)

      # Separator Between Command Selection and Command Description
      sep1 = Qt::Frame.new(sender)
      sep1.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      top_layout.addWidget(sep1)

      # Command Description Label
      dec_label = Qt::Label.new("Description:")
      @description = Qt::Label.new('')
      @description.setWordWrap(true)
      desc_layout = Qt::HBoxLayout.new
      desc_layout.addWidget(dec_label)
      desc_layout.addWidget(@description, 1)
      top_layout.addLayout(desc_layout)

      # Separator Between Command Selection and Description
      sep2 = Qt::Frame.new(sender)
      sep2.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      top_layout.addWidget(sep2)

      # Parameters Label
      param_label = Qt::Label.new("Parameters:")
      top_layout.addWidget(param_label)

      # Grid Layout for Parameters
      @table_layout = Qt::VBoxLayout.new
      top_layout.addLayout(@table_layout, 500)

      # Add stretch to force everything to fit against the top of the window
      # otherwise the selection window, description, and parameters all try
      # to get equal space.
      top_layout.addStretch(1)

      # Create the scroll area
      scroll = Qt::ScrollArea.new
      scroll.setMinimumSize(500, 150)
      scroll.setWidgetResizable(true)
      scroll.setWidget(sender)
      scroll
    end

    # Create the history widget which consists of a {CmdSenderTextEdit} that
    # displays the history of sent commands.
    def create_history_widget
      # Create the text edit where previously issued commands go and where
      # commands can be manually typed in and re-executed
      @input = CmdSenderTextEdit.new(statusBar)
      @input.setFocus()

      layout = Qt::VBoxLayout.new
      layout.setSpacing(1)
      layout.setContentsMargins(1, 1, 1, 1)
      layout.setSizeConstraint(Qt::Layout::SetMaximumSize)
      layout.addWidget(Qt::Label.new("Command History: (Pressing Enter on the line re-executes the command)"))
      layout.addWidget(@input)
      history = Qt::Widget.new
      history.layout = layout
      history
    end

    # Changes the display of items with states to hex if checked is true.
    # Otherwise state values are displayed as decimal.
    # @param checked [Boolean] Whether to display state values in hex
    def menu_states_in_hex(checked)
      @@param_widgets.each do |_, _, state_value_item|
        next unless state_value_item
        text = state_value_item.text
        quotes_removed = text.remove_quotes
        if text == quotes_removed
          if checked
            if text.is_int?
              @@table.blockSignals(true)
              state_value_item.text = sprintf("0x%X", text.to_i)
              @@table.blockSignals(false)
            end
          else
            if text.is_hex?
              @@table.blockSignals(true)
              state_value_item.text = Integer(text).to_s
              @@table.blockSignals(false)
            end
          end
        end
      end
    end

    # Opens a dialog which allows the user to select a file to read and send
    # directly over the interface.
    def file_send_raw
      dialog = Qt::Dialog.new(self, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      dialog.setWindowTitle("Send Raw Data From File")
      layout = Qt::GridLayout.new
      interfaces = Qt::ComboBox.new
      interfaces.addItems(get_interface_names())
      interfaces.setMaxVisibleItems(30)
      layout.addWidget(interfaces, 0, 1)
      int_label = Qt::Label.new("&Interface:")
      int_label.setBuddy(interfaces)
      layout.addWidget(int_label, 0, 0)

      file_line = Qt::LineEdit.new(@send_raw_dir)
      file_line.setMinimumSize(250, 0)
      file_label = Qt::Label.new("&Filename:")
      file_label.setBuddy(file_line)
      get_file = Qt::PushButton.new("Select")
      file_layout = Qt::BoxLayout.new(Qt::Horizontal)
      file_layout.addWidget(get_file)
      file_layout.addWidget(file_line)
      get_file.connect(SIGNAL('clicked()')) do
        Cosmos.set_working_dir do
          file_line.text = Qt::FileDialog::getOpenFileName(self, "Select File", @send_raw_dir, "Binary Files (*.bin);;All Files (*)")
        end
      end

      layout.addWidget(file_label, 1, 0)
      layout.addLayout(file_layout, 1, 1)

      button_layout = Qt::BoxLayout.new(Qt::Horizontal)
      ok = Qt::PushButton.new("Ok")
      connect(ok, SIGNAL('clicked()'), dialog, SLOT('accept()'))
      button_layout.addWidget(ok)
      cancel = Qt::PushButton.new("Cancel")
      connect(cancel, SIGNAL('clicked()'), dialog, SLOT('reject()'))
      button_layout.addWidget(cancel)
      layout.addLayout(button_layout, 2, 0, 1 ,2)

      dialog.setLayout(layout)
      if dialog.exec == Qt::Dialog::Accepted
        @send_raw_dir = file_line.text
        Cosmos.set_working_dir do
          send_raw_file(interfaces.text, file_line.text)
        end
      end
      dialog.dispose
    rescue Exception => err
      message = "Error sending raw file due to #{err}"
      @message_log.write(Time.now.formatted + '  ' + message + "\n")
      statusBar.showMessage(message)
    rescue DRb::DRbConnError
      message = "Error Connecting to Command and Telemetry Server"
      @message_log.write(Time.now.formatted + '  ' + message + "\n")
      statusBar.showMessage(message)
    end

    # (see QtTool#closeEvent)
    def closeEvent(event)
      shutdown_cmd_tlm()
      @message_log.stop
      super(event)
    end

    # Updates the commands combobox and command parameters table
    def target_changed(_)
      update_commands()
      update_cmd_params()
    end

    # Updates the command parameters table
    def cmd_changed(_)
      update_cmd_params()
    end

    # Sends the current command and parameters to the target
    def send_button
      target_name = @target_select.text
      packet_name = @cmd_select.text
      if target_name and packet_name
        output_string, params = view_as_script()
        @message_log.write(Time.now.sys.formatted + '  ' + output_string + "\n")
        if @cmd_raw.checked?
          if @ignore_range.checked?
            cmd_raw_no_range_check(target_name, packet_name, params)
          else
            cmd_raw(target_name, packet_name, params)
          end
        else
          if @ignore_range.checked?
            cmd_no_range_check(target_name, packet_name, params)
          else
            cmd(target_name, packet_name, params)
          end
        end
        if statusBar.currentMessage != 'Hazardous command not sent'
          @@send_count += 1
          statusBar.showMessage("#{output_string} sent. (#{@@send_count})")
          @input.append(output_string)
          @input.moveCursor(Qt::TextCursor::End)
          @input.ensureCursorVisible()
        end
      end
    rescue DRb::DRbConnError
      message = "Error Connecting to Command and Telemetry Server"
      @message_log.write(Time.now.formatted + '  ' + message + "\n")
      statusBar.showMessage(message)
      Qt::MessageBox.critical(self, 'Error', message)
    rescue Exception => err
      message = "Error sending #{target_name} #{packet_name} due to #{err}"
      @message_log.write(Time.now.formatted + '  ' + message + "\n")
      statusBar.showMessage(message)
      Qt::MessageBox.critical(self, 'Error', message)
    end

    # @return [String, Hash] Command as it would appear in a ScriptRunner script
    def view_as_script
      params = {}

      @@param_widgets.each do |packet_item, value_item, state_value_item|
        text = value_item.text

        text = state_value_item.text if state_value_item && (text == MANUALLY or @cmd_raw.checked?)
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
        raise "#{packet_item.name} is required." if quotes_removed == '' && packet_item.required
      end
      statusBar.clearMessage()

      output_string = System.commands.build_cmd_output_string(@target_select.text, @cmd_select.text, params, @cmd_raw.checked?)
      if output_string =~ /[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\xFF]/
        output_string = output_string.inspect.remove_quotes
      end

      if @cmd_raw.checked?
        if @ignore_range.checked?
          output_string.insert(7, '_no_range_check')
        end
      else
        if @ignore_range.checked?
          output_string.insert(3, '_no_range_check')
        end
      end

      return output_string, params
    end

    # Updates the targets combobox
    def update_targets
      @target_select.clearItems()
      target_names = System.commands.target_names
      target_names_to_delete = []
      target_names.each do |target_name|
        found_non_hidden = false
        begin
          packets = System.commands.packets(target_name)
          packets.each do |packet_name, packet|
            found_non_hidden = true unless packet.hidden
          end
        rescue
          # Don't do anything
        end
        target_names_to_delete << target_name unless found_non_hidden
      end
      target_names_to_delete.each do |target_name|
        target_names.delete(target_name)
      end
      target_names.each do |target_name|
        @target_select.addItem(target_name)
      end
    end

    # Updates the commands combobox based on the selected target
    def update_commands
      @cmd_select.clearItems()
      target_name = @target_select.text
      if target_name
        commands = System.commands.packets(@target_select.text)
        command_names = []
        commands.each do |command_name, command|
          command_names << command_name unless command.hidden
        end
        command_names.sort!
        command_names.each do |command_name|
          @cmd_select.addItem(command_name)
        end
      end
    end

    # Updates the command parameters table based on the selected target and
    # packet comboboxes
    # @param ignored_toggle [Boolean] Whether to display the ignored
    #   parameters. Pass nil (the default) to keep the existing setting.
    def update_cmd_params(ignored_toggle = nil)
      old_params = {}
      if !ignored_toggle.nil?
        # Save parameter values
        @@param_widgets.each do |packet_item, value_item, state_value_item|
          text = value_item.text
          if state_value_item
            old_params[packet_item.name] = [text, state_value_item.text]
          else
            old_params[packet_item.name] = text
          end
        end
      end

      # Clear Status Bar
      statusBar.showMessage("")

      target_name = @target_select.text
      target = System.targets[target_name]
      packet_name = @cmd_select.text
      if target_name && packet_name
        packet = System.commands.packet(target_name, packet_name)
        packet_items = packet.sorted_items
        shown_packet_items = []
        packet_items.each do |packet_item|
          next if target && target.ignored_parameters.include?(packet_item.name) && !@show_ignored.checked?
          shown_packet_items << packet_item
        end

        # Update Command Description
        @description.text = packet.description.to_s

        # Destroy the old table widget
        @@table.dispose if @@table
        @@table = nil

        # Update Parameters
        @@param_widgets = []
        drawn_header = false

        row = 0
        shown_packet_items.each do |packet_item|
          next if target && target.ignored_parameters.include?(packet_item.name) && !@show_ignored.checked?
          value_item = nil
          state_value_item = nil

          unless drawn_header
            @@table = Qt::TableWidget.new()
            @@table.setSizePolicy(Qt::SizePolicy::Expanding, Qt::SizePolicy::Expanding)
            @@table.setWordWrap(true)
            @@table.setRowCount(shown_packet_items.length)
            @@table.setColumnCount(5)
            @@table.setHorizontalHeaderLabels(['Name', '         Value or State         ', '         ', 'Units', 'Description'])
            @@table.horizontalHeader.setStretchLastSection(true)
            @@table.verticalHeader.setVisible(false)
            @@table.setItemDelegate(CmdParamTableItemDelegate.new(@@table, @@param_widgets, @production))
            @@table.setContextMenuPolicy(Qt::CustomContextMenu)
            @@table.verticalHeader.setResizeMode(Qt::HeaderView::ResizeToContents)
            @@table.setEditTriggers(Qt::AbstractItemView::DoubleClicked | Qt::AbstractItemView::SelectedClicked | Qt::AbstractItemView::AnyKeyPressed)
            @@table.setSelectionMode(Qt::AbstractItemView::NoSelection)
            connect(@@table, SIGNAL('customContextMenuRequested(const QPoint&)'), self, SLOT('context_menu(const QPoint&)'))
            connect(@@table, SIGNAL('itemClicked(QTableWidgetItem*)'), self, SLOT('click_callback(QTableWidgetItem*)'))
            drawn_header = true
          end

          # Parameter Name
          item = Qt::TableWidgetItem.new("#{packet_item.name}:")
          item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
          item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
          @@table.setItem(row, 0, item)

          if packet_item.states
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
            @@table.setItem(row, 1, value_item)

            if old_params[packet_item.name]
              state_value_item = Qt::TableWidgetItem.new(old_params[packet_item.name][1])
            else
              if @states_in_hex.checked? && packet_item.default.kind_of?(Integer)
                state_value_item = Qt::TableWidgetItem.new(sprintf("0x%X", packet_item.default))
              else
                default_str = packet_item.default.to_s
                if default_str.is_printable?
                  state_value_item = Qt::TableWidgetItem.new(default_str)
                else
                  state_value_item = Qt::TableWidgetItem.new("0x" + default_str.simple_formatted)
                end
              end
            end
            state_value_item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
            if @production
              state_value_item.setFlags(Qt::NoItemFlags)
            else
              state_value_item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
            end
            @@table.setItem(row, 2, state_value_item)

            # If the parameter is required clear the combobox and
            # clear the value field so they have to choose something
            if packet_item.required && !old_params[packet_item.name]
              value_item.setText('')
              state_value_item.setText('')
            end
          else
            # Parameter Value
            if old_params[packet_item.name]
              value_item = Qt::TableWidgetItem.new(old_params[packet_item.name])
            else
              if packet_item.required
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
                if !value_text.is_printable?
                  value_text = "0x" + value_text.simple_formatted
                # Add quotes around STRING or BLOCK defaults so CmdSender interprets them correctly
                elsif (packet_item.data_type == :STRING or packet_item.data_type == :BLOCK)
                  value_text = "'#{packet_item.default}'"
                end
              end
              value_item = Qt::TableWidgetItem.new(value_text)
            end
            value_item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
            value_item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
            @@table.setItem(row, 1, value_item)
            @@table.setSpan(row, 1, 1, 2)
          end

          # Units
          item = Qt::TableWidgetItem.new(packet_item.units.to_s)
          item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
          item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
          @@table.setItem(row, 3, item)

          # Description
          item = Qt::TableWidgetItem.new(packet_item.description.to_s)
          item.setTextAlignment(Qt::AlignLeft | Qt::AlignVCenter)
          item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
          @@table.setItem(row, 4, item)

          @@param_widgets << [packet_item, value_item, state_value_item]
          row += 1
        end

        if @@table
          @@table.connect(SIGNAL('itemChanged(QTableWidgetItem*)')) do |item|
            packet_item, value_item, state_value_item = @@param_widgets[item.row]
            if item.column == 1
              if packet_item.states
                value = packet_item.states[value_item.text]
                @@table.blockSignals(true)
                if @states_in_hex.checked? && value.kind_of?(Integer)
                  state_value_item.setText(sprintf("0x%X", value))
                else
                  state_value_item.setText(value.to_s)
                end
                @@table.blockSignals(false)
              end
            elsif item.column == 2
              @@table.blockSignals(true)
              @@table.item(item.row, 1).setText(MANUALLY)
              @@table.blockSignals(false)
            end
          end
          @table_layout.addWidget(@@table, 500)
          @@table.resizeColumnsToContents()
          @@table.resizeRowsToContents()
        end
      end # if target_name && packet_name
    end

    # If the user right clicks over a table item, this method displays a context
    # menu with various options.
    # @param point [Qt::Point] Point to display the context menu
    def context_menu(point)
      target_name = @target_select.text
      packet_name = @cmd_select.text
      item = @@table.itemAt(point)
      if item
        item_name = @@table.item(item.row, 0).text[0..-2] # Remove :
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
              _, value_item, state_value_item = @@param_widgets[item.row]
              if state_value_item
                state_value_item.setText(filename)
              elsif value_item
                value_item.setText(filename)
              end
            end
          end
          menu.addAction(file_chooser_action)

          menu.exec(@@table.mapToGlobal(point))
          menu.dispose
        end
      end
    end

    # @param item [Qt::TableWidgetItem] Item which was left clicked
    def click_callback(item)
      @@table.editItem(item) if (item.flags & Qt::ItemIsEditable) != 0
    end

    # (see QtTool.run)
    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser && options
          option_parser, options = create_default_options()
          options.width = 600
          options.height = 425
          options.title = 'Command Sender'
          options.production = false
          option_parser.separator "Command Sender Specific Options:"
          option_parser.on("-p", "--packet 'TARGET_NAME PACKET_NAME'", "Start with the specified command selected") do |arg|
            split = arg.split
            if split.length != 2
              puts "Packet must be specified as 'TARGET_NAME PACKET_NAME' in quotes"
              exit
            end
            options.packet = split
          end
          option_parser.on(nil, "--production", "Run in production mode which disables the ability to manually enter data.") do |arg|
            options.production = true
          end
        end

        super(option_parser, options)
      end
    end
  end
end
