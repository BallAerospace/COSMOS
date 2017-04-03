# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the CalendarDialog class.   This class
# provides a dialog box to select a date/time.

require 'cosmos'

module Cosmos
  # Creates a dialog with a date and optional time selection
  class CalendarDialog < Qt::Dialog
    # @return [Time] User entered time
    attr_reader :time

    # @param parent [Qt::Widget] Parent of this dialog
    # @param title [String] Dialog title
    # @param initial_time [Time] Initial time to display
    # @param show_time [Boolean] Whether to display the time selection
    def initialize(parent, title, initial_time = nil, show_time = true)
      super(parent)
      setWindowTitle(title)

      @layout = Qt::VBoxLayout.new

      if initial_time
        @time = initial_time
      else
        time_now = Time.now
        @time = Time.local(time_now.year, time_now.mon, time_now.day)
      end
      @show_time = show_time

      @calendar = Qt::CalendarWidget.new
      @date = Qt::Date.new(@time.year, @time.mon, @time.day)
      @calendar.setSelectedDate(@date)
      @calendar.setVerticalHeaderFormat(Qt::CalendarWidget::NoVerticalHeader)
      @calendar.connect(SIGNAL('selectionChanged()')) { handle_calendar_select() }
      @layout.addWidget(@calendar)

      @date_layout = Qt::HBoxLayout.new
      @date_label = Qt::Label.new('Date:')
      @date_layout.addWidget(@date_label)
      @date_layout.addStretch
      @year_month_day = Qt::Label.new(sprintf("%04u/%02u/%02u", @time.year, @time.mon, @time.day))
      @date_layout.addWidget(@year_month_day)
      @layout.addLayout(@date_layout)

      if @show_time
        @time_layout = Qt::HBoxLayout.new
        @time_label = Qt::Label.new('Time:')
        @time_layout.addWidget(@time_label)
        @time_layout.addStretch
        @hour = Qt::LineEdit.new(sprintf("%02u", @time.hour))
        @hour.setMaximumWidth(20)
        @time_layout.addWidget(@hour)
        @colon_label = Qt::Label.new(':')
        @time_layout.addWidget(@colon_label)
        @minute = Qt::LineEdit.new(sprintf("%02u", @time.min))
        @minute.setMaximumWidth(20)
        @time_layout.addWidget(@minute)
        @colon_label2 = Qt::Label.new(':')
        @time_layout.addWidget(@colon_label2)
        @second = Qt::LineEdit.new(sprintf("%02u", @time.sec))
        @second.setMaximumWidth(20)
        @time_layout.addWidget(@second)
        @period_label = Qt::Label.new('.')
        @time_layout.addWidget(@period_label)
        @microsecond = Qt::LineEdit.new(sprintf("%06u", @time.tv_usec))
        @microsecond.setMaximumWidth(45)
        @time_layout.addWidget(@microsecond)
        @layout.addLayout(@time_layout)
      end

      # Create OK and Cancel buttons
      @button_layout = Qt::HBoxLayout.new
      @ok_button = Qt::PushButton.new('OK')
      @ok_button.connect(SIGNAL('clicked()')) { handle_ok_button() }
      @button_layout.addWidget(@ok_button)
      @cancel_button = Qt::PushButton.new('Cancel')
      @cancel_button.connect(SIGNAL('clicked()')) { self.reject }
      @button_layout.addWidget(@cancel_button)
      @layout.addLayout(@button_layout)

      setLayout(@layout)
    end

    protected

    # Handler for the OK button being pressed - builds the time object
    def handle_ok_button
      @date = @calendar.selectedDate

      # Reduce @time to time at midnight of day
      if @time.utc?
        @time = Time.utc(@date.year, @date.month, @date.day)
      else
        @time = Time.local(@date.year, @date.month, @date.day)
      end

      if @show_time
        hour        = @hour.text.to_i
        hour        = 0 if hour < 0
        hour        = 23 if hour > 23
        minute      = @minute.text.to_i
        minute      = 0 if minute < 0
        minute      = 59 if minute > 59
        second      = @second.text.to_i
        second      = 0 if second < 0
        second      = 59 if second > 59
        microsecond = @microsecond.text.to_i
        microsecond = 0 if microsecond < 0
        microsecond = 999999 if microsecond > 999999
        @time += Time.utc(1970, 1, 1, hour, minute, second, microsecond).to_f
      end

      self.accept
    end

    # Handles a date being selected and updates the displayed date
    def handle_calendar_select
      @date = @calendar.selectedDate
      @year_month_day.setText(sprintf("%04u/%02u/%02u", @date.year, @date.month, @date.day))
    end
  end
end
