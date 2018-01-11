# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/dialogs/calendar_dialog'

module Cosmos
  # Widget which displays a button to configure packet stream from DART.
  # Buttons exist to display start and stop time choosers
  class StreamPacketsFrame < Qt::Widget
    # @return [Time] Start time of packets to process
    attr_reader :time_start
    # @return [Time] End time of packets to process
    attr_reader :time_end
    # @return [#call] Callback called when something changes. Called with
    #   the item that was changed as a symbol. The possible values are
    #   :TIME_START, :TIME_END
    attr_accessor :change_callback

    # @param parent [Qt::Widget] Parent to this dialog
    # @param show_time [Boolean] Whether to show the start and end time
    #   fields and buttons which popup a calendar browser
    def initialize(parent,
                   show_time = true)
      super(parent)

      @time_start = nil
      @time_end = nil
      @change_callback = nil

      @layout = Qt::GridLayout.new
      @layout.setContentsMargins(0,0,0,0)

      row = 0

      # Declare these regardless of if show_time is set so getters and setters work
      @time_start_field = Qt::LineEdit.new('N/A')
      @time_end_field = Qt::LineEdit.new('N/A')
      if show_time
        %w(Start End).each do |time|
          time_label = Qt::Label.new("Time Period #{time}:")
          @layout.addWidget(time_label, row, 0)
          if time == 'Start'
            time_field = @time_start_field
          else
            time_field = @time_end_field
          end
          time_field.setMinimumWidth(340)
          time_field.setReadOnly(true)
          @layout.addWidget(time_field, row, 1)
          time_clear_button = Qt::PushButton.new('Clear')
          time_clear_button.connect(SIGNAL('clicked()')) { handle_time_clear_button(time, time_field) }
          @layout.addWidget(time_clear_button, row, 2)
          time_button = Qt::PushButton.new('Select')
          time_button.connect(SIGNAL('clicked()')) { handle_time_select_button(time, time_field) }
          @layout.addWidget(time_button, row, 3)
          row += 1
        end
      end

      setLayout(@layout)
    end

    # @param time_start [Time] Start time
    def time_start=(time_start)
      @time_start = time_start
      if @time_start
        @time_start_field.setText(@time_start.formatted)
      else
        @time_start_field.setText('N/A')
      end
    end

    # @param time_end [Time] End time
    def time_end=(time_end)
      @time_end = time_end
      if @time_end
        @time_end_field.setText(@time_end.formatted)
      else
        @time_end_field.setText('N/A')
      end
    end

    protected

    # Handles choosing a time
    def handle_time_select_button(time_period, time_field)
      if time_period == 'Start'
        time = @time_start
        time = @time_end unless @time_start
      else
        time = @time_end
        time = @time_start unless @time_end
      end
      dialog = CalendarDialog.new(self, "Select Time Period #{time_period}:", time)
      case dialog.exec
      when Qt::Dialog::Accepted
        time_field.setText(dialog.time.formatted)
        if time_period == 'Start'
          @time_start = dialog.time
          @change_callback.call(:TIME_START) if @change_callback
        else
          @time_end = dialog.time
          @change_callback.call(:TIME_END) if @change_callback
        end
      end
    end

    # Clears the time
    def handle_time_clear_button(time_period, time_field)
      current_text = time_field.text
      time_field.setText('N/A')
      if time_period == 'Start'
        @time_start = nil
        @change_callback.call(:TIME_START) if @change_callback and current_text != 'N/A'
      else
        @time_end = nil
        @change_callback.call(:TIME_END) if @change_callback and current_text != 'N/A'
      end
    end

  end
end
