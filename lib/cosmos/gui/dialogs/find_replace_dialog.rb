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

module Cosmos
  # Provides a Qt::Dialog which implements Find and optionally Replace
  # functionality for a Qt::PlainTextEdit.
  class FindReplaceDialog < Qt::Dialog
    # Constructs a new Find dialog
    # @param text [Qt::PlainTextEdit] Dialog parent
    def self.open_find_dialog(text)
      open_dialog(text) { disable_replace }
    end

    # Constructs a new Find/Replace dialog
    # @param text [Qt::PlainTextEdit] Dialog parent
    def self.open_replace_dialog(text)
      open_dialog(text) { enable_replace }
    end

    # @param text [Qt::PlainTextEdit] Text widget to search
    def self.find_next(text)
      flags = @dialog.find_flags()
      flags &= ~Qt::TextDocument::FindBackward.to_i
      found = text.find(@dialog.find_text(), flags)
      if not found and @dialog.wrap_around?
        cursor = text.textCursor
        cursor.movePosition(Qt::TextCursor::Start)
        text.setTextCursor(cursor)
        text.find(@dialog.find_text(), flags)
      end
    end

    # @param text [Qt::PlainTextEdit] Text widget to search
    def self.find_previous(text)
      flags = @dialog.find_flags()
      flags |= Qt::TextDocument::FindBackward.to_i
      found = text.find(@dialog.find_text(), flags)
      if not found and @dialog.wrap_around?
        cursor = text.textCursor
        cursor.movePosition(Qt::TextCursor::End)
        text.setTextCursor(cursor)
        text.find(@dialog.find_text(), flags)
      end
    end

    # Ideally the next few methods would be private as well
    # but they are needed by the class methods above

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

    def find_text
      @@find_box.text
    end

    private

    def self.open_dialog(text)
      @dialog = new(text) unless @dialog
      yield
      @@find_box.selectAll
      @@find_box.setFocus(Qt::PopupFocusReason)
      @@text = text
      @dialog.show
    end

    def self.enable_replace
      @@replace_items.each {|item| item.show }
      @dialog.setWindowTitle('Replace')
    end

    def self.disable_replace
      @@replace_items.each {|item| item.hide }
      @dialog.setWindowTitle('Find')
    end

    def initialize(parent)
      # Parent the dialog to the most native widget in the stack
      super(parent.nativeParentWidget, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      @@replace_items = []

      layout = Qt::HBoxLayout.new

      find_layout = Qt::FormLayout.new
      @@find_box = Qt::LineEdit.new
      find_layout.addRow(tr("Fi&nd what:"), @@find_box)
      @replace_box = Qt::LineEdit.new
      replace_label = Qt::Label.new(tr("Re&place with:"))
      replace_label.setBuddy(@replace_box)
      @@replace_items << replace_label
      find_layout.addRow(replace_label, @replace_box)
      @@replace_items << @replace_box

      @match_whole_word = Qt::CheckBox.new("Match &whole word only")
      @match_case = Qt::CheckBox.new("Match &case")
      @wrap_around = Qt::CheckBox.new("Wrap ar&ound")
      @wrap_around.setChecked(true)
      checkbox_layout = Qt::VBoxLayout.new
      checkbox_layout.addWidget(@match_whole_word)
      checkbox_layout.addWidget(@match_case)
      checkbox_layout.addWidget(@wrap_around)
      checkbox_layout.addStretch

      @up = Qt::RadioButton.new("&Up")
      down = Qt::RadioButton.new("&Down")
      down.setChecked(true)
      direction_layout = Qt::VBoxLayout.new
      direction_layout.addWidget(@up)
      direction_layout.addWidget(down)
      direction_layout.addStretch
      direction = Qt::GroupBox.new(tr("Direction"))
      direction.setLayout(direction_layout)

      options_layout = Qt::HBoxLayout.new
      options_layout.addLayout(checkbox_layout)
      options_layout.addWidget(direction)

      left_side = Qt::VBoxLayout.new
      left_side.addLayout(find_layout)
      left_side.addLayout(options_layout)

      find_next = Qt::PushButton.new("&Find Next")
      find_next.setDefault(true)
      find_next.connect(SIGNAL('clicked()')) { handle_find_next }
      cancel = Qt::PushButton.new("Cancel")
      cancel.connect(SIGNAL('clicked()')) { self.reject }
      replace = Qt::PushButton.new("&Replace")
      replace.connect(SIGNAL('clicked()')) { handle_replace }
      @@replace_items << replace
      replace_all = Qt::PushButton.new("Replace &All")
      replace_all.connect(SIGNAL('clicked()')) { handle_replace_all }
      @@replace_items << replace_all

      button_layout = Qt::VBoxLayout.new
      button_layout.addWidget(find_next)
      button_layout.addWidget(replace)
      button_layout.addWidget(replace_all)
      button_layout.addWidget(cancel)
      button_layout.addStretch

      layout.addLayout(left_side)
      layout.addLayout(button_layout)

      setLayout(layout)
    end

    def find_up?
      @up.isChecked
    end

    def replace_text
      @replace_box.text
    end

    def handle_find_next
      found = @@text.find(find_text, find_flags)
      if not found and wrap_around?
        cursor = @@text.textCursor
        if find_up?
          cursor.movePosition(Qt::TextCursor::End)
        else
          cursor.movePosition(Qt::TextCursor::Start)
        end
        @@text.setTextCursor(cursor)
        @@text.find(find_text, find_flags)
      end
    end

    def handle_replace
      if @@text.textCursor.hasSelection &&
        @@text.textCursor.selectedText == find_text
        found = true
      else
        found = @@text.find(find_text, find_flags)
        if not found and wrap_around?
          cursor = @@text.textCursor
          if find_up?
            cursor.movePosition(Qt::TextCursor::End)
          else
            cursor.movePosition(Qt::TextCursor::Start)
          end
          @@text.setTextCursor(cursor)
          found = @@text.find(find_text, find_flags)
        end
      end
      if found
        @@text.textCursor.removeSelectedText
        @@text.textCursor.insertText(replace_text)
        cursor = @@text.textCursor
        cursor.setPosition(cursor.position-1)
        cursor.select(Qt::TextCursor::WordUnderCursor)
        @@text.setTextCursor(cursor)
      end
    end

    def handle_replace_all
      cursor = @@text.textCursor
      cursor.movePosition(Qt::TextCursor::Start)
      @@text.setTextCursor(cursor)

      while (@@text.find(find_text, find_flags) == true)
        @@text.textCursor.removeSelectedText
        @@text.textCursor.insertText(replace_text)
      end
    end

  end # class FindReplaceDialog
end # module Cosmos
