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
require 'cosmos/gui/dialogs/splash'

module Cosmos

  class CompletionTextEdit < Qt::PlainTextEdit
    slots 'highlight_line()'

    TRUE_VARIANT = Qt::Variant.new(true)
    SELECTION_DETAILS_POOL = []

    class SelectionDetails
      attr_reader :selection
      attr_reader :format

      def initialize
        @selection = Qt::TextEdit::ExtraSelection.new
        @format = @selection.format
      end
    end

    def initialize(parent)
      super(parent)
      setFocusPolicy(Qt::StrongFocus)
      setLineWrapMode(Qt::PlainTextEdit::NoWrap)

      @cursor = Qt::TextCursor.new(document())
      @selection_details = SELECTION_DETAILS_POOL.pop
      @selection_details = SelectionDetails.new unless @selection_details
      @selection_details.format.setProperty(Qt::TextFormat::FullWidthSelection, TRUE_VARIANT)
      @selection_details.selection.format = @selection_details.format
      @selection_details.selection.cursor = @cursor

      @last_hightlighted_line = 1
      @code_completion = nil
      begin
        @code_completion = Completion.new(self)
      rescue
        # Oh well - no completion
      end
    end

    def line_number
      textCursor.blockNumber + 1
    end

    def column_number
      textCursor.positionInBlock + 1
    end

    def current_line
      textCursor.block.text
    end

    def dispose
      super()
      @cursor.dispose
      SELECTION_DETAILS_POOL << @selection_details
      @code_completion.dispose if @code_completion
    end

    def keyPressCallback=(callback)
      @keypress_callback = callback
    end

    def keyPressEvent(event)
      # If the completion popup is visible then ignore the event and allow the popup to handle it
      if (@code_completion and @code_completion.popup.isVisible)
        case event.key
        when Qt::Key_Return, Qt::Key_Enter
          event.ignore
          return
        end
      end

      continue = @keypress_callback.call(event) if @keypress_callback

      case event.key
      when Qt::Key_Tab
        if event.modifiers == Qt::NoModifier
          indent_selection()
        end
      when Qt::Key_Backtab
        unindent_selection()
      else
        if continue != false
          super(event)
          @code_completion.handle_keypress(event) if @code_completion
        end
      end
    end

    def indent_selection
      cursor = textCursor
      # Figure out if the cursor has a selection
      no_selection = true
      no_selection = false if cursor.hasSelection

      # Start the edit block so this can be all undone with a single undo step
      cursor.beginEditBlock
      selection_end = cursor.selectionEnd
      # Initially place the cursor at the beginning of the selection
      # If nothing is selected this will just put the cursor at the beginning of the current line
      cursor.setPosition(textCursor.selectionStart)
      cursor.movePosition(Qt::TextCursor::StartOfLine)
      result = true
      while (cursor.position < selection_end and result == true) or (no_selection)
        # Add two spaces for a standard Ruby indent
        cursor.insertText('  ')
        # Move the cursor to the beginning of the next line
        cursor.movePosition(Qt::TextCursor::StartOfLine)
        result = cursor.movePosition(Qt::TextCursor::Down)
        # Since we inserted two spaces we need to move the end position by two
        selection_end += 2
        # If nothing was selected then we're working with a single line and we can break
        break if no_selection
      end
      cursor.endEditBlock
    end

    def unindent_selection
      cursor = textCursor
      # Start the edit block so this can be undone with a single undo step
      cursor.beginEditBlock
      # Initially place the cursor at the beginning of the selection
      # If nothing is selected this will just put the cursor at the beginning of the current line
      selection_end = cursor.selectionEnd
      cursor.setPosition(textCursor.selectionStart)
      cursor.movePosition(Qt::TextCursor::StartOfLine)
      result = true
      while cursor.position <= selection_end and result == true
        # Since we inserted two spaces for an indentation we remove a single character twice
        2.times do
          # Only remove the text if we have spaces to remove
          if cursor.block.text =~ /^\s/
            cursor.deleteChar
            # Adjust the selection end since we just removed a character
            selection_end -= 1
          end
        end
        # Move down to the next line in case we have to unindent that
        # We store the result which is false if the move couldn't complete
        # For example if we're on the last line in the editor
        result = cursor.movePosition(Qt::TextCursor::Down)
      end
      cursor.endEditBlock
    end

    def highlight_line(line, color = 'palegreen') #102, 255, 102
      color = Cosmos::getColor(color)
      # Store the line number in case we need to rehighlight this line
      @last_hightlighted_line = line
      brush = Cosmos.getBrush(color)
      @selection_details.format.setBackground(brush)
      # Get the textCursor and move it to the specified line
      @cursor.movePosition(Qt::TextCursor::Start)
      # The line number is based in 1 based but the PlainTextEdit is 0 based
      @cursor.movePosition(Qt::TextCursor::Down, Qt::TextCursor::MoveAnchor, line-1)
      @cursor.clearSelection
      # By setting the text cursor after moving it we ensure we can see the highlight
      # If we just called setExtraSelections without setting the cursor we might not be able to see it
      setTextCursor(@cursor)
      @selection_details.selection.format = @selection_details.format
      @selection_details.selection.cursor = @cursor
      setExtraSelections([@selection_details.selection])
      # Center the cursor to ensure it is visible
      centerCursor()
    end

    def stop_highlight
      # Clearing the extra selections with a nil array clears the selection
      self.setExtraSelections([])
    end

    def rehighlight(color = 'palegreen')
      highlight_line(@last_hightlighted_line, color)
    end
  end

end # module Cosmos
