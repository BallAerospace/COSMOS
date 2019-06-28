# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'
if RUBY_ENGINE == 'ruby'
  require 'cosmos/tools/cmd_tlm_server/gui/interfaces_tab'
  require 'cosmos/tools/cmd_tlm_server/gui/targets_tab'
  require 'cosmos/tools/cmd_tlm_server/gui/packets_tab'
  require 'cosmos/tools/cmd_tlm_server/gui/logging_tab'
  require 'cosmos/tools/cmd_tlm_server/gui/status_tab'
  require 'cosmos/tools/cmd_tlm_server/gui/replay_tab'
  require 'cosmos/gui/qt_tool'
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/gui/dialogs/exception_dialog'
  require 'cosmos/gui/dialogs/set_tlm_dialog'
else
  # The following stubs allow the CmdTlmServer to run under JRuby with no gui
  require 'ostruct'
  require 'optparse'

  class QtTool
    def self.slots(*args)
      # Do nothing
    end

    def self.create_default_options
      options = OpenStruct.new
      options.redirect_io = true
      options.title = "COSMOS Tool"
      parser = OptionParser.new do |option_parser|
        option_parser.banner = "Usage: ruby #{option_parser.program_name} [options]"
        option_parser.separator("")

        # Create the help option
        option_parser.on("-h", "--help", "Show this message") do
          puts option_parser
          exit
        end

        # Create the version option
        option_parser.on("-v", "--version", "Show version") do
          puts "COSMOS Version: #{COSMOS_VERSION}"
          puts "User Version: #{USER_VERSION}" if defined? USER_VERSION
          exit
        end

        # Create the system option
        option_parser.on("--system FILE", "Use an alternative system.txt file") do |arg|
          System.instance(File.join(USERPATH, 'config', 'system', arg))
        end
      end

      return parser, options
    end

    def self.run(option_parser = nil, options = nil)
      Cosmos.set_working_dir do
        option_parser, options = create_default_options() unless option_parser and options
        option_parser.parse!(ARGV)
        post_options_parsed_hook(options)
      end
    end
  end
end

