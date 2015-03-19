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
  require 'cosmos/tools/replay/replay_server'
  require 'cosmos/gui/choosers/string_chooser'
end

module Cosmos

  class Replay < QtTool
    # The number of bytes to print when an UNKNOWN packet is received
    UNKNOWN_BYTES_TO_PRINT = 36

    def initialize(options)
      # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      super(options)
      Cosmos.load_cosmos_icon("replay.png")

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()

      @ready = false
      Splash.execute(self) do |splash|
        ConfigParser.splash = splash
        splash.message = "Initializing Replay Server"

        # Start the thread that will process server messages and add them to the output text
        process_server_messages(options)

        ReplayServer.new(options.config_file, false, false, false)
        @ready = true

        ConfigParser.splash = nil
      end

      # Initialize variables
      @packet_log_reader  = System.default_packet_log_reader.new
      @log_directory = System.paths['LOGS']
      @log_directory << '/' unless @log_directory[-1..-1] == '\\' or @log_directory[-1..-1] == '/'
      @log_filename = nil
      @playing = false
      @playback_thread = nil
      @playback_index = 0
      @packet_offsets = []
    end

    def initialize_menus
      # File Menu
      @file_menu = menuBar.addMenu(tr('&File'))
      @file_menu.addAction(@exit_action)

      # Help Menu
      @about_string = "Telemetry Viewer provides a view of every telemetry packet in the system."
      @about_string << " Packets can be viewed in numerous represenations ranging from the raw data to formatted with units."

      initialize_help_menu()
    end

    def initialize_central_widget
      # Create the central widget
      @central_widget = Qt::Widget.new
      setCentralWidget(@central_widget)

      @top_layout = Qt::VBoxLayout.new

      @log_widget = Qt::Widget.new
      @log_widget.setSizePolicy(Qt::SizePolicy::MinimumExpanding, Qt::SizePolicy::MinimumExpanding)
      @log_layout = Qt::VBoxLayout.new()

      # This widget goes inside the top layout so we want 0 contents margins
      @log_layout.setContentsMargins(0,0,0,0)
      @log_widget.setLayout(@log_layout)

      # Create the log file GUI
      @log_file_selection = Qt::GroupBox.new("Log File Selection")
      @log_select = Qt::HBoxLayout.new(@log_file_selection)
      @log_name = Qt::LineEdit.new
      @log_name.setReadOnly(true)
      @log_select.addWidget(@log_name)
      @log_open = Qt::PushButton.new("Browse...")
      @log_select.addWidget(@log_open)
      @log_layout.addWidget(@log_file_selection)

      @log_open.connect(SIGNAL('clicked()')) { select_log_file() }

      # Create the operation buttons GUI
      @op = Qt::GroupBox.new(tr("Playback Control"))
      @op_layout = Qt::VBoxLayout.new(@op)
      @op_button_layout = Qt::HBoxLayout.new
      @move_start = Qt::PushButton.new(Cosmos.get_icon('skip_to_start-26.png'), '')
      @move_start.connect(SIGNAL('clicked()')) { move_start() }
      @op_button_layout.addWidget(@move_start)
      @step_back = Qt::PushButton.new(Cosmos.get_icon('rewind-26.png'), '')
      @step_back_timer = Qt::Timer.new
      @step_back_timeout = 100
      @step_back_timer.connect(SIGNAL('timeout()')) { step_back(); @step_back_timeout = (@step_back_timeout / 2).to_i; @step_back_timer.start(@step_back_timeout) }
      @step_back.connect(SIGNAL('pressed()')) { step_back(); @step_back_timeout = 300; @step_back_timer.start(@step_back_timeout) }
      @step_back.connect(SIGNAL('released()')) { @step_back_timer.stop }
      @op_button_layout.addWidget(@step_back)
      @reverse_play = Qt::PushButton.new(Cosmos.get_icon('reverse-play-26.png'), '')
      @reverse_play.connect(SIGNAL('clicked()')) { reverse_play() }
      @op_button_layout.addWidget(@reverse_play)
      @stop = Qt::PushButton.new(Cosmos.get_icon('stop-26.png'), '')
      @stop.connect(SIGNAL('clicked()')) { stop() }
      @op_button_layout.addWidget(@stop)
      @play = Qt::PushButton.new(Cosmos.get_icon('play-26.png'), '')
      @play.connect(SIGNAL('clicked()')) { play() }
      @op_button_layout.addWidget(@play)
      @step_forward = Qt::PushButton.new(Cosmos.get_icon('fast_forward-26.png'), '')
      @step_forward_timer = Qt::Timer.new
      @step_forward_timeout = 100
      @step_forward_timer.connect(SIGNAL('timeout()')) { step_forward(); @step_forward_timeout = (@step_forward_timeout / 2).to_i; @step_forward_timer.start(@step_forward_timeout) }
      @step_forward.connect(SIGNAL('pressed()')) { step_forward(); @step_forward_timeout = 300; @step_forward_timer.start(@step_forward_timeout) }
      @step_forward.connect(SIGNAL('released()')) { @step_forward_timer.stop }
      @op_button_layout.addWidget(@step_forward)
      @move_end = Qt::PushButton.new(Cosmos.get_icon('end-26.png'), '')
      @move_end.connect(SIGNAL('clicked()')) { move_end() }
      @op_button_layout.addWidget(@move_end)
      @op_layout.addLayout(@op_button_layout)

      # Speed Selection
      @playback_delay = nil
      @speed_select = Qt::ComboBox.new
      @variants = []
      @variants << Qt::Variant.new(nil)
      @speed_select.addItem("No Delay", @variants[-1])
      @variants << Qt::Variant.new(0.001)
      @speed_select.addItem("1ms Delay", @variants[-1])
      @variants << Qt::Variant.new(0.002)
      @speed_select.addItem("2ms Delay", @variants[-1])
      @variants << Qt::Variant.new(0.005)
      @speed_select.addItem("5ms Delay", @variants[-1])
      @variants << Qt::Variant.new(0.01)
      @speed_select.addItem("10ms Delay", @variants[-1])
      @variants << Qt::Variant.new(0.05)
      @speed_select.addItem("50ms Delay", @variants[-1])
      @variants << Qt::Variant.new(0.125)
      @speed_select.addItem("125ms Delay", @variants[-1])
      @variants << Qt::Variant.new(0.25)
      @speed_select.addItem("250ms Delay", @variants[-1])
      @variants << Qt::Variant.new(0.5)
      @speed_select.addItem("500ms Delay", @variants[-1])
      @variants << Qt::Variant.new(1.0)
      @speed_select.addItem("1s Delay", @variants[-1])
      @variants << Qt::Variant.new(-1.0)
      @speed_select.addItem("Realtime", @variants[-1])
      @speed_select.setMaxVisibleItems(11)
      @speed_select.connect(SIGNAL('currentIndexChanged(int)')) do
        @playback_delay = @speed_select.itemData(@speed_select.currentIndex).value
      end
      @speed_layout = Qt::FormLayout.new()
      @speed_layout.addRow("&Delay:", @speed_select)
      @status = Qt::LineEdit.new
      @status.setReadOnly(true)
      @status.setText('Stopped')
      @speed_layout.addRow("&Status:", @status)
      @op_layout.addLayout(@speed_layout)
      @log_layout.addWidget(@op)

      @file_pos = Qt::GroupBox.new(tr("File Position"))
      @file_pos_layout = Qt::VBoxLayout.new(@file_pos)
      @slider = Qt::Slider.new(Qt::Horizontal)
      @slider.setRange(0, 10000)
      @slider.setTickInterval(1000)
      @slider.setTickPosition(Qt::Slider::TicksBothSides)
      @slider.setTracking(false)
      @slider.connect(SIGNAL('sliderReleased()')) { slider_released() }
      @time_layout = Qt::HBoxLayout.new()
      @start_time = StringChooser.new(self, 'Start:', '', 200, true, true, Qt::AlignCenter | Qt::AlignVCenter)
      @end_time = StringChooser.new(self, 'End:', '', 200, true, true, Qt::AlignCenter | Qt::AlignVCenter)
      @current_time = StringChooser.new(self, 'Current:', '', 200, true, true, Qt::AlignCenter | Qt::AlignVCenter)
      @time_layout.addWidget(@start_time)
      @time_layout.addWidget(@current_time)
      @time_layout.addWidget(@end_time)
      @file_pos_layout.addLayout(@time_layout)
      @file_pos_layout.addWidget(@slider)
      @log_layout.addWidget(@file_pos)
      @top_layout.addWidget(@log_widget)

      # Add the message output
      @output = Qt::PlainTextEdit.new
      @output.setReadOnly(true)
      @output.setMaximumBlockCount(100)

      @top_layout.addWidget(@output, 500)

      # Override stdout to the message window
      # All code attempting to print into the GUI must use $stdout rather than STDOUT
      @string_output = StringIO.new("", "r+")
      $stdout = @string_output
      Logger.level = Logger::INFO

      @central_widget.setLayout(@top_layout)
    end

    def select_log_file
      unless @playback_thread
        selection = Qt::FileDialog.getOpenFileName(
          self, "Select Log File", @log_directory, Cosmos::TLM_FILE_PATTERN)
        if selection
          stop()
          @log_directory = File.dirname(selection)
          @log_name.text = selection
          @log_filename = selection

          System.telemetry.reset

          @cancel = false
          ProgressDialog.execute(self, 'Analyzing Log File', 500, 10, true, false, true, false, true) do |progress_dialog|
            progress_dialog.append_text("Processing File: #{selection}\n")
            progress_dialog.set_overall_progress(0.0)
            progress_dialog.cancel_callback = method(:cancel_callback)
            progress_dialog.enable_cancel_button
            @packet_offsets = @packet_log_reader.packet_offsets(selection, lambda {|percentage| progress_dialog.set_overall_progress(percentage); @cancel})
            @playback_index = 0
            update_slider_and_current_time(nil)
            @packet_log_reader.open(selection)
            progress_dialog.close_done
          end

          if ProgressDialog.canceled?
            @packet_log_reader.close
            @log_name.text = ''
            @log_filename = nil
            @packet_offsets = []
            @playback_index = 0
            @start_time.value = ''
            @current_time.value = ''
            @end_time.value = ''
          else
            move_end()
            move_start()
          end
        end
      end
    end

    def cancel_callback(progress_dialog = nil)
      @cancel = true
      return true, false
    end

    def move_start
      if @log_filename and !@playback_thread
        packet = read_at_index(0, :FORWARD)
        @start_time.value = packet.received_time.formatted if packet and packet.received_time
      else
        stop()
      end
    end

    def step_back
      if @log_filename and !@playback_thread
        @playback_index = @packet_offsets.length - 2 if @playback_index >= @packet_offsets.length
        read_at_index(@playback_index, :BACKWARD)
      else
        stop()
      end
    end

    def reverse_play
      if @log_filename and !@playback_thread
        @playback_index = @packet_offsets.length - 2 if @playback_index >= @packet_offsets.length
        start_playback(:BACKWARD)
      else
        stop()
      end
    end

    def stop
      @playing = false
    end

    def play
      if @log_filename and !@playback_thread
        @playback_index = 1 if @playback_index < 0
        start_playback(:FORWARD)
      else
        stop()
      end
    end

    def step_forward
      if @log_filename and !@playback_thread
        @playback_index = 1 if @playback_index < 0
        read_at_index(@playback_index, :FORWARD)
      else
        stop()
      end
    end

    def move_end
      if @log_filename and !@playback_thread
        packet = read_at_index(@packet_offsets.length - 1, :FORWARD)
        @end_time.value = packet.received_time.formatted if packet and packet.received_time
      else
        stop()
      end
    end

    def slider_released
      if @log_filename and !@playback_thread
        read_at_index(((@slider.sliderPosition / 10000.0) * (@packet_offsets.length - 1)).to_i, :FORWARD)
      end
    end

    def start_playback(direction)
      @playback_thread = Thread.new do
        error = nil
        begin
          @playing = true
          Qt.execute_in_main_thread(true) do
            @status.setText('Playing')
          end
          previous_packet = nil
          while (@playing)
            if @playback_delay
              packet_start = Time.now
              packet = read_at_index(@playback_index, direction)
              break unless packet
              delay_time = 0.0
              if @playback_delay > 0.0
                delay_time = @playback_delay - (Time.now - packet_start)
              elsif previous_packet and packet.received_time and previous_packet.received_time
                if direction == :FORWARD
                  delay_time = packet.received_time - previous_packet.received_time - (Time.now - packet_start)
                else
                  delay_time = previous_packet.received_time - packet.received_time - (Time.now - packet_start)
                end
              end
              sleep(delay_time) if delay_time > 0.0
              previous_packet = packet
            else
              packet = read_at_index(@playback_index, direction)
              break unless packet
            end
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(self, error, "Playback Thread")}
        ensure
          Qt.execute_in_main_thread(true) do
            @status.setText('Stopped')
          end
          @playing = false
          @playback_thread = nil
        end
      end
    end

    def read_at_index(index, direction)
      packet_offset = nil
      packet_offset = @packet_offsets[index] if index >= 0
      if packet_offset
        # Read the packet
        packet = @packet_log_reader.read_at_offset(packet_offset, false)
        handle_packet(packet)

        # Adjust index for next read
        if direction == :FORWARD
          @playback_index = index + 1
        else
          @playback_index = index - 1
        end
        update_slider_and_current_time(packet)

        return packet
      else
        return nil
      end
    end

    def update_slider_and_current_time(packet)
      Qt.execute_in_main_thread(false) do
        value = (((@playback_index - 1) / @packet_offsets.length.to_f) * 10000).to_i
        @slider.setSliderPosition(value)
        @slider.setValue(value)
        @current_time.value = packet.received_time.formatted if packet and packet.received_time
      end
    end

    def handle_packet(packet)
      interface = nil

      # Identify and update packet
      if packet.identified?
        # Preidentifed packet - place it into the current value table
        identified_packet = System.telemetry.update!(packet.target_name,
                                                     packet.packet_name,
                                                     packet.buffer)
      else
        # Packet needs to be identified
        identified_packet = System.telemetry.identify!(packet.buffer)
      end

      if identified_packet and packet.target_name != 'UNKNOWN'
        identified_packet.received_time = packet.received_time
        packet = identified_packet
        target = System.targets[packet.target_name.upcase]
        interface = target.interface if target
      else
        unknown_packet = System.telemetry.update!('UNKNOWN', 'UNKNOWN', packet.buffer)
        unknown_packet.received_time = packet.received_time
        packet = unknown_packet
        data_length = packet.length
        string = "Unknown #{data_length} byte packet starting: "
        num_bytes_to_print = [UNKNOWN_BYTES_TO_PRINT, data_length].min
        data_to_print = packet.buffer(false)[0..(num_bytes_to_print - 1)]
        data_to_print.each_byte do |byte|
          string << sprintf("%02X", byte)
        end
        time_string = ''
        time_string = packet.received_time.formatted << '  ' if packet.received_time
        puts "#{time_string}ERROR:  #{string}"
      end

      target = System.targets[packet.target_name]
      target.tlm_cnt += 1 if target
      packet.received_count += 1
      packet.check_limits(System.limits_set)
      ReplayServer.instance.post_packet(packet)

      # Write to routers
      if interface
        interface.routers.each do |router|
          begin
            router.write(packet) if router.write_allowed? and router.connected?
          rescue => err
            Logger.error "Problem writing to router #{router.name} - #{err.class}:#{err.message}"
          end
        end
      end
    end

    def process_server_messages(options)
      # Start thread to read server messages
      @output_thread = Thread.new do
        begin
          while !@ready
            sleep(1)
          end
          while true
            if @string_output.string[-1..-1] == "\n"
              Qt.execute_in_main_thread(true) do
                string = @string_output.string.clone
                @string_output.string = @string_output.string[string.length..-1]
                string.each_line {|out_line| @output.add_formatted_text(out_line) }
                @output.flush
              end
            end
            sleep(1)
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) do
            ExceptionDialog.new(self, error, "#{options.title}: Messages Thread")
          end
        end
      end
    end

    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.title = 'Replay'
          options.width = 800
          options.height = 500
          options.auto_size = false
          options.config_file = CmdTlmServer::DEFAULT_CONFIG_FILE
          option_parser.separator "Replay Specific Options:"
          option_parser.on("-c", "--config FILE", "Use the specified configuration file") do |arg|
            options.config_file = arg
          end
        end

        super(option_parser, options)
      end
    end

  end # class TlmViewer

end # module Cosmos
