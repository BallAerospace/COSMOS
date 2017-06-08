# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation and ProgressDialog class.

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/dialogs/exception_dialog'

module Cosmos
  # Dialog which shows a progress bar. Optionally can display two progress
  # bars: one for overall progress and one for a sub-task. Can also optionally
  # display informational text.
  class ProgressDialog < Qt::Dialog
    # @return [#call] Called when the dialog is canceled. Passed the current
    #   instance of the ProgressDialog
    attr_accessor :cancel_callback
    # @return [Thread] Ruby thread associated with this dialog. If specified,
    #   it will automatically be killed if the dialog is canceled.
    attr_accessor :thread
    # Accessor to set the complete flag
    attr_writer :complete

    slots 'append_text(const QString&)'
    slots 'set_step_progress(int)'
    slots 'set_overall_progress(int)'

    # @param parent [Qt::Widget] Parent of this dialog
    # @param title [String] Dialog title
    # @param width [Integer] Dialog width
    # @param height [Integer] Dialog height
    # @param show_overall [Boolean] Whether to show the overall progress bar
    # @param show_step [Boolean] Whether to show the individual step progress
    #   bar
    # @param show_text [Boolean] Whether to show informational text along with
    #   the progress bar
    # @param show_done [Boolean] Whether to show a "Done" button which closes
    #   the dialog once the progress is complete
    # @param show_cancel [Boolean] Whether to show a "Cancel" button which
    #   cancels and closes the dialog
    def initialize(parent,
                   title,
                   width = 500,
                   height = 300,
                   show_overall = true,
                   show_step = true,
                   show_text = true,
                   show_done = true,
                   show_cancel = true)
      if show_cancel
        super(parent)
      else
        super(parent, Qt::CustomizeWindowHint | Qt::WindowTitleHint)
      end
      setWindowTitle(title)
      setMinimumWidth(width)
      setMinimumHeight(height)
      @overall_bar = nil
      @step_bar = nil
      @progress_text = nil
      @done_button = nil
      @cancel_button = nil
      @@canceled = false
      @complete = false

      @overall = Qt::HBoxLayout.new
      @overall_bar = nil
      if show_overall
        # Create Overall progress bar
        @overall_bar = Qt::ProgressBar.new
        @overall_bar.setMaximum(100)
        @overall_label = Qt::Label.new("Overall Progress: ")
        @overall.addWidget(@overall_label)
        @overall.addWidget(@overall_bar)
      end

      @step = Qt::HBoxLayout.new
      @step_bar = nil
      if show_step
        # Create Step progress bar
        @step_bar = Qt::ProgressBar.new
        @step_bar.setMaximum(100)
        @step_label = Qt::Label.new("Step Progress: ")
        @step.addWidget(@step_label)
        @step.addWidget(@step_bar)
      end

      @progress_text = nil
      if show_text
        # Create Progress Text Notifications
        @progress_text = Qt::PlainTextEdit.new
        @progress_text.setReadOnly(true)
        @progress_text.setMaximumBlockCount(100)
      end

      @button_layout = Qt::HBoxLayout.new
      @done_button = nil
      if show_done
        # Create Done Button
        @done_button = Qt::PushButton.new('Done')
        @done_button.connect(SIGNAL('clicked()')) { self.close_done }
        @done_button.setEnabled(false)
        @button_layout.addWidget(@done_button)
      end

      @cancel_button = nil
      if show_cancel
        # Create Cancel Button
        @cancel_button = Qt::PushButton.new('Cancel')
        @cancel_button.connect(SIGNAL('clicked()')) { self.close_cancel }
        @cancel_button.setEnabled(false)
        @button_layout.addWidget(@cancel_button)
      end

      @top_layout = Qt::VBoxLayout.new
      @top_layout.addLayout(@overall) if show_overall
      @top_layout.addLayout(@step) if show_step
      @top_layout.addWidget(@progress_text) if show_text
      @top_layout.addLayout(@button_layout) if show_done || show_cancel

      setLayout(@top_layout)

      @thread = nil
      @cancel_callback = nil
      @overall_progress = 0
      @step_progress = 0
    end

    # @return [Boolean] Whether this dialog was canceled
    def self.canceled?
      @@canceled
    end

    # @return [Boolean] Whether this dialog was canceled
    def canceled?
      @@canceled
    end

    # @return [Boolean] Whether this dialog successfully completed
    def complete?
      @complete
    end

    # Enable the cancel button if it was specified
    def enable_cancel_button
      Qt.execute_in_main_thread(true) do
        @cancel_button.setEnabled(true) if @cancel_button
      end
    end

    # Set complete to true and close the dialog
    def close_done
      Qt.execute_in_main_thread(true) do
        @complete = true
        self.done(0) unless self.disposed?
      end
    end

    # Call the cancel_callback if given to determine how to proceed. Set
    # canceled to true and kill any associated threads.
    def close_cancel
      Qt.execute_in_main_thread(true) do
        kill_thread = true
        if @cancel_callback
          continue_cancel, kill_thread = @cancel_callback.call(self)
          return unless continue_cancel
        end
        @@canceled = true
        Thread.new do
          if @thread
            Cosmos.kill_thread(self, @thread) if kill_thread
            @thread.join
          end
          @thread = nil

          close_done()
        end
      end
    end

    # Empty method to remove warning
    # @comment TODO: What warning? How does this manifest?
    def graceful_kill
    end

    # @param font [Font] Font to apply on the progress text
    def set_text_font(font)
      @progress_text.setFont(font)
    end

    # @param text [String] Text to append to the progress text
    def append_text(text)
      unless @complete
        Qt.execute_in_main_thread(false) do
          if @progress_text
            @progress_text.appendPlainText(text)
            @progress_text.ensureCursorVisible
          end
        end
      end
    end

    # Mark the dialog complete by enabling the Done and Cancel button if they
    # were specified. This method does NOT close the dialog automatically.
    def complete
      Qt.execute_in_main_thread(true) do
        @done_button.setEnabled(true) if @done_button
        @cancel_button.setEnabled(true) if @cancel_button
      end
    end

    # @comment TODO: Rename to step_progress=
    # @param value [Float] Fraction from 0 to 1 of the current step that is
    #   complete.
    def set_step_progress(value)
      progress_int = (value * 100).to_i
      if !@complete && @step_progress != progress_int
        @step_progress = progress_int
        Qt.execute_in_main_thread(false) do
          @step_bar.setValue(progress_int) if @step_bar
        end
      end
    end

    # @comment TODO: Rename to overall_progress=
    # @param value [Float] Fraction from 0 to 1 of the overall progress that is
    #   complete.
    def set_overall_progress(value)
      progress_int = (value * 100).to_i
      if !@complete && @overall_progress != progress_int
        @overall_progress = progress_int
        Qt.execute_in_main_thread(false) do
          @overall_bar.setValue(progress_int) if @overall_bar
        end
      end
    end

    # @comment TODO: Rename to step_progress
    # @return [Float] Fraction from 0 to 1 of the step progress that is
    #   complete
    def get_step_progress
      result = nil
      Qt.execute_in_main_thread(true) do
        result = (@step_bar.value.to_f / 100.0) if @step_bar
      end
      return result
    end

    # @comment TODO: Rename to overall_progress
    # @return [Float] Fraction from 0 to 1 of the overall progress that is
    #   complete
    def get_overall_progress
      result = nil
      Qt.execute_in_main_thread(true) do
        result = (@overall_bar.value.to_f / 100.0) if @overall_bar
      end
      return result
    end

    # (see #initialize)
    def self.execute(parent,
                     title,
                     width = 500,
                     height = 300,
                     show_overall = true,
                     show_step = true,
                     show_text = true,
                     show_done = true,
                     show_cancel = true)
      # Create a non-modal dialog by default
      dialog = ProgressDialog.new(parent, title, width, height, show_overall, show_step, show_text, show_done, show_cancel)
      dialog.setModal(true)
      dialog.raise

      dialog.thread = Thread.new do
        dialog.thread = Thread.current
        dialog.complete = false

        begin
          yield dialog
        rescue Exception => error
          Qt.execute_in_main_thread(true) do
            # If something bad happened during the yield we'll show the error
            # but not exit the application. Once the block has completed we
            # hide and dispose the dialog to allow the main application to run
            dialog.hide
            ExceptionDialog.new(parent, error, "Error During Progress", false)
          end
        end

        dialog.thread = nil
        dialog.complete = true
      end
      dialog.exec
      Cosmos.kill_thread(dialog, dialog.thread)
      dialog.thread = nil
      dialog.complete = true

      # Need to make sure all Qt.execute_in_main_thread() have completed before
      # disposing or we will segfault
      Qt::RubyThreadFix.queue.pop.call until Qt::RubyThreadFix.queue.empty?

      dialog.dispose
    end
  end
end
