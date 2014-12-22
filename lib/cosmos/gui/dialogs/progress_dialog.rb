# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
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

  # ProgressDialog class
  #
  # The QT GUI model is to use slots and signals to connect GUI elements together.
  # This is especially important with multithreaded applications because only the main thread
  # can update the GUI and other attempts will cause crashes.
  #
  # It seems like we should be able to do something like the following:
  #   progress_dialog = ProgressDialog.new(self, 'Progress')
  #   thread = MyRubyThreadWorker.new
  #   connect(thread, SIGNAL('finished(int)'), progress_dialog, SLOT('done(int)'), Qt::QueuedConnection)
  #   thread.start
  #   progress_dialog.exec
  #
  # This is creating a thread (but not starting the thread) and then connecting the thread
  # classes 'finished(int)' signal to the progress_dialog classes 'done(int)' signal.
  # It then starts the thread and calls exec on the dialog which makes it a modal dialog
  # that starts its internal QEventLoop going. This allows the GUI to remain updating
  # (so we can click cancel) while the thread runs. Then when the thread finished it should emit
  # its 'finished(int)' signal which closes the dialog.
  #
  # This all SHOULD work but it tends to randomly crash on Ruby 1.8.6.
  # HOWEVER, it appears to work well on 1.9.1. We should consider going to this model
  # in COSMOS 2.0 as it avoids the hacky

  class ProgressDialog < Qt::Dialog
    attr_accessor :cancel_callback
    attr_accessor :thread
    attr_writer :complete

    slots 'append_text(const QString&)'
    slots 'set_step_progress(int)'
    slots 'set_overall_progress(int)'

    def initialize(parent, title, width = 500, height = 300, show_overall = true, show_step = true, show_text = true, show_done = true, show_cancel = true)
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
        @progress_text.setMaximumBlockCount(10000)
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
      @top_layout.addLayout(@button_layout) if show_done or show_cancel

      setLayout(@top_layout)

      @thread = nil
      @cancel_callback = nil
    end

    def self.canceled?
      @@canceled
    end

    def complete?
      return @complete
    end

    def enable_cancel_button
      Qt.execute_in_main_thread(true) do
        @cancel_button.setEnabled(true) if @cancel_button
      end
    end

    def close_done
      Qt.execute_in_main_thread(true) do
        @complete = true
        self.done(0) unless self.disposed?
      end
    end

    def close_cancel
      Qt.execute_in_main_thread(true) do
        kill_thread = true
        if @cancel_callback
          continue_cancel, kill_thread = @cancel_callback.call(self)
          return unless continue_cancel
        end
        Thread.new do
          if @thread
            @thread.kill if kill_thread
            @thread.join
          end
          @thread = nil
          @@canceled = true
          close_done()
        end
      end
    end

    def set_text_font(font)
      @progress_text.setFont(font)
    end

    def append_text(string)
      unless @complete
        Qt.execute_in_main_thread(false) do
          if @progress_text
            @progress_text.appendPlainText(string)
            @progress_text.ensureCursorVisible
          end
        end
      end
    end

    def complete
      Qt.execute_in_main_thread(true) do
        @done_button.setEnabled(true) if @done_button
        @cancel_button.setEnabled(true) if @cancel_button
      end
    end

    def set_step_progress (value)
      unless @complete
        Qt.execute_in_main_thread(false) do
          @step_bar.setValue(value * 100.0) if @step_bar
        end
      end
    end

    def set_overall_progress (value)
      unless @complete
        Qt.execute_in_main_thread(false) do
          @overall_bar.setValue(value * 100.0) if @overall_bar
        end
      end
    end

    def get_step_progress
      result = nil
      Qt.execute_in_main_thread(true) do
        result = (@step_bar.value.to_f / 100.0) if @step_bar
      end
      return result
    end

    def get_overall_progress
      result = nil
      Qt.execute_in_main_thread(true) do
        result = (@overall_bar.value.to_f / 100.0) if @overall_bar
      end
      return result
    end

    def self.execute(parent, title, width = 500, height = 300, show_overall = true, show_step = true, show_text = true, show_done = true, show_cancel = true)
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
            # If something bad happened during the yield we'll show the error but not exit the application
            # Once the block has completed we hide and dispose the dialog to allow the main application to take over
            dialog.hide
            ExceptionDialog.new(parent, error, "Error During Progress", false)
          end
        end

        dialog.thread = nil
        dialog.complete = true
      end
      dialog.exec
      dialog.thread.kill if dialog.thread
      sleep(0.01) # Give a little time to make sure the thread is complete
      dialog.thread = nil
      dialog.complete = true

      # Need to make sure all Qt.execute_in_main_thread() have completed before disposing or
      # we will segfault
      Qt::RubyThreadFix.queue.pop.call until Qt::RubyThreadFix.queue.empty?

      dialog.dispose
    end
  end # class ProgressDialog

end # module Cosmos
