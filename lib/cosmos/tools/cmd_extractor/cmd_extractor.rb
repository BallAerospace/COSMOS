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
  require 'cosmos/gui/widgets/dart_meta_frame'
  require 'cosmos/gui/utilities/analyze_log'
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
      @packet_log_reader = System.default_packet_log_reader.new(*System.default_packet_log_reader_params)
      @time_start = nil
      @time_end = nil
      @interface = Cosmos::TcpipClientInterface.new(
        Cosmos::System.connect_hosts['DART_STREAM'],
        Cosmos::System.ports['DART_STREAM'],
        Cosmos::System.ports['DART_STREAM'],
        10, 30, 'PREIDENTIFIED')

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

      # File Menu Actions
      @analyze_log = Qt::Action.new('&Analyze Logs', self)
      @analyze_log.statusTip = 'Analyze log file packet counts'
      @analyze_log.connect(SIGNAL('triggered()')) { analyze_log_files() }

      # Mode Menu Actions
      @csv_output = Qt::Action.new('&CSV Output', self)
      @csv_output.statusTip = 'Output as CSV based on Packet Time'
      @csv_output.setCheckable(true)
      @csv_output.connect(SIGNAL('triggered()')) { change_callback(:INPUT_FILES) }

      @skip_ignored = Qt::Action.new('&Skip Ignored Items', self)
      @skip_ignored.statusTip = "Skip ignored items in the command when building output"
      @skip_ignored.setCheckable(true)

      @include_raw = Qt::Action.new('Include &Raw Data', self)
      @include_raw_keyseq = Qt::KeySequence.new('Ctrl+R')
      @include_raw.shortcut = @include_raw_keyseq
      @include_raw.statusTip = 'Include raw packet data in the text output'
      @include_raw.setCheckable(true)
    end

    # Create the File and Mode menus and initialize the Help menu
    def initialize_menus
      @file_menu = menuBar.addMenu('&File')
      @file_menu.addAction(@analyze_log)
      @file_menu.addSeparator()
      @file_menu.addAction(@exit_action)
      @mode_menu = menuBar.addMenu('&Mode')
      @mode_menu.addAction(@csv_output)
      @mode_menu.addAction(@skip_ignored)
      @mode_menu.addAction(@include_raw)
      @about_string = "Command Extractor extracts commands from a binary command log file into a human readable text file."
      initialize_help_menu()
    end

    # Create the CmdExtractor application which primarily consists of a
    # {PacketLogFrame}
    def initialize_central_widget
      @resize_timer = Qt::Timer.new
      @resize_timer.connect(SIGNAL('timeout()')) { self.resize(self.width, self.minimumHeight) }

      @central_widget = Qt::Widget.new
      setCentralWidget(@central_widget)
      @top_layout = Qt::VBoxLayout.new(@central_widget)

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
      @packet_log_frame = PacketLogFrame.new(self, @log_dir, System.default_packet_log_reader.new(*System.default_packet_log_reader_params), @input_filenames, @output_filename, true, true, true, Cosmos::CMD_FILE_PATTERN, Cosmos::TXT_FILE_PATTERN)
      @packet_log_frame.change_callback = method(:change_callback)
      @top_layout.addWidget(@packet_log_frame)

      @dart_meta_frame = DartMetaFrame.new(self)
      @dart_meta_frame.hide
      @top_layout.addWidget(@dart_meta_frame)

      # Separator before buttons
      @sep2 = Qt::Frame.new(@central_widget)
      @sep2.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      @top_layout.addWidget(@sep2)

      # Process and Open Buttons
      @button_layout = Qt::HBoxLayout.new
      @process_button = Qt::PushButton.new('&Process Data')
      @process_button.connect(SIGNAL('clicked()')) { process_data() }
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

    def analyze_log_files
      AnalyzeLog.execute(self, @packet_log_frame)
    end

    def process_data
      @cancel = false
      @time_start = @packet_log_frame.time_start
      @time_end = @packet_log_frame.time_end
      @packet_log_reader = @packet_log_frame.packet_log_reader
      @input_filenames = @packet_log_frame.filenames.sort
      @output_filename = @packet_log_frame.output_filename
      @output_filename = nil if @output_filename.strip.empty?
      @meta_filters = @dart_meta_frame.meta_filters

      return unless pre_process_tests()
      csv_output = @csv_output.isChecked
      skip_ignored = @skip_ignored.isChecked
      include_raw = @include_raw.isChecked

      if @log_file_radio.isChecked
        begin
          ProgressDialog.execute(self, # parent
                                'Log File Progress', # title
                                600, # width, height
                                300) do |progress_dialog|
            progress_dialog.cancel_callback = method(:cancel_callback)
            progress_dialog.enable_cancel_button

            begin
              Cosmos.set_working_dir do
                File.open(@output_filename, 'w') do |output_file|
                  process_files(output_file, progress_dialog, csv_output, skip_ignored, include_raw)
                end
              end
            ensure
              progress_dialog.complete
              Qt.execute_in_main_thread(true) do
                @open_button.setEnabled(true)
                @open_excel_button.setEnabled(true) if Kernel.is_windows?
              end
            end
          end
        rescue => error
          Qt::MessageBox.critical(self, 'Error!', "Error Processing Log File(s)\n#{error.formatted}")
        end
      else
        begin
          ProgressDialog.execute(self, # parent
                                'Log File Progress', # title
                                600, # width, height
                                300,
                                true, # Overall progress, no step progress
                                false) do |progress_dialog|
            progress_dialog.cancel_callback = method(:cancel_callback)
            progress_dialog.enable_cancel_button

            begin
              Cosmos.set_working_dir do
                File.open(@output_filename, 'w') do |output_file|

                  @interface.disconnect
                  request_packet = Cosmos::Packet.new('DART', 'DART')
                  request_packet.define_item('REQUEST', 0, 0, :BLOCK)

                  @time_start ||= Time.utc(1970, 1, 1)
                  @time_end ||= Time.now
                  @time_delta = @time_end - @time_start
                  request = {}
                  request['start_time_sec'] = @time_start.tv_sec
                  request['start_time_usec'] = @time_start.tv_usec
                  request['end_time_sec'] = @time_end.tv_sec
                  request['end_time_usec'] = @time_end.tv_usec
                  request['cmd_tlm'] = 'CMD'
                  request['meta_filters'] = @meta_filters unless @meta_filters.empty?
                  request_packet.write('REQUEST', JSON.dump(request))

                  progress_dialog.append_text("Connecting to DART Database...")
                  @interface.connect
                  progress_dialog.append_text("Sending DART Database Query...")
                  @interface.write(request_packet)
                  progress_dialog.append_text("Receiving Packets...")

                  write_output_file_DART_header(output_file, request, csv_output)

                  first = true
                  while true
                    break if @cancel
                    packet = @interface.read
                    unless packet
                      progress_dialog.append_text("Done!")
                      progress_dialog.set_overall_progress(1.0)
                      @interface.disconnect
                      break
                    end

                    # Switch to correct configuration from SYSTEM META when needed
                    if packet.target_name == 'SYSTEM'.freeze and packet.packet_name == 'META'.freeze
                      meta_packet = System.commands.packet('SYSTEM', 'META')
                      meta_packet.buffer = packet.buffer
                      Cosmos::System.load_configuration(meta_packet.read('CONFIG'))
                    elsif first
                      first = false
                      @time_start = packet.packet_time
                      @time_delta = @time_end - @time_start
                    end

                    defined_packet = System.commands.packet(packet.target_name, packet.packet_name)
                    defined_packet.buffer = packet.buffer
                    defined_packet.received_time = packet.received_time
                    write_output_file_packet(output_file, defined_packet, csv_output, skip_ignored, include_raw)
                    progress = ((@time_delta - (@time_end - defined_packet.packet_time)).to_f / @time_delta.to_f)
                    progress_dialog.set_overall_progress(progress) if !@cancel
                  end

                end
              end

            ensure
              progress_dialog.append_text("Canceled!") if @cancel
              progress_dialog.complete
              Qt.execute_in_main_thread(true) do
                @open_button.setEnabled(true)
                @open_excel_button.setEnabled(true) if Kernel.is_windows?
              end
            end
          end
        rescue => error
          Qt::MessageBox.critical(self, 'Error!', "Error Querying DART Database\n#{error.formatted}")
        ensure
          @interface.disconnect
        end
      end
    end # def process_data

    def open_button
      Cosmos.open_in_text_editor(@output_filename)
    end

    def open_excel_button
      system("start Excel.exe \"#{@output_filename}\"")
    end

    ###############################################################################
    # Helper Methods
    ###############################################################################

    def process_files(output_file, progress_dialog, csv_output, skip_ignored, include_raw)
      log_file_count = 1
      @input_filenames.each do |log_file|
        break if @cancel
        begin
          Cosmos.check_log_configuration(@packet_log_reader, log_file)
          file_size = File.size(log_file).to_f
          progress_dialog.append_text("Processing File #{log_file_count}/#{@input_filenames.length}: #{log_file}")
          progress_dialog.set_step_progress(0.0)
          write_output_file_header(output_file, log_file, csv_output)
          @packet_log_reader.each(
            log_file, # log filename
            true,     # identify and define packet
            @time_start,
            @time_end) do |packet|

            break if @cancel
            progress_dialog.set_step_progress(@packet_log_reader.bytes_read / file_size)
            write_output_file_packet(output_file, packet, csv_output, skip_ignored, include_raw)
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

    def write_output_file_header(output_file, log_file, csv_output)
      if csv_output
        output_file.puts "Filename,#{log_file}"
        output_file.puts "PACKET_TIMEFORMATTED,Target,Packet,Parameters"
      else
        output_file.puts '-' * (log_file.length * 1.4).to_i
        output_file.puts log_file
        output_file.puts '-' * (log_file.length * 1.4).to_i
        output_file.puts
      end
    end

    def write_output_file_DART_header(output_file, request, csv_output)
      if csv_output
        output_file.puts "DART Request"
        output_file.puts "start secs,#{request['start_time_sec']},start usec,#{request['start_time_usec']}"
        output_file.puts "end secs,#{request['end_time_sec']},end usec,#{request['end_time_usec']}"
        output_file.puts "meta_filter,#{request['meta_filters']}" unless @meta_filters.empty?
      else
        output_file.puts "DART Request"
        output_file.puts "start secs:#{request['start_time_sec']} start usec:#{request['start_time_usec']}"
        output_file.puts "end secs:#{request['end_time_sec']} end usec:#{request['end_time_usec']}"
        output_file.puts "meta_filter:#{request['meta_filters']}" unless @meta_filters.empty?
      end
    end

    def write_output_file_packet(output_file, packet, csv_output, skip_ignored, include_raw)
      if csv_output
        items_string = ""
        packet.read_all.each do |name, value|
          next if skip_ignored && System.targets[packet.target_name].ignored_items.include?(name)
          items_string << "#{name},#{value},"
        end
        output_file.puts "#{packet.packet_time.formatted},#{packet.target_name},#{packet.packet_name},#{items_string}"
        output_file.puts "#{packet.buffer.formatted}" if include_raw
      else
        output_file.puts "#{packet.target_name} #{packet.packet_name}"
        if packet.received_time
          output_file.puts "  PACKET_TIMEFORMATTED: #{packet.packet_time.formatted}"
          output_file.puts "  RECEIVED_TIMEFORMATTED: #{packet.received_time.formatted}"
        end
        ignored = skip_ignored ? System.targets[packet.target_name].ignored_items : nil
        output_file.puts packet.formatted(:WITH_UNITS, 2, packet.buffer, ignored)
        if include_raw or !packet.identified? or !packet.defined?
          output_file.puts "  RAW PACKET DATA (#{packet.length} bytes):"
          output_file.puts packet.buffer.formatted(1, 16, ' ', 4)
        end
        output_file.puts
      end
    end

    def pre_process_tests
      if @log_file_radio.isChecked
        unless @input_filenames and @input_filenames[0]
          Qt::MessageBox.critical(self, 'Error', 'Please select at least 1 input file')
          return false
        end
      end

      unless @output_filename
        if @log_file_radio.isChecked
          Qt::MessageBox.critical(self, 'Error', 'No Output File Selected')
          return false
        else
          @packet_log_frame.output_filename = File.join(System.paths['LOGS'], File.build_timestamped_filename(['cmd_extractor', 'dart'], get_output_file_extension()))
          @output_filename = @packet_log_frame.output_filename
        end
      end

      if File.exist?(@output_filename)
        result = Qt::MessageBox.warning(self, 'Warning!', 'Output File Already Exists. Overwrite?', Qt::MessageBox::Yes | Qt::MessageBox::No)
        return false if result == Qt::MessageBox::No
      end

      true
    end

    def get_output_file_extension
      @csv_output.isChecked ? '.csv' : '.txt'
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
          @packet_log_frame.output_filename = "#{filename_no_extension}#{get_output_file_extension}"
        end
      end
    end

  end
end
