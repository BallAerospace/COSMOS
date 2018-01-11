# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the StreamPacketsDialog class.   This class
# provides a dialog box to configure packet streaming from DART

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/widgets/stream_packets_frame'

module Cosmos
  # Creates a dialog to allow a user to select the
  # time period to process.
  class StreamPacketsDialog < Qt::Dialog
    extend Forwardable
    def_delegators :@stream_packets_frame, :time_start, :time_start=, :time_end, :time_end=

    # @param parent (see PacketLogFrame#initialize)
    # @param title [String] Dialog title
    # @param show_time (see PacketLogFrame#initialize)
    def initialize(parent, title, show_time = true)
      super(parent)
      setWindowTitle(title)

      @layout = Qt::VBoxLayout.new
      @stream_packets_frame = StreamPacketsFrame.new(self, show_time)
      @stream_packets_frame.change_callback = method(:change_callback)
      @layout.addWidget(@stream_packets_frame)

      # Separator before buttons
      @sep1 = Qt::Frame.new(self)
      @sep1.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      @layout.addWidget(@sep1)

      # Create OK and Cancel buttons
      @button_layout = Qt::HBoxLayout.new
      @ok_button = Qt::PushButton.new('OK')
      @ok_button.connect(SIGNAL('clicked()')) { System.telemetry.reset; self.accept }
      @button_layout.addWidget(@ok_button)
      @cancel_button = Qt::PushButton.new('Cancel')
      @cancel_button.connect(SIGNAL('clicked()')) { self.reject }
      @button_layout.addWidget(@cancel_button)

      @layout.addLayout(@button_layout)
      setLayout(@layout)
    end

    protected

    def change_callback(item_changed)
    end
  end
end
