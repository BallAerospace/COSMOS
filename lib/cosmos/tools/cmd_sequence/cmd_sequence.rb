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
  require 'cosmos/config/config_parser'
  require 'cosmos/gui/qt_tool'
  require 'cosmos/gui/utilities/script_module_gui'
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/gui/widgets/realtime_button_bar'
  require 'cosmos/gui/choosers/file_chooser'
  require 'cosmos/tools/cmd_sequence/sequence_list'
end

module Cosmos
  # Creates and executes command sequences. Commands are choosen through a GUI
  # similar to CmdSender where the user selects a target, command, and then
  # sets the command parameters in a table layout. Sequences can be saved and
  # loaded and can have relative or absolute delays.
  class CmdSequence < QtTool
    # Runs the CmdSequence application
    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser && options
          option_parser, options = create_default_options()
          options.width = 600
          options.height = 425
          option_parser.on("-o", "--output DIRECTORY", "Save files in the specified directory") do |arg|
            options.output_dir = File.expand_path(arg)
          end
          options.run_sequence = nil
          option_parser.on("-r", "--run FILE", "Open and run the specified sequence") do |arg|
            options.run_sequence = arg
          end
        end
        super(option_parser, options)
      end
    end

    # Creates the CmdSequence instance
    # @param options [OpenStruct] Application command line options
    def initialize(options)
      # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      super(options)
      Cosmos.load_cosmos_icon("cmd_sequence.png")
      if options.output_dir
        @sequence_dir = options.output_dir
      else
        @sequence_dir = System.paths['SEQUENCES']
      end
      @filename = "Untitled"
      @run_thread = nil

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize() # defined in qt_tool
      update_title()

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
        end
        # Unconfigure CosmosConfig to interact with splash screen
        ConfigParser.splash = nil
      end
      run_sequence(options.run_sequence) if options.run_sequence
    end

    # Creates the menu actions
    def initialize_actions
      super()

      @file_new = Qt::Action.new(Cosmos.get_icon('file.png'), tr('&New'), self)
      @file_new_keyseq = Qt::KeySequence.new(tr('Ctrl+N'))
      @file_new.shortcut  = @file_new_keyseq
      @file_new.statusTip = tr('Start a new sequence')
      @file_new.connect(SIGNAL('triggered()')) { file_new() }

      @file_save = Qt::Action.new(Cosmos.get_icon('save.png'), tr('&Save'), self)
      @file_save_keyseq = Qt::KeySequence.new(tr('Ctrl+S'))
      @file_save.shortcut  = @file_save_keyseq
      @file_save.statusTip = tr('Save the sequence')
      @file_save.connect(SIGNAL('triggered()')) { file_save(false) }

      @file_save_as = Qt::Action.new(Cosmos.get_icon('save_as.png'), tr('Save &As'), self)
      @file_save_as.statusTip = tr('Save the sequence')
      @file_save_as.connect(SIGNAL('triggered()')) { file_save(true) }

      @export_action = Qt::Action.new(tr('&Export Sequence'), self)
      @export_action.shortcut = Qt::KeySequence.new(tr('Ctrl+E'))
      @export_action.statusTip = tr('Export the current sequence to a custom binary format')
      @export_action.connect(SIGNAL('triggered()')) { export() }

      @show_ignored = Qt::Action.new(tr('&Show Ignored Parameters'), self)
      @show_ignored.statusTip = tr('Show ignored parameters which are normally hidden')
      @show_ignored.setCheckable(true)
      @show_ignored.setChecked(false)
      @show_ignored.connect(SIGNAL('toggled(bool)')) do |bool|
        @sequence_list.map {|item| item.show_ignored(bool) }
      end

      @states_in_hex = Qt::Action.new(tr('&Display State Values in Hex'), self)
      @states_in_hex.statusTip = tr('Display states values in hex instead of decimal')
      @states_in_hex.setCheckable(true)
      @states_in_hex.setChecked(false)
      @states_in_hex.connect(SIGNAL('toggled(bool)')) do |bool|
        @sequence_list.map {|item| item.states_in_hex(bool) }
      end

      @expand_action = Qt::Action.new(tr('&Expand All'), self)
      @expand_action.statusTip = tr('Expand all currently visible commands')
      @expand_action.connect(SIGNAL('triggered()')) do
        @sequence_list.map {|item| item.expand }
      end

      @collapse_action = Qt::Action.new(tr('&Collapse All'), self)
      @collapse_action.statusTip = tr('Collapse all currently visible commands')
      @collapse_action.connect(SIGNAL('triggered()')) do
        @sequence_list.map {|item| item.collapse }
      end

      @script_disconnect = Qt::Action.new(Cosmos.get_icon('disconnected.png'), tr('&Toggle Disconnect'), self)
      @script_disconnect_keyseq = Qt::KeySequence.new(tr('Ctrl+T'))
      @script_disconnect.shortcut  = @script_disconnect_keyseq
      @script_disconnect.statusTip = tr('Toggle disconnect from the server')
      @script_disconnect.connect(SIGNAL('triggered()')) do
        @server_config_file ||= CmdTlmServer::DEFAULT_CONFIG_FILE
        @server_config_file = toggle_disconnect(@server_config_file)
      end
    end

    # Create the application menus and assign the actions
    def initialize_menus
      file_menu = menuBar.addMenu(tr('&File'))
      file_menu.addAction(@file_new)

      open_action = Qt::Action.new(self)
      open_action.shortcut = Qt::KeySequence.new(tr('Ctrl+O'))
      open_action.connect(SIGNAL('triggered()')) { file_open(@sequence_dir) }
      self.addAction(open_action)

      file_open = file_menu.addMenu(tr('&Open'))
      file_open.setIcon(Cosmos.get_icon('open.png'))
      target_dirs_action(file_open, System.paths['SEQUENCES'], 'sequences', method(:file_open))

      file_menu.addAction(@file_save)
      file_menu.addAction(@file_save_as)
      file_menu.addSeparator()
      file_menu.addAction(@exit_action)

      action_menu = menuBar.addMenu(tr('&Actions'))
      action_menu.addAction(@show_ignored)
      action_menu.addAction(@states_in_hex)
      action_menu.addSeparator()
      action_menu.addAction(@expand_action)
      action_menu.addAction(@collapse_action)
      action_menu.addSeparator()
      action_menu.addAction(@script_disconnect)

      @about_string = "Sequence Generator generates and executes sequences of commands."
      initialize_help_menu()
    end

    # Create the CmdSequence GUI
    def initialize_central_widget
      central_widget = Qt::Widget.new
      setCentralWidget(central_widget)
      central_layout = Qt::VBoxLayout.new
      central_widget.layout = central_layout

      @realtime_button_bar = RealtimeButtonBar.new(self)
      @realtime_button_bar.start_callback = method(:handle_start)
      @realtime_button_bar.pause_callback = method(:handle_pause)
      @realtime_button_bar.stop_callback  = method(:handle_stop)
      @realtime_button_bar.state = 'Stopped'
      central_layout.addWidget(@realtime_button_bar)

      @target_select = Qt::ComboBox.new
      @target_select.setMaxVisibleItems(6)
      @target_select.connect(SIGNAL('activated(const QString&)')) do |target|
        target_changed()
      end
      target_label = Qt::Label.new(tr("&Target:"))
      target_label.setBuddy(@target_select)

      @cmd_select = Qt::ComboBox.new
      @cmd_select.setMaxVisibleItems(20)
      cmd_label = Qt::Label.new(tr("&Command:"))
      cmd_label.setBuddy(@cmd_select)

      add = Qt::PushButton.new("Add")
      add.connect(SIGNAL('clicked()')) do
        command = System.commands.packet(@target_select.text, @cmd_select.text)
        @sequence_list.add(command)
      end

      # Layout the target and command selection with Add button
      select_layout = Qt::HBoxLayout.new
      select_layout.addWidget(target_label)
      select_layout.addWidget(@target_select, 1)
      select_layout.addWidget(cmd_label)
      select_layout.addWidget(@cmd_select, 1)
      select_layout.addWidget(add)
      central_layout.addLayout(select_layout)

      # Create a splitter to hold the sequence area and the script output text area
      splitter = Qt::Splitter.new(Qt::Vertical, self)
      central_layout.addWidget(splitter)

      @sequence_list = SequenceList.new
      @sequence_list.connect(SIGNAL("modified()")) { update_title }

      scroll = Qt::ScrollArea.new()
      scroll.setSizePolicy(Qt::SizePolicy::Preferred, Qt::SizePolicy::Expanding)
      scroll.setWidgetResizable(true)
      scroll.setWidget(@sequence_list)
      connect(scroll.verticalScrollBar(), SIGNAL("valueChanged(int)"), @sequence_list, SLOT("update()"))
      splitter.addWidget(scroll)

      bottom_frame = Qt::Widget.new
      bottom_layout = Qt::VBoxLayout.new
      bottom_layout.setContentsMargins(0,0,0,0)
      bottom_layout_label = Qt::Label.new("Sequence Output:")
      bottom_layout.addWidget(bottom_layout_label)
      @output = Qt::TextEdit.new
      @output.setReadOnly(true)
      bottom_layout.addWidget(@output)
      bottom_frame.setLayout(bottom_layout)
      splitter.addWidget(bottom_frame)
      splitter.setStretchFactor(0,1)
      splitter.setStretchFactor(1,0)
    end

    # Clears the sequence list
    def file_new
      return unless prompt_for_save_if_needed()
      @sequence_list.clear
      @filename = "Untitled"
    end

    # Opens a sequence list file and populates the GUI
    # @param filename [String] Name of the file to open
    def file_open(filename = nil)
      return unless prompt_for_save_if_needed()
      if File.directory?(filename)
        filename = Qt::FileDialog.getOpenFileName(self, "Select Sequence", filename)
      else
        filename = Qt::FileDialog.getOpenFileName(self, "Select Sequence")
      end
      if !filename.nil? && File.exist?(filename) && !File.directory?(filename)
        # Try to open and load the file. Errors are handled here.
        @sequence_list.open(filename)
        @filename = filename
        @sequence_dir = File.dirname(filename)
        @sequence_dir << '/' if @sequence_dir[-1..-1] != '/' and @sequence_dir[-1..-1] != '\\'
        update_title()
      end
    rescue => error
      @sequence_list.clear() # Errors during load invalidate the sequence
      Qt::MessageBox.critical(self, 'Error', error.message)
    end

    # Saves the GUI configuration to file. Also performs SaveAs by prompting
    # for a new filename.
    # @param save_as [Boolean] Whether to SaveAs and prompt for a filename
    def file_save(save_as = false)
      filename = @filename # Start with the current filename
      saved = false
      if filename == 'Untitled' # No file is currently open
        filename = Qt::FileDialog::getSaveFileName(self,         # parent
                                                   'Save As...', # caption
                                                   @sequence_dir + '/sequence.tsv', # dir
                                                   'Sequence Files (*.tsv)') # filter
      elsif save_as
        filename = Qt::FileDialog::getSaveFileName(self,         # parent
                                                   'Save As...', # caption
                                                   filename,     # dir
                                                   'Sequence Files (*.tsv)') # filter
      end
      if !filename.nil? && !filename.empty?
        begin
          @sequence_list.save(filename)
          saved = true
          @filename = filename
          update_title()
          @sequence_dir = File.dirname(filename)
          @sequence_dir << '/' if @sequence_dir[-1..-1] != '/' and @sequence_dir[-1..-1] != '\\'
        rescue => error
          Qt::MessageBox.critical(self, 'Error', error.message)
        end
      end
      saved
    end

    # Toggles whether CmdSequence is sending files to the CmdTlmServer (default)
    # or disconnects and processes them all internally. The disconnected mode
    # sets the background color to red to visually distinguish that no commands
    # are actually going to the server.
    # @param config_file [String] cmd_tlm_server.txt configuration file to
    #   process when creating the disconnected server
    def toggle_disconnect(config_file)
      if get_cmd_tlm_disconnect
        set_cmd_tlm_disconnect(false)
        self.setPalette(Cosmos::DEFAULT_PALETTE)
      else
        dialog = Qt::Dialog.new(self, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
        dialog.setWindowTitle(tr("Server Config File"))
        dialog_layout = Qt::VBoxLayout.new

        chooser = FileChooser.new(self, "Config File", config_file, 'Select',
                                  File.join('config', 'tools', 'cmd_tlm_server', config_file))
        chooser.callback = lambda do |filename|
          chooser.filename = File.basename(filename)
        end
        dialog_layout.addWidget(chooser)

        button_layout = Qt::HBoxLayout.new
        ok = Qt::PushButton.new("Ok")
        ok.setDefault(true)
        ok.connect(SIGNAL('clicked()')) do
          dialog.accept()
        end
        button_layout.addWidget(ok)
        cancel = Qt::PushButton.new("Cancel")
        cancel.connect(SIGNAL('clicked()')) do
          dialog.reject()
        end
        button_layout.addWidget(cancel)
        dialog_layout.addLayout(button_layout)

        dialog.setLayout(dialog_layout)
        if dialog.exec == Qt::Dialog::Accepted
          config_file = chooser.filename
          self.setPalette(Qt::Palette.new(Cosmos.getColor(170, 57, 57)))
          Splash.execute(self) do |splash|
            ConfigParser.splash = splash
            splash.message = "Initializing Command and Telemetry Server"
            set_cmd_tlm_disconnect(true, config_file)
            ConfigParser.splash = nil
          end
        end
        dialog.dispose
      end
      config_file
    end

    # Handle the closeEvent to check if we're running or a sequence needs to
    # be saved before closing. Must be part of the public API.
    def closeEvent(event)
      if prompt_if_running_on_close()
        handle_stop()
        if prompt_for_save_if_needed()
          super(event)
        else
          event.ignore()
        end
      else
        event.ignore()
      end
    end

    # Handles the start button on the realtime_button_bar. This button changes
    # as sequences are running to "Go" which skips any remaining wait time on
    # the command. It also continues any paused sequences.
    def handle_start
      case @realtime_button_bar.state
      when 'Stopped'
        return unless prompt_for_save_if_needed()
        @pause = false
        @go = false
        @realtime_button_bar.state = 'Running'
        @realtime_button_bar.start_button.setText('Go')
        output_append("*** Sequence Started ***")
        @run_thread = Thread.new do
          @sequence_list.each do |item|
            execute_item(item)
          end
          # Since we're inside a new Ruby thread
          Qt.execute_in_main_thread do
            output_append("*** Sequence Complete ***")
            @output.append("") # delimit the sequences in the output log
            @realtime_button_bar.start_button.setText('Start')
            @realtime_button_bar.state = 'Stopped'
          end
        end
      when 'Paused'
        output_append("User pressed #{@realtime_button_bar.start_button.text}")
        @realtime_button_bar.state = 'Running'
        @pause = false
      when 'Running'
        output_append("User pressed #{@realtime_button_bar.start_button.text}")
        @go = true
      end
    end

    # Handles the pause button on the realtime_button_bar.
    def handle_pause
      @pause = true
      @realtime_button_bar.state = 'Paused'
      @realtime_button_bar.start_button.setEnabled(true)
      output_append("User pressed Pause")
    end

    # Handles the stop button on the realtime_button_bar. This kills the
    # run_thread which requires the user to restart the sequence.
    def handle_stop
      Cosmos.kill_thread(nil, @run_thread)
      @run_thread = nil
      @realtime_button_bar.start_button.setEnabled(true)
      @realtime_button_bar.start_button.setText('Start')
      @realtime_button_bar.state = 'Stopped'
      output_append("User pressed Stop")
      @output.append("") # delimit the sequences in the output log
    end

    protected

    # Executes a particular sequence item (command) by delaying for the given
    # time and then sending the command via cmd_no_hazardous_check.
    # @param item [SequenceItem] Item to execute, e.g. send the command
    def execute_item(item)
      Qt.execute_in_main_thread { item.setStyleSheet("color: green") }
      result = process_delay(item)
      command = item.command_string
      result += command # += in case we added a warning above
      cmd_no_hazardous_check(command)
    rescue DRb::DRbConnError
      result = "Error Connecting to Command and Telemetry Server"
    rescue Exception => err
      result = "Error sending #{target} #{packet} due to #{err}\n#{err.backtrace}"
    ensure
      Qt.execute_in_main_thread do
        item.setStyleSheet("")
        output_append(result)
      end
    end

    # Delays for the absolute or relative time given for the item
    # @param item [SequenceItem] Item with given delay time
    def process_delay(item)
      result = ''
      # Check for item containing a date
      if item.time.include?('/')
        start_time = Time.parse(item.time)
        if start_time - Time.now > 0
          while start_time - Time.now > 0
            break if check_go_and_pause()
          end
        else
          result = "WARNING: Start time #{start_time} has already passed!\n"
        end
      else # Relative delay
        start = Time.now
        while Time.now - start < item.time.to_f
          break if check_go_and_pause()
        end
      end
      result
    end

    # Checks the @go and @pause instance variables to determine how to proceed.
    # If @go is true it returns true immediately. If @pause is true it sleeps
    # continously while @pause is true. Otherwise it sleeps for a short time
    # and returns false.
    # @return [Boolean] true if @go is true, else false
    def check_go_and_pause
      if @go
        @go = false
        return true
      end
      if @pause
        sleep 0.01 while @pause
      else
        sleep 0.01
      end
      false
    end

    # Called when the target select dropdown changes to force the command
    # select to update
    def target_changed
      update_commands()
    end

    # Called once at initialization to populate the target select dropdown
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

    # Updates the command select dropdown based on the currently selected target
    def update_commands
      @cmd_select.clearItems()
      target_name = @target_select.text
      if target_name
        commands = System.commands.packets(target_name)
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

    # Opens the given filename and executes the sequence. Implemented to allow
    # for a command line option to immediately load and execute a sequence.
    # @param filename [String] Sequence file to open and run
    def run_sequence(filename)
      filename = find_sequence(filename)
      return unless filename
      @sequence_list.open(filename)
      @filename = filename
      update_title()
      handle_start()
    end

    # Finds the given filename by looking in the system sequences path as
    # well as in each target's sequences directory. If the file can not be
    # found an Error dialog is created.
    # @param filename [String] Filename to locate
    def find_sequence(filename)
      # If the filename is already sufficient, just expand the path.
      return File.expand_path(filename) if File.exist?(filename)

      # If the filename wasn't sufficient, can we find the file in the
      # system sequence directory?
      new_filename = File.join(System.paths['SEQUENCES'], filename)
      return File.expand_path(new_filename) if File.exist?(new_filename)

      # Ok, how about one of the target sequence directories?
      System.targets.each do |target_name, target|
        new_filename = File.join(target.dir, 'sequences', filename)
        return File.expand_path(new_filename) if File.exist?(new_filename)
      end
      Qt::MessageBox.critical(self, 'Error', "Could not find #{filename}")

      # Couldn't find the file anywhere.
      return nil
    end

    # Prompts the user that a sequence is running before they close the app
    def prompt_if_running_on_close
      safe_to_continue = true
      # Check for not Stopped since it can also be Running or Paused
      if @realtime_button_bar.state != "Stopped"
        case Qt::MessageBox.warning(
          self,      # parent
          'Warning!', # title
          'A Sequence is Running! Close Anyways?', # text
          Qt::MessageBox::Yes | Qt::MessageBox::No, # buttons
          Qt::MessageBox::No) # default button
        when Qt::MessageBox::Yes
          safe_to_continue = true
        else
          safe_to_continue = false
        end
      end
      safe_to_continue
    end

    # Prompts for save if the current sequence has been modified
    def prompt_for_save_if_needed(message = 'Save Current Sequence?')
      safe_to_continue = true
      if @sequence_list.modified?
        case Qt::MessageBox.question(
          self,    # parent
          'Save?', # title
          message, # text
          Qt::MessageBox::Yes | Qt::MessageBox::No | Qt::MessageBox::Cancel, # buttons
          Qt::MessageBox::Cancel) # default button
        when Qt::MessageBox::Cancel
          safe_to_continue = false
        when Qt::MessageBox::Yes
          saved = file_save(false) # Try save which returns true if successful
          safe_to_continue = false if !saved
        end
      end
      safe_to_continue
    end

    # Updates the title to show the sequence filename and modified status
    def update_title
      self.setWindowTitle("Command Sequence : #{@filename}")
      self.setWindowTitle(self.windowTitle << '*') if @sequence_list.modified?
    end

    # Append string to the output with the current time
    def output_append(string)
      Qt.execute_in_main_thread do
        string.split("\n").each do |line|
          @output.append(Time.now.sys.formatted + ':  ' + line)
        end
        @output.moveCursor(Qt::TextCursor::End)
        @output.ensureCursorVisible()
      end
    end
  end
end
