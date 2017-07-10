# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/script'
require 'cosmos/gui/utilities/script_module_gui'
require 'cosmos/gui/dialogs/splash'
require 'cosmos/gui/dialogs/exception_dialog'
require 'cosmos/gui/text/completion'
require 'cosmos/gui/text/completion_line_edit'
require 'cosmos/gui/text/ruby_editor'
require 'cosmos/gui/dialogs/progress_dialog'
require 'cosmos/gui/dialogs/find_replace_dialog'
require 'cosmos/gui/choosers/file_chooser'
require 'cosmos/io/stdout'
require 'cosmos/io/stderr'

module Cosmos
  class ConfigEditorFrame < Qt::Widget
    slots 'context_menu(const QPoint&)'
    slots 'undo_available(bool)'
    slots 'cursor_position_changed()'
    signals 'undoAvailable(bool)'
    signals 'modificationChanged(bool)'
    signals 'cursorPositionChanged()'

    attr_reader :filename
    attr_reader :editor

    @@file_number = 1

    def initialize(parent, default_tab_text = 'Untitled')
      super(parent)
      @default_tab_text = '  ' + default_tab_text + '  '
      # Keep track of whether this frame has been fully initialized
      @initialized = false

      # Keep track of a unique file number so we can differentiate untitled tabs
      @file_number = @@file_number
      @@file_number += 1
      @filename = ''

      @layout = Qt::VBoxLayout.new
      @layout.setContentsMargins(0,0,0,0)

      # Create a splitter to hold the config text area and the config GUI help
      @splitter = Qt::Splitter.new(Qt::Horizontal, self)
      @layout.addWidget(@splitter)
      @top_widget = Qt::Widget.new(@splitter)
      @top_widget.setContentsMargins(0,0,0,0)
      @top_frame = Qt::VBoxLayout.new(@top_widget)
      @top_frame.setContentsMargins(0,0,0,0)

      # Add Initial Text Window
      @editor = create_ruby_editor()
      @editor.filename = unique_filename()
      @editor.connect(SIGNAL('modificationChanged(bool)')) do |changed|
        emit modificationChanged(changed)
      end
      @top_frame.addWidget(@editor)

      # Set self as the gui window to allow prompts and other popups to appear
      set_cmd_tlm_gui_window(self)

      # Add change handlers
      connect(@editor,
              SIGNAL('undoAvailable(bool)'),
              self,
              SLOT('undo_available(bool)'))
      connect(@editor,
              SIGNAL('cursorPositionChanged()'),
              self,
              SLOT('cursor_position_changed()'))

      # Add GUI Frame
      @bottom_frame = Qt::Widget.new
      @bottom_layout = Qt::VBoxLayout.new
      @bottom_layout.setContentsMargins(5,0,0,0)
      @bottom_layout_label = Qt::Label.new("COSMOS Config File Help")
      @bottom_layout.addWidget(@bottom_layout_label)
      @bottom_frame.setLayout(@bottom_layout)
      @splitter.addWidget(@bottom_frame)
      @splitter.setStretchFactor(0,1)
      @splitter.setStretchFactor(1,0)

      setLayout(@layout)

      # Configure Variables
      @key_press_callback = nil
      @output_time = Time.now.sys
      initialize_variables()

      # Create Tabbook
      @tab_book = Qt::TabWidget.new
      @tab_book_shown = false

      @find_dialog = nil
      @replace_dialog = nil
    end

    def unique_filename
      if @filename and !@filename.empty?
        return @filename
      else
        return @default_tab_text.strip + @file_number.to_s
      end
    end

    def current_tab_filename
      if @tab_book_shown
        return @tab_book.widget(@tab_book.currentIndex).filename
      else
        return @editor.filename
      end
    end

    def create_ruby_editor
      script = RubyEditor.new(self)
      # Add right click menu
      script.setContextMenuPolicy(Qt::CustomContextMenu)
      connect(script,
              SIGNAL('customContextMenuRequested(const QPoint&)'),
              self,
              SLOT('context_menu(const QPoint&)'))
      script
    end

    def filename=(filename)
      @filename = filename
    end

    def modified
      @editor.document.isModified()
    end

    def modified=(bool)
      @editor.document.setModified(bool)
    end

    def undo_available(bool)
      emit undoAvailable(bool)
    end

    def cursor_position_changed()
      emit cursorPositionChanged()
    end

    def key_press_callback=(callback)
      @editor.keyPressCallback = callback

    end

    def setFocus
      @editor.setFocus
    end

    def clear
      self.set_text('')
      self.filename = ''
      @editor.filename = unique_filename()
      self.modified = false
    end

    def text
      @editor.toPlainText.gsub("\r", '')
    end

    def set_text(text, filename = '')
      @editor.setPlainText(text)
      @editor.stop_highlight
      @filename = filename
      @editor.filename = unique_filename()
    end

    def set_text_from_file(filename)
      load_file_into_script(filename)
      @filename = filename
    end

    ######################################
    # Implement edit functionality in the frame (cut, copy, paste, etc)
    ######################################
    def undo
      @editor.undo
    end

    def redo
      @editor.redo
    end

    def cut
      @editor.cut
    end

    def copy
      @editor.copy
    end

    def paste
      @editor.paste
    end

    def select_all
      @editor.select_all
    end

    def comment_or_uncomment_lines
      @editor.comment_or_uncomment_lines
    end

    def cursor
      @editor.textCursor
    end

    def line_number
      @editor.line_number
    end

    def column_number
      @editor.column_number
    end

    def current_line
      @editor.current_line
    end

    def keyword
      return '' if current_line.strip[0] == '#' || current_line.strip.empty?
      current_line.strip.split(" ")[0]
    end

    def current_word
      @editor.blockSignals(true) # block signals while we programatically update it
      c = cursor
      position = c.position
      # Programatically select the word under the cursor
      # I also tried: c.select(Qt::TextCursor::WordUnderCursor)
      # but this doesn't work as well with words with periods like ruby.rb
      c.movePosition(Qt::TextCursor::StartOfWord)
      c.movePosition(Qt::TextCursor::EndOfWord, Qt::TextCursor::KeepAnchor)
      @editor.setTextCursor(c)
      text = @editor.textCursor.selectedText()
      c.setPosition(position)
      @editor.setTextCursor(c)
      @editor.blockSignals(false) # re-enable signals
      text
    end

    def graceful_kill
      # Just to avoid warning
    end

    protected

    def initialize_variables
      @active_script = @editor
      @current_file = @filename
      @current_filename = nil
      @editor.stop_highlight
    end

    def show_active_tab
      @tab_book.setCurrentIndex(@call_stack.length - 1) if @tab_book_shown
    end

    # Right click context_menu for the script
    def context_menu(point)
      if @tab_book_shown
        current_script = @tab_book.widget(@tab_book.currentIndex)
      else
        current_script = @editor
      end
      menu = current_script.context_menu(point)
      menu.exec(current_script.mapToGlobal(point))
      menu.dispose
    end

    def load_file_into_script(filename)
      @active_script.setPlainText(File.read(filename).gsub("\r", ''))
      @active_script.stop_highlight
    end

    def create_tabs
      tab_text = @default_tab_text
      tab_text = '  ' + File.basename(@filename) + '  ' unless @filename.empty?
      @tab_book.addTab(@editor, tab_text)
      @top_frame.insertWidget(0, @tab_book)
      @tab_book_shown = true
    end

    def remove_tabs
      @top_frame.takeAt(0) # Remove the @tab_book from the layout
      @top_frame.addWidget(@editor) # Add back the script
      @editor.show
      @tab_book_shown = false
    end
  end
end
