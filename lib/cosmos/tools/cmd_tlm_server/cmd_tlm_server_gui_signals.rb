# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'
require 'cosmos/tools/cmd_tlm_server/gui/interfaces_tab'
require 'cosmos/tools/cmd_tlm_server/gui/targets_tab'
require 'cosmos/tools/cmd_tlm_server/gui/packets_tab'
require 'cosmos/tools/cmd_tlm_server/gui/logging_tab'
require 'cosmos/tools/cmd_tlm_server/gui/status_tab'
require 'cosmos/gui/qt_tool'
require 'cosmos/gui/dialogs/splash'
require 'cosmos/gui/dialogs/exception_dialog'
require 'cosmos/gui/dialogs/set_tlm_dialog'

module Cosmos

  # Implements the GUI functions of the Command and Telemetry Server. All the
  # QT calls are implemented here. The non-GUI functionality is contained in
  # the CmdTlmServer class.
  class CmdTlmServerGui < QtTool
    slots 'handle_tab_change(int)'

    STOPPED = 0
    RUNNING = 1
    ERROR = 2

    TOOL_NAME = "Command and Telemetry Server"

    # For the CTS we display all the tables as full size
    # Thus we don't want the table to absorb the scroll wheel events but
    # instead pass them up to the container so the entire window will scroll.
    class Qt::TableWidget
      def wheelEvent(event)
        event.ignore()
      end
    end

    def meta_callback
      Qt.execute_in_main_thread(true) do
        result = SetTlmDialog.execute(self, 'Enter Metadata', 'Set Metadata', 'Cancel', 'SYSTEM', 'META')
        exit(1) unless result
      end
    end

    def initialize(options)
      super(options) # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      Cosmos.load_cosmos_icon("cts.png")

      @production = options.production
      @no_prompt = options.no_prompt
      @message_log = nil
      @output_sleeper = Sleeper.new
      @first_output = 0
      @interfaces_tab = InterfacesTab.new
      @targets_tab = TargetsTab.new
      @packets_tab = PacketsTab.new(self)
      @logging_tab = LoggingTab.new(@production)
      @status_tab = StatusTab.new

      statusBar.showMessage(tr("")) # Show blank message to initialize status bar

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      configure_tabs(options)
      complete_initialize()
    end

    def configure_tabs(options)
      Splash.execute(self) do |splash|
        ConfigParser.splash = splash
        splash.message = "Initializing #{TOOL_NAME}"

        # Start the thread that will process server messages and add them to the output text
        process_server_messages(options)

        CmdTlmServer.meta_callback = method(:meta_callback)
        cts = CmdTlmServer.new(options.config_file, @production)
        cts.stop_callback = method(:stop_callback)
        @message_log = CmdTlmServer.message_log

        # Now that we've started the server (CmdTlmServer.new) we can populate all the tabs
        splash.message = "Populating Tabs"
        Qt.execute_in_main_thread(true) do
          # Override the default title if one was given in the config file
          self.window_title = CmdTlmServer.title if CmdTlmServer.title
          splash.progress = 0
          @interfaces_tab.populate_interfaces(@tab_widget)
          splash.progress = 100/7 * 1
          @targets_tab.populate(@tab_widget)
          splash.progress = 100/7 * 2
          @packets_tab.populate_commands(@tab_widget)
          splash.progress = 100/7 * 3
          @packets_tab.populate_telemetry(@tab_widget)
          splash.progress = 100/7 * 4
          @interfaces_tab.populate_routers(@tab_widget)
          splash.progress = 100/7 * 5
          @logging_tab.populate(@tab_widget)
          splash.progress = 100/7 * 6
          @status_tab.populate(@tab_widget)
          splash.progress = 100
        end
        ConfigParser.splash = nil
      end
    end

    def initialize_actions
      super()

      # Edit actions
      @edit_clear_counters = Qt::Action.new(tr('&Clear Counters'), self)
      @edit_clear_counters.statusTip = tr('Clear counters for all interfaces and targets')
      @edit_clear_counters.connect(SIGNAL('triggered()')) { CmdTlmServer.clear_counters }
    end

    def initialize_menus
      @file_menu = menuBar.addMenu(tr('&File'))
      @file_menu.addAction(@exit_action)

      # Do not allow clear counters in production mode
      unless @production
        @edit_menu = menuBar.addMenu(tr('&Edit'))
        @edit_menu.addAction(@edit_clear_counters)
      end

      @about_string = "#{TOOL_NAME} is the heart of the COSMOS system. "
      @about_string << "It connects to the target and processes command and telemetry requests from other tools."

      initialize_help_menu()
    end

    def initialize_central_widget
      # Create the central widget
      @splitter = Qt::Splitter.new(Qt::Vertical, central_widget)
      setCentralWidget(@splitter)

      @tab_widget = Qt::TabWidget.new
      connect(@tab_widget, SIGNAL('currentChanged(int)'), self, SLOT('handle_tab_change(int)'))
      @splitter.addWidget(@tab_widget)

      # Add the message output
      @output = Qt::PlainTextEdit.new
      @output.setReadOnly(true)
      # Block count does NOT equal line numbers. Testing on Windows indicates
      # 100 blocks equals a little over 27000 lines.
      @output.setMaximumBlockCount(100)

      @splitter.addWidget(@output)
      # Set the stretch factor to give priority to the tab_widget (index 0) instead of the output (index 1)
      @splitter.setStretchFactor(0, 1) # (index, stretch)

      # Override stdout to the message window
      # All code attempting to print into the GUI must use $stdout rather than STDOUT
      @string_output = StringIO.new("", "r+")
      $stdout = @string_output
      Logger.level = Logger::INFO

      @tab_thread = nil
    end

    # Called when the user changes tabs in the Server application. It kills the
    # currently executing tab and then creates a new thread to update the GUI
    # for the selected tab.
    def handle_tab_change(index)
      kill_tab_thread()
      @tab_sleeper = Sleeper.new

      case index
      when 0
        handle_tab('Interfaces') { @interfaces_tab.update(InterfacesTab::INTERFACES) }
      when 1
        handle_tab('Targets') { @targets_tab.update }
      when 2
        handle_tab('Commands') { @packets_tab.update(PacketsTab::COMMANDS) }
      when 3
        handle_tab('Telemetry') { @packets_tab.update(PacketsTab::TELEMETRY) }
      when 4
        handle_tab('Routers') { @interfaces_tab.update(InterfacesTab::ROUTERS) }
      when 5
        handle_tab('Logging') { @logging_tab.update }
      when 6
        handle_status_tab()
      end
    end

    # Cancel the tab sleeper and kill the tab thread so we can create a new one
    def kill_tab_thread
      @tab_sleeper ||= nil
      @tab_sleeper.cancel if @tab_sleeper
      Qt::CoreApplication.instance.processEvents
      Cosmos.kill_thread(self, @tab_thread)
      @tab_thread = nil
    end

    # Wrapper method that starts a new thread and then loops. It ensures we are
    # executing in the main thread and then yields to allow updates to the GUI.
    # Finally it sleeps using a sleeper so it can be interrupted.
    #
    # @param name [String] Name of the tab
    def handle_tab(name)
      @tab_thread = Thread.new do
        begin
          while true
            Qt.execute_in_main_thread(true) { yield }
            break if @tab_sleeper.sleep(1)
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(self, error, "COSMOS CTS : #{name} Tab Thread")}
        end
      end
    end

    # Update the status tab of the server
    def handle_status_tab
      @tab_thread = Thread.new do
        begin
          while true
            start_time = Time.now.sys
            Qt.execute_in_main_thread(true) { @status_tab.update }
            total_time = Time.now.sys - start_time
            if total_time > 0.0 and total_time < 1.0
              break if @tab_sleeper.sleep(1.0 - total_time)
            end
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(self, error, "COSMOS CTS : Status Tab Thread")}
        end
      end
    end

    # Called when the user tries to close the server application. Popup a
    # dialog to warn them about the consequences and then gracefully shut
    # everything down.
    def closeEvent(event)
      # Create are you sure dialog
      if @no_prompt
        continue = true
      else
        msg = Qt::MessageBox.new(self)
        msg.setIcon(Qt::MessageBox::Question)
        msg.setText("Are you sure? All tools connected to this CmdTlmServer will lose connections and cease to function if the CmdTlmServer is closed.")
        msg.setWindowTitle('Confirm Close')
        msg.setStandardButtons(Qt::MessageBox::Yes | Qt::MessageBox::No)
        continue = false
        continue = true if msg.exec() == Qt::MessageBox::Yes
        msg.dispose
      end

      if continue
        kill_tab_thread()
        CmdTlmServer.instance.stop_logging('ALL')
        CmdTlmServer.instance.stop
        super(event)
      else
        event.ignore()
      end
    end

    # Thread to process server messages. Uses handle_string_output to process
    # the output.
    def process_server_messages(options)
      # Start thread to read server messages
      @output_thread = Thread.new do
        begin
          while !@message_log
            sleep(1)
          end
          while true
            handle_string_output()
            break if @output_sleeper.sleep(1)
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) do
            ExceptionDialog.new(self, error, "#{options.title}: Messages Thread")
          end
        end
      end
    end

    # Write any available messages to the output pane in the server GUI
    # as well as to the server message log.
    def handle_string_output
      if @string_output.string[-1..-1] == "\n"
        Qt.execute_in_main_thread(true) do
          lines_to_write = ''
          string = @string_output.string.clone
          @string_output.string = @string_output.string[string.length..-1]
          string.each_line {|out_line| @output.add_formatted_text(out_line); lines_to_write << out_line }
          @output.flush
          if @first_output < 2
            # Scroll to the bottom on the first two outputs for Linux
            # Otherwise it does not stay at the bottom
            @output.verticalScrollBar.value = @output.verticalScrollBar.maximum
            @first_output += 1
          end
          @message_log.write(lines_to_write)
        end
      end
    end

    # CmdTlmServer stop callback called by CmdTlmServer.stop. Ensures all the
    # output is written to the message logs.
    def stop_callback
      handle_string_output()
      @output_sleeper.cancel
      Qt::CoreApplication.processEvents()
      Cosmos.kill_thread(self, @output_thread)
      handle_string_output()
    end

    def graceful_kill
      # Just to avoid warning
    end

    def self.graceful_kill
      # Just to avoid warning
    end

    def self.no_gui_handle_string_output
      if @string_output.string[-1..-1] == "\n"
        lines_to_write = ''
        string = @string_output.string.clone
        @string_output.string = @string_output.string[string.length..-1]
        string.each_line {|out_line| lines_to_write << out_line }
        @message_log.write(lines_to_write)
        STDOUT.print lines_to_write if STDIN.isatty # Have a console
      end
    end

    def self.no_gui_stop_callback
      no_gui_handle_string_output()
      @output_sleeper.cancel
      Cosmos.kill_thread(self, @output_thread)
      no_gui_handle_string_output()
    end

    def self.post_options_parsed_hook(options)
      if options.no_gui
        begin
          @output_sleeper = Sleeper.new
          @string_output = StringIO.new("", "r+")
          $stdout = @string_output
          Logger.level = Logger::INFO
          cts = CmdTlmServer.new(options.config_file, options.production)
          @message_log = CmdTlmServer.message_log
          @output_thread = Thread.new do
            while true
              no_gui_handle_string_output()
              break if @output_sleeper.sleep(1)
            end
          end
          cts.stop_callback = method(:no_gui_stop_callback)
          keep_running = true
          Signal.trap("TERM") do
            puts "Caught signal: TERM"
            keep_running = false
          end
          Signal.trap("INT") do
            puts "Caught signal: INT"
            keep_running = false
          end
          while keep_running
            sleep(1)
          end
          puts "**** Shut down CTS ****"
          no_gui_handle_string_output()
          return false
        ensure
          puts "**** Executing ensure block ****"
          no_gui_handle_string_output()
          if defined? cts and cts
            cts.stop_logging('ALL')
            cts.stop
          end
        end
        return false
      else
        return true
      end
    end

    # Entry point to the server application
    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.width = 800
          options.height = 500
          # Set the default title which can be overridden in the config file
          options.title = TOOL_NAME
          options.auto_size = false
          options.config_file = CmdTlmServer::DEFAULT_CONFIG_FILE
          options.production = false
          options.no_prompt = false
          options.no_gui = false
          option_parser.separator "CTS Specific Options:"
          option_parser.on("-c", "--config FILE", "Use the specified configuration file") do |arg|
            options.config_file = arg
          end
          option_parser.on("-p", "--production", "Run the server in production mode which disables the ability to stop logging.") do |arg|
            options.production = true
          end
          option_parser.on("-n", "--no-prompt", "Don't prompt with Are You Sure dialog on close.") do |arg|
            options.no_prompt = true
          end
          option_parser.on(nil, "--no-gui", "Run the server without a GUI") do |arg|
            options.no_gui = true
          end
        end

        super(option_parser, options)
      end
    end

  end # class CmdTlmServerGui
end # module Cosmos
