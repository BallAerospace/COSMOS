# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation for the COSMOS Splash Screen

require 'cosmos'
require 'cosmos/gui/qt_tool'
require 'cosmos/gui/dialogs/exception_dialog'

module Cosmos
  # Provides a single class method which creates a splash screen dialog box.
  # This dialog has both a text message box and progress bar.
  class Splash
    # Creates a dialog with a message box and a progress bar.
    class SplashDialogBox < Qt::Dialog
      # @param parent [Qt::Widget] The dialog parent
      def initialize(parent)
        super(parent, Qt::WindowTitleHint | Qt::CustomizeWindowHint)
        setWindowTitle(parent.windowTitle)
        setModal(true)
        layout = Qt::VBoxLayout.new

        splash_image_filename = File.join(::Cosmos::USERPATH, 'config', 'data', 'splash.gif')
        splash_image_filename = File.join(::Cosmos::PATH, 'data', 'splash.gif') unless File.exist?(splash_image_filename)
        image = Qt::Pixmap.new(splash_image_filename)
        label = Qt::Label.new
        label.setPixmap(image)
        layout.addWidget(label)

        @message_box = Qt::LineEdit.new
        @message_box.setReadOnly(true)
        layout.addWidget(@message_box)
        @progress_bar = Qt::ProgressBar.new
        layout.addWidget(@progress_bar)
        setLayout(layout)

        @progress = 0
        @complete = false
      end

      # @param message [String] Text to place in the message box. Text is
      #   replaced and not appended.
      def message=(message)
        unless @complete
          Qt.execute_in_main_thread(false) do
            @message_box.setText(message)
          end
        end
      end

      # @param progress [Float] Set the progress bar to a percentage from 0 to 1
      def progress=(progress)
        progress_int = (progress * 100).to_i
        if !@complete and @progress != progress_int
          @progress = progress_int
          Qt.execute_in_main_thread(false) do
            @progress_bar.setValue(progress_int)
          end
        end
      end

      # @return [Method] message= method
      def message_callback
        method(:message=)
      end

      # @return [Method] progress= method
      def progress_callback
        method(:progress=)
      end

      # Override keyPressEvent to prevent Esc from closing the splash dialog
      # @param event [Qt::KeyEvent] Pressed key event
      def keyPressEvent(event)
        # Don't allow the Escape key to close this dialog
        if event.key == Qt::Key_Escape
          event.ignore
        else
          super(event)
        end
      end
    end

    # @param parent [Qt::Widget] Dialog parent
    # @param wait_for_complete [Boolean] Whether to call dialog.exec and block
    #   other threads from running until this dialog is closed
    # @yieldparam dialog [SplashDialogBox] The dialog box
    def self.execute(parent, wait_for_complete = false, &block)
      # Create the dialog and show it
      dialog = SplashDialogBox.new(parent)
      dialog.show unless wait_for_complete
      dialog.raise

      # Create a new thread to run the block
      # WARNING! If you need to update your own gui you must wrap it with:
      #   Qt.execute_in_main_thread(true) do
      #     < Update the GUI >
      #   end
      Thread.new do
        error = nil
        begin
          yield dialog
        rescue Exception => e
          error = e
        end

        @complete = true

        # If the block threw an error show it before allowing the application to crash
        if error
          Qt.execute_in_main_thread(true) do
            ExceptionDialog.new(parent, error, "Error During Startup")
          end
        end

        Qt.execute_in_main_thread(true) do
          # Once the block has completed we hide and dispose the dialog to allow the main application to take over
          dialog.hide

          unless wait_for_complete
            # Need to make sure all Qt.execute_in_main_thread() have completed before disposing or
            # we will segfault
            Qt::RubyThreadFix.queue.pop.call until Qt::RubyThreadFix.queue.empty?

            dialog.dispose
          end
        end
      end
      if wait_for_complete
        dialog.exec
        # Need to make sure all Qt.execute_in_main_thread() have completed
        # before disposing or we will segfault
        Qt::RubyThreadFix.queue.pop.call until Qt::RubyThreadFix.queue.empty?
        dialog.dispose
      end
    end
  end
end
