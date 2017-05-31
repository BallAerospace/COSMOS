# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
Cosmos.catch_fatal_exception do
  require 'cosmos/gui/qt'
  Cosmos.disable_warnings do
    require 'pry'
  end
end

module Cosmos
  # Class to intercept keyPressEvents
  class PryLineEdit < Qt::LineEdit
    attr_accessor :keyPressCallback
    def keyPressEvent(event)
      call_super = @keyPressCallback.call(event)
      super(event) if call_super
    end
  end

  # Creates a dialog with a {http://pryrepl.org pry instance}.
  class PryDialog < Qt::Dialog
    # @param parent [Qt::Widget] Parent to this dialog
    # @param pry_binding [Object] Ruby binding
    # @param title [String] Dialog title
    def initialize(parent, pry_binding, title = 'Pry Dialog')
      super(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      setMinimumWidth(700)
      setMinimumHeight(400)
      @queue = Queue.new

      setWindowTitle(title)

      layout = Qt::VBoxLayout.new
      @text_edit = Qt::PlainTextEdit.new(self)
      @text_edit.setReadOnly(true)
      if Kernel.is_windows?
        @text_edit.font = Cosmos.getFont('courier', 9)
      else
        @text_edit.font = Cosmos.getFont('courier', 12)
      end
      layout.addWidget(@text_edit)

      @pry_history = []
      @pry_frame = Qt::HBoxLayout.new
      @pry_frame.setContentsMargins(0,0,0,0)
      @pry_frame_label = Qt::Label.new("Pry:")
      @pry_frame.addWidget(@pry_frame_label)
      @pry_text = PryLineEdit.new(self)
      @pry_text.setFocus(Qt::OtherFocusReason)
      @pry_text.keyPressCallback = lambda do |event|
        return_value = true
        case event.key
        when Qt::Key_Return, Qt::Key_Enter
          pry_text = @pry_text.text
          @pry_history.unshift(pry_text)
          @pry_history_index = 0
          if pry_text.strip == 'exit' or pry_text.strip == 'quit'
            return_value = false
            self.close
          else
            sendToPry(pry_text)
            @pry_text.setText('')
          end
        when Qt::Key_Up
          if @pry_history.length > 0
            @pry_text.setText(@pry_history[@pry_history_index])
            @pry_history_index += 1
            if @pry_history_index == @pry_history.length
              @pry_history_index = @pry_history.length-1
            end
          end
        when Qt::Key_Down
          if @pry_history.length > 0
            @pry_text.setText(@pry_history[@pry_history_index])
            @pry_history_index -= 1
            @pry_history_index = 0 if @pry_history_index < 0
          end
        when Qt::Key_Escape
          @pry_text.setText("")
        end
        return_value
      end
      @pry_frame.addWidget(@pry_text)
      layout.addLayout(@pry_frame)

      self.setLayout(layout)
      self.show
      self.raise

      # Attach pry
      @pry_thread = Thread.new do
        Pry.config.pager = false
        Pry.config.color = false
        Pry.config.correct_indent = false
        Pry.start pry_binding, :input => self, :output => self
        @pry_thread = nil
      end
    end

    # @param text [String] Text to append to the dialog and send to the pry
    #   instance
    def sendToPry(text)
      @text_edit.appendPlainText(text)
      @queue << text
    end

    # sep and limit needed to meet the pry API
    def readline(sep = nil, limit = nil)
      @queue.pop
    end

    def puts(*args)
      Qt.execute_in_main_thread(true) do
        if String === args[0]
          @text_edit.appendPlainText(args[0])
        else
          args.each do |string|
            if string[-1..-1] == "\n"
              @text_edit.appendPlainText(string)
            else
              @text_edit.appendPlainText(string + "\n")
            end
          end
        end
      end
    end

    def print(*args)
      Qt.execute_in_main_thread(true) do
        if String === args[0]
          @text_edit.appendPlainText(args[0])
        else
          args.each do |string|
            @text_edit.appendPlainText(string)
          end
        end
      end
    end

    def tty?
      false
    end

    def reject
      super()
      Cosmos.kill_thread(self, @pry_thread)
      self.dispose
    end

    def closeEvent(event)
      super(event)
      Cosmos.kill_thread(self, @pry_thread)
      self.dispose
    end

    def graceful_kill
      sendToPry("throw :breakout")
    end
  end
end
