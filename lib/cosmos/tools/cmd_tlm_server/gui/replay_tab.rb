# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/choosers/string_chooser'
require 'cosmos/gui/dialogs/packet_log_dialog'
require 'cosmos/gui/dialogs/progress_dialog'

module Cosmos
  # Implements the replay tab in the Command and Telemetry Server GUI
  class ReplayTab
    attr_accessor :widget

    def initialize(tab_widget)
      @widget = nil
      @update_slider = true
      @file_max_index = 0
      reset()
      @scroll = Qt::ScrollArea.new
      tab_widget.addTab(@scroll, "Replay")
    end

    def reset
      CmdTlmServer.replay_backend.reset if CmdTlmServer.instance
      Qt.execute_in_main_thread(true) do
        @widget.destroy if @widget
        @widget = nil
      end
    end

    # Create the targets tab and add it to the tab_widget
    def populate
      return if @widget

      @widget = Qt::Widget.new

      layout = Qt::VBoxLayout.new(@widget)
      # Since the layout will be inside a scroll area make sure it respects the sizes we set
      layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)

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
      @op = Qt::GroupBox.new("Playback Control")
      @op_layout = Qt::VBoxLayout.new(@op)
      @op_button_layout = Qt::HBoxLayout.new
      @move_start = Qt::PushButton.new(Cosmos.get_icon('skip_to_start-26.png'), '')
      @move_start.connect(SIGNAL('clicked()')) { CmdTlmServer.replay_backend.move_start() }
      @op_button_layout.addWidget(@move_start)
      @step_back = Qt::PushButton.new(Cosmos.get_icon('rewind-26.png'), '')
      @step_back_timer = Qt::Timer.new
      @step_back_timeout = 100
      @step_back_timer.connect(SIGNAL('timeout()')) { CmdTlmServer.replay_backend.step_back(); @step_back_timeout = (@step_back_timeout / 2).to_i; @step_back_timer.start(@step_back_timeout) }
      @step_back.connect(SIGNAL('pressed()')) { CmdTlmServer.replay_backend.step_back(); @step_back_timeout = 300; @step_back_timer.start(@step_back_timeout) }
      @step_back.connect(SIGNAL('released()')) { @step_back_timer.stop }
      @op_button_layout.addWidget(@step_back)
      @reverse_play = Qt::PushButton.new(Cosmos.get_icon('reverse-play-26.png'), '')
      @reverse_play.connect(SIGNAL('clicked()')) { CmdTlmServer.replay_backend.reverse_play() }
      @op_button_layout.addWidget(@reverse_play)
      @stop = Qt::PushButton.new(Cosmos.get_icon('stop-26.png'), '')
      @stop.connect(SIGNAL('clicked()')) { CmdTlmServer.replay_backend.stop() }
      @op_button_layout.addWidget(@stop)
      @play = Qt::PushButton.new(Cosmos.get_icon('play-26.png'), '')
      @play.connect(SIGNAL('clicked()')) { CmdTlmServer.replay_backend.play() }
      @op_button_layout.addWidget(@play)
      @step_forward = Qt::PushButton.new(Cosmos.get_icon('fast_forward-26.png'), '')
      @step_forward_timer = Qt::Timer.new
      @step_forward_timeout = 100
      @step_forward_timer.connect(SIGNAL('timeout()')) { CmdTlmServer.replay_backend.step_forward(); @step_forward_timeout = (@step_forward_timeout / 2).to_i; @step_forward_timer.start(@step_forward_timeout) }
      @step_forward.connect(SIGNAL('pressed()')) { CmdTlmServer.replay_backend.step_forward(); @step_forward_timeout = 300; @step_forward_timer.start(@step_forward_timeout) }
      @step_forward.connect(SIGNAL('released()')) { @step_forward_timer.stop }
      @op_button_layout.addWidget(@step_forward)
      @move_end = Qt::PushButton.new(Cosmos.get_icon('end-26.png'), '')
      @move_end.connect(SIGNAL('clicked()')) { CmdTlmServer.replay_backend.move_end() }
      @op_button_layout.addWidget(@move_end)
      @op_layout.addLayout(@op_button_layout)

      # Speed Selection
      @playback_delay = nil
      @speed_select = Qt::ComboBox.new
      @variants = []
      @variants << [Qt::Variant.new(0.0), 0.0]
      @speed_select.addItem("No Delay", @variants[-1][0])
      @variants << [Qt::Variant.new(0.001), 0.001]
      @speed_select.addItem("1ms Delay", @variants[-1][0])
      @variants << [Qt::Variant.new(0.002), 0.002]
      @speed_select.addItem("2ms Delay", @variants[-1][0])
      @variants << [Qt::Variant.new(0.005), 0.005]
      @speed_select.addItem("5ms Delay", @variants[-1][0])
      @variants << [Qt::Variant.new(0.01), 0.01]
      @speed_select.addItem("10ms Delay", @variants[-1][0])
      @variants << [Qt::Variant.new(0.05), 0.05]
      @speed_select.addItem("50ms Delay", @variants[-1][0])
      @variants << [Qt::Variant.new(0.125), 0.125]
      @speed_select.addItem("125ms Delay", @variants[-1][0])
      @variants << [Qt::Variant.new(0.25), 0.25]
      @speed_select.addItem("250ms Delay", @variants[-1][0])
      @variants << [Qt::Variant.new(0.5), 0.5]
      @speed_select.addItem("500ms Delay", @variants[-1][0])
      @variants << [Qt::Variant.new(1.0), 1.0]
      @speed_select.addItem("1s Delay", @variants[-1][0])
      @variants << [Qt::Variant.new(nil), nil]
      @speed_select.addItem("Realtime", @variants[-1][0])
      @speed_select.setMaxVisibleItems(11)
      @speed_select.connect(SIGNAL('currentIndexChanged(int)')) do
        CmdTlmServer.replay_backend.set_playback_delay(@speed_select.itemData(@speed_select.currentIndex).value)
      end
      @speed_layout = Qt::FormLayout.new()
      @speed_layout.addRow("&Delay:", @speed_select)
      @status = Qt::LineEdit.new
      @status.setReadOnly(true)
      @status.setText('Stopped')
      @speed_layout.addRow("&Status:", @status)
      @op_layout.addLayout(@speed_layout)
      @log_layout.addWidget(@op)

      @file_pos = Qt::GroupBox.new("File Position")
      @file_pos_layout = Qt::VBoxLayout.new(@file_pos)
      @slider = Qt::Slider.new(Qt::Horizontal)
      @slider.setRange(0, 10000)
      @slider.setTickInterval(1000)
      @slider.setTickPosition(Qt::Slider::TicksBothSides)
      @slider.setTracking(false)
      @slider.connect(SIGNAL('sliderPressed()')) { slider_pressed() }
      @slider.connect(SIGNAL('sliderReleased()')) { slider_released() }
      @time_layout = Qt::HBoxLayout.new()
      @start_time = StringChooser.new(@widget, 'Start:', '', 200, true, true, Qt::AlignCenter | Qt::AlignVCenter)
      @end_time = StringChooser.new(@widget, 'End:', '', 200, true, true, Qt::AlignCenter | Qt::AlignVCenter)
      @current_time = StringChooser.new(@widget, 'Current:', '', 200, true, true, Qt::AlignCenter | Qt::AlignVCenter)
      @time_layout.addWidget(@start_time)
      @time_layout.addWidget(@current_time)
      @time_layout.addWidget(@end_time)
      @file_pos_layout.addLayout(@time_layout)
      @file_pos_layout.addWidget(@slider)
      @log_layout.addWidget(@file_pos)
      layout.addWidget(@log_widget)

      @scroll.setWidget(@widget)
    end

    # Update the replay tab gui
    def update
      status, playback_delay, filename, file_start, file_current, file_end, file_index, @file_max_index = CmdTlmServer.replay_backend.status
      @status.setText(status)
      @log_name.text = filename
      found = false
      @variants.each_with_index do |data, index|
        value = data[1]
        if !playback_delay.nil? and !value.nil?
          if (playback_delay >= (value - 0.0001)) and (playback_delay <= (value + 0.0001))
            @speed_select.currentIndex = index
            found = true
            break
          end
        else
          if playback_delay == value
            @speed_select.currentIndex = index
            found = true
            break
          end
        end
      end
      unless found
        @variants << [Qt::Variant.new(playback_delay.to_f), playback_delay.to_f]
        @speed_select.addItem("#{(playback_delay.to_f * 1000.0).to_i}ms Delay", @variants[-1][0])
        @speed_select.currentIndex = @variants.length - 1
      end
      @start_time.value = file_start
      @current_time.value = file_current
      @end_time.value = file_end

      if @update_slider
        if @file_max_index != 0
          value = (((file_index - 1).to_f / @file_max_index.to_f) * 10000.0).to_i
        else
          value = 0
        end
        @slider.setSliderPosition(value)
        @slider.setValue(value)
      end
    end

    def slider_pressed
      @update_slider = false
      CmdTlmServer.replay_backend.stop
    end

    def slider_released
      CmdTlmServer.replay_backend.move_index(((@slider.sliderPosition / 10000.0) * (@file_max_index - 1)).to_i)
      @update_slider = true
    end

    def shutdown
      CmdTlmServer.replay_backend.shutdown
    end

    private

    def select_log_file
      packet_log_dialog = PacketLogDialog.new(
        @widget, 'Select Log File', CmdTlmServer.replay_backend.log_directory, CmdTlmServer.replay_backend.packet_log_reader,
        [], nil, false, false, true, Cosmos::TLM_FILE_PATTERN,
        Cosmos::BIN_FILE_PATTERN, false
      )
      case packet_log_dialog.exec
      when Qt::Dialog::Accepted
        CmdTlmServer.replay_backend.select_file(packet_log_dialog.filenames[0], packet_log_dialog.packet_log_reader)
      end
    end
  end
end
