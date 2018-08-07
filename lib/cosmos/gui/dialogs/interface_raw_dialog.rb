# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'

module Cosmos
  # Creates a dialog showing the most recent raw data read and written by an interface
  class InterfaceRawDialog < Qt::Dialog
    slots 'data_update_timeout()'

    # Dialog update period
    DATA_UPDATE_PERIOD_MS = 1000
    # Header string to display over the dump
    HEADER = "Address   Data                                             Ascii\n"\
             "---------------------------------------------------------------------------\n"

    # @return [Qt::Font] Font to display the dialog dump (should be monospaced)
    @@font = nil

    # @param parent [Qt::Dialog] Parent for the dialog
    # @param interface [Interface] Interface to get data from
    def initialize(parent, interface)
      super(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)

      @interface = interface
      @done = false

      begin
        title = "Interface #{@interface.name} Raw Data"
        setWindowTitle(title)

        @timer = Qt::Timer.new

        overall_layout = Qt::VBoxLayout.new
        top_layout = Qt::HBoxLayout.new
        text_layout = Qt::VBoxLayout.new

        title_label = Qt::Label.new(title)
        text_layout.addWidget(title_label)
        @read_raw_data_time = Qt::Label.new("Read Raw Data Time: ")
        text_layout.addWidget(@read_raw_data_time)
        top_layout.addLayout(text_layout)
        top_layout.addStretch(1)

        button = Qt::PushButton.new("Pause")
        top_layout.addWidget(button)
        button.connect(SIGNAL('clicked()')) do
          if button.text == "Pause"
            button.setText("Resume")
            @timer.method_missing(:stop)
          else
            button.setText("Pause")
            @timer.method_missing(:start, DATA_UPDATE_PERIOD_MS)
          end
        end
        overall_layout.addLayout(top_layout)

        @read_raw_data = Qt::PlainTextEdit.new
        @read_raw_data.setReadOnly(true)
        @read_raw_data.setWordWrapMode(Qt::TextOption::NoWrap)
        overall_layout.addWidget(@read_raw_data)
        if Kernel.is_windows?
          @@font = Cosmos.getFont('Courier', 10) unless @@font
        else
          @@font = Cosmos.getFont('Courier', 14) unless @@font
        end
        @read_format = @read_raw_data.currentCharFormat()
        @read_format.setFont(@@font)
        @read_raw_data.setCurrentCharFormat(@read_format)

        @written_raw_data_time = Qt::Label.new("Written Raw Data Time: ")
        overall_layout.addWidget(@written_raw_data_time)

        @written_raw_data = Qt::PlainTextEdit.new
        @written_raw_data.setReadOnly(true)
        @written_raw_data.setWordWrapMode(Qt::TextOption::NoWrap)
        overall_layout.addWidget(@written_raw_data)
        if Kernel.is_windows?
          @@font = Cosmos.getFont('Courier', 10) unless @@font
        else
          @@font = Cosmos.getFont('Courier', 14) unless @@font
        end
        @written_format = @written_raw_data.currentCharFormat()
        @written_format.setFont(@@font)
        @written_raw_data.setCurrentCharFormat(@written_format)

        connect(@timer, SIGNAL('timeout()'), self, SLOT('data_update_timeout()'))
        @timer.method_missing(:start, DATA_UPDATE_PERIOD_MS)
        data_update_timeout()

        self.setLayout(overall_layout)
        self.resize(700, 280)
        self.show
        self.raise
      rescue DRb::DRbConnError
        # Just do nothing
      end
    end

    # Callback to get the latest data and update the dialog
    def data_update_timeout
      @read_raw_data_time.setText("Read Raw Data Time: #{@interface.read_raw_data_time.formatted}") if @interface.read_raw_data_time
      position_x = @read_raw_data.horizontalScrollBar.value
      position_y = @read_raw_data.verticalScrollBar.value
      @read_raw_data.setPlainText(HEADER + @interface.read_raw_data.formatted)
      @read_raw_data.horizontalScrollBar.setValue(position_x)
      @read_raw_data.verticalScrollBar.setValue(position_y)

      @written_raw_data_time.setText("Written Raw Data Time: #{@interface.written_raw_data_time.formatted}") if @interface.written_raw_data_time
      position_x = @written_raw_data.horizontalScrollBar.value
      position_y = @written_raw_data.verticalScrollBar.value
      @written_raw_data.setPlainText(HEADER + @interface.written_raw_data.formatted)
      @written_raw_data.horizontalScrollBar.setValue(position_x)
      @written_raw_data.verticalScrollBar.setValue(position_y)
    end

    def reject
      super()
      stop_timer if @timer
      self.dispose
    end

    def closeEvent(event)
      super(event)
      stop_timer if @timer
      self.dispose
    end

    def stop_timer
      @timer.stop
      @timer.dispose
      @timer = nil
    end
  end
end
