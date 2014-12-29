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

  class PacketLogDialog < Qt::Dialog
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
      # Call base class constructor
      super(parent)
      setWindowTitle(title)

      @layout = Qt::VBoxLayout.new

      # Create log frame
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
    end # def initialize

    # Returns the chosen filenames
    def filenames
      @packet_log_frame.filenames
    end

    # Return the output filename
    def output_filename
      @packet_log_frame.output_filename
    end

    # Return Start time of packets to process
    def time_start
      @packet_log_frame.time_start
    end

    # Set the start time
    def time_start=(new_time_start)
      @packet_log_frame.time_start = new_time_start
    end

    # Return End time of packets to process
    def time_end
      @packet_log_frame.time_end
    end

    # Set the end time
    def time_end=(new_time_end)
      @packet_log_frame.time_end = new_time_end
    end

    # Return Log reader to use
    def packet_log_reader
      @packet_log_frame.packet_log_reader
    end

    protected

    def change_callback(item_changed)
      if @packet_log_frame.filenames.empty?
        @ok_button.setEnabled(false)
      else
        @ok_button.setEnabled(true)
      end
    end

  end # class PacketLogDialog

end # module Cosmos
