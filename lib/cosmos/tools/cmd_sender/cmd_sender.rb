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
  require 'cosmos/tools/cmd_sender/cmd_params'
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
    MANUALLY = CmdParamTableItemDelegate::MANUALLY

    # @return [Integer] Number of commands sent
    def self.send_count
      @@send_count
    end

    # @param val [Integer] Number of commands sent
    def self.send_count=(val)
      @@send_count = val
    end

    # Create the application by building the GUI and loading an initial target
    # and command packet. This can be passed on the command line or the first
    # target and packet will be loaded.
    # @param (see QtTool#initialize)
    def initialize(options)
      # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      super(options)
      Cosmos.load_cosmos_icon("cmd_sender.png")

      @message_log = MessageLog.new('cmdsender')
      @production = options.production
      @send_raw_dir = nil
      @@send_count = 0
      @cmd_params = CmdParams.new

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
      @send_raw_action.connect(SIGNAL('triggered()')) { file_send_raw }

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
      @states_in_hex.setChecked(CmdParams.states_in_hex)
      @states_in_hex.connect(SIGNAL('toggled(bool)')) do |checked|
        @cmd_params.states_in_hex(checked)
      end

      @show_ignored = Qt::Action.new('&Show Ignored Parameters', self)
      @show_ignored.statusTip = 'Show ignored parameters which are normally hidden'
      @show_ignored.setCheckable(true)
      @show_ignored.setChecked(CmdParams.show_ignored)
      @show_ignored.connect(SIGNAL('toggled(bool)')) do |checked|
        update_cmd_params(checked)
      end

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
      @target_select.connect(SIGNAL('activated(const QString&)')) do |target|
        update_commands()
        update_cmd_params()
      end
      target_label = Qt::Label.new("&Target:")
      target_label.setBuddy(@target_select)

      # Set the comamnd combobox selection
      @cmd_select = Qt::ComboBox.new
      @cmd_select.setMaxVisibleItems(20)
      @cmd_select.connect(SIGNAL('activated(const QString&)')) {|command| update_cmd_params }
      cmd_label = Qt::Label.new("&Command:")
      cmd_label.setBuddy(@cmd_select)

      # Button to send command
      send = Qt::PushButton.new("Send")
      send.connect(SIGNAL('clicked()')) { send_button }

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
      statusBar.clearMessage()
      params = @cmd_params.params_text(@cmd_raw.checked?)
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
    # @param checked [Boolean] Whether the show ignored parameters option
    #   is checked. Pass nil (the default) to keep the existing setting.
    def update_cmd_params(checked = nil)
      # Clear Status Bar
      statusBar.showMessage("")

      target_name = @target_select.text
      target = System.targets[target_name]
      packet_name = @cmd_select.text
      if target_name && packet_name
        packet = System.commands.packet(target_name, packet_name)
        # Directly update packet description ... safe because always in GUI thread
        hazardous, _ = System.commands.cmd_hazardous?(target_name, packet_name)
        if hazardous
          @description.text = "(Hazardous) #{packet.description}"
        else
          @description.text = packet.description
        end
        table = @cmd_params.update_cmd_params(packet, show_ignored: checked)
        @table_layout.addWidget(table, 500) if table
      end
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
