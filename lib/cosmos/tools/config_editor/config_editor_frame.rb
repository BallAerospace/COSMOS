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
require 'cosmos/config/meta_config_parser'

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
      @editor.connect(SIGNAL('undoAvailable(bool)')) { |bool| undo_available(bool) }
      @editor.connect(SIGNAL('cursorPositionChanged()')) { cursor_position_changed() }
      @top_frame.addWidget(@editor)

      # Set self as the gui window to allow prompts and other popups to appear
      set_cmd_tlm_gui_window(self)

      # Add GUI Frame
      @gui_frame = Qt::Widget.new
      gui_layout = Qt::VBoxLayout.new
      gui_layout.setContentsMargins(5,0,0,0)
      gui_layout_label = Qt::Label.new("COSMOS Config File Help")
      gui_layout.addWidget(gui_layout_label)
      @gui_frame.setLayout(gui_layout)
      @splitter.addWidget(@gui_frame)
      @splitter.setStretchFactor(0,10)
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
        @file_type = 'none'
        return @default_tab_text.strip + @file_number.to_s
      end
    end

    def determine_file_type
      if @filename.empty?
        @file_type = :none
      else
        # Check for inside target directory
        if @filename.include?('/config/targets/')
          if @filename.split('/')[-3] == 'targets'
            @file_type = :target_base
          else
            @file_type = :target_config
          end
        end
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
      determine_file_type()
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
      display_keyword_help()
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

    def graceful_kill
      # Just to avoid warning
    end

    protected

    def display_keyword_help
      meta = get_keyword_meta()
      if !meta
        @gui_frame.dispose()
        return
      end

      # if meta.keys[0] == @current_keyword
      #   # Do stuff
      # else
        build_help_frame(meta)
      # end
    end

    def build_help_frame(meta)
      word = @editor.current_word('palegreen')
      line_parts = current_line.split
      @gui_frame.dispose()
      @gui_frame = Qt::Widget.new
      layout = Qt::VBoxLayout.new
      @gui_frame.setLayout(layout)
      meta.each do |key, attributes|
        @current_keyword = key.to_s
        keyword = Qt::Label.new(key.to_s)
        keyword.setFont(Cosmos.getFont("Arial", 16, Qt::Font::Bold))
        layout.addWidget(keyword)
        attributes.each do |attribute_name, value|
          if attribute_name != :parameters
            case attribute_name
            when :summary
              summary = Qt::Label.new(value)
              summary.setFont(Cosmos.getFont("Arial", 12))
              summary.setWordWrap(true)
              layout.addWidget(summary)
            when :description
              description = Qt::Label.new(value)
              description.setFont(Cosmos.getFont("Arial", 9))
              description.setWordWrap(true)
              layout.addWidget(description)
            end
          else # Process parameters
            next if value.empty?
            line = Qt::Frame.new(@gui_frame)
            line.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
            layout.addWidget(line)
            param = Qt::Label.new("Parameters:")
            param.setFont(Cosmos.getFont("Arial", 14, Qt::Font::Bold))
            layout.addWidget(param)

            value.each_with_index do |parameter, parameter_index|
              parameter.each do |parameter_name, parameter_attributes|
                name_layout = Qt::HBoxLayout.new
                param = Qt::Label.new(parameter_name.to_s)
                param.setFont(Cosmos.getFont("Arial", 12, Qt::Font::Bold))
                param.setWordWrap(true)
                name_layout.addWidget(param)
                value_widget = Qt::Widget.new
                parameter_attributes.each do |name, value|
                  case name
                  when :description
                    description = Qt::Label.new(value)
                    description.setFont(Cosmos.getFont("Arial", 9))
                    description.setWordWrap(true)
                  when :required
                    if value == true
                      required = Qt::Label.new("(Required)")
                    else
                      required = Qt::Label.new("(Optional)")
                    end
                    required.setFont(Cosmos.getFont("Arial", 10))
                    name_layout.addWidget(required)
                  when :values
                    if value.is_a? Array
                      value_widget = Qt::ComboBox.new()
                      value_widget.addItem(line_parts[parameter_index + 1])
                      value_widget.addItems(value)
                      value_widget.setEditable(true)
                      value_widget.connect(SIGNAL('currentIndexChanged(const QString&)')) do |text|
                        new_parts = @editor.current_line.split
                        new_parts[parameter_index + 1] = text
                        c = @editor.textCursor
                        c.movePosition(Qt::TextCursor::StartOfLine)
                        c.movePosition(Qt::TextCursor::EndOfLine, Qt::TextCursor::KeepAnchor)
                        c.insertText(new_parts.join(' '))
                      end
                      value_widget.connect(SIGNAL('editTextChanged(const QString&)')) do |text|
                        @editor.current_line.gsub(word, text)
                      end

                    else
                      value_widget = Qt::LineEdit.new(line_parts[parameter_index + 1])
                    end
                  end
                end
                layout.addLayout(name_layout)
                layout.addWidget(description)
                layout.addWidget(value_widget)

                # if word == line_parts[index + 1]
                #   value_widget.setStyleSheet("QLineEdit {background-color: green}")
                # end
              end
            end
          end
        end
      end
      layout.addStretch
      @splitter.addWidget(@gui_frame)
    end

    def get_keyword_meta
      return nil if keyword().empty?

      keyword_symbol = keyword().intern
      case @file_type
      when :target_base
        target = MetaConfigParser.load('target.yaml')
        keyword_meta = target.select {|item| item.keys[0] == keyword_symbol }[0]
        unless keyword_meta
          target = MetaConfigParser.load('cmd_tlm_server.yaml')
          keyword_meta = target.select {|item| item.keys[0] == keyword_symbol }[0]
        end
      when :target_config
      end
      keyword_meta
    end

    def initialize_variables
      @active_script = @editor
      @current_file = @filename
      @current_filename = nil
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
