# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the TlmRawDialog class.   This class
# is used to view a raw telemetry packet.

require 'cosmos'
require 'cosmos/gui/qt'

module Cosmos
  # Creates a dialog showing a packet formatted as a binary hex dump
  class RawDialog < Qt::Dialog
    slots 'packet_update_timeout()'

    # Constant to indicate a command packet dump
    CMD_TYPE = 'cmd'
    # Constant to indicate a telemetry packet dump
    TLM_TYPE = 'tlm'
    # Dialog update period
    PACKET_UPDATE_PERIOD_MS = 1000
    # Header string to display over the dump
    HEADER = "Address   Data                                             Ascii\n"\
             "---------------------------------------------------------------------------\n"

    # @return [Qt::Font] Font to display the dialog dump (should be monospaced)
    @@font = nil

    # @param parent [Qt::Dialog] Parent for the dialog
    # @param type [String] Dialog type which must be 'cmd' or 'tlm'
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    def initialize(parent, type, target_name, packet_name)
      super(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      raise "RawDialog: Undefined type:#{type}" if (type != CMD_TYPE) && (type != TLM_TYPE)

      @type = type
      @done = false
      @target_name = target_name
      @packet_name = packet_name

      begin
        if @type == CMD_TYPE
          title = "Raw Command Packet: #{target_name} #{packet_name}"
        else
          title = "Raw Telemetry Packet: #{target_name} #{packet_name}"
        end
        setWindowTitle(title)

        @timer = Qt::Timer.new

        overall_layout = Qt::VBoxLayout.new
        top_layout = Qt::HBoxLayout.new
        text_layout = Qt::VBoxLayout.new

        title_label = Qt::Label.new(tr(title))
        text_layout.addWidget(title_label)
        @packet_time = Qt::Label.new("Packet Time: ")
        text_layout.addWidget(@packet_time)
        @received_time = Qt::Label.new("Received Time: ")
        text_layout.addWidget(@received_time)
        top_layout.addLayout(text_layout)
        top_layout.addStretch(1)

        button = Qt::PushButton.new(tr("Pause"))
        top_layout.addWidget(button)
        button.connect(SIGNAL('clicked()')) do
          if button.text == "Pause"
            button.setText("Resume")
            @timer.method_missing(:stop)
          else
            button.setText("Pause")
            @timer.method_missing(:start, PACKET_UPDATE_PERIOD_MS)
          end
        end
        overall_layout.addLayout(top_layout)

        @packet_data = Qt::PlainTextEdit.new
        @packet_data.setReadOnly(true)
        @packet_data.setWordWrapMode(Qt::TextOption::NoWrap)
        overall_layout.addWidget(@packet_data)
        if Kernel.is_windows?
          @@font = Cosmos.getFont('Courier', 10) unless @@font
        else
          @@font = Cosmos.getFont('Courier', 14) unless @@font
        end
        @format = @packet_data.currentCharFormat()
        @format.setFont(@@font)
        @packet_data.setCurrentCharFormat(@format)

        connect(@timer, SIGNAL('timeout()'), self, SLOT('packet_update_timeout()'))
        @timer.method_missing(:start, PACKET_UPDATE_PERIOD_MS)
        packet_update_timeout()

        self.setLayout(overall_layout)
        self.resize(700, 280)
        self.show
        self.raise
      rescue DRb::DRbConnError
        # Just do nothing
      end
    end

    # Callback to get the latest packet and update the dialog
    def packet_update_timeout
      if (@type == CMD_TYPE)
        packet = System.commands.packet(@target_name, @packet_name)
      else
        packet = System.telemetry.packet(@target_name, @packet_name)
      end
      packet_data = packet.buffer
      packet_time = packet.packet_time
      @packet_time.setText("Packet Time: #{packet_time.formatted}") if packet_time
      received_time = packet.received_time
      @received_time.setText("Received Time: #{received_time.formatted}") if received_time
      position_x = @packet_data.horizontalScrollBar.value
      position_y = @packet_data.verticalScrollBar.value
      @packet_data.setPlainText(HEADER + packet_data.formatted)
      @packet_data.horizontalScrollBar.setValue(position_x)
      @packet_data.verticalScrollBar.setValue(position_y)
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

  # Creates a dialog which displays a command packet as a hex dump
  class CmdRawDialog < RawDialog
    # @param parent (see RawDialog#initialize)
    # @param target_name (see RawDialog#initialize)
    # @param packet_name (see RawDialog#initialize)
    def initialize(parent, target_name, packet_name)
      super(parent, RawDialog::CMD_TYPE, target_name, packet_name)
    end
  end

  # Creates a dialog which displays a telemetry packet as a hex dump
  class TlmRawDialog < RawDialog
    # @param parent (see RawDialog#initialize)
    # @param target_name (see RawDialog#initialize)
    # @param packet_name (see RawDialog#initialize)
    def initialize(parent, target_name, packet_name)
      super(parent, RawDialog::TLM_TYPE, target_name, packet_name)
    end
  end
end
