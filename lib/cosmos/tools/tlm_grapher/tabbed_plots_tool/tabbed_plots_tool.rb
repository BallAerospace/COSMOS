# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/gui/qt'
require 'cosmos/gui/qt_tool'
require 'cosmos/gui/dialogs/splash'
require 'cosmos/packet_logs/packet_log_reader'
require 'cosmos/tools/tlm_grapher/tabbed_plots_tool/tabbed_plots_config'
require 'cosmos/tools/tlm_grapher/tabbed_plots_tool/tabbed_plots_realtime_thread'
require 'cosmos/tools/tlm_grapher/tabbed_plots_tool/tabbed_plots_logfile_thread'
require 'cosmos/tools/tlm_grapher/tabbed_plots_tool/tabbed_plots_dart_thread'
require 'cosmos/gui/widgets/realtime_button_bar'
require 'cosmos/gui/dialogs/exception_list_dialog'
require 'cosmos/gui/dialogs/packet_log_dialog'
require 'cosmos/gui/dialogs/progress_dialog'
require 'cosmos/gui/dialogs/dart_dialog'
require 'cosmos/tools/tlm_grapher/tabbed_plots/overview_tabbed_plots'

module Cosmos
  # Displays multiple plots that perform various analysis on data.
  class TabbedPlotsTool < QtTool
    MINIMUM_LEFT_PANEL_WIDTH = 200
    DEFAULT_LEFT_PANEL_WIDTH = 250

    def initialize(options)
      super(options) # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      @options = options
      @base_title = self.windowTitle
      Cosmos.load_cosmos_icon("tlm_grapher.png")

      statusBar.showMessage("") # Show blank message to initialize status bar

      initialize_actions()
      initialize_menus(options)
      initialize_central_widget()
      complete_initialize()

      # Define instance variables
      @need_reset = false
      @log_filenames = []
      @log_dir = System.paths['LOGS']
      @log_dir += '/' unless @log_dir[-1..-1] == '\\' or @log_dir[-1..-1] == '/'
      @time_start = nil
      @time_end = nil
      @screenshot_dir = @log_dir.clone
      @export_dir = @log_dir.clone
      @data_object_types = options.data_object_types
      @adder_orientation = options.adder_orientation
      @adder_types = options.adder_types
      @tool_short_name = options.tool_short_name
      @plot_types = options.plot_types
      @tabbed_plots_type = options.tabbed_plots_type
      @items = options.items
      @plot_type_to_data_object_type_mapping = options.plot_type_to_data_object_type_mapping
      @start = options.start
      @packet_log_reader = PacketLogReader.new
      @tabbed_plots_config = nil
      @tabbed_plots = nil
      @realtime_thread = nil
      @config_modified = false
      @replay_mode = false

      # Bring up slash screen for long duration tasks after creation
      Splash.execute(self) do |splash|
        # Configure CosmosConfig to interact with splash screen
        ConfigParser.splash = splash

        # Load telemetry
        System.telemetry

        # Create tabbed plots definition
        @config_filename = options.config_file ? options.config_file : ''
        Qt.execute_in_main_thread(true) do
          load_configuration()
          toggle_replay_mode() if options.replay
        end

        # Unconfigure CosmosConfig to interact with splash screen
        ConfigParser.splash = nil
      end
    end

    def initialize_actions
      super()

      # File Menu Actions
      @file_process = Qt::Action.new('&Open Log', self)
      @file_process_keyseq = Qt::KeySequence.new('Ctrl+O')
      @file_process.shortcut = @file_process_keyseq
      @file_process.statusTip = 'Open Log File'
      @file_process.connect(SIGNAL('triggered()')) { on_file_process_log() }

      @file_dart = Qt::Action.new('&Query DART Database', self)
      @file_dart_keyseq = Qt::KeySequence.new('Ctrl+D')
      @file_dart.shortcut = @file_dart_keyseq
      @file_dart.statusTip = 'Query DART Database'
      @file_dart.connect(SIGNAL('triggered()')) { on_file_dart() }

      @file_load = Qt::Action.new(Cosmos.get_icon('open.png'), '&Load Config', self)
      @file_load.statusTip = 'Load Saved Configuration'
      @file_load.connect(SIGNAL('triggered()')) { on_file_load_config() }

      @file_save = Qt::Action.new(Cosmos.get_icon('save.png'), '&Save Config', self)
      @file_save_keyseq = Qt::KeySequence.new('Ctrl+S')
      @file_save.shortcut = @file_save_keyseq
      @file_save.statusTip = 'Save Current Configuration'
      @file_save.connect(SIGNAL('triggered()')) { on_file_save_config() }

      @file_screenshot = Qt::Action.new(Cosmos.get_icon('screenshot.png'), 'Screensho&t', self)
      @file_screenshot.statusTip = 'Screenshot of Application'
      @file_screenshot.connect(SIGNAL('triggered()')) { on_file_screenshot() }

      @replay_action = Qt::Action.new('Toggle Replay Mode', self)
      @replay_action.statusTip = 'Toggle Replay Mode'
      @replay_action.connect(SIGNAL('triggered()')) { toggle_replay_mode() }

      # Tab Menu Actions
      @tab_add = Qt::Action.new(Cosmos.get_icon('add_tab.png'), '&Add Tab', self)
      @tab_add.statusTip = 'Add New Tab'
      @tab_add.connect(SIGNAL('triggered()')) { on_tab_add() }

      @tab_delete = Qt::Action.new(Cosmos.get_icon('delete_tab.png'), '&Delete Tab', self)
      @tab_delete.statusTip = 'Delete Active Tab'
      @tab_delete.connect(SIGNAL('triggered()')) { on_tab_delete() }

      @tab_edit = Qt::Action.new(Cosmos.get_icon('edit_tab.png'), '&Edit Tab', self)
      @tab_edit.statusTip = 'Edit Active Tab'
      @tab_edit.connect(SIGNAL('triggered()')) { on_tab_edit() }

      @tab_screenshot = Qt::Action.new(Cosmos.get_icon('screenshot.png'), '&Screenshot Tab', self)
      @tab_screenshot.statusTip = 'Screenshot of Active Tab'
      @tab_screenshot.connect(SIGNAL('triggered()')) { on_tab_screenshot() }

      @tab_export = Qt::Action.new('E&xport Tab Data Objects', self)
      @tab_export.statusTip = 'Export Tab Data Object(s)'
      @tab_export.connect(SIGNAL('triggered()')) { on_tab_export() }

      @tab_reset = Qt::Action.new('&Reset Tab Data Objects', self)
      @tab_reset.statusTip = 'Reset Tab Data Object(s)'
      @tab_reset.connect(SIGNAL('triggered()')) { on_tab_reset() }

      # Plot Menu Actions
      @plot_add = Qt::Action.new(Cosmos.get_icon('add_plot.png'), '&Add Plot', self)
      @plot_add.statusTip = 'Add New Plot'
      @plot_add.connect(SIGNAL('triggered()')) { on_plot_add() }

      @plot_delete = Qt::Action.new(Cosmos.get_icon('delete_plot.png'), '&Delete Plot', self)
      @plot_delete.statusTip = 'Delete Selected Plot'
      @plot_delete.connect(SIGNAL('triggered()')) { on_plot_delete() }

      @plot_edit = Qt::Action.new(Cosmos.get_icon('edit_plot.png'), '&Edit Plot', self)
      @plot_edit.statusTip = 'Edit Selected Plot'
      @plot_edit.connect(SIGNAL('triggered()')) { on_plot_edit() }

      @plot_screenshot = Qt::Action.new(Cosmos.get_icon('screenshot.png'), '&Screenshot Plot', self)
      @plot_screenshot.statusTip = 'Screenshot Selected Plot'
      @plot_screenshot.connect(SIGNAL('triggered()')) { on_plot_screenshot() }

      @plot_add_data = Qt::Action.new(Cosmos.get_icon('add_database.png'), 'Add Data &Object', self)
      @plot_add_data.statusTip = 'Add Data Object'
      @plot_add_data.connect(SIGNAL('triggered()')) { on_data_object_add() }

      @plot_edit_data = Qt::Action.new(Cosmos.get_icon('edit_database.png'), 'Edit &Plot Data Objects', self)
      @plot_edit_data.statusTip = 'Edit Plot Data Object(s)'
      @plot_edit_data.connect(SIGNAL('triggered()')) { on_plot_data_object_edit() }

      @plot_export = Qt::Action.new('E&xport Plot Data Objects', self)
      @plot_export.statusTip = 'Export Plot Data Object(s)'
      @plot_export.connect(SIGNAL('triggered()')) { on_plot_export() }

      @plot_reset = Qt::Action.new('&Reset Plot Data Objects', self)
      @plot_reset.statusTip = 'Reset Plot Data Object(s)'
      @plot_reset.connect(SIGNAL('triggered()')) { on_plot_reset() }

      # Data Object Menu
      @data_add = Qt::Action.new(Cosmos.get_icon('add_database.png'), '&Add Data Object', self)
      @data_add.statusTip = 'Add Data Object'
      @data_add.connect(SIGNAL('triggered()')) { on_data_object_add() }

      @data_delete = Qt::Action.new(Cosmos.get_icon('delete_database.png'), '&Delete Data Object', self)
      @data_delete.statusTip = 'Delete Selected Data Object(s)'
      @data_delete.connect(SIGNAL('triggered()')) { on_data_object_delete() }

      @data_edit = Qt::Action.new(Cosmos.get_icon('edit_database.png'), '&Edit Data Object', self)
      @data_edit.statusTip = 'Edit Selected Data Object(s)'
      @data_edit.connect(SIGNAL('triggered()')) { on_data_object_edit() }

      @data_duplicate = Qt::Action.new('Du&plicate Data Object', self)
      @data_duplicate.statusTip = 'Duplicate Selected Data Object(s)'
      @data_duplicate.connect(SIGNAL('triggered()')) { on_data_object_duplicate() }

      @data_export = Qt::Action.new('E&xport Data Object', self)
      @data_export.statusTip = 'Export Selected Data Object(s)'
      @data_export.connect(SIGNAL('triggered()')) { on_data_object_export() }

      @data_export_all = Qt::Action.new('Expor&t All Data Objects', self)
      @data_export_all.statusTip = 'Export All Data Objects'
      @data_export_all.connect(SIGNAL('triggered()')) { on_data_object_export_all() }

      @data_reset = Qt::Action.new('&Reset Data Object', self)
      @data_reset.statusTip = 'Reset Selected Data Object(s)'
      @data_reset.connect(SIGNAL('triggered()')) { on_data_object_reset() }

      @data_reset_all = Qt::Action.new('Re&set All Data Objects', self)
      @data_reset_all.statusTip = 'Reset All Data Objects'
      @data_reset_all.connect(SIGNAL('triggered()')) { on_data_object_reset_all() }
    end

    def initialize_menus(options)
      # File Menu
      @file_menu = menuBar.addMenu('&File')
      @file_menu.addAction(@file_process)
      @file_menu.addAction(@file_dart)
      @file_menu.addSeparator()
      @file_menu.addAction(@file_load)
      @file_menu.addAction(@file_save)
      @file_menu.addSeparator()
      @file_menu.addAction(@file_screenshot)
      @file_menu.addSeparator()
      @file_menu.addAction(@replay_action)
      @file_menu.addSeparator()
      @file_menu.addAction(@exit_action)

      @tab_menu = menuBar.addMenu('&Tab')
      @tab_menu.addAction(@tab_add)
      @tab_menu.addAction(@tab_delete)
      @tab_menu.addAction(@tab_edit)
      @tab_menu.addSeparator()
      @tab_menu.addAction(@tab_screenshot)
      @tab_menu.addAction(@tab_export)
      @tab_menu.addSeparator()
      @tab_menu.addAction(@tab_reset)

      @plot_menu = menuBar.addMenu('&Plot')
      @plot_menu.addAction(@plot_add)
      @plot_menu.addAction(@plot_delete)
      @plot_menu.addAction(@plot_edit)
      @plot_menu.addSeparator()
      @plot_menu.addAction(@plot_add_data)
      @plot_menu.addAction(@plot_edit_data)
      @plot_menu.addSeparator()
      @plot_menu.addAction(@plot_screenshot)
      @plot_menu.addAction(@plot_export)
      @plot_menu.addSeparator()
      @plot_menu.addAction(@plot_reset)

      @data_menu = menuBar.addMenu('&Data Object')
      @data_menu.addAction(@data_add)
      @data_menu.addAction(@data_delete)
      @data_menu.addAction(@data_edit)
      @data_menu.addSeparator()
      @data_menu.addAction(@data_duplicate)
      @data_menu.addAction(@data_export)
      @data_menu.addAction(@data_export_all)
      @data_menu.addSeparator()
      @data_menu.addAction(@data_reset)
      @data_menu.addAction(@data_reset_all)

      # Help Menu
      @about_string = options.about_string
      initialize_help_menu()
    end

    def initialize_central_widget
      # Create a splitter to break application into to halves
      @splitter = Qt::Splitter.new(Qt::Horizontal, central_widget)
      setCentralWidget(@splitter)

      # Create a Vertical Frame for the left contents
      @left_widget = Qt::Widget.new(self)
      @left_frame = Qt::VBoxLayout.new
      @left_widget.setLayout(@left_frame)
      @splitter.addWidget(@left_widget)

      # Create a Vertical Frame for the right contents
      @right_widget = Qt::Widget.new(self)
      @right_frame = Qt::VBoxLayout.new
      @replay_flag = Qt::Label.new("Replay Mode")
      @replay_flag.setStyleSheet("background:green;color:white;padding:5px;font-weight:bold;height:30px;")
      @right_frame.addWidget(@replay_flag)
      @replay_flag.hide
      @right_widget.setLayout(@right_frame)
      @splitter.addWidget(@right_widget)
      @splitter.setStretchFactor(0,0) # Set the left side stretch factor to 0
      @splitter.setStretchFactor(1,1) # Set the right side stretch factor to 1 to give it priority for space

      # Realtime Button Bar
      @realtime_button_bar = RealtimeButtonBar.new(self, Qt::Vertical)
      @realtime_button_bar.start_callback = method(:handle_start)
      @realtime_button_bar.pause_callback = method(:handle_pause)
      @realtime_button_bar.stop_callback = method(:handle_stop)
      @realtime_button_bar.state = 'Stopped'
      @left_frame.addWidget(@realtime_button_bar)

      # Separator after RBB
      @sep = Qt::Frame.new
      @sep.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      @left_frame.addWidget(@sep)
    end # def initialize

    protected

    ###############################################################################
    # Protected Methods Used During Initialization
    ###############################################################################

    # Loads in a new configuration file
    def load_configuration
      # Shutdown TabbedPlots if one already exists
      @tabbed_plots.shutdown if @tabbed_plots

      if @items && !@items.empty?
        # Don't use config file and handle items passed in from the command line
        @tabbed_plots_config = TabbedPlotsConfig.new(nil,
                                                     @plot_types,
                                                     @data_object_types,
                                                     @plot_type_to_data_object_type_mapping)
        handle_items()
      else
        # Create new tabbed plots definition from config file
        @tabbed_plots_config = TabbedPlotsConfig.new(@config_filename,
                                                     @plot_types,
                                                     @data_object_types,
                                                     @plot_type_to_data_object_type_mapping)
      end
      @config_modified = false

      # Handle configuration errors
      unless @tabbed_plots_config.configuration_errors.empty?
        ExceptionListDialog.new('Errors Encountered in Configuration File:',
                                @tabbed_plots_config.configuration_errors)
      end

      # Add a TabbedPlots widget to show all the plots
      if @tabbed_plots
        @tabbed_plots.config_modified_callback = nil
      else
        # Require tabbed plots file
        tabbed_plots_filename = @tabbed_plots_type + '_tabbed_plots.rb'
        tabbed_plots_class = Cosmos.require_class(tabbed_plots_filename)
        @tabbed_plots = tabbed_plots_class.new(self, @left_frame, @right_frame, statusBar)
        @tabbed_plots.tab_item_right_button_release_callback = method(:handle_tab_right_click)
        @tabbed_plots.plot_right_button_release_callback = method(:handle_plot_right_click)
        @tabbed_plots.data_object_right_button_release_callback = method(:handle_data_object_right_click)
      end
      @tabbed_plots.startup(@tabbed_plots_config, @adder_orientation, @adder_types)
      @tabbed_plots.config_modified_callback = method(:handle_config_modified)
      @tabbed_plots.pause

      # Start realtime collection if given an item or told to start
      if (@items and not @items.empty?) or @start
        handle_start()
        @items = nil
        @start = false
      end

      if !File.exist?(@config_filename)
        # Warn if the configuration file did not exist
        statusBar.showMessage("Configuration File does not exist: #{@config_filename}. Using default configuration.")
      end
      update_window_title()
    end # def load_configuration

    def update_window_title
      if File.exist?(@config_filename)
        if @config_modified
          self.windowTitle = @base_title + ' - ' + @config_filename + '*'
        else
          self.windowTitle = @base_title + ' - ' + @config_filename
        end
      else
        self.windowTitle = @base_title
      end
    end

    # Override this method to handle items passed in from command line
    def handle_items
      # Do nothing by default
    end # def handle_items

    def screenshot
      screenshot_filename = File.join(@screenshot_dir,
        File.build_timestamped_filename([@tool_short_name, 'screenshot'], '.png'))
      filename = Qt::FileDialog::getSaveFileName(self,
                                                 "Save Screen Shot",
                                                 screenshot_filename,
                                                 "Screenshots (*.png);;All Files (*)")
      unless filename.nil? or filename.empty?
        Qt.execute_in_main_thread(true) do
          begin
            yield filename
            @screenshot_dir = File.dirname(filename)
            statusBar.showMessage("Screenshot saved to: #{filename}")
          rescue Exception => error
            statusBar.showMessage("Screenshot creation failed")
            Qt::MessageBox.warning(
              self,
              "Screenshot Creation Error",
              "Could not create file: #{filename}\n#{error.class} : #{error.message}")
          end
        end
      end
    end

    def export
      export_filename = File.join(@export_dir,
        File.build_timestamped_filename([@tool_short_name, 'export'], '.txt'))
      filename = Qt::FileDialog::getSaveFileName(self,
                                                 "Export Filename",
                                                 export_filename,
                                                 "Export Files (*.txt);;All Files (*)")
      unless filename.nil? or filename.empty?
        filename << '.txt' if File.extname(filename).empty?
        begin
          ProgressDialog.execute(self, "Export Progress", 500, 100, true, false, true, true, true) do |dialog|
            yield filename, dialog
            dialog.append_text("\n\nExported to #{filename}")
            dialog.set_overall_progress(1.0)
            dialog.complete
          end
          @export_dir = File.dirname(filename)
          statusBar.showMessage("Exported to #{filename}")
        rescue Exception => error
          statusBar.showMessage("Export Failed")
          Qt::MessageBox.warning(
            self,
            "Export Error",
            "Could not create file: #{filename}\n#{error.class} : #{error.message}")
        end
      end
    end

    def reset_or_delete(item, delete)
      action = "reset"
      action = "delete" if delete
      result = Qt::MessageBox.warning(self,
                                      'Warning!',
                                      "Are you sure you want to #{action} the #{item}?",
                                      Qt::MessageBox::Yes | Qt::MessageBox::No,
                                      Qt::MessageBox::No)
      if result == Qt::MessageBox::Yes
        yield
        @config_modified = true if delete
        update_window_title() if delete
        statusBar.showMessage("#{action.capitalize} #{item} successful")
      else
        statusBar.showMessage("#{action.capitalize} #{item} canceled")
      end
    end
    def reset(item)
      reset_or_delete(item, false) do
        yield
      end
    end
    def delete(item)
      reset_or_delete(item, true) do
        yield
      end
    end

    ###############################################################################
    # Application Close Handler
    ###############################################################################

    # Prompts for save if the current configuration has been modified
    def prompt_for_save_if_needed
      safe_to_continue = true
      if @config_modified and File.exist?(@config_filename)
        case Qt::MessageBox.question(
          self,    # parent
          'Save?', # title
          "Save changes to '#{@config_filename}'?", # text
          Qt::MessageBox::Yes | Qt::MessageBox::No | Qt::MessageBox::Cancel, # buttons
          Qt::MessageBox::Cancel) # default button
        when Qt::MessageBox::Cancel
          safe_to_continue = false
        when Qt::MessageBox::Yes
          saved = on_file_save_config()
          if not saved
            safe_to_continue = false
          end
        end
      end
      return safe_to_continue
    end

    # Handles application window closing
    def closeEvent(event)
      if prompt_for_save_if_needed()
        super(event)
        @realtime_thread.kill if @realtime_thread
        @realtime_thread = nil
      else
        event.ignore()
      end
    end

    ###############################################################################
    # File Menu Handlers
    ###############################################################################

    # Handles processing log files
    def on_file_process_log
      paused = @tabbed_plots.paused?
      @tabbed_plots.pause
      dialog = PacketLogDialog.new(self,
                                   'Process Log File(s):',
                                   @log_dir,
                                   @packet_log_reader,
                                   @log_filenames)
      dialog.time_start = @time_start
      dialog.time_end = @time_end
      result = dialog.exec
      if result != 0
        @time_start = dialog.time_start
        @time_end = dialog.time_end
        handle_stop()
        @need_reset = true
        System.telemetry.reset
        @tabbed_plots.reset_all_data_objects
        @packet_log_reader = dialog.packet_log_reader
        @log_filenames = dialog.filenames.clone
        filenames = dialog.filenames.sort

        ProgressDialog.execute(self, 'Log File Progress', 500, 300) do |progress_dialog|
          logfile_thread = TabbedPlotsLogfileThread.new(filenames,
                                                        @packet_log_reader,
                                                        @tabbed_plots_config,
                                                        progress_dialog,
                                                        @time_start,
                                                        @time_end)
          sleep(0.1) until logfile_thread.done?
          progress_dialog.close_done
        end

        @tabbed_plots.redraw_plots(true, true)
        @tabbed_plots.update
      else
        @tabbed_plots.resume unless paused
      end
      dialog.dispose
    end # def on_file_process_log

    # Handles querying data from DART
    def on_file_dart
      paused = @tabbed_plots.paused?
      @tabbed_plots.pause
      dialog = DartDialog.new(self,
                              'Query DART Database:')
      dialog.time_start = @time_start
      dialog.time_end = @time_end
      result = dialog.exec
      if result != 0
        @time_start = dialog.time_start
        @time_end = dialog.time_end
        @meta_filters = dialog.meta_filters
        handle_stop()
        @need_reset = true
        System.telemetry.reset
        @tabbed_plots.reset_all_data_objects

        ProgressDialog.execute(self, 'DART Query Progress', 500, 300) do |progress_dialog|
          dart_thread = TabbedPlotsDartThread.new(@tabbed_plots_config,
                                                  progress_dialog,
                                                  @time_start,
                                                  @time_end,
                                                  @meta_filters)
          sleep(0.1) until dart_thread.done?
          progress_dialog.close_done
        end

        @tabbed_plots.redraw_plots(true, true)
        @tabbed_plots.update
      else
        @tabbed_plots.resume unless paused
      end
      dialog.dispose
    end # def on_file_process_log

    # Handles loading a configuration file
    def on_file_load_config
      paused = @tabbed_plots.paused?
      @tabbed_plots.pause

      if prompt_for_save_if_needed()
        if @config_filename.empty?
          load_filename = @options.config_dir
        else
          load_filename = @config_filename
        end
        filename = Qt::FileDialog.getOpenFileName(self,
                                                  "Load Configuration",
                                                  load_filename,
                                                  "Config File (*.txt);;All Files (*)")
        if filename and not filename.empty?
          @config_filename = filename
          if @realtime_thread then running = true else running = false end
          handle_stop()
          load_configuration()
          handle_start() if running
          handle_pause() if paused
        else
          @tabbed_plots.resume unless paused
        end
      end
    end # def on_file_load_config

    # Handles saving the current configuration to a file
    def on_file_save_config
      saved = false
      paused = @tabbed_plots.paused?
      @tabbed_plots.pause
      filename = Qt::FileDialog.getSaveFileName(self,
                                                "Save Configuration",
                                                @config_filename,
                                                "Config File (*.txt);;All Files (*)")
      if filename and not filename.empty?
        filename << '.txt' if File.extname(filename).empty?
        File.open(filename, 'w') {|file| file.write(@tabbed_plots_config.configuration_string)}
        @config_filename = filename
        @config_modified = false
        update_window_title()
        saved = true
      end
      @tabbed_plots.resume unless paused
      return saved
    end # def on_file_save_config

    # Handles taking a screenshot of the tool
    def on_file_screenshot
      paused = @tabbed_plots.paused?
      @tabbed_plots.pause
      screenshot do |filename|
        Screenshot.screenshot_window(self, filename)
      end
      @tabbed_plots.resume unless paused
    end # def on_file_screenshot

    def toggle_replay_mode
      running = @realtime_thread ? true : false
      handle_stop()
      System.telemetry.reset
      @tabbed_plots.reset_all_data_objects
      @replay_mode = !@replay_mode
      if @replay_mode
        @replay_flag.show
      else
        @replay_flag.hide
      end
      handle_start() if running
    end

    ###############################################################################
    # Tab Menu Handlers
    ###############################################################################

    # Common method to check for the existance of a tab before yielding
    def tab_selected?
      paused = @tabbed_plots.paused?
      @tabbed_plots.pause
      if @tabbed_plots.current_tab_index
        yield
      else
        Qt::MessageBox.information(self, 'Info', "No tabs exist")
      end
      @tabbed_plots.resume unless paused
    end

    # Handles adding a new tab
    def on_tab_add
      paused = @tabbed_plots.paused?
      @tabbed_plots.pause
      @tabbed_plots.add_tab
      statusBar.showMessage("Tab Added")
      @config_modified = true
      update_window_title()
      @tabbed_plots.resume unless paused
    end # def on_tab_add

    # Handles deleting the current tab
    def on_tab_delete
      tab_selected? do
        delete("tab") do
          @tabbed_plots.delete_tab
        end
      end
    end # def on_tab_delete

    # Handles editing the current tab
    def on_tab_edit
      tab_selected? do
        edited = @tabbed_plots.edit_tab
        if edited
          statusBar.showMessage("Tab Edited")
          @config_modified = true
          update_window_title()
        end
      end
    end # def on_tab_edit

    # Handles taking a screenshot of the current tab
    def on_tab_screenshot
      tab_selected? do
        screenshot do |filename|
          @tabbed_plots.screenshot_tab(filename)
        end
      end
    end

    # Handles exporting all data objects on the current tab
    def on_tab_export
      tab_selected? do
        if @tabbed_plots.tab_has_data_objects?
          export do |filename, progress_dialog|
            @tabbed_plots.export_tab(filename, progress_dialog)
          end
        else
          Qt::MessageBox.information(self, 'Info', "No data objects exist on this tab")
        end
      end
    end # def on_tab_export

    # Handles reseting all data objects on the current tab
    def on_tab_reset
      tab_selected? do
        reset("data objects on the current tab") do
          @tabbed_plots.reset_tab
        end
      end
    end # def on_tab_reset

    ###############################################################################
    # Plot Menu Handlers
    ###############################################################################

    # Common method to check for a selected plot before yielding
    def plot_selected?
      paused = @tabbed_plots.paused?
      @tabbed_plots.pause
      if @tabbed_plots.selected_plot_index
        yield
      else
        Qt::MessageBox.information(self, 'Info', "Please select a plot")
      end
      @tabbed_plots.resume unless paused
    end

    # Common method to check for the existance of data objects before yielding
    def plot_data_objects?
      if @tabbed_plots.plot_has_data_objects?
        yield
      else
        Qt::MessageBox.information(self, 'Info', "No data objects exist on this plot")
      end
    end

    # Handles adding a new plot to the current tab
    def on_plot_add
      paused = @tabbed_plots.paused?
      @tabbed_plots.pause
      added = @tabbed_plots.add_plot
      if added
        @config_modified = true
        update_window_title()
      end
      @tabbed_plots.resume unless paused
    end # def on_plot_add

    # Handles deleting the selected plot
    def on_plot_delete
      plot_selected? do
        delete("plot") do
          @tabbed_plots.delete_plot
        end
      end
    end # def on_plot_delete

    # Handles editing the selected plot
    def on_plot_edit
      plot_selected? do
        edited = @tabbed_plots.edit_plot
        if edited
          @config_modified = true
          update_window_title()
        end
      end
    end # def on_plot_edit

    # Handles taking a screenshot of the selected plot
    def on_plot_screenshot
      plot_selected? do
        screenshot do |filename|
          @tabbed_plots.screenshot_plot(filename)
        end
      end
    end # def on_plot_screenshot

    def on_plot_data_object_edit
      edited = false
      plot_selected? do
        plot_data_objects? do
          tab_index = @tabbed_plots.current_tab_index
          plot_index =  @tabbed_plots.selected_plot_index
          @tabbed_plots_config.tabs[tab_index].plots[plot_index].data_objects.each_with_index do |object, index|
            edited |= @tabbed_plots.edit_data_object(tab_index, plot_index, index)
          end
          if edited
            @config_modified = true
            update_window_title()
          end
        end
      end
    end

    # Handles exporting the data objects on the selected plot
    def on_plot_export
      plot_selected? do
        plot_data_objects? do
          export do |filename, progress_dialog|
            @tabbed_plots.export_plot(filename, progress_dialog)
          end
        end
      end
    end # def on_plot_export

    # Handles reseting the data objects on the selected plot
    def on_plot_reset
      plot_selected? do
        plot_data_objects? do
          reset("data objects on the selected plot") do
            @tabbed_plots.reset_plot
          end
        end
      end
    end # def on_plot_reset

    ###############################################################################
    # Data Object Menu Handlers
    ###############################################################################

    def data_objects_selected?
      paused = @tabbed_plots.paused?
      @tabbed_plots.pause
      unless @tabbed_plots.selected_data_object_indexes.empty?
        yield
      else
        Qt::MessageBox.information(self, 'Information', "Please select one or more data objects")
      end
      @tabbed_plots.resume unless paused
    end

    def data_objects_exist?
      paused = @tabbed_plots.paused?
      @tabbed_plots.pause
      if @tabbed_plots.plot_has_data_objects?
        yield
      else
        Qt::MessageBox.information(self, 'Information', "No data objects exist on this plot")
      end
      @tabbed_plots.resume unless paused
    end

    # Handles adding a data object to the selected plot
    def on_data_object_add
      paused = @tabbed_plots.paused?
      @tabbed_plots.pause
      added = @tabbed_plots.add_data_object
      if added
        @config_modified = true
        update_window_title()
      end
      @tabbed_plots.resume unless paused
    end # def on_data_object_add

    # Handles editing the selected data object(s)
    def on_data_object_edit
      data_objects_selected? do
        edited = @tabbed_plots.edit_data_object
        if edited
          @config_modified = true
          update_window_title()
        end
      end
    end # def on_data_object_edit

    # Handles duplicating the selected data object(s)
    def on_data_object_duplicate
      data_objects_selected? do
        @tabbed_plots.duplicate_data_object
        @config_modified = true
        update_window_title()
      end
    end # def on_data_object_duplicate

    # Handles deleting the selected data object(s)
    def on_data_object_delete
      data_objects_selected? do
        delete("selected data object(s)") do
          @tabbed_plots.delete_data_object
        end
      end
    end # def on_data_object_delete

    # Handles exporting the selected data object(s)
    def on_data_object_export
      data_objects_selected? do
        export do |filename, progress_dialog|
          @tabbed_plots.export_data_object(filename, progress_dialog)
        end
      end
    end # def on_data_object_export

    # Handles exporting all data objects
    def on_data_object_export_all
      data_objects_exist? do
        export do |filename, progress_dialog|
          @tabbed_plots.export_all_data_objects(filename, progress_dialog)
        end
      end
    end # def on_data_object_export_all

    # Handles reseting the selected data object(s)
    def on_data_object_reset
      data_objects_selected? do
        reset("selected data objects") do
          @tabbed_plots.reset_data_object
        end
      end
    end # def on_data_object_reset

    # Handles reseting all data objects
    def on_data_object_reset_all
      data_objects_exist? do
        reset("all data objects") do
          @tabbed_plots.reset_all_data_objects
        end
      end
    end # def on_data_object_reset_all

    ###############################################################################
    # Right-Click Handlers
    ###############################################################################

    # Handles right clicking for tabs
    def handle_tab_right_click(point)
      # Popup menu
      @tab_menu.exec(point)
    end # def handle_tab_right_click

    # Handles right clicking for plots
    def handle_plot_right_click(point)
      # Popup menu
      @plot_menu.exec(point)
    end # def handle_plot_right_click

    # Handles right clicking for data objects
    def handle_data_object_right_click(point)
      # Popup menu
      @data_menu.exec(point)
    end # def handle_data_object_right_click

    ###############################################################################
    # Other Tabbed Plots Handlers
    ###############################################################################

    def handle_config_modified
      @config_modified = true
      update_window_title()
    end

    ###############################################################################
    # Realtime Button Bar Button Handlers
    ###############################################################################

    # Handle start button
    def handle_start
      if @realtime_thread
        # Resume plotting in case it was paused
        @tabbed_plots.resume
        statusBar.showMessage("Plot Updates Resumed")
        @realtime_button_bar.state = 'Running'
      else
        System.load_configuration
        if @need_reset
          @need_reset = false
          System.telemetry.reset
          @tabbed_plots.reset_all_data_objects
        end
        @tabbed_plots.resume

        # Startup realtime thread
        @realtime_button_bar.state = 'Connecting'
        statusBar.showMessage("Connecting to COSMOS Server")
        @realtime_thread = TabbedPlotsRealtimeThread.new(@tabbed_plots_config, method(:realtime_thread_connection_success_callback), method(:realtime_thread_connection_failed_callback), method(:realtime_thread_connection_lost_callback), method(:realtime_thread_fatal_exception_callback), @replay_mode)
      end
    end # def handle_start

    # Handle pause button
    def handle_pause
      if @realtime_thread
        # Pause plotting
        @tabbed_plots.pause
        statusBar.showMessage("Plot Updates Paused - Still Collecting Data in the Background")
        @realtime_button_bar.state = 'Paused'
      else
        # Do Nothing
      end
    end # def handle_pause

    # Handle stop button
    def handle_stop
      @tabbed_plots.pause
      if @realtime_thread
        # Kill realtime thread
        @realtime_thread.kill
        @realtime_thread = nil
        @realtime_button_bar.state = 'Stopped'
        statusBar.showMessage("Disconnection from COSMOS Server Successful")
      else
        # Do Nothing
      end
    end # def handle_stop

    ###############################################################################
    # Realtime Thread Callbacks - Not executed in GUI context - No Direct GUI
    #                             interaction allowed!
    ###############################################################################

    # Handle succesful realtime thread connection
    def realtime_thread_connection_success_callback
      # Notify user of connection success
      Qt.execute_in_main_thread(true) do
        statusBar.showMessage("Connection to COSMOS Server Successful")
        if @tabbed_plots.paused?
          @realtime_button_bar.state = 'Paused'
        else
          @realtime_button_bar.state = 'Running'
        end
      end
    end # def realtime_thread_connection_success_callback

    # Handle realtime thread connection failure
    def realtime_thread_connection_failed_callback(error)
      # Notify user connection failed
      Qt.execute_in_main_thread(true) do
        statusBar.showMessage("Connection to COSMOS Server Failed : #{error.class} : #{error.message}")
        @realtime_button_bar.state = 'Connecting'
      end
    end # def realtime_thread_connection_failed_callback

    # Handle realtime thread connection lost
    def realtime_thread_connection_lost_callback(error)
      # Notify user of connection lost
      if error
        Qt.execute_in_main_thread(true) do
          statusBar.showMessage("Connection to COSMOS Server Lost : #{error.class} : #{error.message}")
          @realtime_button_bar.state = 'Connecting'
        end
      else
        Qt.execute_in_main_thread(true) do
          statusBar.showMessage("Connection to COSMOS Server Lost")
          @realtime_button_bar.state = 'Connecting'
        end
      end
    end # def realtime_thread_connection_lost_callback

    # Handle realtime thread fatal exception
    def realtime_thread_fatal_exception_callback(error)
      Cosmos.handle_fatal_exception(error)
    end # def realtime_thread_fatal_exception_callback
  end
end
