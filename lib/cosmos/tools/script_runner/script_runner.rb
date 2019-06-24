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
  require 'cosmos/gui/qt_tool'
  require 'cosmos/tools/script_runner/script_runner_frame'
  require 'cosmos/tools/script_runner/script_runner_config'
  require 'cosmos/tools/script_runner/script_audit'
  require 'cosmos/gui/dialogs/progress_dialog'
  require 'cosmos/gui/dialogs/scroll_text_dialog'
end

module Cosmos

  class ScriptRunner < QtTool
    slots 'handle_tab_change(int)'
    slots 'context_menu(const QPoint&)'
    slots 'undo_available(bool)'

    UNTITLED_TAB_TEXT = '  Untitled  '
    MAX_RECENT_FILES = 20

    def initialize(options)
      # All code before super is executed twice in RubyQt Based classes
      super(options) # MUST BE FIRST
      Cosmos.load_cosmos_icon("script_runner.png")
      setAcceptDrops(true) # Allow dropping in files

      @server_config_file = options.server_config_file

      # Add procedures to search path
      System.paths['PROCEDURES'].each do |path|
        Cosmos.add_to_search_path(path)
      end

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()

      # Load icons
      @running_icon = Cosmos.get_icon('running.png')
      @no_icon = Qt::Icon.new

      begin
        # Always create the ScriptRunnerConfig but note that it's optional to pass a config file
        # If the user doesn't have one it will be created automatically if the default config is changed
        @config = ScriptRunnerConfig.new(options.config_file)
      rescue => error
        ExceptionDialog.new(self, error, "Error parsing #{options.config_file}")
      end

      @procedure_dir = System.paths['PROCEDURES'][0]
      @debug = false

      # Create the initial tab(s)
      initial_tabs = []
      ARGV.each do |argv_filename|
        proc_filename = find_procedure(argv_filename)
        initial_tabs << proc_filename if proc_filename
      end
      if options.run_procedure
        options.run_procedure = find_procedure(options.run_procedure)
        initial_tabs << options.run_procedure if options.run_procedure
      end
      initial_tabs.uniq!

      if initial_tabs.length == 0
        create_tab()
      else
        initial_tabs.each {|filename| create_tab(filename)}
      end

      if options.disconnect_mode
        script_toggle_disconnect(false)
      end

      if options.run_procedure
        run_procedure(options.run_procedure)
      end
    end

    def initialize_actions
      super()

      # File actions
      @file_new = Qt::Action.new(Cosmos.get_icon('file.png'), '&New', self)
      @file_new_keyseq = Qt::KeySequence.new('Ctrl+N')
      @file_new.shortcut  = @file_new_keyseq
      @file_new.statusTip = 'Start a new script'
      @file_new.connect(SIGNAL('triggered()')) { file_new() }

      @clear_file_open_recent = Qt::Action.new('&Clear Recent', self)
      @clear_file_open_recent.statusTip = 'Clear the recently opened file list'
      @clear_file_open_recent.connect(SIGNAL('triggered()')) { clear_file_open_recent() }

      @file_close = Qt::Action.new('&Close', self)
      @file_close_keyseq = Qt::KeySequence.new('Ctrl+W')
      @file_close.shortcut  = @file_close_keyseq
      @file_close.statusTip = 'Close the script'
      @file_close.connect(SIGNAL('triggered()')) { file_close() }

      @file_reload = Qt::Action.new('Re&load', self)
      @file_reload_keyseq = Qt::KeySequence.new('Ctrl+R')
      @file_reload.shortcut  = @file_reload_keyseq
      @file_reload.statusTip = 'Reload a script'
      @file_reload.connect(SIGNAL('triggered()')) { file_reload() }

      @file_save = Qt::Action.new(Cosmos.get_icon('save.png'), '&Save', self)
      @file_save_keyseq = Qt::KeySequence.new('Ctrl+S')
      @file_save.shortcut  = @file_save_keyseq
      @file_save.statusTip = 'Save the script'
      @file_save.connect(SIGNAL('triggered()')) { file_save(false) }

      @file_save_as = Qt::Action.new(Cosmos.get_icon('save_as.png'), 'Save &As', self)
      @file_save_as.statusTip = 'Save the script'
      @file_save_as.connect(SIGNAL('triggered()')) { file_save(true) }

      @file_options = Qt::Action.new('O&ptions', self)
      @file_options.statusTip = 'Application Options'
      @file_options.connect(SIGNAL('triggered()')) { file_options() }

      # Edit actions
      @edit_undo = Qt::Action.new(Cosmos.get_icon('undo.png'), '&Undo', self)
      @edit_undo_keyseq = Qt::KeySequence.new('Ctrl+Z')
      @edit_undo.shortcut  = @edit_undo_keyseq
      @edit_undo.statusTip = 'Undo'
      @edit_undo.connect(SIGNAL('triggered()')) { active_script_runner_frame().undo }

      @edit_redo = Qt::Action.new(Cosmos.get_icon('redo.png'), '&Redo', self)
      @edit_redo_keyseq = Qt::KeySequence.new('Ctrl+Y')
      @edit_redo.shortcut  = @edit_redo_keyseq
      @edit_redo.statusTip = 'Redo'
      @edit_redo.connect(SIGNAL('triggered()')) { active_script_runner_frame().redo }

      @edit_cut = Qt::Action.new(Cosmos.get_icon('cut.png'), 'Cu&t', self)
      @edit_cut_keyseq = Qt::KeySequence.new('Ctrl+X')
      @edit_cut.shortcut  = @edit_cut_keyseq
      @edit_cut.statusTip = 'Cut'
      @edit_cut.connect(SIGNAL('triggered()')) { active_script_runner_frame().cut }

      @edit_copy = Qt::Action.new(Cosmos.get_icon('copy.png'), '&Copy', self)
      @edit_copy_keyseq = Qt::KeySequence.new('Ctrl+C')
      @edit_copy.shortcut  = @edit_copy_keyseq
      @edit_copy.statusTip = 'Copy'
      @edit_copy.connect(SIGNAL('triggered()')) { active_script_runner_frame().copy }

      @edit_paste = Qt::Action.new('&Paste', self)
      @edit_paste_keyseq = Qt::KeySequence.new('Ctrl+V')
      @edit_paste.shortcut  = @edit_paste_keyseq
      @edit_paste.statusTip = 'Paste'
      @edit_paste.connect(SIGNAL('triggered()')) { active_script_runner_frame().paste }

      @edit_select_all = Qt::Action.new('Select &All', self)
      @edit_select_all_keyseq = Qt::KeySequence.new('Ctrl+A')
      @edit_select_all.shortcut  = @edit_select_all_keyseq
      @edit_select_all.statusTip = 'Select All'
      @edit_select_all.connect(SIGNAL('triggered()')) { active_script_runner_frame().select_all }

      @edit_comment = Qt::Action.new('Comment/Uncomment &Lines', self)
      @edit_comment_keyseq = Qt::KeySequence.new('Ctrl+K')
      @edit_comment.shortcut  = @edit_comment_keyseq
      @edit_comment.statusTip = 'Comment/Uncomment Lines'
      @edit_comment.connect(SIGNAL('triggered()')) { active_script_runner_frame().comment_or_uncomment_lines }

      @edit_zoom_in = Qt::Action.new('&Increase Font Size', self)
      @edit_zoom_in_keyseq = Qt::KeySequence.new(Qt::KeySequence::ZoomIn)
      @edit_zoom_in.shortcut  = @edit_zoom_in_keyseq
      @edit_zoom_in.connect(SIGNAL('triggered()')) { active_script_runner_frame().zoom_in }

      @edit_zoom_out = Qt::Action.new('&Decrease Font Size', self)
      @edit_zoom_out_keyseq = Qt::KeySequence.new(Qt::KeySequence::ZoomOut)
      @edit_zoom_out.shortcut  = @edit_zoom_out_keyseq
      @edit_zoom_out.connect(SIGNAL('triggered()')) { active_script_runner_frame().zoom_out }

      @edit_zoom_default = Qt::Action.new('Restore &Font Size', self)
      @edit_zoom_default.connect(SIGNAL('triggered()')) { active_script_runner_frame().zoom_default }

      # Search Actions
      @search_find = Qt::Action.new(Cosmos.get_icon('search.png'), '&Find', self)
      @search_find_keyseq = Qt::KeySequence.new('Ctrl+F')
      @search_find.shortcut  = @search_find_keyseq
      @search_find.statusTip = 'Find text'
      @search_find.connect(SIGNAL('triggered()')) do
        FindReplaceDialog.show_find(self)
      end

      @search_find_next = Qt::Action.new('Find &Next', self)
      @search_find_next_keyseq = Qt::KeySequence.new('F3')
      @search_find_next.shortcut  = @search_find_next_keyseq
      @search_find_next.statusTip = 'Find next instance'
      @search_find_next.connect(SIGNAL('triggered()')) do
        FindReplaceDialog.find_next(self)
      end

      @search_find_previous = Qt::Action.new('Find &Previous', self)
      @search_find_previous_keyseq = Qt::KeySequence.new('Shift+F3')
      @search_find_previous.shortcut  = @search_find_previous_keyseq
      @search_find_previous.statusTip = 'Find previous instance'
      @search_find_previous.connect(SIGNAL('triggered()')) do
        FindReplaceDialog.find_previous(self)
      end

      @search_replace = Qt::Action.new('&Replace', self)
      @search_replace_keyseq = Qt::KeySequence.new('Ctrl+H')
      @search_replace.shortcut  = @search_replace_keyseq
      @search_replace.statusTip = 'Replace'
      @search_replace.connect(SIGNAL('triggered()')) do
        FindReplaceDialog.show_replace(self)
      end

      # Script Actions
      @script_syntax_all = Qt::Action.new('&Ruby Syntax Check', self)
      @script_syntax_all.statusTip = 'Check ruby syntax of this script'
      @script_syntax_all.connect(SIGNAL('triggered()')) do
        active_script_runner_frame().ruby_syntax_check_text()
      end

      @script_mnemonic_all = Qt::Action.new('&Mnemonic Check', self)
      @script_mnemonic_all.statusTip = 'Check mnemonics of this script'
      @script_mnemonic_all.connect(SIGNAL('triggered()')) do
        active_script_runner_frame().mnemonic_check_text(active_script_runner_frame().text)
      end

      @script_execute_lines = Qt::Action.new('&Execute Selected Lines', self)
      @script_execute_lines.statusTip = 'Execute selected lines'
      @script_execute_lines.connect(SIGNAL('triggered()')) { active_script_runner_frame().run_selection }

      @script_execute_cursor = Qt::Action.new('E&xecute From Cursor', self)
      @script_execute_cursor.statusTip = 'Execute from cursor position'
      @script_execute_cursor.connect(SIGNAL('triggered()')) { active_script_runner_frame().run_from_cursor }

      @script_syntax_lines = Qt::Action.new('Ruby &Syntax Check Selected Lines', self)
      @script_syntax_lines.statusTip = 'Check ruby syntax of selected lines'
      @script_syntax_lines.connect(SIGNAL('triggered()')) { active_script_runner_frame().ruby_syntax_check_selection }

      @script_mnemonic_lines = Qt::Action.new('M&nemonic Check Selected Lines', self)
      @script_mnemonic_lines.statusTip = 'Check mnemonics of selected lines'
      @script_mnemonic_lines.connect(SIGNAL('triggered()')) { active_script_runner_frame().mnemonic_check_selection }

      @script_audit = Qt::Action.new('&Generate Cmd/Tlm Audit', self)
      @script_audit.statusTip = 'Generate audit about commands sent and telemetry checked'
      @script_audit.connect(SIGNAL('triggered()')) { script_audit() }

      @script_instrumented = Qt::Action.new('&View Instrumented Script', self)
      @script_instrumented.statusTip = 'View instrumented script'
      @script_instrumented.connect(SIGNAL('triggered()')) { script_view_instrumented() }

      @script_log_message = Qt::Action.new('Log Message to Script Log', self)
      @script_log_message.statusTip = 'Log Message to Script Log'
      @script_log_message.connect(SIGNAL('triggered()')) { script_log_message() }
      @script_log_message.setEnabled(false)

      @script_call_stack = Qt::Action.new('Show Call Stack', self)
      @script_call_stack.statusTip = 'Show Call Stack'
      @script_call_stack.connect(SIGNAL('triggered()')) { script_call_stack() }
      @script_call_stack.setEnabled(false)

      @script_error_backtrace = Qt::Action.new('Show Error Backtrace', self)
      @script_error_backtrace.statusTip = 'Show Error Backtrace from the last encountered exception'
      @script_error_backtrace.connect(SIGNAL('triggered()')) do
        ScriptRunnerFrame.show_backtrace = @script_error_backtrace.checked?
      end
      @script_error_backtrace.setCheckable(true)

      @script_debug = Qt::Action.new(Cosmos.get_icon('bug.png'), 'Toggle &Debug', self)
      @script_debug_keyseq = Qt::KeySequence.new('Ctrl+D')
      @script_debug.shortcut  = @script_debug_keyseq
      @script_debug.statusTip = 'Toggle debug capabilities for the script'
      @script_debug.connect(SIGNAL('triggered()')) { script_toggle_debug() }

      @script_disconnect = Qt::Action.new(Cosmos.get_icon('disconnected.png'), '&Toggle Disconnect', self)
      @script_disconnect_keyseq = Qt::KeySequence.new('Ctrl+T')
      @script_disconnect.shortcut  = @script_disconnect_keyseq
      @script_disconnect.statusTip = 'Toggle disconnect from the server'
      @script_disconnect.connect(SIGNAL('triggered()')) { script_toggle_disconnect() }
    end

    def initialize_menus
      # File Menu
      @file_menu = menuBar.addMenu('&File')
      @file_menu.addAction(@file_new)

      open_action = Qt::Action.new(self)
      open_action.shortcut = Qt::KeySequence.new('Ctrl+O')
      open_action.connect(SIGNAL('triggered()')) { file_open(@procedure_dir) }
      self.addAction(open_action)

      @file_open = @file_menu.addMenu('&Open')
      @file_open.setIcon(Cosmos.get_icon('open.png'))
      target_dirs_action(@file_open, System.paths['PROCEDURES'], 'procedures', method(:file_open))

      @file_open_recent = @file_menu.addMenu('Open &Recent')
      @file_open_recent.setIcon(Cosmos.get_icon('open.png'))
      settings = Qt::Settings.new('Ball Aerospace', self.class.to_s)
      if settings.contains('recent_files')
        recent = settings.value('recent_files').toStringList()
        recent.each do |filename|
          action = Qt::Action.new(filename, self)
          action.connect(SIGNAL('triggered()')) { open_filename(filename) }
          @file_open_recent.addAction(action)
        end
      end
      @file_open_recent.addSeparator()
      @file_open_recent.addAction(@clear_file_open_recent)

      @file_menu.addAction(@file_close)
      @file_menu.addAction(@file_reload)
      @file_menu.addSeparator()
      @file_menu.addAction(@file_save)
      @file_menu.addAction(@file_save_as)
      @file_menu.addSeparator()
      @file_menu.addAction(@file_options)
      @file_menu.addSeparator()
      @file_menu.addAction(@exit_action)

      # Edit Menu
      mode_menu = menuBar.addMenu('&Edit')
      mode_menu.addAction(@edit_undo)
      mode_menu.addAction(@edit_redo)
      mode_menu.addSeparator()
      mode_menu.addAction(@edit_cut)
      mode_menu.addAction(@edit_copy)
      mode_menu.addAction(@edit_paste)
      mode_menu.addSeparator()
      mode_menu.addAction(@edit_select_all)
      mode_menu.addSeparator()
      mode_menu.addAction(@edit_comment)
      mode_menu.addSeparator()
      mode_menu.addAction(@edit_zoom_in)
      mode_menu.addAction(@edit_zoom_out)
      mode_menu.addAction(@edit_zoom_default)

      # Search Menu
      view_menu = menuBar.addMenu('&Search')
      view_menu.addAction(@search_find)
      view_menu.addAction(@search_find_next)
      view_menu.addAction(@search_find_previous)
      view_menu.addAction(@search_replace)

      # Script Menu
      view_menu = menuBar.addMenu('Scrip&t')
      view_menu.addAction(@script_syntax_all)
      view_menu.addAction(@script_syntax_lines)
      view_menu.addSeparator()
      view_menu.addAction(@script_mnemonic_all)
      view_menu.addAction(@script_mnemonic_lines)
      view_menu.addSeparator()
      view_menu.addAction(@script_execute_lines)
      view_menu.addAction(@script_execute_cursor)
      view_menu.addSeparator()
      view_menu.addAction(@script_audit)
      view_menu.addAction(@script_instrumented)
      view_menu.addSeparator()
      view_menu.addAction(@script_log_message)
      view_menu.addAction(@script_call_stack)
      view_menu.addAction(@script_error_backtrace)
      view_menu.addAction(@script_debug)
      view_menu.addAction(@script_disconnect)

      # Help Menu
      @about_string = "Script Runner allows the user to execute commands "\
        "and take action on telemetry within a saveable script. "\
        "It allows the full power of the Ruby programming language "\
        "while defining several keywords to manipulate commands and telemetry in COSMOS.\n"

      initialize_help_menu()
    end

    def initialize_central_widget
      # Create the central widget
      @tab_book = Qt::TabWidget.new
      @tab_book.setMovable(true)
      @tab_book.setContextMenuPolicy(Qt::CustomContextMenu)
      connect(@tab_book,
              SIGNAL('customContextMenuRequested(const QPoint&)'),
              self,
              SLOT('context_menu(const QPoint&)'))
      connect(@tab_book,
              SIGNAL('currentChanged(int)'),
              self,
              SLOT('handle_tab_change(int)'))
      setCentralWidget(@tab_book)

      next_child = Qt::Shortcut.new(Qt::KeySequence.new(Qt::CTRL + Qt::Key_Tab), self)
      self.connect(next_child, SIGNAL('activated()')) { next_child() }
      # Note using Qt::KeySequence::PreviousChild does not work due to QT bug
      previous_child = Qt::Shortcut.new(Qt::KeySequence.new(Qt::CTRL + Qt::SHIFT + Qt::Key_Tab), self)
      self.connect(previous_child, SIGNAL('activated()')) { previous_child() }

      # Display a blank message to force the statusBar to show
      statusBar.showMessage("")
    end

    ###########################################
    # Drag files into ScriptRunner support
    ###########################################

    def dragEnterEvent(event)
      if event.mimeData.hasUrls
        event.acceptProposedAction();
      end
    end

    def dragMoveEvent(event)
      if event.mimeData.hasUrls
        event.acceptProposedAction();
      end
    end

    def dropEvent(event)
      event.mimeData.urls.each do |url|
        filename = url.toLocalFile
        extension = File.extname(filename).to_s.downcase
        if extension == '.rb' or extension == '.txt'
          file_open(filename)
        end
      end
    end

    ###########################################
    # File Menu Options
    ###########################################

    # File->New
    def file_new
      create_tab()
    end

    # File->Open
    def file_open(filename = nil)
      if File.directory?(filename)
        filenames = Qt::FileDialog.getOpenFileNames(self, "Select Script(s)", filename, "Scripts (*.rb);;All Files(*.*)")
      else
        filenames = [filename]
      end
      filenames.compact!
      return if filenames.nil? || filenames.empty?
      filenames.each do |filename|
        open_filename(filename)

        found = false
        @file_open_recent.actions.each do |action|
          found = true if action.text == filename
        end
        next if found
        action = Qt::Action.new(filename, self)
        action.connect(SIGNAL('triggered()')) { open_filename(filename) }
        @file_open_recent.insertAction(@file_open_recent.actions[0], action)
        # Add 2 for the separator and Clear Recent action
        if @file_open_recent.actions.length > (MAX_RECENT_FILES + 2)
          @file_open_recent.removeAction(@file_open_recent.actions[-3]) # ignore last 2
        end
      end
    end

    def clear_file_open_recent
      # Subtract 2 for the separator and Clear Recent action
      (@file_open_recent.actions.length - 2).times do
        @file_open_recent.removeAction(@file_open_recent.actions[0])
      end
    end

    def open_filename(filename)
      # If the user opens a file we already have open
      # just set the current tab to that file and return
      @tab_book.tabs.each_with_index do |tab, index|
        if tab.filename == filename
          @tab_book.setCurrentIndex(index)
          @tab_book.currentTab.set_text_from_file(filename)
          @tab_book.currentTab.filename = filename
          return
        end
      end

      if ((@tab_book.count == 1) &&
          @tab_book.currentTab.filename.empty? &&
          !@tab_book.currentTab.modified)
        # Active Tab is an unmodified Untitled so just open the file in it
        @tab_book.currentTab.set_text_from_file(filename)
        @tab_book.currentTab.filename = filename
        @tab_book.setTabText(@tab_book.currentIndex, File.basename(filename))
      else
        create_tab(filename)
      end

      update_title()
      @procedure_dir = File.dirname(filename)
      @procedure_dir << '/' if @procedure_dir[-1..-1] != '/' and @procedure_dir[-1..-1] != '\\'
    end

    # File->Reload
    def file_reload
      safe_to_continue = true
      if @tab_book.currentTab.modified
        case Qt::MessageBox.question(self, # parent
                                     'Discard Changes?', # title
                                     'Warning: Changes will be lost. Continue?', # text
                                     Qt::MessageBox::Yes | Qt::MessageBox::No, # buttons
                                     Qt::MessageBox::No) # default button
        when Qt::MessageBox::No
          safe_to_continue = false
        end
      end

      if safe_to_continue
        if active_script_runner_frame().filename.empty?
          active_script_runner_frame().set_text('')
        else
          active_script_runner_frame().set_text_from_file(active_script_runner_frame().filename)
        end
        @tab_book.currentTab.modified = false
        update_title()
      end
    end

    # File->Save and File->Save As
    def file_save(save_as = false)
      saved = false
      filename = active_script_runner_frame().filename
      if filename.empty?
        filename = Qt::FileDialog::getSaveFileName(self,         # parent
                                                   'Save As...', # caption
                                                   @procedure_dir + '/procedure.rb', # dir
                                                   'Procedure Files (*.rb)') # filter
      elsif save_as
        filename = Qt::FileDialog::getSaveFileName(self,         # parent
                                                   'Save As...', # caption
                                                   filename,     # dir
                                                   'Procedure Files (*.rb)') # filter
      end
      if not filename.nil? and not filename.empty?
        begin
          @tab_book.currentTab.filename = filename
          @tab_book.currentTab.modified = false
          @tab_book.setTabText(@tab_book.currentIndex, File.basename(filename))
          active_script_runner_frame().filename = filename
          File.open(filename, "w") {|file| file.write(active_script_runner_frame().text)}
          saved = true
          update_title()
          statusBar.showMessage("#{filename} saved")
          @procedure_dir = File.dirname(filename)
          @procedure_dir << '/' if @procedure_dir[-1..-1] != '/' and @procedure_dir[-1..-1] != '\\'
        rescue => error
          statusBar.showMessage("Error Saving Script : #{error.class} : #{error.message}")
        end
      end

      return saved
    end

    # File->Close
    def file_close
      if prompt_for_save_if_needed('Save Current Script?')
        if @tab_book.count > 1
          close_active_tab()
        else
          active_script_runner_frame().stop_message_log
          active_script_runner_frame().clear_breakpoints
          @tab_book.setTabText(0, '  Untitled  ')
          @tab_book.currentTab.clear
        end
        update_title()
      end
    end

    # File->Options
    def file_options
      dialog = Qt::Dialog.new(self)
      dialog.setWindowTitle('Script Runner Options')
      layout = Qt::VBoxLayout.new

      form = Qt::FormLayout.new
      box = Qt::DoubleSpinBox.new
      box.setRange(0, 60)
      box.setValue(ScriptRunnerFrame.line_delay)
      form.addRow("&Delay between each script line:", box)
      pause_on_error = Qt::CheckBox.new
      form.addRow("&Pause on error:", pause_on_error)
      monitor = Qt::CheckBox.new
      form.addRow("&Monitor limits:", monitor)
      if ScriptRunnerFrame.pause_on_error
        pause_on_error.setCheckState(Qt::Checked)
      else
        pause_on_error.setCheckState(Qt::Unchecked)
      end
      pause_on_red = Qt::CheckBox.new
      form.addRow("Pause on &red limit:", pause_on_red)
      if ScriptRunnerFrame.monitor_limits
        monitor.setCheckState(Qt::Checked)
        pause_on_red.setCheckState(Qt::Checked) if ScriptRunnerFrame.pause_on_red
      else
        pause_on_red.setEnabled(false)
      end
      monitor.connect(SIGNAL('stateChanged(int)')) do
        if monitor.isChecked()
          pause_on_red.setEnabled(true)
        else
          pause_on_red.setCheckState(Qt::Unchecked)
          pause_on_red.setEnabled(false)
        end
      end
      layout.addLayout(form)

      divider = Qt::Frame.new
      divider.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Raised)
      divider.setLineWidth(1)
      layout.addWidget(divider)

      ok = Qt::PushButton.new('Ok')
      ok.setDefault(true)
      ok.connect(SIGNAL('clicked(bool)')) do
        ScriptRunnerFrame.line_delay = box.value
        ScriptRunnerFrame.pause_on_error = (pause_on_error.checkState == Qt::Checked)
        ScriptRunnerFrame.monitor_limits = (monitor.checkState == Qt::Checked)
        ScriptRunnerFrame.pause_on_red = (pause_on_red.checkState == Qt::Checked)
        @config.write_config
        dialog.accept
      end
      cancel = Qt::PushButton.new('Cancel')
      cancel.connect(SIGNAL('clicked(bool)')) { dialog.reject }
      button_layout = Qt::HBoxLayout.new
      button_layout.addWidget(ok)
      button_layout.addWidget(cancel)
      layout.addLayout(button_layout)
      dialog.setLayout(layout)
      dialog.exec
      dialog.dispose
    end

    ###########################################
    # Script Menu Options
    ###########################################

    include ScriptAudit

    # Script->View Instrumented
    def script_view_instrumented
      begin
        instrumented_script =
          ScriptRunnerFrame.instrument_script(active_script_runner_frame().text,
                                              active_script_runner_frame().filename,
                                              true)
      rescue StopScript
        return
      end

      # Show Dialog box containing script code
      box = Qt::Dialog.new(self)
      box.setWindowTitle('Instrumented Script')
      text = Qt::PlainTextEdit.new
      text.setWordWrapMode(Qt::TextOption::NoWrap)
      text.setReadOnly(true)
      text.setPlainText(instrumented_script)
      layout = Qt::VBoxLayout.new
      layout.addWidget(text)
      ok = Qt::PushButton.new('OK')
      ok.setDefault(true)
      ok.connect(SIGNAL('clicked(bool)')) { box.accept }
      button_layout = Qt::HBoxLayout.new
      button_layout.addStretch
      button_layout.addWidget(ok)
      button_layout.addStretch
      layout.addLayout(button_layout)
      box.setLayout(layout)
      box.setMinimumWidth([Qt::CoreApplication.instance.desktop.availableGeometry.width,
                          text.document.size.width].min)
      screen_height = Qt::CoreApplication.instance.desktop.availableGeometry.height
      preferred_height = (text.document.size.height * text.fontMetrics.lineSpacing) +
        text.horizontalScrollBar.height + ok.sizeHint.height + (layout.spacing * 5)
      box.setMinimumHeight([screen_height, preferred_height].min)
      box.exec
      box.dispose
    end

    # Script->Log Message to Script Log
    def script_log_message
      message = get_scriptrunner_log_message()
      if message
        active_script_runner_frame().scriptrunner_puts 'User logged: '  + message.to_s
        active_script_runner_frame().handle_output_io
      end
    end

    # Script->Show Call Stack
    def script_call_stack
      trace = active_script_runner_frame().current_backtrace
      ScrollTextDialog.new(self, 'Call Stack', trace.join("\n"))
    end

    # Script->Toggle Debug
    def script_toggle_debug
      @debug = !@debug
      if @tab_book.count > 0
        (0..(@tab_book.count - 1)).each do |index|
          @tab_book.widget(index).toggle_debug(@debug)
        end
      end
    end

    # Script->Toggle Disconnect
    def script_toggle_disconnect(ask_for_config_file = true)
      @server_config_file = active_script_runner_frame().toggle_disconnect(@server_config_file, ask_for_config_file)
    end

    ###########################################
    # Callbacks
    ###########################################

    # Called by the FindReplaceDialog to get the text to search
    def search_text
      active_script_runner_frame().script
    end

    def undo_available(bool)
      update_title()
    end

    def closeEvent(event)
      if active_script_runner_frame().prompt_if_running_on_close()
        if prompt_for_save_if_needed_on_close()
          settings = Qt::Settings.new('Ball Aerospace', self.class.to_s)
          recent_files = @file_open_recent.actions.collect {|action| action.text }
          # Ignore the last 2 because of the separator and Clear Recent action
          settings.setValue('recent_files', Qt::Variant.new(recent_files[0..-3]))
          shutdown_cmd_tlm()
          @tab_book.tabs.each_with_index do |tab, index|
            tab.stop_message_log
          end
          super(event)
        else
          event.ignore()
        end
      else
        event.ignore()
      end
    end

    # This method disables things that you shouldn't do while running
    def run_callback(script_runner_frame = nil)
      if script_runner_frame
        @tab_book.tabs.each_with_index do |tab, index|
          if tab != script_runner_frame
            @tab_book.setTabEnabled(index, false)
          else
            @tab_book.tabBar.setTabIcon(index, @running_icon)
          end
        end
      end
      disable_menu_items()
    end

    # This method reenables things after running
    def stop_callback(script_runner_frame = nil)
      if script_runner_frame
        @tab_book.tabs.each_with_index do |tab, index|
          @tab_book.setTabEnabled(index, true)
          @tab_book.tabBar.setTabIcon(index, @no_icon)
        end
      end
      enable_menu_items()
    end

    def enable_menu_items
      # Enable File Menu Items
      @file_new.setEnabled(true)
      @file_open.setEnabled(true)
      @file_close.setEnabled(true)
      @file_reload.setEnabled(true)
      @file_save.setEnabled(true)
      @file_save_as.setEnabled(true)
      @file_options.setEnabled(true)

      # Enable Edit Menu Items
      @edit_undo.setEnabled(true)
      @edit_redo.setEnabled(true)
      @edit_cut.setEnabled(true)
      @edit_copy.setEnabled(true)
      @edit_paste.setEnabled(true)
      @edit_select_all.setEnabled(true)
      @edit_comment.setEnabled(true)

      # Enable Script Menu Items
      @script_syntax_all.setEnabled(true)
      @script_syntax_lines.setEnabled(true)
      @script_mnemonic_all.setEnabled(true)
      @script_mnemonic_lines.setEnabled(true)
      @script_execute_lines.setEnabled(true)
      @script_execute_cursor.setEnabled(true)

      # Disable Script Runtime Items'
      @script_log_message.setEnabled(false)
      @script_call_stack.setEnabled(false)
    end

    def disable_menu_items
      # Disable File Menu Items
      @file_new.setEnabled(false)
      @file_open.setEnabled(false)
      @file_close.setEnabled(false)
      @file_reload.setEnabled(false)
      @file_save.setEnabled(false)
      @file_save_as.setEnabled(false)
      @file_options.setEnabled(false)

      # Disable Edit Menu Items
      @edit_undo.setEnabled(false)
      @edit_redo.setEnabled(false)
      @edit_cut.setEnabled(false)
      @edit_copy.setEnabled(false)
      @edit_paste.setEnabled(false)
      @edit_select_all.setEnabled(false)
      @edit_comment.setEnabled(false)

      # Disable Script Menu Items
      @script_syntax_all.setEnabled(false)
      @script_syntax_lines.setEnabled(false)
      @script_mnemonic_all.setEnabled(false)
      @script_mnemonic_lines.setEnabled(false)
      @script_execute_lines.setEnabled(false)
      @script_execute_cursor.setEnabled(false)

      # Enable Script Runtime Items
      @script_log_message.setEnabled(true)
      @script_call_stack.setEnabled(true)
    end

    # Handle the user changing tabs
    def handle_tab_change(index)
      update_title()
    end

    def next_child
      index = @tab_book.currentIndex + 1
      index = 0 if index >= @tab_book.count
      @tab_book.setCurrentIndex(index)
      update_title()
    end

    def previous_child
      index = @tab_book.currentIndex - 1
      index = @tab_book.count - 1 if index < 0
      @tab_book.setCurrentIndex(index)
      update_title()
    end

    def context_menu(point)
      index = 0
      @tab_book.tabBar.count.times do
        break if @tab_book.tabBar.tabRect(index).contains(point)
        index += 1
      end

      return if (index == @tab_book.tabBar.count)

      # Bring the right clicked tab to the front
      @tab_book.setCurrentIndex(index)

      menu = Qt::Menu.new()

      new_action = Qt::Action.new("&New", self)
      new_action.statusTip = "Create a new script"
      new_action.connect(SIGNAL('triggered()')) { file_new() }
      menu.addAction(new_action)

      close_action = Qt::Action.new("&Close", self)
      close_action.statusTip = "Close the script"
      close_action.connect(SIGNAL('triggered()')) { file_close() }
      menu.addAction(close_action)

      save_action = Qt::Action.new("&Save", self)
      save_action.statusTip = "Save the script"
      save_action.connect(SIGNAL('triggered()')) { file_save(false) }
      menu.addAction(save_action)

      save_action = Qt::Action.new("Save &As", self)
      save_action.statusTip = "Save the script as"
      save_action.connect(SIGNAL('triggered()')) { file_save(true) }
      menu.addAction(save_action)

      menu.exec(@tab_book.mapToGlobal(point))
      menu.dispose
    end

    #############################################################
    # Helper Methods
    #############################################################

    # Called by cosmos_script_module by the user calling the status_bar scripting method
    def script_set_status(message)
      Qt.execute_in_main_thread(true) do
        # Check for self.disposed? to work around crash when using SimpleCov
        unless self.disposed?
          status_bar = statusBar()
          status_bar.showMessage(message)
        end
      end
    end

    # Updates the title appropriately to show the tabs filename and modified status
    def update_title
      if @tab_book.currentTab.filename.empty?
        self.setWindowTitle("Script Runner : Untitled")
      else
        self.setWindowTitle("Script Runner : #{@tab_book.currentTab.filename}")
      end
      self.setWindowTitle(self.windowTitle << '*') if @tab_book.currentTab.modified
    end

    # Returns the script runner frame of the active tab
    def active_script_runner_frame
      @tab_book.currentTab
    end

    # Creates a new tab
    def create_tab(filename = '')
      if filename.empty?
        tab_item_name = UNTITLED_TAB_TEXT
      else
        tab_item_name = '  ' + File.basename(filename) + '  '
      end

      script_runner_frame = ScriptRunnerFrame.new(self)
      script_runner_frame.toggle_debug(@debug)
      script_runner_frame.setContentsMargins(5,5,5,5)
      connect(script_runner_frame,
              SIGNAL('undoAvailable(bool)'),
              self,
              SLOT('undo_available(bool)'))
      script_runner_frame.run_callback = method(:run_callback)
      script_runner_frame.stop_callback = method(:stop_callback)
      script_runner_frame.set_text_from_file(filename) unless filename.empty?
      script_runner_frame.filename = filename
      # Update the title if the frame changes so we can add/remove the asterix
      script_runner_frame.connect(SIGNAL('modificationChanged(bool)')) { update_title() }

      @tab_book.addTab(script_runner_frame, tab_item_name)
      @tab_book.setCurrentIndex(@tab_book.count-1) # index is 0 based
      # Set the focus on the input now that we've added the tab
      script_runner_frame.setFocus
      update_title()
    end

    # Closes the active tab
    def close_active_tab
      if @tab_book.count > 1
        active_script_runner_frame().stop_message_log
        active_script_runner_frame().clear_breakpoints
        tab_index = @tab_book.currentIndex
        @tab_book.removeTab(tab_index)
        if tab_index >= 1
          @tab_book.setCurrentIndex(tab_index - 1)
        else
          @tab_book.setCurrentIndex(0)
        end
      end
    end

    # Prompts for save if the current tab has been modified
    def prompt_for_save_if_needed(message = 'Save?')
      safe_to_continue = true
      if @tab_book.currentTab.modified
        case Qt::MessageBox.question(
          self,    # parent
          'Save?', # title
          message, # text
          Qt::MessageBox::Yes | Qt::MessageBox::No | Qt::MessageBox::Cancel, # buttons
          Qt::MessageBox::Cancel) # default button
        when Qt::MessageBox::Cancel
          safe_to_continue = false
        when Qt::MessageBox::Yes
          saved = file_save(false)
          if not saved
            safe_to_continue = false
          end
        end
      end
      return safe_to_continue
    end

    # Prompts the user that unsaved changes have been made before they close the app
    def prompt_for_save_if_needed_on_close
      safe_to_continue = true
      @tab_book.tabs.each_with_index do |tab, index|
        if tab.modified
          @tab_book.setCurrentIndex(index)
          if tab.filename.empty?
            message = "Save changes to 'Untitled'?"
          else
            message = "Save changes to '#{tab.filename}'?"
          end
          safe_to_continue = prompt_for_save_if_needed(message)
          #~ break unless safe_to_continue
        end
      end
      return safe_to_continue
    end

    def find_procedure(filename)
      # If the filename is already sufficient, just expand the path.
      return File.expand_path(filename) if File.exist?(filename)

      # If the filename wasn't sufficient, can we find the file in one of the
      # system procedure directories?
      System.paths['PROCEDURES'].each do |path|
        new_filename = File.join(path, filename)
        return File.expand_path(new_filename) if File.exist?(new_filename)
      end

      # Ok, how about one of the target procedure directories?
      System.targets.each do |target_name, target|
        new_filename = File.join(target.dir, 'procedures', filename)
        return File.expand_path(new_filename) if File.exist?(new_filename)
      end

      # Couldn't find the file anywhere.
      return nil
    end

    def run_procedure(filename)
      # Switch to the desired tab and begin execution
      @tab_book.tabs.each_with_index do |tab, index|
        if tab.filename == filename
          @tab_book.setCurrentIndex(index)
        end
      end
      @tab_book.currentTab.run()
    end

    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.width = 750
          options.height = 600
          options.title = "Script Runner : Untitled"
          options.auto_size = false
          options.server_config_file = CmdTlmServer::DEFAULT_CONFIG_FILE
          options.run_procedure = nil
          options.disconnect_mode = false

          option_parser.separator "Script Runner Specific Options:"
          option_parser.on("-s", "--server FILE", "Use the specified server configuration file for disconnect mode") do |arg|
            options.server_config_file = arg
          end
          option_parser.on("-r", "--run FILE", "Open and run the specified procedure") do |arg|
            options.run_procedure = arg
          end
          option_parser.on("-d", "--disconnect", "Start in disconnect mode") do |arg|
            options.disconnect_mode = true
          end
        end

        super(option_parser, options)
      end
    end
  end
end
