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
  require 'cosmos/gui/choosers/telemetry_chooser'
  require 'cosmos/gui/choosers/float_chooser'
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/gui/widgets/packet_log_frame'
  require 'cosmos/gui/widgets/dart_meta_frame'
  require 'cosmos/gui/dialogs/progress_dialog'
  require 'cosmos/gui/widgets/full_text_search_line_edit'
  require 'cosmos/gui/utilities/analyze_log'
  require 'cosmos/tools/tlm_extractor/tlm_extractor_processor'
  require 'cosmos/tools/tlm_extractor/text_item_chooser'
end

module Cosmos

  # TlmExtractor class
  #
  # This class implements the TlmExtractor.  This application breaks a binary log of telemetry
  # into a csv type file
  #
  class TlmExtractor < QtTool
    slots 'context_menu(const QPoint&)'

    FORMATTING_OPTIONS = %w(CONVERTED RAW FORMATTED WITH_UNITS)
    DART_REDUCED_TYPE_OPTIONS = %w(AVG MIN MAX STDDEV)
    DART_REDUCTION_OPTIONS = %w(NONE MINUTE HOUR DAY)

    class MyListWidget < Qt::ListWidget
      signals 'enterKeyPressed(int)'

      def keyPressEvent(event)
        case event.key
        when Qt::Key_Delete, Qt::Key_Backspace
          remove_selected_items()
        when Qt::Key_Return, Qt::Key_Enter
          emit enterKeyPressed(currentRow())
        end
        super(event)
      end

      def remove_selected_items
        indexes = selected_items()
        indexes.reverse_each do |index|
          item = takeItem(index)
          item.dispose if item
        end
      end

      # Returns an array with the indexes of the selected items
      def selected_items
        selected = []
        index = 0
        self.each do |list_item|
          selected << index if list_item.selected?
          index += 1
        end
        selected
      end
    end

    # Constructor
    def initialize(options)
      super(options) # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      Cosmos.load_cosmos_icon("tlm_extractor.png")

      # Define instance variables
      @input_filenames = []
      @log_dir = System.paths['LOGS']
      @config_dir = File.join(Cosmos::USERPATH, 'config', 'tools', 'tlm_extractor', '')
      @cancel = false

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()

      # Bring up slash screen for long duration tasks after creation
      Splash.execute(self) do |splash|
        # Configure CosmosConfig to interact with splash screen
        ConfigParser.splash = splash

        System.telemetry
        @search_box.completion_list = System.telemetry.all_item_strings(true, splash)
        # Always create the TlmExtractorConfig but note that it's optional to pass a config file
        @tlm_extractor_config = TlmExtractorConfig.new(options.config_file)
        @tlm_extractor_processor = TlmExtractorProcessor.new
        Qt.execute_in_main_thread(true) do
          @telemetry_chooser.update
          sync_config_to_gui()
        end

        # Unconfigure CosmosConfig to interact with splash screen
        ConfigParser.splash = nil
      end
    end

    def initialize_actions
      super()

      # File Menu Actions
      @open_config = Qt::Action.new('Open &Config', self)
      @open_config.statusTip = 'Open configuration file'
      @open_config.connect(SIGNAL('triggered()')) { handle_browse_button() }

      @save_config = Qt::Action.new('&Save Config', self)
      @save_config_keyseq = Qt::KeySequence.new('Ctrl+S')
      @save_config.shortcut = @save_config_keyseq
      @save_config.statusTip = 'Save current configuration'
      @save_config.connect(SIGNAL('triggered()')) { handle_save_button() }

      @file_options = Qt::Action.new('O&ptions', self)
      @file_options.statusTip = 'Open the options dialog'
      @file_options.connect(SIGNAL('triggered()')) { handle_options() }

      @analyze_log = Qt::Action.new('&Analyze Logs', self)
      @analyze_log.statusTip = 'Analyze log file packet counts'
      @analyze_log.connect(SIGNAL('triggered()')) { analyze_log_files() }

      # Mode Menu Actions
      @fill_down_check = Qt::Action.new('&Fill Down', self)
      @fill_down_check_keyseq = Qt::KeySequence.new('Ctrl+F')
      @fill_down_check.shortcut = @fill_down_check_keyseq
      @fill_down_check.statusTip = 'Fill Down'
      @fill_down_check.setCheckable(true)

      @matlab_header_check = Qt::Action.new('&Matlab Header', self)
      @matlab_header_check_keyseq = Qt::KeySequence.new('Ctrl+M')
      @matlab_header_check.shortcut = @matlab_header_check_keyseq
      @matlab_header_check.statusTip = 'Add a Matlab header to the output data'
      @matlab_header_check.setCheckable(true)

      @unique_only_check = Qt::Action.new('&Unique Only', self)
      @unique_only_check_keyseq = Qt::KeySequence.new('Ctrl+U')
      @unique_only_check.shortcut = @unique_only_check_keyseq
      @unique_only_check.statusTip = 'Only output rows where data has changed'
      @unique_only_check.setCheckable(true)

      @batch_mode_check = Qt::Action.new('&Batch Mode', self)
      @batch_mode_check_keyseq = Qt::KeySequence.new('Ctrl+B')
      @batch_mode_check.shortcut = @batch_mode_check_keyseq
      @batch_mode_check.statusTip = 'Process multiple config files with the same input files'
      @batch_mode_check.setCheckable(true)
      @batch_mode_check.connect(SIGNAL('triggered()')) { batch_mode_changed() }

      @normal_columns_check = Qt::Action.new('&Normal Columns', self)
      @normal_columns_check.statusTip = 'Normal Columns'
      @normal_columns_check.setCheckable(true)
      @normal_columns_check.setChecked(true)
      @normal_columns_check.connect(SIGNAL('triggered()')) { column_mode_changed() }

      @share_columns_check = Qt::Action.new('Share Columns (&All)', self)
      @share_columns_check.statusTip = 'Share columns for all items with the same name'
      @share_columns_check.setCheckable(true)
      @share_columns_check.connect(SIGNAL('triggered()')) { column_mode_changed() }

      @share_indiv_columns_check = Qt::Action.new('Share Columns (&Selected)', self)
      @share_indiv_columns_check.statusTip = 'Share columns for selected items with the same name'
      @share_indiv_columns_check.setCheckable(true)
      @share_indiv_columns_check.connect(SIGNAL('triggered()')) { column_mode_changed() }

      @full_column_names_check = Qt::Action.new('Full &Column Names', self)
      @full_column_names_check.statusTip = 'Use full item names in each column'
      @full_column_names_check.setCheckable(true)
      @full_column_names_check.connect(SIGNAL('triggered()')) { column_mode_changed() }

      # The column options are mutually exclusive so create an action group
      column_group = Qt::ActionGroup.new(self)
      column_group.addAction(@normal_columns_check)
      column_group.addAction(@share_columns_check)
      column_group.addAction(@share_indiv_columns_check)
      column_group.addAction(@full_column_names_check)

      @shared_columns = []
      @shared_columns_edit = Qt::Action.new('S&elect Shared Columns', self)
      @shared_columns_edit.statusTip = 'Select which columns are shared'
      @shared_columns_edit.setEnabled(false)
      @shared_columns_edit.connect(SIGNAL('triggered()')) { shared_columns_edit() }

      # Item Menu Actions
      @item_edit = Qt::Action.new('&Edit Items', self)
      @item_edit_keyseq = Qt::KeySequence.new('Ctrl+E')
      @item_edit.shortcut = @item_edit_keyseq
      @item_edit.statusTip = 'Options'
      @item_edit.connect(SIGNAL('triggered()')) { item_edit() }

      @item_delete = Qt::Action.new('&Delete Items', self)
      @item_delete.statusTip = 'Options'
      @item_delete.connect(SIGNAL('triggered()')) { item_delete() }
    end

    def initialize_menus
      # File Menu
      @file_menu = menuBar.addMenu('&File')
      @file_menu.addAction(@open_config)
      @file_menu.addAction(@save_config)
      @file_menu.addSeparator()
      @file_menu.addAction(@file_options)
      @file_menu.addAction(@analyze_log)
      @file_menu.addSeparator()
      @file_menu.addAction(@exit_action)

      # Mode Menu
      @mode_menu = menuBar.addMenu('&Mode')
      @mode_menu.addAction(@fill_down_check)
      @mode_menu.addAction(@matlab_header_check)
      @mode_menu.addAction(@unique_only_check)
      @mode_menu.addAction(@batch_mode_check)
      @mode_menu.addSeparator();
      @mode_menu.addAction(@normal_columns_check)
      @mode_menu.addAction(@share_columns_check)
      @mode_menu.addAction(@share_indiv_columns_check)
      @mode_menu.addAction(@full_column_names_check)
      @mode_menu.addSeparator();
      @mode_menu.addAction(@shared_columns_edit)

      # Item Menu
      @item_menu = menuBar.addMenu('&Item')
      @item_menu.addAction(@item_edit)
      @item_menu.addAction(@item_delete)

      # Help Menu
      @about_string = "COSMOS Telemetry Extractor allows processing of telemetry log files and breaking out specified items."
      initialize_help_menu()
    end

    def initialize_central_widget
      @resize_timer = Qt::Timer.new
      @resize_timer.connect(SIGNAL('timeout()')) { self.resize(self.width, self.minimumHeight) }

      # Create the central widget
      @central_widget = Qt::Widget.new
      setCentralWidget(@central_widget)

      @top_layout = Qt::VBoxLayout.new

      @config_box = Qt::GroupBox.new("Configuration")
      @config_box_layout = Qt::VBoxLayout.new
      @config_box.setLayout(@config_box_layout)
      @top_layout.addWidget(@config_box)

      # Configuration File Selector
      @config_layout = Qt::HBoxLayout.new
      @config_layout_label = Qt::Label.new('Configuration File:')
      @config_layout.addWidget(@config_layout_label)
      @config_field = Qt::LineEdit.new
      @config_field.setReadOnly(true)
      @config_layout.addWidget(@config_field)
      @save_button = Qt::PushButton.new('Save...')
      @config_layout.addWidget(@save_button)
      @save_button.connect(SIGNAL('clicked()')) { handle_save_button() }
      @browse_button = Qt::PushButton.new('Browse...')
      @config_layout.addWidget(@browse_button)
      @browse_button.connect(SIGNAL('clicked()')) { handle_browse_button() }
      @config_box_layout.addLayout(@config_layout)

      # Separator before editor
      @sep1 = Qt::Frame.new(@central_widget)
      @sep1.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      @config_box_layout.addWidget(@sep1)

      # Configuration File Editor
      @config_item_list = MyListWidget.new(self)
      @config_item_list.setContextMenuPolicy(Qt::CustomContextMenu)
      @config_item_list.setDragDropMode(Qt::AbstractItemView::InternalMove)
      @config_item_list.setSelectionMode(Qt::AbstractItemView::ExtendedSelection)
      @config_item_list.setMinimumHeight(150)
      # Allow either double click or enter / return key to bring up the item editor
      @config_item_list.connect(SIGNAL('itemDoubleClicked(QListWidgetItem*)')) { item_list_editor() }
      @config_item_list.connect(SIGNAL('enterKeyPressed(int)')) { item_list_editor() }
      connect(@config_item_list, SIGNAL('customContextMenuRequested(const QPoint&)'), self, SLOT('context_menu(const QPoint&)'))
      @config_box_layout.addWidget(@config_item_list)

      # Telemetry Search
      @search_layout = Qt::HBoxLayout.new
      @search_box = FullTextSearchLineEdit.new(self)
      @search_add_item_button = Qt::PushButton.new('Add Item')
      @search_add_item_button.connect(SIGNAL('clicked()')) do
        split_tlm = @search_box.text.to_s.split(" ")
        if split_tlm.length == 3
          target_name = split_tlm[0].to_s.upcase
          packet_name = split_tlm[1].to_s.upcase
          item_name = split_tlm[2].to_s.upcase
          begin
            System.telemetry.packet_and_item(target_name, packet_name, item_name)
            add_item_callback(target_name, packet_name, item_name)
          rescue
            # Does not exist
          end
        end
      end
      @search_add_packet_button = Qt::PushButton.new('Add Packet')
      @search_add_packet_button.connect(SIGNAL('clicked()')) do
        split_tlm = @search_box.text.to_s.split(" ")
        if split_tlm.length >= 2
          target_name = split_tlm[0].to_s.upcase
          packet_name = split_tlm[1].to_s.upcase
          begin
            System.telemetry.packet(target_name, packet_name)
            add_packet_callback(target_name, packet_name)
          rescue
            # Does not exist
          end
        end
      end
      @search_add_target_button = Qt::PushButton.new('Add Target')
      @search_add_target_button.connect(SIGNAL('clicked()')) do
        split_tlm = @search_box.text.to_s.split(" ")
        if split_tlm.length >= 1
          target_name = split_tlm[0].to_s.upcase
          if System.telemetry.target_names.include?(target_name)
            add_target_callback(target_name)
          end
        end
      end
      @search_layout.addWidget(@search_box)
      @search_layout.addWidget(@search_add_item_button)
      @search_layout.addWidget(@search_add_packet_button)
      @search_layout.addWidget(@search_add_target_button)
      @config_box_layout.addLayout(@search_layout)

      # Telemetry Chooser
      tlm_chooser_layout = Qt::BoxLayout.new(Qt::Horizontal)
      add_target_button = Qt::PushButton.new('Add Target')
      add_target_button.connect(SIGNAL('clicked()')) do
        add_target_callback(@telemetry_chooser.target_name)
      end
      tlm_chooser_layout.addWidget(add_target_button)
      add_packet_button = Qt::PushButton.new('Add Packet')
      add_packet_button.connect(SIGNAL('clicked()')) do
        add_packet_callback(@telemetry_chooser.target_name, @telemetry_chooser.packet_name)
      end
      tlm_chooser_layout.addWidget(add_packet_button)
      @telemetry_chooser = TelemetryChooser.new(self, Qt::Horizontal, true, true, false, true)
      @telemetry_chooser.button_text = 'Add Item'
      @telemetry_chooser.select_button_callback = method(:add_item_callback)
      tlm_chooser_layout.addWidget(@telemetry_chooser)
      @config_box_layout.addLayout(tlm_chooser_layout)

      # Text Item Chooser
      @text_item_chooser = TextItemChooser.new(self)
      @text_item_chooser.button_callback = method(:add_text_item_callback)
      @config_box_layout.addWidget(@text_item_chooser)

      # Downsample
      @downsample_entry = FloatChooser.new(self, 'Downsample Seconds:', 0.0, 0.0, nil, 20, true)
      @config_box_layout.addWidget(@downsample_entry)

      # Batch Configuration
      @batch_config_box = Qt::GroupBox.new("Batch Configuration")
      @batch_config_layout = Qt::GridLayout.new
      @batch_config_layout.setColumnStretch(1, 1)
      @batch_config_box.setLayout(@batch_config_layout)
      @top_layout.addWidget(@batch_config_box)

      row = 0

      # Chooser for Log Files
      label = Qt::Label.new('Config Files:')
      @batch_config_layout.addWidget(label, row, 0)
      @batch_fill_widget = Qt::Widget.new
      @batch_fill_widget.setMinimumWidth(360)
      @batch_config_layout.addWidget(@batch_fill_widget, row, 1, 0, 3)
      @batch_browse_button = Qt::PushButton.new('Browse...')
      @batch_browse_button.connect(SIGNAL('clicked()')) { handle_batch_browse_button() }
      @batch_config_layout.addWidget(@batch_browse_button, row, 2)
      @batch_remove_button = Qt::PushButton.new('Remove')
      @batch_remove_button.connect(SIGNAL('clicked()')) { handle_batch_remove_button() }
      @batch_config_layout.addWidget(@batch_remove_button, row, 3)
      row += 1

      @batch_filenames_entry = Qt::ListWidget.new(self)
      @batch_filenames_entry.setSelectionMode(Qt::AbstractItemView::ExtendedSelection)
      @batch_filenames_entry.setSortingEnabled(true)
      @batch_filenames_entry.setMinimumHeight(90)
      @batch_config_layout.addWidget(@batch_filenames_entry, row, 0, 3, 4)
      row += 3

      # Batch Name
      @batch_name_label = Qt::Label.new('Batch Name:')
      @batch_config_layout.addWidget(@batch_name_label, row, 0)
      @batch_name_entry = Qt::LineEdit.new
      @batch_name_entry.setMinimumWidth(340)
      @batch_config_layout.addWidget(@batch_name_entry, row, 1, 1, 3)
      row += 1

      @batch_config_box.hide

      # Data Source Selection
      @data_source_layout = Qt::HBoxLayout.new()
      label = Qt::Label.new("Data Source: ")
      @data_source_layout.addWidget(label)
      @log_file_radio = Qt::RadioButton.new("Log File", self)
      @log_file_radio.setChecked(true)
      @log_file_radio.connect(SIGNAL('clicked()')) do
        @packet_log_frame.show_log_fields(true)
        @packet_log_frame.output_filename = ""
        @dart_meta_frame.hide
        @resize_timer.start(100)
      end
      @data_source_layout.addWidget(@log_file_radio)
      @dart_radio = Qt::RadioButton.new("DART Database", self)
      @dart_radio.connect(SIGNAL('clicked()')) do
        @packet_log_frame.show_log_fields(false)
        @packet_log_frame.output_filename = ""
        @dart_meta_frame.show
        @resize_timer.start(100)
      end
      @data_source_layout.addWidget(@dart_radio)
      @data_source_layout.addStretch()
      @top_layout.addLayout(@data_source_layout)

      # Packet Log Frame
      @packet_log_frame = PacketLogFrame.new(self, @log_dir, System.default_packet_log_reader.new(*System.default_packet_log_reader_params), @input_filenames, nil, true, true, true, Cosmos::TLM_FILE_PATTERN, Cosmos::TXT_FILE_PATTERN)
      @packet_log_frame.change_callback = method(:change_callback)
      @top_layout.addWidget(@packet_log_frame)

      @dart_meta_frame = DartMetaFrame.new(self)
      @dart_meta_frame.hide
      @top_layout.addWidget(@dart_meta_frame)

      # Process and Open Buttons
      @button_layout = Qt::HBoxLayout.new
      @process_button = Qt::PushButton.new('&Process')
      @process_button.connect(SIGNAL('clicked()')) { process() }
      @button_layout.addWidget(@process_button)

      @open_button = Qt::PushButton.new('&Open in Text Editor')
      @open_button.connect(SIGNAL('clicked()')) { open_button() }
      @open_button.setEnabled(false)
      @button_layout.addWidget(@open_button)

      if Kernel.is_windows?
        @open_excel_button = Qt::PushButton.new('&Open in Excel')
        @open_excel_button.connect(SIGNAL('clicked()')) { open_excel_button() }
        @open_excel_button.setEnabled(false)
        @button_layout.addWidget(@open_excel_button)
      end
      @top_layout.addLayout(@button_layout)

      @central_widget.setLayout(@top_layout)
    end # def initialize

    def self.post_options_parsed_hook(options)
      if options.input_files or options.dart
        normalize_config_options(options)
        
        # Process config file
        raise "Configuration File must be specified for command line processing" unless options.config_file

        # Process the input file(s)
        tlm_extractor_config = TlmExtractorConfig.new(options.config_file)
        tlm_extractor_processor = TlmExtractorProcessor.new
        unless options.output_file
          if options.input_files
            filename = options.input_files[0]
            extension = File.extname(filename)
            filename_no_extension = filename[0..-(extension.length + 1)]
            if tlm_extractor_config.delimiter.to_s.strip == ','
              filename = filename_no_extension << '.csv'
            else
              filename = filename_no_extension << '.txt'
            end
            options.output_file = File.join(System.paths['LOGS'], File.basename(filename))
          else
            options.output_file = File.join(System.paths['LOGS'], File.build_timestamped_filename(['tlmextractor']))
          end
        end

        tlm_extractor_config.output_filename = options.output_file
        if options.dart
          tlm_extractor_processor.process_dart([tlm_extractor_config])
        else
          tlm_extractor_processor.process(options.input_files, [tlm_extractor_config])
        end
        puts "Created #{options.output_file}"
        return false
      else
        return true
      end
    end

    # Runs the application
    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.width = 700
          options.height = 425
          options.auto_size = false
          options.restore_size = false # always render this the correct size
          options.title = "Telemetry Extractor"
          options.dart = false
          option_parser.separator "Telemetry Extractor Specific Options:"
          option_parser.on("-i", "--input FILE", "Process the specified input file") do |arg|
            options.input_files ||= []
            if arg[0..0] != '/' and arg[1..1] != ':'
              # Relative path to default of log folder
              arg = File.join(System.paths['LOGS'], arg)
            end
            options.input_files << arg
          end
          option_parser.on("-o", "--output FILE", "Output results to the specified file") do |arg|
            options.output_file = arg
          end
          option_parser.on("--dart", "Query Dart instead of files") do |arg|
            options.dart = true
          end
        end

        super(option_parser, options)
      end
    end # def self.run

    def context_menu(point)
      @item_menu.exec(@config_item_list.mapToGlobal(point))
    end

    protected

    def sync_gui_to_config
      @tlm_extractor_config.matlab_header = @matlab_header_check.checked?
      @tlm_extractor_config.fill_down = @fill_down_check.checked?
      if @share_columns_check.checked?
        @tlm_extractor_config.set_column_mode(:SHARE_ALL_COLUMNS)
      elsif @share_indiv_columns_check.checked?
        @tlm_extractor_config.set_column_mode(:SHARE_INDIV_COLUMNS)
        @tlm_extractor_config.clear_shared_columns
        @shared_columns.each do |item|
          split_item = item.scan ConfigParser::PARSING_REGEX
          item_name = split_item[0]
          value_type = split_item[1].to_sym
          @tlm_extractor_config.add_shared_column(item_name, value_type)
        end
      elsif @full_column_names_check.checked?
        @tlm_extractor_config.set_column_mode(:FULL_COLUMN_NAMES)
      else
        @tlm_extractor_config.set_column_mode(:NORMAL)
      end
      @tlm_extractor_config.unique_only = @unique_only_check.checked?
      @tlm_extractor_config.downsample_seconds = @downsample_entry.value
      @tlm_extractor_config.output_filename = @packet_log_frame.output_filename

      @tlm_extractor_config.clear_items
      @config_item_list.each do |item|
        split_item = item.text.scan ConfigParser::PARSING_REGEX
        item_type = split_item[0]
        target_name_or_column_name = split_item[1]
        packet_name_or_text = split_item[2]
        item_name = split_item[3]
        value_type = split_item[4]
        dart_reduction = split_item[5]
        dart_reduced_type = split_item[6]
        if value_type
          value_type = value_type.upcase.intern
        else
          value_type = :CONVERTED
        end
        if dart_reduction
          dart_reduction = dart_reduction.upcase.intern
        else
          dart_reduction = :NONE
        end
        if dart_reduced_type
          dart_reduced_type = dart_reduced_type.upcase.intern
        else
          dart_reduced_type = :AVG
        end
        if item_type == 'ITEM'
          @tlm_extractor_config.add_item(target_name_or_column_name, packet_name_or_text, item_name, value_type, dart_reduction, dart_reduced_type)
        else
          @tlm_extractor_config.add_text(target_name_or_column_name.remove_quotes, packet_name_or_text.remove_quotes)
        end
      end
    end

    def sync_config_to_gui
      @matlab_header_check.setChecked(@tlm_extractor_config.matlab_header)
      @fill_down_check.setChecked(@tlm_extractor_config.fill_down)
      case @tlm_extractor_config.column_mode
      when :SHARE_ALL_COLUMNS
        @share_columns_check.setChecked(true)
      when :SHARE_INDIV_COLUMNS
        @share_indiv_columns_check.setChecked(true)
        @shared_columns = []
        @tlm_extractor_config.shared_indiv_columns.each do |shared_column|
          @shared_columns << shared_column
        end
      when :FULL_COLUMN_NAMES
        @full_column_names_check.setChecked(true)
      else
        @normal_columns_check.setChecked(true)
      end
      column_mode_changed()
      @unique_only_check.setChecked(@tlm_extractor_config.unique_only)
      @downsample_entry.value = @tlm_extractor_config.downsample_seconds

      clear_config_item_list()
      @tlm_extractor_config.items.each do |item_type, target_name_or_column_name, packet_name_or_text, item_name, value_type, dart_reduction, dart_reduced_type|
        if item_type == 'ITEM'
          if dart_reduction == :NONE
            if value_type == :CONVERTED
              @config_item_list.addItem("#{item_type} #{target_name_or_column_name} #{packet_name_or_text} #{item_name}")
            else
              @config_item_list.addItem("#{item_type} #{target_name_or_column_name} #{packet_name_or_text} #{item_name} #{value_type}")
            end
          else
            @config_item_list.addItem("#{item_type} #{target_name_or_column_name} #{packet_name_or_text} #{item_name} #{value_type} #{dart_reduction} #{dart_reduced_type}")
          end
        else
          @config_item_list.addItem("#{item_type} \"#{target_name_or_column_name}\" \"#{packet_name_or_text}\"")
        end
      end
    end

    ###############################################################################
    # File Menu Handlers
    ###############################################################################

    def analyze_log_files
      AnalyzeLog.execute(self, @packet_log_frame)
    end

    # Handles processing log files
    def process
      @cancel = false
      if @log_file_radio.isChecked
        begin
          @tlm_extractor_processor.packet_log_reader = @packet_log_frame.packet_log_reader
          @input_filenames = @packet_log_frame.filenames.sort
          @batch_filenames = []
          output_extension = '.txt'
          batch_name = nil
          if @batch_mode_check.checked?
            batch_name = @batch_name_entry.text
            @batch_filenames_entry.each {|list_item| @batch_filenames << list_item.text}
            if @packet_log_frame.output_filename_filter == Cosmos::CSV_FILE_PATTERN
              output_extension = '.csv'
            else
              output_extension = '.txt'
            end
          end
          return unless pre_process_tests()

          # Configure Tlm Extractor Config
          sync_gui_to_config()

          start_time = Time.now.sys
          ProgressDialog.execute(self, 'Log File Progress', 600, 300) do |progress_dialog|
            progress_dialog.cancel_callback = method(:cancel_callback)
            progress_dialog.enable_cancel_button

            begin
              current_input_file_index = -1
              current_config_file_index = -1
              start_packet_count = -1
              last_packet_count = -1

              if @batch_filenames.empty?
                process_method = :process
                process_args = [@input_filenames, [@tlm_extractor_config], @packet_log_frame.time_start, @packet_log_frame.time_end]
              else
                process_method = :process_batch
                process_args = [batch_name, @input_filenames, @log_dir, output_extension, @batch_filenames, @packet_log_frame.time_start, @packet_log_frame.time_end]
              end

              @tlm_extractor_processor.send(process_method, *process_args) do |input_file_index, packet_count, file_progress|
                # Handle Cancel
                break if @cancel

                # Handle Input File Change
                if input_file_index != current_input_file_index
                  current_input_file_index = input_file_index

                  if start_packet_count >= 0
                    # Make sure some packets were found in the previous file
                    if packet_count == start_packet_count
                      # No packets found in previous file
                      progress_dialog.append_text("  WARNING: No packets processed in #{File.basename(@input_filenames[input_file_index - 1])}")
                    end
                  end
                  start_packet_count = packet_count

                  progress_dialog.append_text("Processing File #{input_file_index + 1}/#{@input_filenames.length}: #{File.basename(@input_filenames[input_file_index])}")
                  progress_dialog.set_step_progress(0.0)
                  progress_dialog.set_overall_progress((input_file_index).to_f / @input_filenames.length.to_f)
                end

                # Save packet_count
                last_packet_count = packet_count

                # Handle Progress Reporting
                progress_dialog.set_step_progress(file_progress)
              end
              # Make sure some packets were found in the previous file
              if start_packet_count == last_packet_count
                # No packets found in previous file
                progress_dialog.append_text("  WARNING: No packets processed in #{File.basename(@input_filenames[-1])}")
              end

            rescue => error
              progress_dialog.append_text("Error processing:\n#{error.formatted}\n")
            ensure
              progress_dialog.set_step_progress(1.0) if !@cancel
              progress_dialog.set_overall_progress(1.0) if !@cancel
              progress_dialog.append_text("Runtime: #{Time.now.sys - start_time} s")
              progress_dialog.complete
              if @batch_filenames.empty?
                Qt.execute_in_main_thread(true) do
                  @open_button.setEnabled(true)
                  @open_excel_button.setEnabled(true) if Kernel.is_windows?
                end
              end
            end
          end # ProgressDialog.execute
        rescue => error
          Qt::MessageBox.critical(self, 'Error!', "Error Processing Log File(s)\n#{error.formatted}")
        end
      else
        begin
          @batch_filenames = []
          output_extension = '.txt'
          batch_name = nil
          if @batch_mode_check.checked?
            batch_name = @batch_name_entry.text
            @batch_filenames_entry.each {|list_item| @batch_filenames << list_item.text}
            if @packet_log_frame.output_filename_filter == Cosmos::CSV_FILE_PATTERN
              output_extension = '.csv'
            else
              output_extension = '.txt'
            end
          end
          return unless pre_process_tests()

          # Configure Tlm Extractor Config
          sync_gui_to_config()

          start_time = Time.now.sys
          ProgressDialog.execute(self, 'DART Query Progress', 600, 300) do |progress_dialog|
            progress_dialog.cancel_callback = method(:cancel_callback)
            progress_dialog.enable_cancel_button

            begin
              if @batch_filenames.empty?
                process_method = :process_dart
                process_args = [[@tlm_extractor_config], @packet_log_frame.time_start, @packet_log_frame.time_end, @dart_meta_frame.meta_filters]
              else
                process_method = :process_dart_batch
                process_args = [batch_name, @log_dir, output_extension, @batch_filenames, @packet_log_frame.time_start, @packet_log_frame.time_end, @dart_meta_frame.meta_filters]
              end

              @tlm_extractor_processor.send(process_method, *process_args) do |percentage, message|
                # Handle Cancel
                break if @cancel
                progress_dialog.append_text(message)
                progress_dialog.set_overall_progress(percentage)
              end

            rescue => error
              progress_dialog.append_text("Error processing:\n#{error.formatted}\n")
            ensure
              progress_dialog.set_step_progress(1.0) if !@cancel
              progress_dialog.set_overall_progress(1.0) if !@cancel
              progress_dialog.append_text("Runtime: #{Time.now.sys - start_time} s")
              progress_dialog.complete
              if @batch_filenames.empty?
                Qt.execute_in_main_thread(true) do
                  @open_button.setEnabled(true)
                  @open_excel_button.setEnabled(true) if Kernel.is_windows?
                end
              end
            end
          end # ProgressDialog.execute
        rescue => error
          Qt::MessageBox.critical(self, 'Error!', "Error Querying DART\n#{error.formatted}")
        end
      end
    end # def process

    # Handles options dialog
    def handle_options
      box = Qt::Dialog.new(self)
      box.setWindowTitle('Options')
      top_layout = Qt::VBoxLayout.new

      delimiter_layout = Qt::HBoxLayout.new
      delimiter_label = Qt::Label.new('Delimeter:')
      delimiter_layout.addWidget(delimiter_label)
      delimiter_field = Qt::LineEdit.new
      delimiter_layout.addWidget(delimiter_field)
      if @tlm_extractor_config.delimiter != "\t"
        delimiter_field.setText(@tlm_extractor_config.delimiter)
      else
        delimiter_field.setText('tab')
      end
      top_layout.addLayout(delimiter_layout)

      checkbox_layout = Qt::HBoxLayout.new
      checkbox_label = Qt::Label.new('Output filenames')
      checkbox_layout.addWidget(checkbox_label)
      checkbox_field = Qt::CheckBox.new
      if @tlm_extractor_config.print_filenames_to_output
        checkbox_field.setChecked(true)
      else
        checkbox_field.setChecked(false)
      end
      checkbox_layout.addWidget(checkbox_field)
      top_layout.addLayout(checkbox_layout)

      button_layout = Qt::HBoxLayout.new
      ok_button = Qt::PushButton.new('OK')
      ok_button.connect(SIGNAL('clicked()')) { box.accept }
      button_layout.addWidget(ok_button)
      button_layout.addStretch
      cancel_button = Qt::PushButton.new('CANCEL')
      cancel_button.connect(SIGNAL('clicked()')) { box.reject }
      button_layout.addWidget(cancel_button)
      top_layout.addLayout(button_layout)

      box.setLayout(top_layout)
      case box.exec
      when Qt::Dialog::Accepted
        delimiter = delimiter_field.text
        if delimiter == 'tab'
          delimiter = "\t"
        end
        @tlm_extractor_config.print_filenames_to_output = checkbox_field.checked?
        @tlm_extractor_config.delimiter = delimiter
        if @tlm_extractor_config.delimiter.to_s.strip == ','
          @packet_log_frame.output_filename_filter = Cosmos::CSV_FILE_PATTERN
        else
          @packet_log_frame.output_filename_filter = Cosmos::TXT_FILE_PATTERN
        end
      end
      box.dispose
    end

    def column_mode_changed()
      if @share_indiv_columns_check.checked?
        @shared_columns_edit.setEnabled(true)
      else
        @shared_columns_edit.setEnabled(false)
        @shared_columns = []
      end
    end

    def batch_mode_changed
      if @batch_mode_check.checked?
        @config_box.hide
        @batch_config_box.show
        @open_button.setEnabled(false)
        @open_excel_button.setEnabled(false) if Kernel.is_windows?
        @fill_down_check.setEnabled(false)
        @matlab_header_check.setEnabled(false)
        @share_columns_check.setEnabled(false)
        @full_column_names_check.setEnabled(false)
        @unique_only_check.setEnabled(false)
        @open_config.setEnabled(false)
        @save_config.setEnabled(false)
        @file_options.setEnabled(false)
        @item_edit.setEnabled(false)
        @item_delete.setEnabled(false)
        @packet_log_frame.select_output_dir
        @packet_log_frame.output_filename = @log_dir
      else
        @config_box.show
        @batch_config_box.hide
        @fill_down_check.setEnabled(true)
        @matlab_header_check.setEnabled(true)
        @share_columns_check.setEnabled(true)
        @full_column_names_check.setEnabled(true)
        @unique_only_check.setEnabled(true)
        @open_config.setEnabled(true)
        @save_config.setEnabled(true)
        @file_options.setEnabled(true)
        @item_edit.setEnabled(true)
        @item_delete.setEnabled(true)
        @packet_log_frame.select_output_file
        @packet_log_frame.output_filename = ''
      end
    end

    ###############################################################################
    # Item Menu Handlers
    ###############################################################################

    def item_edit
      item_list_editor()
    end

    def item_delete
      @config_item_list.remove_selected_items
    end

    ###############################################################################
    # Handlers
    ###############################################################################

    def handle_save_button
      filename = nil
      begin
        if @config_field.text.strip.length > 0
          filename = Qt::FileDialog.getSaveFileName(self, "Save Config File", @config_field.text, "Config Files (*.txt);;All Files (*)")
        else
          filename = Qt::FileDialog.getSaveFileName(self, "Save Config File", @config_dir, "Config Files (*.txt);;All Files (*)")
        end
        if filename and filename.length != 0
          sync_gui_to_config()
          @tlm_extractor_config.save(filename)
          @config_field.setText(filename)
          @config_dir = File.dirname(filename) + '/'
        end
      rescue => error
        Qt::MessageBox.critical(self, 'Error!', "Error Saving Configuration File: #{filename}\n#{error.formatted}")
      end
    end

    def handle_browse_button
      filename = Qt::FileDialog::getOpenFileName(self, "Open Config File:", @config_dir, "Config Files (*.txt);;All Files (*)")
      if filename and not filename.empty?
        @config_field.setText(filename)
        @config_dir = File.dirname(filename) + '/'

        begin
          process_config_file(filename)
        rescue => error
          Qt::MessageBox.critical(self, 'Error', "Error Processing Configuration File: #{filename}\n\n#{error.formatted}")
        end
      end
    end

    def item_list_editor
      done_items = false
      selected_items = @config_item_list.selected_items()
      if @config_item_list.currentItem and !selected_items.empty?
        selected_items.each do |item_index|
          dialog = Qt::Dialog.new(self)
          dialog.setWindowTitle("Edit Item")
          layout = Qt::VBoxLayout.new
          split_item = @config_item_list.item(item_index).text.scan ConfigParser::PARSING_REGEX

          if split_item[0] == 'ITEM' and !done_items
            label = Qt::Label.new("#{split_item[1]} #{split_item[2]} #{split_item[3]}")
            layout.addWidget(label)

            label = Qt::Label.new('Value Type:')
            layout.addWidget(label)

            box = Qt::ComboBox.new
            box.maxCount = FORMATTING_OPTIONS.length
            FORMATTING_OPTIONS.each {|item| box.addItem(item) }
            current_formatting = split_item[4]
            current_formatting = 'CONVERTED' unless current_formatting
            if FORMATTING_OPTIONS.index(current_formatting)
              box.currentIndex = FORMATTING_OPTIONS.index(current_formatting)
            end
            layout.addWidget(box)

            label = Qt::Label.new('DART Reduction:')
            layout.addWidget(label)

            dart_reduction_box = Qt::ComboBox.new
            dart_reduction_box.maxCount = DART_REDUCTION_OPTIONS.length
            DART_REDUCTION_OPTIONS.each {|item| dart_reduction_box.addItem(item) }
            current_reduction = split_item[5]
            current_reduction = 'NONE' unless current_reduction
            if DART_REDUCTION_OPTIONS.index(current_reduction)
              dart_reduction_box.currentIndex = DART_REDUCTION_OPTIONS.index(current_reduction)
            end
            layout.addWidget(dart_reduction_box)

            label = Qt::Label.new('DART Reduced Type:')
            layout.addWidget(label)

            dart_reduction_type_box = Qt::ComboBox.new
            dart_reduction_type_box.maxCount = DART_REDUCED_TYPE_OPTIONS.length
            DART_REDUCED_TYPE_OPTIONS.each {|item| dart_reduction_type_box.addItem(item) }
            current_dart_type = split_item[6]
            current_dart_type = 'AVG' unless current_dart_type
            if DART_REDUCED_TYPE_OPTIONS.index(current_dart_type)
              dart_reduction_type_box.currentIndex = DART_REDUCED_TYPE_OPTIONS.index(current_dart_type)
            end
            layout.addWidget(dart_reduction_type_box)

            check_box = nil
            if selected_items.length > 1 and item_index == selected_items[0]
              check_box = Qt::CheckBox.new('Apply to All?')
              layout.addWidget(check_box)
            end

            button_layout = Qt::BoxLayout.new(Qt::Horizontal)
            ok = Qt::PushButton.new("Save")
            connect(ok, SIGNAL('clicked()'), dialog, SLOT('accept()'))
            button_layout.addWidget(ok)
            cancel = Qt::PushButton.new("Cancel")
            connect(cancel, SIGNAL('clicked()'), dialog, SLOT('reject()'))
            button_layout.addWidget(cancel)
            layout.addLayout(button_layout)

            dialog.setLayout(layout)
            if dialog.exec == Qt::Dialog::Accepted
              if box.currentIndex != -1
                set_indexes = [item_index]
                if check_box and check_box.checked?
                  set_indexes = selected_items
                end

                set_indexes.each do |set_item_index|
                  split_item = @config_item_list.item(set_item_index).text.scan ConfigParser::PARSING_REGEX
                  if split_item[0] == 'ITEM'
                    # Remove any formatting/dart info from the item by only keeping the first four strings
                    @config_item_list.item(set_item_index).text = split_item[0..3].join(' ')

                    if dart_reduction_box.currentIndex == 0
                      if box.currentIndex != 0
                        @config_item_list.item(set_item_index).text = "#{@config_item_list.item(set_item_index).text} #{FORMATTING_OPTIONS[box.currentIndex]}"
                      end
                    else
                      @config_item_list.item(set_item_index).text = "#{@config_item_list.item(set_item_index).text} #{FORMATTING_OPTIONS[box.currentIndex]} #{DART_REDUCTION_OPTIONS[dart_reduction_box.currentIndex]} #{DART_REDUCED_TYPE_OPTIONS[dart_reduction_type_box.currentIndex]}"
                    end
                  end
                end
                if set_indexes.length > 1
                  done_items = true
                end
              end
            end
          elsif split_item[0] == 'TEXT'
            label = Qt::Label.new('Column Name:')
            layout.addWidget(label)
            column_name = Qt::LineEdit.new(split_item[1].remove_quotes)
            layout.addWidget(column_name)
            label = Qt::Label.new('Text:')
            layout.addWidget(label)
            text = Qt::LineEdit.new(split_item[2].remove_quotes)
            layout.addWidget(text)

            button_layout = Qt::BoxLayout.new(Qt::Horizontal)
            ok = Qt::PushButton.new("Save")
            connect(ok, SIGNAL('clicked()'), dialog, SLOT('accept()'))
            button_layout.addWidget(ok)
            cancel = Qt::PushButton.new("Cancel")
            connect(cancel, SIGNAL('clicked()'), dialog, SLOT('reject()'))
            button_layout.addWidget(cancel)
            layout.addLayout(button_layout)

            dialog.setLayout(layout)
            if dialog.exec == Qt::Dialog::Accepted
              # Remove any formatting from the item by only keeping the first four strings
              @config_item_list.item(item_index).text = "#{split_item[0]} \"#{column_name.text}\" \"#{text.text}\""
            end
          end

          dialog.dispose
        end
      end
    end

    def shared_columns_edit

      # Get the list of "common" items in the config item list.
      item_list = []
      @config_item_list.each do |item|
        split_item = item.text.scan ConfigParser::PARSING_REGEX
        item_type = split_item[0]
        item_name = split_item[3]
        value_type = split_item[4]
        if value_type
          value_type = value_type.upcase.intern
        else
          value_type = :CONVERTED
        end
        if item_type == 'ITEM'
          item_list << item_name + ' ' + value_type.to_s
        end
      end
      shared_column_list = item_list.select {|item| item_list.count(item) > 1}
      shared_column_list.uniq!

      dialog = Qt::Dialog.new(self)
      dialog.setWindowTitle("Select Common Items to Share Columns")
      layout = Qt::VBoxLayout.new

      list_layout = Qt::BoxLayout.new(Qt::Horizontal)
      list = MyListWidget.new(self)
      list.setSelectionMode(Qt::AbstractItemView::MultiSelection)
      list.setMinimumHeight(150)
      list.setMinimumWidth(400)
      shared_column_list.each {|item| list.addItem(item)}
      list_layout.addWidget(list)
      layout.addLayout(list_layout)
      list.each {|item| item.setSelected(true) if @shared_columns.include?(item.text)}

      button_layout = Qt::BoxLayout.new(Qt::Horizontal)
      cancel = Qt::PushButton.new("Cancel")
      connect(cancel, SIGNAL('clicked()'), dialog, SLOT('reject()'))
      button_layout.addWidget(cancel)
      ok = Qt::PushButton.new("Save")
      connect(ok, SIGNAL('clicked()'), dialog, SLOT('accept()'))
      button_layout.addWidget(ok)
      layout.addLayout(button_layout)

      dialog.setLayout(layout)
      if dialog.exec == Qt::Dialog::Accepted
        @shared_columns = []
        list.each {|item| @shared_columns << item.text if item.isSelected()}
      end
      dialog.dispose
    end

    def open_button
      Cosmos.open_in_text_editor(@packet_log_frame.output_filename)
    end

    def open_excel_button
      system("start Excel.exe \"#{@packet_log_frame.output_filename}\"")
    end

    def clear_config_item_list
      @config_item_list.clearItems
    end # def clear_data_object_list

    # Handles removing a selected filename
    def handle_batch_remove_button
      @batch_filenames_entry.remove_selected_items
    end

    # Handles browsing for log files
    def handle_batch_browse_button
      Cosmos.set_working_dir do
        filenames = Qt::FileDialog::getOpenFileNames(
          self, "Select Config File(s):", @config_dir, Cosmos::TXT_FILE_PATTERN)
        if filenames and not filenames.empty?
          @config_dir = File.dirname(filenames[0]) + '/'
          filenames.each {|filename| @batch_filenames_entry.addItem(filename) if @batch_filenames_entry.findItems(filename, Qt::MatchExactly).empty? }
        end
      end
    end

    ###############################################################################
    # Additional Callbacks
    ###############################################################################

    def cancel_callback(progress_dialog = nil)
      @cancel = true
      return true, false
    end

    def add_target_callback(target_name)
      packets = System.telemetry.packets(target_name)
      packets.each do |packet_name, packet|
        packet.sorted_items.each do |item|
          @config_item_list.addItem("ITEM #{target_name} #{packet_name} #{item.name}")
        end
      end
    end

    def add_packet_callback(target_name, packet_name)
      packet = System.telemetry.packet(target_name, packet_name)
      packet.sorted_items.each do |item|
        @config_item_list.addItem("ITEM #{target_name} #{packet_name} #{item.name}")
      end
    end

    def add_item_callback(target_name, packet_name, item_name)
      @config_item_list.addItem("ITEM #{target_name} #{packet_name} #{item_name}")
    end

    def add_text_item_callback(column_name, text)
      @config_item_list.addItem("TEXT \"#{column_name}\" \"#{text}\"")
    end

    ###############################################################################
    # Helper Methods
    ###############################################################################

    def pre_process_tests
      if !@batch_mode_check.checked?
        # Normal Mode

        if @config_item_list.count < 1
          Qt::MessageBox.critical(self, 'Error', 'Please select at least 1 item')
          return false
        end

        if @packet_log_frame.output_filename.to_s.empty?
          if @log_file_radio.isChecked
            Qt::MessageBox.critical(self, 'Error', 'No Output File Selected')
            return false
          else
            @packet_log_frame.output_filename = File.join(System.paths['LOGS'], File.build_timestamped_filename(['tlm_extractor', 'dart']))
          end
        end

        if File.exist?(@packet_log_frame.output_filename)
          result = Qt::MessageBox.warning(self, 'Warning!', 'Output File Already Exists. Overwrite?', Qt::MessageBox::Yes | Qt::MessageBox::No)
          return false if result == Qt::MessageBox::No
        end
      else
        # Batch Mode

        if !@batch_name_entry.text or @batch_name_entry.text.strip.empty?
          Qt::MessageBox.critical(self, 'Error', 'Batch Name is Required')
          return false
        end

        unless @batch_filenames and @batch_filenames[0]
          Qt::MessageBox.critical(self, 'Error', 'Please select at least 1 config file')
          return false
        end
      end

      if @log_file_radio.isChecked
        unless @input_filenames and @input_filenames[0]
          Qt::MessageBox.critical(self, 'Error', 'Please select at least 1 input file')
          return false
        end

        # Validate configurations exist for input filenames
        @input_filenames.each do |input_filename|
          Cosmos.check_log_configuration(@tlm_extractor_processor.packet_log_reader, input_filename)
        end

        #Validate config information
        @tlm_extractor_processor.packet_log_reader.open(@input_filenames[0])
        @tlm_extractor_processor.packet_log_reader.close

        @config_item_list.each do |item|
          split_item = item.text.split
          item_type = split_item[0]
          target_name = split_item[1]
          packet_name = split_item[2]
          item_name = split_item[3]

          if item_type == 'ITEM'
            # Verify Packet
            packet = nil
            begin
              packet = System.telemetry.packet(target_name, packet_name)
            rescue
              Qt::MessageBox.critical(self, 'Error!', "Unknown Packet #{target_name} #{packet_name} specified")
              return false
            end

            # Verify Item
            begin
              packet.get_item(item_name)
            rescue
              Qt::MessageBox.critical(self, 'Error!', "Item #{item_name} not present in packet")
              return false
            end
          end
        end
      end

      true
    end

    def process_config_file(filename)
      @tlm_extractor_config.restore(filename)
      sync_config_to_gui()
    end

    def change_callback(item_changed)
      if item_changed == :INPUT_FILES
        if !@batch_mode_check.checked?
          filename = @packet_log_frame.filenames[0]
          if filename
            extension = File.extname(filename)
            filename_no_extension = filename[0..-(extension.length + 1)]
            if @packet_log_frame.output_filename_filter == Cosmos::CSV_FILE_PATTERN
              filename = filename_no_extension << '.csv'
            else
              filename = filename_no_extension << '.txt'
            end
            @packet_log_frame.output_filename = filename
          end
        end
      elsif item_changed == :OUTPUT_FILE
        output_filename = @packet_log_frame.output_filename
        if output_filename and !output_filename.to_s.strip.empty?
          @log_dir = File.dirname(output_filename)
        end
      elsif item_changed == :OUTPUT_DIR
        output_filename = @packet_log_frame.output_filename
        if output_filename and !output_filename.to_s.strip.empty?
          @log_dir = output_filename
        end
      end
    end

  end # class TlmExtractor

end # module Cosmos
