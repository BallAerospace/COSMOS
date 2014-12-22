# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the FindDialog class.   This class
# provides a dialog box with options for finding text

require 'cosmos'
require 'cosmos/gui/qt'

module Cosmos

  class FindReplaceDialog < Qt::Dialog
    signals 'find_next()'
    signals 'replace()'
    signals 'replace_all()'

    @@find_text = ""
    @@replace_text = ""
    @@match_whole_word = false
    @@match_case = false
    @@wrap_around = true
    @@find_up = false
    @@find_down = true
    @@find_flags = 0

    def initialize(parent, replace_dialog = false)
      # Call base class constructor
      super(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      @replace_dialog = replace_dialog
      setWindowTitle('Find') unless @replace_dialog
      setWindowTitle('Replace') if @replace_dialog

      @layout = Qt::HBoxLayout.new

      @find_layout = Qt::FormLayout.new
      @find_box = Qt::LineEdit.new(@@find_text)
      @find_layout.addRow(tr("Fi&nd what:"), @find_box)
      if @replace_dialog
        @replace_box = Qt::LineEdit.new(@@replace_text)
        @find_layout.addRow(tr("Re&place with:"), @replace_box)
      end

      @match_whole_word = Qt::CheckBox.new("Match &whole word only")
      @match_whole_word.setChecked(@@match_whole_word)
      @match_case = Qt::CheckBox.new("Match &case")
      @match_case.setChecked(@@match_case)
      @wrap_around = Qt::CheckBox.new("Wrap ar&ound")
      @wrap_around.setChecked(@@wrap_around)
      @checkbox_layout = Qt::VBoxLayout.new
      @checkbox_layout.addWidget(@match_whole_word)
      @checkbox_layout.addWidget(@match_case)
      @checkbox_layout.addWidget(@wrap_around)
      @checkbox_layout.addStretch

      @up = Qt::RadioButton.new("&Up")
      @up.setChecked(@@find_up)
      @down = Qt::RadioButton.new("&Down")
      @down.setChecked(@@find_down)
      @direction_layout = Qt::VBoxLayout.new
      @direction_layout.addWidget(@up)
      @direction_layout.addWidget(@down)
      @direction_layout.addStretch
      @direction = Qt::GroupBox.new(tr("Direction"))
      @direction.setLayout(@direction_layout)

      @options_layout = Qt::HBoxLayout.new
      @options_layout.addLayout(@checkbox_layout)
      @options_layout.addWidget(@direction)

      @left_side = Qt::VBoxLayout.new
      @left_side.addLayout(@find_layout)
      @left_side.addLayout(@options_layout)

      @find_next = Qt::PushButton.new("&Find Next")
      @find_next.setDefault(true)
      @find_next.connect(SIGNAL('clicked()')) { emit find_next() }
      @cancel = Qt::PushButton.new("Cancel")
      @cancel.connect(SIGNAL('clicked()')) { self.reject }
      if @replace_dialog
        @replace = Qt::PushButton.new("&Replace")
        @replace.connect(SIGNAL('clicked()')) { emit replace() }
        @replace_all = Qt::PushButton.new("Replace &All")
        @replace_all.connect(SIGNAL('clicked()')) { emit replace_all() }
      end

      @button_layout = Qt::VBoxLayout.new
      @button_layout.addWidget(@find_next)
      if @replace_dialog
        @button_layout.addWidget(@replace)
        @button_layout.addWidget(@replace_all)
      end
      @button_layout.addWidget(@cancel)
      @button_layout.addStretch

      @layout.addLayout(@left_side)
      @layout.addLayout(@button_layout)

      setLayout(@layout)

      self.connect(SIGNAL('finished(int)')) { dialog_closing }
    end # def initialize

    def show
      super
      @find_box.selectAll
      @find_box.setFocus(Qt::PopupFocusReason)
    end

    def find_flags
      flags = 0
      flags |= Qt::TextDocument::FindBackward.to_i if @up.isChecked
      flags |= Qt::TextDocument::FindCaseSensitively.to_i if @match_case.isChecked
      flags |= Qt::TextDocument::FindWholeWords.to_i if @match_whole_word.isChecked
      flags
    end

    def find_text
      @find_box.text
    end

    def replace_text
      @replace_box.text if @replace_dialog
    end

    def match_whole_word?
      @match_whole_word.isChecked
    end

    def match_case?
      @match_case.isChecked
    end

    def wrap_around?
      @wrap_around.isChecked
    end

    def find_up?
      @up.isChecked
    end

    def find_down?
      @down.isChecked
    end

    def dialog_closing
      @@find_text = @find_box.text
      @@replace_text = @replace_box.text if @replace_dialog
      @@match_whole_word = @match_whole_word.isChecked
      @@match_case = @match_case.isChecked
      @@wrap_around = @wrap_around.isChecked
      @@find_up = @up.isChecked
      @@find_down = @down.isChecked
      @@find_flags = find_flags
    end

    def self.find_text
      @@find_text
    end

    def self.replace_text
      @@replace_text
    end

    def self.match_whole_word?
      @@match_whole_word
    end

    def self.match_case?
      @@match_case
    end

    def self.wrap_around?
      @@wrap_around
    end

    def self.find_up?
      @@find_up
    end

    def self.find_down?
      @@find_down
    end

    def self.find_flags
      @@find_flags
    end
  end # class FindReplaceDialog

end # module Cosmos
