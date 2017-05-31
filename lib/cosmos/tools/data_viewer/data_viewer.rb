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
  require 'cosmos/script'
  require 'cosmos/config/config_parser'
  require 'cosmos/gui/qt_tool'
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/gui/dialogs/progress_dialog'
  require 'cosmos/gui/dialogs/exception_dialog'
  require 'cosmos/gui/dialogs/packet_log_dialog'
  require 'cosmos/gui/dialogs/find_replace_dialog'
  require 'cosmos/gui/widgets/realtime_button_bar'
  require 'cosmos/tools/data_viewer/data_viewer_component'
  require 'cosmos/tools/data_viewer/dump_component'
end

module Cosmos

  class DataViewer < QtTool
    slots 'context_menu(const QPoint&)'
    slots 'handle_tab_change(int)'

    def initialize(options)
      super(options) # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      Cosmos.load_cosmos_icon("data_viewer.png")

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()

      # Initialize instance variables
      @auto_start = false
      @pause = false
      @log_file_directory = System.paths['LOGS']
      @tlm_log_system = nil
      @subscription_thread = nil
      @subscription_id = nil
      @packet_log_reader = System.default_packet_log_reader.new
      @time_start = nil
      @time_end = nil
      @log_filenames = []
      @cancel_thread = false
      @sleeper = Sleeper.new

      # Process config file and create a tab for each data viewer component
      @component_mutex = Mutex.new
      @components = []
      @packets = []
      @packet_to_components_mapping = {}
      @config_filename = options.config_file
      process_config()

      # Load System Definition and Event Data
      Splash.execute(self) do |splash|
        Qt.execute_in_main_thread(true) do
          ConfigParser.splash = splash
          System.telemetry
          @components.each do |component|
            # Create tab for each component
            component.initialize_gui
            @tab_book.addTab(component, component.tab_name)
          end
          if @auto_start
            handle_start()
          end
          ConfigParser.splash = nil
        end
      end

      # Add GUI Update Timeout
      @timer = Qt::Timer.new(self)
      @timer.connect(SIGNAL('timeout()')) { update_gui() }
      @timer.method_missing(:start, 100)
    end

    def initialize_actions
      super()

      # File Menu Actions
      @open_log = Qt::Action.new(tr('&Open Log File'), self)
      @open_log_keyseq = Qt::KeySequence.new(tr('Ctrl+O'))
      @open_log.shortcut  = @open_log_keyseq
      @open_log.statusTip = tr('Open telemetry log file for processing')
      @open_log.connect(SIGNAL('triggered()')) { handle_open_log_file() }

      @handle_reset = Qt::Action.new(tr('&Reset'), self)
      @handle_reset_keyseq = Qt::KeySequence.new(tr('Ctrl+R'))
      @handle_reset.shortcut  = @handle_reset_keyseq
      @handle_reset.statusTip = tr('Reset Components')
      @handle_reset.connect(SIGNAL('triggered()')) { handle_reset() }

      # Search Actions
      @search_find = Qt::Action.new(Cosmos.get_icon('search.png'), tr('&Find'), self)
      @search_find_keyseq = Qt::KeySequence.new(tr('Ctrl+F'))
      @search_find.shortcut  = @search_find_keyseq
      @search_find.statusTip = tr('Find text')
      @search_find.connect(SIGNAL('triggered()')) do
        FindReplaceDialog.show_find(self)
      end

      @search_find_next = Qt::Action.new(tr('Find &Next'), self)
      @search_find_next_keyseq = Qt::KeySequence.new(tr('F3'))
      @search_find_next.shortcut  = @search_find_next_keyseq
      @search_find_next.statusTip = tr('Find next instance')
      @search_find_next.connect(SIGNAL('triggered()')) do
        FindReplaceDialog.find_next(self)
      end

      @search_find_previous = Qt::Action.new(tr('Find &Previous'), self)
      @search_find_previous_keyseq = Qt::KeySequence.new(tr('Shift+F3'))
      @search_find_previous.shortcut  = @search_find_previous_keyseq
      @search_find_previous.statusTip = tr('Find previous instance')
      @search_find_previous.connect(SIGNAL('triggered()')) do
        FindReplaceDialog.find_previous(self)
      end

      # Tab Menu Actions
      @delete_tab = Qt::Action.new(Cosmos.get_icon('delete_tab.png'), tr('&Delete Tab'), self)
      @delete_tab.statusTip = tr('Delete active tab')
      @delete_tab.connect(SIGNAL('triggered()')) { on_tab_delete() }
    end

    def initialize_menus
      # File Menu
      file_menu = menuBar.addMenu(tr('&File'))
      file_menu.addAction(@open_log)
      file_menu.addAction(@handle_reset)
      file_menu.addSeparator()
      file_menu.addAction(@exit_action)

      # Tab Menu
      @tab_menu = menuBar.addMenu(tr('&Tab'))
      @tab_menu.addAction(@delete_tab)
      @tab_menu.addSeparator()
      @tab_menu_actions = []

      # Search Menu
      view_menu = menuBar.addMenu(tr('&Search'))
      view_menu.addAction(@search_find)
      view_menu.addAction(@search_find_next)
      view_menu.addAction(@search_find_previous)

      # Help Menu
      @about_string = "Data Viewer is designed to allow users view data that is not easily displayed on telemetry screens."
      initialize_help_menu()
    end

    def initialize_central_widget
      # Create the central widget
      @central_widget = Qt::Widget.new
      setCentralWidget(@central_widget)

      # Create the top level vertical layout
      @top_layout = Qt::VBoxLayout.new(@central_widget)

      # Realtime Button Bar
      @realtime_button_bar = RealtimeButtonBar.new(self)
      @realtime_button_bar.start_callback = method(:handle_start)
      @realtime_button_bar.pause_callback = method(:handle_pause)
      @realtime_button_bar.stop_callback  = method(:handle_stop)
      @realtime_button_bar.state = 'Stopped'
      @top_layout.addWidget(@realtime_button_bar)

      # Create tab book
      @tab_book = Qt::TabWidget.new
      @tab_book.setContextMenuPolicy(Qt::CustomContextMenu)
      connect(@tab_book, SIGNAL('currentChanged(int)'), self, SLOT('handle_tab_change(int)'))
      connect(@tab_book, SIGNAL('customContextMenuRequested(const QPoint&)'), self, SLOT('context_menu(const QPoint&)'))
      @top_layout.addWidget(@tab_book)
    end

    def current_component
      @component_mutex.synchronize do
        yield @components[@tab_book.currentIndex()]
      end
    end

    # Called by the FindReplaceDialog to get the text to search
    def search_text
      current_component do |component|
        component.text
      end
    end

    def handle_tab_change(index)
      # Remove existing actions
      @tab_menu_actions.each do |action|
        @tab_menu.removeAction(action)
        action.dispose
      end
      @tab_menu_actions = []

      # Add new actions
      unless @components.empty?
        @component_mutex.synchronize do
          component = @components[index]
          component.packets.each do |target_name, packet_name|
            action = Qt::Action.new("#{target_name} #{packet_name}", @tab_menu)
            action.setCheckable(true)
            key = target_name + ' ' + packet_name
            components = @packet_to_components_mapping[key]
            if components.include?(component)
              action.setChecked(true)
            else
              action.setChecked(false)
            end
            action.connect(SIGNAL('triggered()')) { enable_disable_component_packet(index, target_name, packet_name, action.checked?) }
            @tab_menu.addAction(action)
            @tab_menu_actions << action
          end
        end
      end
    end

    def context_menu(point)
      index = 0
      (0..@tab_book.tabBar.count).each do |i|
        index = i if @tab_book.tabBar.tabRect(i).contains(point)
      end

      return if (index == @tab_book.tabBar.count)

      # Bring the right clicked tab to the front
      @tab_book.setCurrentIndex(index)
      @tab_menu.exec(@tab_book.mapToGlobal(point))
    end

    def start_subscription_thread
      unless @subscription_thread
        # Start Thread to Gather Events
        @subscription_thread = Thread.new do
          @cancel_thread = false
          @sleeper = Sleeper.new
          if !@packets.empty?
            begin
              while true
                break if @cancel_thread
                begin
                  @subscription_id = subscribe_packet_data(@packets, 10000)
                  break if @cancel_thread
                  if @pause
                    Qt.execute_in_main_thread(true) { @realtime_button_bar.state = 'Paused' }
                  else
                    Qt.execute_in_main_thread(true) { @realtime_button_bar.state = 'Running' }
                  end
                  Qt.execute_in_main_thread(true) { statusBar.showMessage("Connected to Command and Telemetry Server: #{Time.now.sys.formatted}") }
                rescue DRb::DRbConnError
                  break if @cancel_thread
                  Qt.execute_in_main_thread(true) do
                    @realtime_button_bar.state = 'Connecting'
                    statusBar.showMessage(tr("Error Connecting to Command and Telemetry Server"))
                  end
                  break if @sleeper.sleep(1)
                  break if @cancel_thread
                  retry
                end

                while true
                  break if @cancel_thread
                  begin
                    # Get a subscribed to packet
                    packet_data, target_name, packet_name, received_time, received_count = get_packet_data(@subscription_id)

                    # Put packet data into its packet
                    packet = System.telemetry.packet(target_name, packet_name)
                    packet.buffer = packet_data
                    packet.received_time = received_time
                    packet.received_count = received_count

                    # Route packet to its component(s)
                    index = packet.target_name + ' ' + packet.packet_name
                    @component_mutex.synchronize do
                      components = @packet_to_components_mapping[index]
                      if components
                        components.each do |component|
                          component.process_packet(packet)
                        end
                      end
                    end
                  rescue DRb::DRbConnError
                    break if @cancel_thread
                    Qt.execute_in_main_thread(true) { statusBar.showMessage(tr("Error Connecting to Command and Telemetry Server")) }
                    break # Let outer loop resubscribe
                  rescue RuntimeError => error
                    raise error unless error.message =~ /queue/
                    break if @cancel_thread
                    Qt.execute_in_main_thread(true) { statusBar.showMessage(tr("Connection Dropped by Command and Telemetry Server: #{Time.now.sys.formatted}")) }
                    break # Let outer loop resubscribe
                  end
                end
              end
            rescue Exception => error
              break if @cancel_thread
              Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(self, error, "Data Viewer : Subscription Thread")}
            end
          end # if !@packets.empty
        end
      else
        Qt.execute_in_main_thread(true) { @realtime_button_bar.state = 'Running' }
      end
    end

    def kill_subscription_thread
      Cosmos.kill_thread(self, @subscription_thread)
      @subscription_thread = nil
    end

    def graceful_kill
      @cancel_thread = true
      @sleeper.cancel
      script_disconnect() # This will break out of get_packet_data
      Qt::CoreApplication.processEvents
    end

    def handle_reset
      @component_mutex.synchronize do
        @components.each do |component|
          component.reset
        end
      end
      System.telemetry.reset
    end

    def handle_start
      if windowTitle() != 'Data Viewer'
        # Clear Title
        setWindowTitle('Data Viewer')

        # Return to default configuration
        # Show splash during possible reconfiguration
        Splash.execute(self) do |splash|
          ConfigParser.splash = splash
          System.load_configuration
          ConfigParser.splash = nil
        end

        # Reset Components
        handle_reset()
      end

      # Restart GUI Updates if necessary
      if @pause
        @pause = false
        @timer.method_missing(:start, 100)
      end

      # Restart Subscription Thread if necessary
      start_subscription_thread()
    end

    def handle_pause
      @pause = true
      if @subscription_thread
        @realtime_button_bar.state = 'Paused'
      end
    end

    def handle_stop
      # Shutdown packet subscription thread
      kill_subscription_thread()

      # Unsubscribe from subscription
      if @subscription_id
        begin
          unsubscribe_packet_data(@subscription_id)
        rescue DRb::DRbConnError
          # Do Nothing
        end
      end

      # Restart GUI Updates if necessary
      if @pause
        @pause = false
        @timer.method_missing(:start, 100)
      end

      @realtime_button_bar.state = 'Stopped'
    end

    def handle_open_log_file
      # Prompt user for filename
      packet_log_dialog = PacketLogDialog.new(self, 'Open Log File(s):', @log_file_directory, @packet_log_reader, [], nil, false, true, true, Cosmos::TLM_FILE_PATTERN)
      begin
        packet_log_dialog.time_start = @time_start
        packet_log_dialog.time_end = @time_end
        case packet_log_dialog.exec
        when Qt::Dialog::Accepted
          @packet_log_reader = packet_log_dialog.packet_log_reader
          @log_filenames = packet_log_dialog.filenames.sort
          @time_start = packet_log_dialog.time_start
          @time_end = packet_log_dialog.time_end
          @log_file_directory = File.dirname(@log_filenames[0])
          @log_file_directory << '/' unless @log_file_directory[-1..-1] == '\\'

          # Stop realtime collection
          handle_stop()

          # Reset components
          handle_reset()

          @cancel_progress = false
          ProgressDialog.execute(self, 'Processing Log File', 500, 200, @log_filenames.length > 1, true, true, true, true) do |dialog|
            dialog.cancel_callback = method(:cancel_callback)
            dialog.enable_cancel_button

            @log_filenames.each_with_index do |filename, file_index|
              break if @cancel_progress
              Qt.execute_in_main_thread(true) do
                self.setWindowTitle("Data Viewer : #{filename}")
              end

              file_size = File.size(filename).to_f
              dialog.append_text("Processing: #{filename}")

              Cosmos.check_log_configuration(@packet_log_reader, filename)
              @packet_log_reader.each(filename, true, @time_start, @time_end) do |packet|
                break if @cancel_progress
                progress = @packet_log_reader.bytes_read.to_f / file_size
                dialog.set_step_progress(progress)

                # Route packet to its component(s)
                index = packet.target_name + ' ' + packet.packet_name
                components = @packet_to_components_mapping[index]
                if components
                  @component_mutex.synchronize do
                    components.each do |component|
                      component.process_packet(packet)
                    end
                  end
                end
              end

              dialog.set_overall_progress((file_index + 1).to_f / @log_filenames.length) if @log_filenames.length > 1
            end

            dialog.append_text("Done!")
            dialog.set_step_progress(1.0)
            dialog.set_overall_progress(1.0) if @log_filenames.length > 1
            dialog.complete
          end
        end
      ensure
        packet_log_dialog.dispose if packet_log_dialog
      end
    end

    def cancel_callback(progress_dialog = nil)
      @cancel_progress = true
      return true, false
    end

    def update_gui
      if @pause
        @timer.method_missing(:stop)
      else
        Qt.execute_in_main_thread(true) do
          @component_mutex.synchronize do
            @components.each do |component|
              break if @pause
              component.update_gui
            end
          end
        end
      end
    end

    def closeEvent(event)
      # Stop GUI update timeout
      @pause = true

      # Stop Processing Packets
      handle_stop()

      # Shutdown each component
      @component_mutex.synchronize do
        @components.each {|component| component.shutdown}
      end

      # Give things time to complete
      sleep(0.1)

      # Standard COSMOS Shutdown
      shutdown_cmd_tlm()

      # Accept closure
      super(event)
    end

    def process_config
      # ensure the file exists
      unless test ?f, @config_filename
        raise "Configuration File Does not Exist: #{@config_filename}"
      end

      parser = ConfigParser.new
      parser.parse_file(@config_filename) do |keyword, params|
        case keyword

        when 'AUTO_START'
          usage = "#{keyword}"
          parser.verify_num_parameters(0, 0, usage)
          @auto_start = true

        when 'COMPONENT'
          usage = "#{keyword} <tab name> <component class filename> <component specific options...>"
          parser.verify_num_parameters(2, nil, usage)
          component_class = Cosmos.require_class(params[1])
          if params.length >= 3
            @components << component_class.new(self, params[0], *params[2..-1])
          else
            @components << component_class.new(self, params[0])
          end

        when 'PACKET'
          usage = "#{keyword} <target_name> <packet_name>"
          parser.verify_num_parameters(2, 2, usage)
          target_name = params[0].upcase
          packet_name = params[1].upcase
          @packets << [target_name, packet_name]
          @components[-1].add_packet(target_name, packet_name)
          index = target_name + ' ' + packet_name
          @packet_to_components_mapping[index] ||= []
          @packet_to_components_mapping[index] << @components[-1]

        # Unknown keyword
        else
          raise "Unhandled keyword: #{keyword}" if keyword
        end
      end
    end

    def delete_component(index)
      @component_mutex.synchronize do
        # Get the component to be deleted
        component = @components[index]

        # Delete from the components array
        @components.delete_at(index)

        # Delete from mapping
        @packet_to_components_mapping.each do |key, components|
          components.delete(component)
        end
      end
    end

    def enable_disable_component_packet(index, target_name, packet_name, enabled)
      @component_mutex.synchronize do
        # Get the component to be deleted
        component = @components[index]

        key = target_name + ' ' + packet_name
        if enabled
          # Add to mapping
          components = @packet_to_components_mapping[key]
          components << component unless components.include?(component)
        else
          # Delete from mapping
          components = @packet_to_components_mapping[key]
          components.delete(component)
        end
      end
    end

    # Handles deleting the current tab
    def on_tab_delete
      if @tab_book.currentIndex() and @tab_book.currentIndex() >= 0
        case Qt::MessageBox.warning(self, 'Warning!', "Are you sure you want to delete the active tab?", Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::No)
        when Qt::MessageBox::Yes
          # Remove component
          tab_index = @tab_book.currentIndex()
          delete_component(tab_index)
          @tab_book.removeTab(tab_index)

          statusBar.showMessage(tr("Tab Deleted"))
        end
      else
        Qt::MessageBox.information(self, 'Info', "No tabs exist")
      end
    end # def on_tab_delete

    #############################
    # Class methods
    #############################

    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.width = 550
          options.height = 500
          options.title = "Data Viewer"
          options.config_file = 'data_viewer.txt'
          option_parser.separator "Data Viewer Specific Options:"
          option_parser.on("-c", "--config FILE", "Use the specified configuration file") do |arg|
            options.config_file = arg
          end
        end

        super(option_parser, options)
      end
    end

  end # class DataViewer

end # module Cosmos
