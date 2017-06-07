# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the PacketLogDialog class.   This class
# provides a dialog box to process log files.

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/widgets/packet_log_frame'

module Cosmos
  # Creates a dialog to allow a user to browse for a COSMOS log and select the
  # time period to process.
  class PacketLogDialog < Qt::Dialog
    extend Forwardable
    def_delegators :@packet_log_frame, :filenames, :time_start, :time_start=,\
      :time_end, :time_end=, :packet_log_reader

    # @param parent (see PacketLogFrame#initialize)
    # @param title [String] Dialog title
    # @param log_directory (see PacketLogFrame#initialize)
    # @param packet_log_reader (see PacketLogFrame#initialize)
    # @param initial_filenames (see PacketLogFrame#initialize)
    # @param initial_output_filename (see PacketLogFrame#initialize)
    # @param show_output_filename (see PacketLogFrame#initialize)
    # @param show_time (see PacketLogFrame#initialize)
    # @param show_log_reader (see PacketLogFrame#initialize)
    # @param input_filename_filter (see PacketLogFrame#initialize)
    # @param output_filename_filter (see PacketLogFrame#initialize)
    def initialize(parent,
                   title,
                   log_directory,
                   packet_log_reader,
                   initial_filenames = [],
                   initial_output_filename = nil,
                   show_output_filename = false,
                   show_time = true,
                   show_log_reader = true,
                   input_filename_filter = Cosmos::BIN_FILE_PATTERN,
                   output_filename_filter = Cosmos::BIN_FILE_PATTERN)
      super(parent)
      setWindowTitle(title)

      @layout = Qt::VBoxLayout.new
      @packet_log_frame = PacketLogFrame.new(self,
                                             log_directory,
                                             packet_log_reader,
                                             initial_filenames,
                                             initial_output_filename,
                                             show_output_filename,
                                             show_time,
                                             show_log_reader,
                                             input_filename_filter,
                                             output_filename_filter)
      @packet_log_frame.change_callback = method(:change_callback)
      @layout.addWidget(@packet_log_frame)

      # Separator before buttons
      @sep1 = Qt::Frame.new(self)
      @sep1.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      @layout.addWidget(@sep1)

      # Create OK and Cancel buttons
      @button_layout = Qt::HBoxLayout.new
      @ok_button = Qt::PushButton.new('OK')
      @ok_button.connect(SIGNAL('clicked()')) { System.telemetry.reset; self.accept }
      @ok_button.setEnabled(false) if initial_filenames.empty?
      @button_layout.addWidget(@ok_button)
      @cancel_button = Qt::PushButton.new('Cancel')
      @cancel_button.connect(SIGNAL('clicked()')) { self.reject }
      @button_layout.addWidget(@cancel_button)

      @layout.addLayout(@button_layout)
      setLayout(@layout)
    end

    protected

    def change_callback(item_changed)
      if @packet_log_frame.filenames.empty?
        @ok_button.setEnabled(false)
      else
        @ok_button.setEnabled(true)
      end
    end
  end
end
