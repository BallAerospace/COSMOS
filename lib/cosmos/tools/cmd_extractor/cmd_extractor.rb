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
  require 'cosmos/gui/dialogs/packet_log_dialog'
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/gui/dialogs/progress_dialog'
end

module Cosmos
  # Breaks a binary log of commands into readable text
  class CmdExtractor < QtTool
    # Create a new CmdExtractor by instantiating a new packet log reader,
    # loading the custom icon, building the application and loading the system
    # commands.
    # @param (see QtTool#initialize)
    def initialize(options)
      # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      super(options)

      @output_filename = nil
      @input_filenames = []
      @log_dir = System.paths['LOGS']
      @export_dir = @log_dir.clone
      @packet_log_reader = System.default_packet_log_reader.new
      @time_start = nil
      @time_end = nil

      Cosmos.load_cosmos_icon("cmd_extractor.png")

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()

      # Bring up slash screen for long duration tasks after creation
      Splash.execute(self) do |splash|
        ConfigParser.splash = splash
        System.commands
        ConfigParser.splash = nil
      end
    end

    # Initialize the Mode menu actions
    def initialize_actions
      super()

      # Mode Menu Actions
      @include_raw = Qt::Action.new(tr('Include &Raw Data'), self)
      @include_raw_keyseq = Qt::KeySequence.new(tr('Ctrl+R'))
      @include_raw.shortcut = @include_raw_keyseq
      @include_raw.statusTip = tr('Include raw packet data in the text output')
      @include_raw.setCheckable(true)
    end

    # Create the File and Mode menus and initialize the Help menu
    def initialize_menus
      @file_menu = menuBar.addMenu(tr('&File'))
      @file_menu.addAction(@exit_action)
      @mode_menu = menuBar.addMenu(tr('&Mode'))
      @mode_menu.addAction(@include_raw)
      @about_string = "Command Extractor extracts commands from a binary command log file into a human readable text file."
      initialize_help_menu()
    end

    # Create the CmdExtractor application which primarily consists of a
    # {PacketLogFrame}
    def initialize_central_widget
      @central_widget = Qt::Widget.new
      setCentralWidget(@central_widget)
      @top_layout = Qt::VBoxLayout.new(@central_widget)

      # Packet Log Frame
      @packet_log_frame = PacketLogFrame.new(self, @log_dir, System.default_packet_log_reader.new, @input_filenames, @output_filename, true, true, true, Cosmos::CMD_FILE_PATTERN, Cosmos::TXT_FILE_PATTERN)
      @packet_log_frame.change_callback = method(:change_callback)
      @top_layout.addWidget(@packet_log_frame)

      # Separator before buttons
      @sep2 = Qt::Frame.new(@central_widget)
      @sep2.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      @top_layout.addWidget(@sep2)

      # Process and Open Buttons
      @button_layout = Qt::HBoxLayout.new
      @process_button = Qt::PushButton.new('&Process Files')
      @process_button.connect(SIGNAL('clicked()')) { process_log_files() }
      @button_layout.addWidget(@process_button)

      @open_button = Qt::PushButton.new('&Open in Text Editor')
      @open_button.connect(SIGNAL('clicked()')) { open_button() }
      @open_button.setEnabled(false)
      @button_layout.addWidget(@open_button)
      @top_layout.addLayout(@button_layout)
    end

    # (see QtTool.run)
    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.width = 700
          options.height = 425
          options.title = "Command Extractor"
        end

        super(option_parser, options)
      end
    end

    protected

    ###############################################################################
    # File Menu Handlers
    ###############################################################################

    def process_log_files
      @cancel = false
      begin
        @packet_log_reader = @packet_log_frame.packet_log_reader
        @input_filenames = @packet_log_frame.filenames.sort
        @time_start = @packet_log_frame.time_start
        @time_end = @packet_log_frame.time_end
        @output_filename = @packet_log_frame.output_filename
        include_raw = @include_raw.isChecked
        return unless pre_process_tests()

        ProgressDialog.execute(self, # parent
                               'Log File Progress', # title
                               600, # width, height
                               300) do |progress_dialog|
          progress_dialog.cancel_callback = method(:cancel_callback)
          progress_dialog.enable_cancel_button

          begin
            Cosmos.set_working_dir do
              File.open(@output_filename, 'w') do |output_file|
                process_files(output_file, include_raw, progress_dialog)
              end
            end
          ensure
            progress_dialog.complete
            Qt.execute_in_main_thread(true) do
              @open_button.setEnabled(true)
            end
          end
        end
      rescue => error
        Qt::MessageBox.critical(self, 'Error!', "Error Processing Log File(s)\n#{error.formatted}")
      end
    end # def process_log_files

    def open_button
      Cosmos.open_in_text_editor(@output_filename)
    end

    ###############################################################################
    # Helper Methods
    ###############################################################################

    def process_files(output_file, include_raw, progress_dialog)
      log_file_count = 1
      @input_filenames.each do |log_file|
        break if @cancel
        begin
          Cosmos.check_log_configuration(@packet_log_reader, log_file)
          file_size = File.size(log_file).to_f
          progress_dialog.append_text("Processing File #{log_file_count}/#{@input_filenames.length}: #{log_file}")
          progress_dialog.set_step_progress(0.0)
          output_file.puts '-' * (log_file.length * 1.4).to_i
          output_file.puts log_file
          output_file.puts '-' * (log_file.length * 1.4).to_i
          output_file.puts
          @packet_log_reader.each(
            log_file, # log filename
            true,     # identify and define packet
            @time_start,
            @time_end) do |packet|

            break if @cancel
            progress_dialog.set_step_progress(@packet_log_reader.bytes_read / file_size)
            if packet.received_time
              output_file.puts "#{packet.target_name} #{packet.packet_name}"
              output_file.puts "  RECEIVED_TIMEFORMATTED: #{packet.received_time.formatted}"
            end
            output_file.puts packet.formatted(:WITH_UNITS, 2)
            if include_raw or !packet.identified? or !packet.defined?
              output_file.puts "  RAW PACKET DATA (#{packet.length} bytes):"
              output_file.puts packet.buffer.formatted(1, 16, ' ', 4)
            end
            output_file.puts
          end
          progress_dialog.set_step_progress(1.0) if !@cancel
          progress_dialog.set_overall_progress(log_file_count.to_f / @input_filenames.length.to_f) if !@cancel
        rescue Exception => error
          progress_dialog.append_text("Error processing: #{error.formatted}\n")
        end
        log_file_count += 1
      end
    end

    ###############################################################################
    # Helper Methods
    ###############################################################################

    def pre_process_tests
      unless @input_filenames and @input_filenames[0]
        Qt::MessageBox.critical(self, 'Error', 'Please select at least 1 input file')
        return false
      end

      unless @output_filename
        Qt::MessageBox.critical(self, 'Error', 'No Output File Selected')
        return false
      end

      if File.exist?(@output_filename)
        result = Qt::MessageBox.warning(self, 'Warning!', 'Output File Already Exists. Overwrite?', Qt::MessageBox::Yes | Qt::MessageBox::No)
        return false if result == Qt::MessageBox::No
      end

      true
    end

    ###############################################################################
    # Additional Callbacks
    ###############################################################################

    def cancel_callback(progress_dialog = nil)
      @cancel = true
      return true, false
    end

    def change_callback(item_changed)
      if item_changed == :INPUT_FILES
        filename = @packet_log_frame.filenames[0]
        if filename
          extension = File.extname(filename)
          filename_no_extension = filename[0..-(extension.length + 1)]
          filename = filename_no_extension << '.txt'
          @packet_log_frame.output_filename = filename
        end
      end
    end

  end # class CmdExtractor

end # module Cosmos
