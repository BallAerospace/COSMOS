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
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/gui/dialogs/progress_dialog'
  require 'cosmos/gui/dialogs/select_dialog'
  require 'cosmos/gui/widgets/full_text_search_line_edit'
  require 'cosmos/tools/tlm_viewer/tlm_viewer_config'
  require 'cosmos/tools/tlm_viewer/screen'
  require 'cosmos/script'
  require 'find'
  require 'fileutils'
end

module Cosmos
  Cosmos.disable_warnings do
    module Script
      private

      def display(display_name, x_pos = nil, y_pos = nil)
        TlmViewer.instance.display(display_name, x_pos, y_pos)
      end

      def clear(display_name)
        TlmViewer.instance.clear(display_name)
      end

      def clear_all(target = nil)
        TlmViewer.instance.clear_all(target)
      end
    end
  end
end

module Cosmos
  # The Telemetry Viewer Application provides a frameword for user defined
  # 'screens'. Screens can contain telemetry items but also command senders,
  # graphs, and any other user defined widgets. The TlmViewer class itself is
  # responsible for reading the tlm_viewer.txt file and building the list of
  # screens. The actual rendering of the screen is defered to the various
  # widget classes.
  class TlmViewer < QtTool
    @@instance = nil

    def self.instance
      @@instance
    end

    def self.load_config(filename)
      raise "Configuration file #{filename} does not exist." unless filename && File.exist?(filename)

      # Find all screen files so we can calculate hashing sum
      tlmviewer_files = [filename, System.initial_filename]
      additional_data = ''
      System.targets.each do |target_name, target|
        tlmviewer_files << target.filename if File.exist?(target.filename)
        screen_dir = File.join(target.dir, 'screens')
        if File.exist?(screen_dir)
          if target.substitute
            additional_data << target.original_name
            additional_data << target.name
          else
            additional_data << target.original_name
          end
          Dir.new(screen_dir).each do |screen_dir_filename|
            if screen_dir_filename[0] != '.'
              tlmviewer_files << File.join(screen_dir, screen_dir_filename)
            end
          end
        end
      end
      # Calculate the hashing sum and attempt to load marshal file
      hashing_result = Cosmos.hash_files(tlmviewer_files, additional_data, System.hashing_algorithm)
      # Only use at most, 32 characters of the hex
      hash_string = hashing_result.hexdigest
      hash_string = hash_string[-32..-1] if hash_string.length >= 32

      marshal_filename = File.join(System.paths['TMP'], "tlmviewer_#{hash_string}.bin")
      config = Cosmos.marshal_load(marshal_filename)
      unless config
        # Marshal file load failed - Manually load configuration
        config = TlmViewerConfig.new(filename)
        # Create marshal file for next time
        Cosmos.marshal_dump(marshal_filename, config)
      end
      config
    end

    def initialize(options)
      # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      super(options)
      Cosmos.load_cosmos_icon("tlm_viewer.png")
      setMinimumWidth(300)
      @@instance = self

      Splash.execute(self, true) do |splash|
        ConfigParser.splash = splash
        splash.message = "Starting TlmViewer"
        System.telemetry
        @tlm_viewer_config = self.class.load_config(options.config_file)
        ConfigParser.splash = nil
      end

      initialize_actions()
      initialize_menus(options)
      initialize_central_widget(options)
      complete_initialize()

      Splash.execute(self) do |splash|
        ConfigParser.splash = splash
        splash.message = "Displaying requested screens"

        # Startup desired screens once we're running
        @tlm_viewer_config.screen_infos.each do |screen_full_name, screen_info|
          if screen_info.show_on_startup
            display(screen_full_name, screen_info.x_pos, screen_info.y_pos)
          end
        end

        if options.listen
          # Start DRb with access control
          @json_drb = JsonDRb.new
          port = System.ports['TLMVIEWER_API']
          @json_drb.acl = System.acl
          whitelist = [
            'display',
            'clear',
            'clear_all']
          @json_drb.method_whitelist = whitelist
          begin
            @json_drb.start_service System.listen_hosts['TLMVIEWER_API'], port, self
          rescue Exception
            raise FatalError.new("Error starting JsonDRb on port #{port}.\nPerhaps a Telemetry Viewer is already running?")
          end
        else
          @json_drb = nil
        end

        @all_telemetry = System.telemetry.all_item_strings(false, splash)

        Qt.execute_in_main_thread(true) do
          toggle_replay_mode() if options.replay
          @search_box.completion_list = @tlm_viewer_config.completion_list
          @search_box.callback = lambda do |tlm|
            mapping = @tlm_viewer_config.tlm_to_screen_mapping[tlm]
            if mapping
              mapping.each do |screen_name|
                display(screen_name)
              end
            end
          end
        end

        ConfigParser.splash = nil
      end
    end

    def initialize_actions
      super()

      # File actions
      @file_save = Qt::Action.new(Cosmos.get_icon('save.png'), '&Save Configuration', self)
      @file_save_keyseq = Qt::KeySequence.new('Ctrl+S')
      @file_save.shortcut = @file_save_keyseq
      @file_save.statusTip = 'Save all screen positions'
      @file_save.connect(SIGNAL('triggered()')) { file_save() }

      @file_generate = Qt::Action.new('&Generate Screens', self)
      @file_generate_keyseq = Qt::KeySequence.new('Ctrl+G')
      @file_generate.shortcut = @file_generate_keyseq
      @file_generate.statusTip = 'Generate screen definition files'
      @file_generate.connect(SIGNAL('triggered()')) { file_generate() }

      @file_audit = Qt::Action.new('Audi&t Screens vs Tlm', self)
      @file_audit_keyseq = Qt::KeySequence.new('Ctrl+T')
      @file_audit.shortcut = @file_audit_keyseq
      @file_audit.statusTip = 'Create a report listing which telemetry points are not on screens'
      @file_audit.connect(SIGNAL('triggered()')) { file_audit() }

      @replay_action = Qt::Action.new('Toggle Replay Mode', self)
      @replay_action.statusTip = 'Toggle Replay Mode'
      @replay_action.connect(SIGNAL('triggered()')) { toggle_replay_mode() }
    end

    def initialize_menus(options)
      # File Menu
      @file_menu = menuBar.addMenu('&File')
      @file_menu.addAction(@file_save)
      @file_menu.addAction(@file_generate)
      @file_menu.addAction(@file_audit)
      @file_menu.addAction(@replay_action)
      @file_menu.addSeparator()
      @file_menu.addAction(@exit_action)

      # Help Menu
      @about_string = "Telemetry Viewer provides a view of every telemetry packet in the system."
      @about_string << " Packets can be viewed in numerous representations ranging from the raw data to formatted with units."

      initialize_help_menu()
    end

    def initialize_central_widget(options)
      central_widget = Qt::Widget.new
      setCentralWidget(central_widget)
      top_layout = Qt::VBoxLayout.new

      @replay_flag = Qt::Label.new("Replay Mode")
      @replay_flag.setStyleSheet("background:green;color:white;padding:5px;font-weight:bold;")
      top_layout.addWidget(@replay_flag)
      @replay_flag.hide

      @search_box = FullTextSearchLineEdit.new(self)
      top_layout.addWidget(@search_box)

      # Create Screen Drop Down Lists
      selection_pane = Qt::HBoxLayout.new
      top_layout.addLayout(selection_pane)

      column_widgets = []
      @tlm_viewer_config.columns.each_with_index do |target_screen_infos, col|
        if col != 0 # Don't add separator for the first column
          separator = Qt::Frame.new(central_widget)
          separator.setFrameStyle(Qt::Frame::VLine | Qt::Frame::Sunken)
          selection_pane.addWidget(separator)
        end
        grid = Qt::GridLayout.new
        selection_pane.addLayout(grid)
        row = 0
        target_screen_infos.each do |target_name, screen_infos|
          grid.addWidget(Qt::Label.new("#{target_name}:"), row, 0)

          # Create drop down of screens for this target
          combo = Qt::ComboBox.new
          screen_infos.each do |screen_name, screen_info|
            # Store both the screen name (for display) and the screen filename
            # (for the edit button) in a variant we can access in button handlers
            combo.addItem(screen_info.name,
                          Qt::Variant.new("#{screen_info.full_name};#{screen_info.filename}"))
          end
          if screen_infos.length >= 20
            combo.setMaxVisibleItems(20)
          else
            combo.setMaxVisibleItems(screen_infos.length)
          end

          # Create an anonymous method to display the screen which we can
          # attach to both the combobox activated signal and the button press
          display_handler = lambda do
            # Access the variant we created for this screen name
            string = combo.itemData(combo.currentIndex)
            # The first part of the variant before the semicolon is the screen name
            display(string.value.split(';')[0])
          end
          combo.connect(SIGNAL('activated(int)')) { display_handler.call }
          grid.addWidget(combo, row, 1)

          show_button =  Qt::PushButton.new("Show Screen")
          show_button.connect(SIGNAL('clicked(bool)')) { display_handler.call }
          grid.addWidget(show_button, row, 2)

          unless options.production
            edit_button = Qt::PushButton.new(Cosmos.get_icon('edit.png'), '')
            edit_button.setFixedSize(24, 24)
            edit_button.connect(SIGNAL('clicked(bool)')) do
              # Access the variant we created for this screen name
              string = combo.itemData(combo.currentIndex)
              # The second part of the variant after the semicolon is the screen filename
              Cosmos.run_cosmos_tool('ConfigEditor', "-f #{string.value.split(';')[1]}")
            end
            grid.addWidget(edit_button, row, 3)
          end

          row += 1
        end
      end

      central_widget.setLayout(top_layout)
    end

    # Handles saving the current configuration to a file
    def file_save
      filename = Qt::FileDialog.getSaveFileName(self, "Save Configuration", @tlm_viewer_config.filename, "Config Files (*.txt);;All Files (*)")
      if filename and not filename.empty?
        # Update config with open screen positions and show on startup
        Screen.open_screens.clone.each do |screen|
          @tlm_viewer_config.screen_infos.each do |screen_full_name, screen_info|
            if screen_full_name == screen.full_name
              begin
                screen_info.x_pos = screen.window.x
                screen_info.y_pos = screen.window.y
                screen_info.show_on_startup = true
              rescue
                # Screen probably already closed - continue
              end
              break
            end
          end
        end

        filename << '.txt' if File.extname(filename).empty?
        @tlm_viewer_config.save(filename)
      end
    end

    def generate_target(target_name)
      target = System.targets[target_name]

      results = ''
      screen_dir = File.join(USERPATH, 'config', 'targets', target.original_name, 'screens')
      FileUtils.mkdir_p(screen_dir, :mode => 0777) unless File.exist?(screen_dir)

      System.telemetry.packets(target.name).each do |packet_name, packet|
        filename = File.join(screen_dir, packet_name.downcase + '.txt')
        unless File.exist?(filename)
          results << "Creating #{filename}...\n"
          File.open(filename, 'w') do |file|
            items = packet.sorted_items
            if items.length > 34
              file.puts "SCREEN 250 800 1.0"
              file.puts ""
              file.puts "SCROLLWINDOW"
            else
              file.puts "SCREEN AUTO AUTO 1.0"
            end
            file.puts ""
            file.puts "  VERTICALBOX"
            items.each do |item|
              file.puts "    LABELVALUE #{target.original_name} #{packet_name} #{item.name} # #{item.description}"
            end
            file.puts "  END"
            file.puts ""
            file.puts "END" if items.length > 34
          end
        else
          results << "Skipping #{filename}... already exists\n"
        end
      end

      return results
    end

    def file_generate
      target_names = System.telemetry.target_names
      target_names.unshift('ALL')

      dialog = SelectDialog.new(self, 'Target Name:', target_names, 'Select Target Name to Generate Screens')
      target_name = dialog.result
      if target_name
        ProgressDialog.execute(self, 'Generating Telemetry Screens', 500, 10, false, false, true, true, false) do |progress_dialog|
          if target_name == 'ALL'
            System.telemetry.target_names.each do |my_target_name|
              progress_dialog.append_text(generate_target(my_target_name))
            end
          else
            progress_dialog.append_text(generate_target(target_name))
          end
          progress_dialog.complete
        end
      end
    end

    def file_audit
      output_filename = ''
      all_telemetry = @all_telemetry.clone

      # Open a progress dialog with out a step progress
      @cancel_audit = false
      ProgressDialog.execute(self, 'Audit Progress', 650, 400, true, false) do |progress|
        progress.cancel_callback = lambda {|dialog| @cancel_audit = true; [true, false]}
        progress.enable_cancel_button
        begin
          index = 1
          @tlm_viewer_config.screen_infos.each do |name, info|
            break if @cancel_audit
            progress.append_text("Processing screen #{name}")
            screen_text = File.read(info.filename).upcase
            found = []
            all_telemetry.each do |tlm|
              break if @cancel_audit
              if screen_text.include?(tlm) || Packet::RESERVED_ITEM_NAMES.include?(tlm.split[-1].strip)
                found << tlm
              end
            end
            all_telemetry -= found

            progress.set_overall_progress(index.to_f / @tlm_viewer_config.screen_infos.length.to_f)
            index += 1
          end

          unless @cancel_audit
            output_filename = File.join(System.paths['LOGS'],
                                        File.build_timestamped_filename(['screen','audit'], '.txt'))
            File.open(output_filename, 'w') do |file|
              file.puts "Telemetry Viewer audit created on #{Time.now.sys.formatted}.\n"
              if all_telemetry.empty?
                msg = "\nAll telemetry points accounted for in screens."
                progress.append_text(msg)
                file.puts msg
              else
                progress.append_text("\nThere were #{all_telemetry.length} telemetry points not accounted for.")
                file.puts "\nThe following telemetry points were not on any screens:"
                all_telemetry.map {|item| file.puts item }
              end
            end
          end
        rescue => error
          progress.append_text("Error processing:\n#{error.formatted}\n")
        ensure
          progress.append_text("\nWriting audit to #{output_filename}")
          progress.set_overall_progress(1.0)
          progress.complete
        end
      end
      # Open the file as a convenience
      Cosmos.open_in_text_editor(output_filename) if output_filename
    end

    def toggle_replay_mode
      set_replay_mode(!get_replay_mode())
      if get_replay_mode()
        @replay_flag.show
      else
        @replay_flag.hide
      end
      Screen.update_replay_mode
    end

    # Method called by screens to notify that they have been closed
    def notify(closed_screen)
      screen_full_name = closed_screen.full_name
      begin
        screen_info = find_screen_info(screen_full_name)
        screen_info.screen = nil
      rescue
        # Oh well
      end
    end

    def closeEvent(event)
      # Are you sure if any screens are open
      if Screen.open_screens.length > 0
        result = Qt::MessageBox.warning(self, "Confirm Close",
          "Are you sure? All Open Telemetry Screens will be Closed.",
          Qt::MessageBox::Yes | Qt::MessageBox::No)
        if result != Qt::MessageBox::Yes
          event.ignore()
        else
          # Close any open screens
          shutdown_cmd_tlm()
          Screen.close_all_screens(self)
          @json_drb.stop_service if @json_drb
          super(event)
        end
      else
        shutdown_cmd_tlm()
        @json_drb.stop_service if @json_drb
        super(event)
      end
    end

    def find_screen_info(screen_full_name)
      screen_info = @tlm_viewer_config.screen_infos[screen_full_name.upcase]
      raise "Unknown screen: #{screen_full_name.upcase}" unless screen_info
      screen_info
    end

    def display(screen_full_name, x_pos = nil, y_pos = nil)
      return unless screen_full_name
      x_pos = x_pos.to_i if x_pos
      y_pos = y_pos.to_i if y_pos

      # Find the specified screen
      screen_info = find_screen_info(screen_full_name)

      # Raise Screens that are already open
      if screen_info.screen
        success = false
        Qt.execute_in_main_thread(true) do
          begin
            if screen_info.screen.window
              screen_info.screen.window.raise
              screen_info.screen.window.activateWindow
              screen_info.screen.window.showNormal
              success = true
            end
          rescue
            # Screen probably was closed - continue
            screen_info.screen = nil
          end
        end
        return if success
      end

      # Create screens that are not open yet
      Qt.execute_in_main_thread(true) do
        if x_pos and y_pos
          screen_info.screen = Screen.new(screen_info.full_name, screen_info.filename, self, :REALTIME, x_pos, y_pos, screen_info.original_target_name, screen_info.substitute, screen_info.force_substitute)
        else
          screen_info.screen = Screen.new(screen_info.full_name, screen_info.filename, self, :REALTIME, screen_info.x_pos, screen_info.y_pos, screen_info.original_target_name, screen_info.substitute, screen_info.force_substitute)
        end
        if screen_info.screen.window
          screen_info.screen.window.raise
          screen_info.screen.window.activateWindow
          screen_info.screen.window.showNormal
        end
      end
    end

    # Close the specified screen
    def clear(screen_full_name)
      close_screen(find_screen_info(screen_full_name))
    end

    # Close all screens
    def clear_all(target_name = nil)
      if target_name
        screens = @tlm_viewer_config.screen_infos.values.select do |screen_info|
          screen_info.target_name == target_name.upcase
        end
        raise "Unknown screen target: #{target_name.upcase}" if screens.length == 0
        screens.each { |screen_info| close_screen(screen_info) }
      else
        Qt.execute_in_main_thread(true) { Screen.close_all_screens(self) }
      end
    end

    def close_screen(screen_info)
      Qt.execute_in_main_thread(true) do
        begin
          screen_info.screen.window.close if screen_info.screen
        ensure
          screen_info.screen = nil
        end
      end
    end

    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.title = 'Telemetry Viewer'
          options.screen = nil
          options.listen = true
          options.restore_size = false
          options.production = false
          options.replay = false
          options.config_file = true # config_file is required

          option_parser.separator "Telemetry Viewer Specific Options:"
          option_parser.on("-s", "--screen SCREEN_NAME", "Start up the specified screen") { |arg| options.screen = arg }
          option_parser.on("-n", "--nolisten", "Don't listen for requests") do
            options.listen = false
            options.title << ' : Not Listening'
          end
          option_parser.on("-p", "--production", "Run Telemetry Viewer in production mode which disables the edit buttons.") do |arg|
            options.production = true
          end
          option_parser.on("--replay", "Run Telemetry Viewer in Replay mode") do
            options.replay = true
          end
          option_parser.parse!(ARGV)
        end

        if options.screen
          normalize_config_options(options)
          application = nil
          begin
            QtTool.redirect_io
            System.telemetry
            application = Qt::Application.new(ARGV)
            application.addLibraryPath(Qt::PLUGIN_PATH) if Kernel.is_windows?
            tlm_viewer_config = load_config(options.config_file)
            screen_info = tlm_viewer_config.screen_infos[options.screen.upcase]
            raise "Unknown screen: #{options.screen.upcase}" unless screen_info
            if not options.auto_position
              screen_info.screen = Screen.new(screen_info.full_name, screen_info.filename, nil, :REALTIME, options.x, options.y, screen_info.original_target_name, screen_info.substitute, screen_info.force_substitute, true)
            else
              screen_info.screen = Screen.new(screen_info.full_name, screen_info.filename, nil, :REALTIME, screen_info.x_pos, screen_info.y_pos, screen_info.original_target_name, screen_info.substitute, screen_info.force_substitute, true)
            end
            set_replay_mode(true) if options.replay
            Screen.update_replay_mode
            application.exec
          rescue Exception => error
            unless error.class == SystemExit or error.class == Interrupt
              Cosmos.handle_fatal_exception(error, false)
            end
          end
        else
          super(option_parser, options)
        end
      end
    end
  end
end
