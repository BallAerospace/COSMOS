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
require 'cosmos/gui/dialogs/calendar_dialog'

module Cosmos
  # Widget which displays a button to browse for log files. Files are listed
  # and can be removed. Buttons exist to display start and stop time choosers
  # which apply to all files in the list. The widget can also show a button
  # which allows the user to change the Cosmos log file reader class.
  class PacketLogFrame < Qt::Widget
    # @return [Time] Start time of packets to process
    attr_reader :time_start
    # @return [Time] End time of packets to process
    attr_reader :time_end
    # @return [PacketLogReader] Log reader class to use
    attr_reader :packet_log_reader
    # @return [String] Output filename filter. Must conform to the syntax as
    #   described in the Qt::FileDialog class.
    attr_accessor :output_filename_filter
    # @return [#call] Callback called when something changes. Called with
    #   the item that was changed as a symbol. The possible values are
    #   :INPUT_FILES, :OUTPUT_FILE, :OUTPUT_DIR, :TIME_START, :TIME_END,
    #   :LOG_READER
    attr_accessor :change_callback

    # @param parent [Qt::Widget] Parent to this dialog
    # @param log_directory [String] Initial directory to display when browsing
    #   for log files
    # @param packet_log_reader [PacketLogReader] The COSMOS log reader class
    #   used to parse the log
    # @param initial_filenames [Array<String>] Array of filenames to
    #   pre-populate the dialog with
    # @param initial_output_filename [String] Initial output filename if
    #   show_output_filename is true
    # @param show_output_filename [Boolean] Whether to show the output filename
    #   and button to open a file chooser
    # @param show_time [Boolean] Whether to show the start and end time
    #   fields and buttons which popup a calendar browser
    # @param show_log_reader [Boolean] Whether to show the log reader class
    #   and button which popup a dialog to select a new log reader
    # @param input_filename_filter [String] File filter to apply when
    #   selecting input log files with the FileDialog
    # @param output_filename_filter [String] File filter to apply when
    #   selecting an output filename with the FileDialog
    # @param multiple_file_select [Boolean] Whether to allow multiple file
    #   selections when browsing for files
    def initialize(parent,
                   log_directory,
                   packet_log_reader,
                   initial_filenames = [],
                   initial_output_filename = nil,
                   show_output_filename = false,
                   show_time = true,
                   show_log_reader = true,
                   input_filename_filter = Cosmos::BIN_FILE_PATTERN,
                   output_filename_filter = Cosmos::BIN_FILE_PATTERN,
                   multiple_file_select = true)
      super(parent)

      @output_select = :FILE
      @input_filename_filter = input_filename_filter
      @output_filename_filter = output_filename_filter
      @multiple_file_select = multiple_file_select
      @log_directory = log_directory
      if initial_output_filename
        @output_directory = File.dirname(initial_output_filename)
      else
        @output_directory = log_directory.clone
      end
      @packet_log_reader = packet_log_reader
      @time_start = nil
      @time_end = nil
      @change_callback = nil

      @layout = Qt::GridLayout.new
      @layout.setContentsMargins(0,0,0,0)

      row = 0

      # Chooser for Log Files
      @log_files_label = Qt::Label.new('Log Files:')
      @layout.addWidget(@log_files_label, row, 0, 1, 2)
      @browse_button = Qt::PushButton.new('Browse...')
      @browse_button.connect(SIGNAL('clicked()')) { handle_browse_button() }
      @layout.addWidget(@browse_button, row, 2)
      @remove_button = Qt::PushButton.new('Remove')
      @remove_button.connect(SIGNAL('clicked()')) { handle_remove_button() }
      @layout.addWidget(@remove_button, row, 3)
      row += 1

      @filenames = Qt::ListWidget.new(self)
      @filenames.setSelectionMode(Qt::AbstractItemView::ExtendedSelection)
      @filenames.setSortingEnabled(true)
      delete = Qt::Shortcut.new(Qt::KeySequence.new(Qt::Key_Delete), @filenames)
      delete.connect(SIGNAL('activated()')) { handle_remove_button }
      backspace = Qt::Shortcut.new(Qt::KeySequence.new(Qt::Key_Backspace), @filenames)
      backspace.connect(SIGNAL('activated()')) { handle_remove_button }
      initial_filenames.each {|filename| @filenames.addItem(filename)}
      @filenames.setMinimumHeight(90)
      @layout.addWidget(@filenames, row, 0, 3, 4)
      row += 3

      if show_output_filename
        @output_filename_label = Qt::Label.new('Output File:')
        @layout.addWidget(@output_filename_label, row, 0)
        @output_filename = Qt::LineEdit.new(initial_output_filename.to_s)
        @output_filename.setMinimumWidth(340)
        @output_filename.setReadOnly(true)
        @layout.addWidget(@output_filename, row, 1, 1, 2)
        @output_filename_select_button = Qt::PushButton.new('Select')
        @output_filename_select_button.connect(SIGNAL('clicked()')) { handle_output_file_button() }
        @layout.addWidget(@output_filename_select_button, row, 3)
        row += 1
      end

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

      if show_log_reader
        @packet_log_reader = PacketLogReader.new unless @packet_log_reader

        # Chooser or label for log reader
        @packet_log_reader_label = Qt::Label.new('Packet Log Reader:')
        @layout.addWidget(@packet_log_reader_label, row, 0)
        @packet_log_reader_field = Qt::LineEdit.new(@packet_log_reader.class.to_s)
        @packet_log_reader_field.setMinimumWidth(340)
        @packet_log_reader_field.setReadOnly(true)
        @layout.addWidget(@packet_log_reader_field, row, 1, 1, 2)
        @plr_select_button = Qt::PushButton.new('Select')
        @plr_select_button.connect(SIGNAL('clicked()')) { handle_log_reader_button() }
        @layout.addWidget(@plr_select_button, row, 3)
        row += 1
      end

      setLayout(@layout)
    end

    # @return [Array<String>] The chosen filenames
    def filenames
      filename_array = []
      @filenames.each {|list_item| filename_array << list_item.text}
      filename_array
    end

    # @return [String] The output filename
    def output_filename
      @output_filename.text
    end

    # @param output_filename [String] Output filename to set
    def output_filename=(output_filename)
      @output_filename.setText(output_filename.to_s)
    end

    # Change the output selection to select a file (not a directory)
    def select_output_file
      @output_filename_label.text = 'Output File:'
      @output_select = :FILE
    end

    # Change the output selection to select a directory (not a file)
    def select_output_dir
      @output_filename_label.text = 'Output Dir:'
      @output_select = :DIR
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

    def show_log_fields(show_fields)
      if show_fields
        @filenames.show if @filenames
        @log_files_label.show if @log_files_label
        @browse_button.show if @browse_button
        @remove_button.show if @remove_button
        @packet_log_reader_field.show if @packet_log_reader_field
        @packet_log_reader_label.show if @packet_log_reader_label
        @plr_select_button.show if @plr_select_button
      else
        @filenames.hide if @filenames
        @log_files_label.hide if @log_files_label
        @browse_button.hide if @browse_button
        @remove_button.hide if @remove_button
        @packet_log_reader_field.hide if @packet_log_reader_field
        @packet_log_reader_label.hide if @packet_log_reader_label
        @plr_select_button.hide if @plr_select_button
      end
    end

    protected

    # Handles removing a selected filename
    def handle_remove_button
      @filenames.remove_selected_items
      @change_callback.call(:INPUT_FILES) if @change_callback
    end

    # Handles browsing for log files
    def handle_browse_button
      Cosmos.set_working_dir do
        if @multiple_file_select
          filenames = Qt::FileDialog::getOpenFileNames(
            self, "Select Log File(s):", @log_directory, @input_filename_filter)
          if filenames and not filenames.empty?
            @log_directory.replace(File.dirname(filenames[0]) + '/')
            filenames.each {|filename| @filenames.addItem(filename) if @filenames.findItems(filename, Qt::MatchExactly).empty? }
          end
        else
          filename = Qt::FileDialog::getOpenFileName(
            self, "Select Log File:", @log_directory, @input_filename_filter)
          if filename
            @log_directory.replace(File.dirname(filename) + '/')
            @filenames.addItem(filename)
          end
        end
        @change_callback.call(:INPUT_FILES) if @change_callback
      end
    end

    # Handles browsing for output file
    def handle_output_file_button
      Cosmos.set_working_dir do
        if @output_select == :FILE
          if @output_filename.text.strip != ''
            filename = Qt::FileDialog::getSaveFileName(
              self, "Select Output File:", @output_filename.text, @output_filename_filter)
          else
            filename = Qt::FileDialog::getSaveFileName(
              self, "Select Output File:", @output_directory, @output_filename_filter)
          end
          if filename and not filename.empty?
            @output_filename.setText(filename)
            @output_directory.replace(File.dirname(filename))
          end
          @change_callback.call(:OUTPUT_FILE) if @change_callback
        else
          if @output_filename.text.strip != ''
            filename = Qt::FileDialog::getExistingDirectory(
              self, "Select Output Dir:", @output_filename.text)
          else
            filename = Qt::FileDialog::getExistingDirectory(
              self, "Select Output File:", @output_directory)
          end
          if filename and not filename.empty?
            @output_filename.setText(filename)
            @output_directory.replace(File.dirname(filename))
          end
          @change_callback.call(:OUTPUT_DIR) if @change_callback
        end
      end
    end

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

    # Handles choosing a log reader
    def handle_log_reader_button
      Cosmos.set_working_dir do
        log_reader_class_name = @packet_log_reader.class.to_s
        log_reader_file_name = log_reader_class_name.class_name_to_filename
        filename = File.find_in_search_path(log_reader_file_name)
        if filename
          log_reader_directory = filename
        else
          log_reader_directory = File.join(Cosmos::USERPATH, 'lib')
          log_reader_directory << '/'
        end
        filename = Qt::FileDialog::getOpenFileName(self, "Select Packet Log Reader:", log_reader_directory, "Ruby File (*.rb);;All Files (*)")
        if filename and not filename.empty? and filename =~ /_log_reader\.rb/
          begin
            packet_log_reader_class = Cosmos.require_class(filename)
            @packet_log_reader = packet_log_reader_class.new
            @packet_log_reader_field.setText(@packet_log_reader.class.to_s)
          rescue Exception
            # No change
          end
        end
        @change_callback.call(:LOG_READER) if @change_callback
      end
    end
  end
end
