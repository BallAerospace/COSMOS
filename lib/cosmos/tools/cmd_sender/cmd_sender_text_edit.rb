# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos
  # CmdSenderTextEdit is a subclass of TextEdit that creates a CosmosCompletion class to
  # allow for code completion when creating new commands in the command history
  # window. It also monitors for the Enter key to allow for commands in the
  # command history to be executed.
  class CmdSenderTextEdit < Qt::TextEdit
    def initialize(status_bar)
      super()
      @status_bar = status_bar
      @c = Completion.new(self)
    end

    def keyPressEvent(event)
      # If the completion popup is visible then ignore the event and allow the popup to handle it
      if (@c and @c.popup.isVisible)
        case event.key
        when Qt::Key_Return, Qt::Key_Enter
          event.ignore
          return
        end
      end

      case event.key
      # The return key means we need to execute the current line
      when Qt::Key_Return, Qt::Key_Enter
        # If the cursor is at the beginning of the line allow the newline
        if textCursor.atBlockStart
          super(event)
        # If the line isn't blank then execute it
        elsif textCursor.block.text.strip != ""
          begin
            eval(textCursor.block.text, $eval_binding)
            CmdSender.send_count += 1
            @status_bar.showMessage("#{textCursor.block.text} sent. (#{CmdSender.send_count})")
          rescue Exception => error
            if error.class == DRb::DRbConnError
              message = "Error Connecting to Command and Telemetry Server"
            else
              message = "Error sending command due to #{error}"
            end
            @status_bar.showMessage(message)
            Qt::MessageBox.critical(self, 'Error', message)
          end
        end
      # Handle Key_Down to automatically create a newline if they Key_Down at
      # the bottom of the document
      when Qt::Key_Down
        # If the number of lines equals the current line (plus one since it is 0
        # based) then we append a newline to allow the Key_Down to go to a new line
        if self.toPlainText.split("\n").length == (textCursor.block.blockNumber + 1)
          self.append("")
        end
        super(event)
      else # All other keys are handled by this widget as well as being passed to the completion handler
        super(event)
        @c.handle_keypress(event)
      end
    end
  end
end # module Cosmos