module Cosmos
  # Implements the GUI functions of the Command and Telemetry Server. All the
  # QT calls are implemented here. The non-GUI functionality is contained in
  # the CmdTlmServer class.
  class CmdTlmServerGui < QtTool
    slots 'handle_tab_change(int)'

    STOPPED = 0
    RUNNING = 1
    ERROR = 2

    TOOL_NAME = "Command and Telemetry Server".freeze
    BLANK = ''.freeze

    attr_writer :no_prompt

    if RUBY_ENGINE == 'ruby'
      # For the CTS we display all the tables as full size
      # Thus we don't want the table to absorb the scroll wheel events but
      # instead pass them up to the container so the entire window will scroll.
      class Qt::TableWidget
        def wheelEvent(event)
          event.ignore()
        end
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

      @ready = false
      @tabs_ready = false
      if options.replay
        @mode = :REPLAY
        Cosmos.load_cosmos_icon("replay.png")
      else
        @mode = :CMD_TLM_SERVER
        Cosmos.load_cosmos_icon("cts.png")
      end
      @production = options.production
      @no_prompt = options.no_prompt
      @replay_routers = options.replay_routers
      @message_log = nil
      @output_sleeper = Sleeper.new
      @first_output = 0
      @options = options

      statusBar.showMessage("") # Show blank message to initialize status bar

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      Splash.execute(self) do |splash|
        ConfigParser.splash = splash
        process_server_messages(@options)
        start(splash)
        ConfigParser.splash = nil
      end
      complete_initialize()
    end

    def start(splash)
      splash.message = "Initializing #{@options.title}" if splash

      if !CmdTlmServer.instance or @mode == :CMD_TLM_SERVER
        CmdTlmServer.meta_callback = method(:meta_callback)
        cts = CmdTlmServer.new(@options.config_file, @production, false, @mode, @replay_routers)
        CmdTlmServerGui.configure_signal_handlers()
        cts.stop_callback = method(:stop_callback)
        cts.reload_callback = method(:reload)
        CmdTlmServer.replay_backend.config_change_callback = method(:config_change_callback) if @mode != :CMD_TLM_SERVER
        @message_log = CmdTlmServer.message_log
        @ready = true
      end

      # Now that we've started the server (CmdTlmServer.new) we can populate all the tabs
      splash.message = "Populating Tabs" if splash
      Qt.execute_in_main_thread(true) do
        # Override the default title if one was given in the config file
        self.window_title = CmdTlmServer.title if CmdTlmServer.title
        splash.progress = 0 if splash
        @tabs_ready = false
        if @mode == :CMD_TLM_SERVER
          @interfaces_tab.populate_interfaces
        else
          @replay_tab.populate
        end
        splash.progress = 100/7 * 1 if splash
        @targets_tab.populate
        splash.progress = 100/7 * 2 if splash
        @commands_tab.populate_commands
        splash.progress = 100/7 * 3 if splash
        @telemetry_tab.populate_telemetry
        splash.progress = 100/7 * 4 if splash
        @routers_tab.populate_routers
        if @mode == :CMD_TLM_SERVER
          splash.progress = 100/7 * 5 if splash
          @logging_tab.populate
        end
        splash.progress = 100/7 * 6 if splash
        @status_tab.populate
        splash.progress = 100 if splash
        @tabs_ready = true
        @tab_widget.setCurrentIndex(0)
        handle_tab_change(0)
      end
    end

    def initialize_actions
      super()

      # File actions
      @file_reload = Qt::Action.new('&Reload Configuration', self)
      @file_reload.statusTip = 'Reload configuraton and reset'
      @file_reload.connect(SIGNAL('triggered()')) do
        CmdTlmServer.instance.reload()
      end

      # Edit actions
      @edit_clear_counters = Qt::Action.new('&Clear Counters', self)
      @edit_clear_counters.statusTip = 'Clear counters for all interfaces and targets'
      @edit_clear_counters.connect(SIGNAL('triggered()')) { CmdTlmServer.clear_counters }
    end

    def initialize_menus
      @file_menu = menuBar.addMenu('&File')
      @file_menu.addAction(@file_reload)
      @file_menu.addAction(@exit_action)

      # Do not allow clear counters in production mode
      unless @production
        @edit_menu = menuBar.addMenu('&Edit')
        @edit_menu.addAction(@edit_clear_counters)
      end

      if @mode == :CMD_TLM_SERVER
        @about_string = "#{TOOL_NAME} is the heart of the COSMOS system. "
        @about_string << "It connects to the target and processes command and telemetry requests from other tools."
      else
        @about_string = "Replay allows playing back data into the COSMOS realtime tools. "
      end

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

      if @mode == :CMD_TLM_SERVER
        @interfaces_tab = InterfacesTab.new(self, InterfacesTab::INTERFACES, @tab_widget)
      else
        @replay_tab = ReplayTab.new(@tab_widget)
      end
      @targets_tab = TargetsTab.new(@tab_widget)
      @commands_tab = PacketsTab.new(self, PacketsTab::COMMANDS, @tab_widget)
      @telemetry_tab = PacketsTab.new(self, PacketsTab::TELEMETRY, @tab_widget, (@mode == :REPLAY))
      @routers_tab = InterfacesTab.new(self, InterfacesTab::ROUTERS, @tab_widget)
      if @mode == :CMD_TLM_SERVER
        @logging_tab = LoggingTab.new(@production, @tab_widget)
      end
      @status_tab = StatusTab.new(@tab_widget)
    end

    def config_change_callback
      CmdTlmServer.instance.replay_map_targets_to_interfaces
      start(nil)
    end

    def reload(confirm = true)
      Qt.execute_in_main_thread(true) do
        if confirm
          msg = Qt::MessageBox.new(self)
          msg.setIcon(Qt::MessageBox::Question)
          msg.setText("Are you sure? All connections will temporarily disconnect as the server restarts")
          msg.setWindowTitle('Confirm Reload')
          msg.setStandardButtons(Qt::MessageBox::Yes | Qt::MessageBox::No)
          continue = false
          continue = true if msg.exec() == Qt::MessageBox::Yes
          msg.dispose
        else
          continue = true
        end

        if continue
          Splash.execute(self) do |splash|
            ConfigParser.splash = splash
            Qt.execute_in_main_thread(true) do
              @tab_widget.setCurrentIndex(0)
            end
            if @mode == :CMD_TLM_SERVER
              Qt.execute_in_main_thread(true) do
                splash.message = "Stopping Threads"
                CmdTlmServer.instance.stop_callback = nil
                stop_threads()
              end
            end
            System.reset
            start(splash)
            Qt.execute_in_main_thread(true) do
              @tab_widget.setCurrentIndex(0)
              handle_tab_change(0)
            end
            ConfigParser.splash = nil
          end
        end
      end
    end

    # Called when the user changes tabs in the Server application. It kills the
    # currently executing tab and then creates a new thread to update the GUI
    # for the selected tab.
    def handle_tab_change(index)
      return unless @tabs_ready
      kill_tab_thread()
      @tab_sleeper = Sleeper.new

      case index
      when 0
        if @mode == :CMD_TLM_SERVER
          handle_tab('Interfaces') { @interfaces_tab.update }
        else
          handle_tab('Replay', 0.5) { @replay_tab.update }
        end
      when 1
        handle_tab('Targets') { @targets_tab.update }
      when 2
        handle_tab('Commands') { @commands_tab.update }
      when 3
        handle_tab('Telemetry') { @telemetry_tab.update }
      when 4
        handle_tab('Routers') { @routers_tab.update }
      when 5
        if @mode == :CMD_TLM_SERVER
          handle_tab('Logging') { @logging_tab.update }
        else
          handle_tab('Status') { @status_tab.update }
        end
      when 6
        handle_tab('Status') { @status_tab.update }
      end
    end

    # Cancel the tab sleeper and kill the tab thread so we can create a new one
    def kill_tab_thread
      @tab_sleeper ||= nil
      @tab_sleeper.cancel if @tab_sleeper
      @tab_thread_shutdown = true
      Qt::CoreApplication.instance.processEvents
      Qt::RubyThreadFix.queue.pop.call until Qt::RubyThreadFix.queue.empty?
      Cosmos.kill_thread(self, @tab_thread)
      @tab_thread = nil
    end

    # Wrapper method that starts a new thread and then loops. It ensures we are
    # executing in the main thread and then yields to allow updates to the GUI.
    # Finally it sleeps using a sleeper so it can be interrupted.
    #
    # @param name [String] Name of the tab
    def handle_tab(name, period = 1.0)
      @tab_thread_shutdown = false
      @tab_thread = Thread.new do
        begin
          while true
            start_time = Time.now.sys
            break if @tab_thread_shutdown
            Qt.execute_in_main_thread(true) { yield }
            total_time = Time.now.sys - start_time
            if total_time > 0.0 and total_time < period
              break if @tab_sleeper.sleep(period - total_time)
            end
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(self, error, "COSMOS CTS : #{name} Tab Thread")}
        end
      end
    end

    def stop_threads
      kill_tab_thread()
      @replay_tab.shutdown if @replay_tab
      CmdTlmServer.instance.stop_logging('ALL') if @mode == :CMD_TLM_SERVER
      CmdTlmServer.instance.stop
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
        if @mode == :CMD_TLM_SERVER
          msg.setText("Are you sure? All tools connected to this CmdTlmServer will lose connections and cease to function if the CmdTlmServer is closed.")
        else
          msg.setText("Are you sure? All tools connected to this Replay will lose connections and cease to function if the Replay is closed.")
        end
        msg.setWindowTitle('Confirm Close')
        msg.setStandardButtons(Qt::MessageBox::Yes | Qt::MessageBox::No)
        continue = false
        continue = true if msg.exec() == Qt::MessageBox::Yes
        msg.dispose
      end

      if continue
        stop_threads()
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
          while !@ready
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
          lines_to_write = []
          string = @string_output.string.clone
          @string_output.string = @string_output.string[string.length..-1]
          string.each_line {|out_line| lines_to_write << out_line; @output.add_formatted_text(out_line) }
          @output.flush
          if @first_output < 2
            # Scroll to the bottom on the first two outputs for Linux
            # Otherwise it does not stay at the bottom
            @output.verticalScrollBar.value = @output.verticalScrollBar.maximum
            @first_output += 1
          end
          clean_lines, messages = CmdTlmServerGui.process_output_colors(lines_to_write)
          @message_log.write(clean_lines) if @message_log
          messages.each {|msg| CmdTlmServer.instance.post_server_message(msg) }
        end
      end
    end

    # CmdTlmServer stop callback called by CmdTlmServer.stop. Ensures all the
    # output is written to the message logs.
    def stop_callback
      Qt.execute_in_main_thread(true) do
        handle_string_output()
        @output_sleeper.cancel
        Qt::CoreApplication.processEvents()
        Cosmos.kill_thread(self, @output_thread)
        handle_string_output()
      end
    end

    def graceful_kill
      # Just to avoid warning
    end

    def self.graceful_kill
      # Just to avoid warning
    end

    def self.no_gui_handle_string_output
      if @string_output.string[-1..-1] == "\n"
        lines_to_write = []
        string = @string_output.string.clone
        @string_output.string = @string_output.string[string.length..-1]
        string.each_line {|out_line| lines_to_write << out_line }
        clean_lines, messages = CmdTlmServerGui.process_output_colors(lines_to_write)
        @message_log.write(clean_lines) if @mode == :CMD_TLM_SERVER
        messages.each {|msg| CmdTlmServer.instance.post_server_message(msg) }
        STDOUT.print clean_lines if STDIN.isatty # Have a console
      end
    end

    def self.no_gui_stop_callback
      no_gui_handle_string_output()
      @output_sleeper.cancel
      Cosmos.kill_thread(self, @output_thread)
      no_gui_handle_string_output()
    end

    def self.no_gui_reload_callback(confirm = false)
      CmdTlmServer.instance.stop_logging('ALL') if @mode == :CMD_TLM_SERVER
      CmdTlmServer.instance.stop_callback = nil
      CmdTlmServer.instance.stop
      System.reset
      cts = CmdTlmServer.new(@options.config_file, @options.production, false, @mode, @options.replay_routers)

      # Signal catching needs to be repeated here because Puma interferes
      ["TERM", "INT"].each {|sig| Signal.trap(sig) {exit}}

      @message_log = CmdTlmServer.message_log
      cts.stop_callback = method(:no_gui_stop_callback)
      cts.reload_callback = method(:no_gui_reload_callback)
    end

    def self.process_output_colors(lines)
      clean_lines = ''
      messages = []
      lines.each do |line|
        if line =~ /<G>/
          line.gsub!(/<G>/, BLANK)
          messages << [line.strip, 'GREEN']
        elsif line =~ /<Y>/
          line.gsub!(/<Y>/, BLANK)
          messages << [line.strip, 'YELLOW']
        elsif line =~ /<R>/
          line.gsub!(/<R>/, BLANK)
          messages << [line.strip, 'RED']
        elsif line =~ /<B>/
          line.gsub!(/<B>/, BLANK)
          messages << [line.strip, 'BLUE']
        else
          messages << [line.strip, 'BLACK']
        end
        clean_lines << line
      end
      return [clean_lines, messages]
    end

    def self.post_options_parsed_hook(options)
      @options = options
      if options.no_gui
        normalize_config_options(options)
        
        ["TERM", "INT"].each {|sig| Signal.trap(sig) {exit}}

        begin
          @output_sleeper = Sleeper.new
          @string_output = StringIO.new("", "r+")
          $stdout = @string_output
          Logger.level = Logger::INFO
          if options.replay
            @mode = :REPLAY
          else
            @mode = :CMD_TLM_SERVER
          end
          cts = CmdTlmServer.new(options.config_file, options.production, false, @mode, options.replay_routers)

          # Signal catching needs to be repeated here because Puma interferes
          ["TERM", "INT"].each {|sig| Signal.trap(sig) {exit}}

          @message_log = CmdTlmServer.message_log
          @ready = true
          @output_thread = Thread.new do
            while true
              no_gui_handle_string_output()
              break if @output_sleeper.sleep(1)
            end
          end
          cts.stop_callback = method(:no_gui_stop_callback)
          cts.reload_callback = method(:no_gui_reload_callback)
          sleep # Sleep until waked by signal
        ensure
          if CmdTlmServer.instance
            CmdTlmServer.instance.stop_logging('ALL') if @mode == :CMD_TLM_SERVER
            CmdTlmServer.instance.stop
          end
        end
        return false
      else
        CmdTlmServerGui.configure_signal_handlers()
        return true
      end
    end

    def self.configure_signal_handlers
      ["TERM", "INT"].each do |sig|
        Signal.trap(sig) do
          # No synchronization is allowed in trap context, so we have
          # to spawn a thread here to send the close event.
          Thread.new do
            Qt.execute_in_main_thread(true) do
              @@window.no_prompt = true
              @@window.closeEvent(Qt::CloseEvent.new())
              exit
            end
          end
        end
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
          options.production = false
          options.no_prompt = false
          options.no_gui = false
          options.replay_routers = false
          options.config_file = true # config_file is required
          # Set config_dir because by default it would be config/tools/cmd_tlm_server_gui
          options.config_dir = File.join(Cosmos::USERPATH, 'config', 'tools', 'cmd_tlm_server')

          option_parser.separator "CTS Specific Options:"
          option_parser.on("-p", "--production", "Run the server in production mode which disables the ability to stop logging.") do |arg|
            options.production = true
          end
          option_parser.on("-n", "--no-prompt", "Don't prompt with Are You Sure dialog on close.") do |arg|
            options.no_prompt = true
          end
          option_parser.on(nil, "--no-gui", "Run the server without a GUI") do |arg|
            options.no_gui = true
          end

          if self.name == "Cosmos::Replay"
            options.replay = true
            options.title = "Replay"
            option_parser.on(nil, "--routers", "Enable All Routers") do |arg|
              options.replay_routers = true
            end
          else
            options.replay = false
          end
        end

        super(option_parser, options)
      end
    end
  end
end
