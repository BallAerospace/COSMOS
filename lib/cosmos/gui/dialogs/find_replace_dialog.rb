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
require 'singleton'

module Cosmos
  # Provides a Qt::Dialog which implements Find and optionally Replace
  # functionality for a Qt::PlainTextEdit.
  class FindReplaceDialog < Qt::Dialog
    include Singleton

    # (see #show_find)
    def self.show_find(parent)
      self.instance.show_find(parent)
    end
    # Displays a Find dialog
    # @param parent [Qt::Widget] Dialog parent which must implement a
    #   search_text method which returns a String to search on
    def show_find(parent)
      @parent = parent
      disable_replace
      show_dialog
    end

    # (see #show_replace)
    def self.show_replace(parent)
      self.instance.show_replace(parent)
    end
    # Displays a Find/Replace dialog
    # @param parent [Qt::Widget] Dialog parent which must implement a
    #   search_text method which returns a String to search on
    def show_replace(parent)
      @parent = parent
      enable_replace
      show_dialog
    end

    # (see #find_next)
    def self.find_next(parent)
      self.instance.find_next(parent)
    end
    # Finds the next instance of the search term
    # @param parent [#search_text] Object which must implement a
    #   search_text method which returns a String to search on
    def find_next(parent)
      flags = find_flags()
      flags &= ~Qt::TextDocument::FindBackward.to_i
      found = parent.search_text.find(find_text(), flags)
      if !found && wrap_around?
        cursor = parent.search_text.textCursor
        cursor.movePosition(Qt::TextCursor::Start)
        parent.search_text.setTextCursor(cursor)
        parent.search_text.find(find_text(), flags)
      end
    end

    # (see #find_previous)
    def self.find_previous(parent)
      self.instance.find_previous(parent)
    end
    # Finds the previous instance of the search term
    # @param parent [#search_text] Object which must implement a
    #   search_text method which returns a String to search on
    def find_previous(parent)
      flags = find_flags()
      flags |= Qt::TextDocument::FindBackward.to_i
      found = parent.search_text.find(find_text(), flags)
      if !found && wrap_around?
        cursor = parent.search_text.textCursor
        cursor.movePosition(Qt::TextCursor::End)
        parent.search_text.setTextCursor(cursor)
        parent.search_text.find(find_text(), flags)
      end
    end

    private

    def initialize
      # The dialog will be re-parented when shown so pass nil
      super(nil, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      # Items which are only valid in a Replace dialog
      @replace_items = []

      layout = Qt::HBoxLayout.new
      left_side = Qt::VBoxLayout.new
      left_side.addLayout(create_input_layout)
      left_side.addLayout(create_options_layout)
      layout.addLayout(left_side)
      layout.addLayout(create_button_layout)

      setLayout(layout)
    end

    def create_input_layout
      input_layout = Qt::FormLayout.new
      @find_box = Qt::LineEdit.new
      input_layout.addRow("Fi&nd what:", @find_box)
      @replace_box = Qt::LineEdit.new
      replace_label = Qt::Label.new("Re&place with:")
      replace_label.setBuddy(@replace_box)
      @replace_items << replace_label
      input_layout.addRow(replace_label, @replace_box)
      @replace_items << @replace_box
      input_layout
    end

    def create_options_layout
      options_layout = Qt::HBoxLayout.new
      options_layout.addLayout(create_checkbox_layout)
      options_layout.addWidget(create_direction_widget)
      options_layout
    end

    def create_checkbox_layout
      checkbox_layout = Qt::VBoxLayout.new
      @match_whole_word = Qt::CheckBox.new("Match &whole word only")
      checkbox_layout.addWidget(@match_whole_word)
      @match_case = Qt::CheckBox.new("Match &case")
      checkbox_layout.addWidget(@match_case)
      @wrap_around = Qt::CheckBox.new("Wrap ar&ound")
      @wrap_around.setChecked(true)
      checkbox_layout.addWidget(@wrap_around)
      checkbox_layout.addStretch
      checkbox_layout
    end

    def create_direction_widget
      @up = Qt::RadioButton.new("&Up")
      down = Qt::RadioButton.new("&Down")
      down.setChecked(true)
      direction_layout = Qt::VBoxLayout.new
      direction_layout.addWidget(@up)
      direction_layout.addWidget(down)
      direction_layout.addStretch
      direction = Qt::GroupBox.new("Direction")
      direction.setLayout(direction_layout)
      direction
    end

    def create_button_layout
      find_next = Qt::PushButton.new("&Find Next")
      find_next.setDefault(true)
      find_next.connect(SIGNAL('clicked()')) { handle_find_next }
      cancel = Qt::PushButton.new("Cancel")
      cancel.connect(SIGNAL('clicked()')) { reject }
      replace = Qt::PushButton.new("&Replace")
      replace.connect(SIGNAL('clicked()')) { handle_replace }
      @replace_items << replace
      replace_all = Qt::PushButton.new("Replace &All")
      replace_all.connect(SIGNAL('clicked()')) { handle_replace_all }
      @replace_items << replace_all

      button_layout = Qt::VBoxLayout.new
      button_layout.addWidget(find_next)
      button_layout.addWidget(replace)
      button_layout.addWidget(replace_all)
      button_layout.addWidget(cancel)
      button_layout.addStretch
      button_layout
    end

    def show_dialog
      @find_box.selectAll
      @find_box.setFocus(Qt::PopupFocusReason)
      setParent(@parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint | 3)
      show()
    end

    def enable_replace
      @replace_items.each {|item| item.show }
      setWindowTitle('Replace')
    end

    def disable_replace
      @replace_items.each {|item| item.hide }
      setWindowTitle('Find')
    end

    def find_flags
      flags = 0
      flags |= Qt::TextDocument::FindBackward.to_i if @up.isChecked
      flags |= Qt::TextDocument::FindCaseSensitively.to_i if @match_case.isChecked
      flags |= Qt::TextDocument::FindWholeWords.to_i if @match_whole_word.isChecked
      flags
    end

    def wrap_around?
      @wrap_around.isChecked
    end

    def find_up?
      @up.isChecked
    end

    def find_text
      @find_box.text
    end

    def replace_text
      @replace_box.text
    end

    def handle_find_next
      text = @parent.search_text
      found = text.find(find_text, find_flags)
      if !found && wrap_around?
        cursor = text.textCursor
        if find_up?
          cursor.movePosition(Qt::TextCursor::End)
        else
          cursor.movePosition(Qt::TextCursor::Start)
        end
        text.setTextCursor(cursor)
        text.find(find_text, find_flags)
      end
    end

    def handle_replace
      text = @parent.search_text
      if text.textCursor.hasSelection &&
        text.textCursor.selectedText == find_text
        found = true
      else
        found = text.find(find_text, find_flags)
        if !found && wrap_around?
          cursor = text.textCursor
          if find_up?
            cursor.movePosition(Qt::TextCursor::End)
          else
            cursor.movePosition(Qt::TextCursor::Start)
          end
          text.setTextCursor(cursor)
          found = text.find(find_text, find_flags)
        end
      end
      if found
        cursor = text.textCursor
        cursor.removeSelectedText
        position = cursor.position
        cursor.insertText(replace_text)
        # Move the cursor back over the inserted text to select it
        cursor.movePosition(Qt::TextCursor::PreviousCharacter, Qt::TextCursor::KeepAnchor, replace_text.length)
        text.setTextCursor(cursor)
      end
    end

    def handle_replace_all
      text = @parent.search_text
      cursor = text.textCursor
      # Start the edit block so this can be all undone with a single undo step
      cursor.beginEditBlock

      cursor.movePosition(Qt::TextCursor::Start)
      text.setTextCursor(cursor)

      while (text.find(find_text, find_flags) == true)
        text.textCursor.removeSelectedText
        text.textCursor.insertText(replace_text)
      end
      cursor.endEditBlock
    end
  end # class FindReplaceDialog
end # module Cosmos
