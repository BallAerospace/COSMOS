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
  require 'cosmos/tools/config_editor/config_editor_frame'
  require 'cosmos/gui/dialogs/progress_dialog'
  require 'cosmos/gui/dialogs/scroll_text_dialog'
end

module Cosmos
  class ConfigEditor < QtTool
    # Class to intercept keyPressEvents
    class MyTreeView < Qt::TreeView
      attr_accessor :keyPressCallback
      def keyPressEvent(event)
        call_super = @keyPressCallback.call(event)
        super(event) if call_super
      end
    end

    slots 'handle_tab_change(int)'
    slots 'tab_context_menu(const QPoint&)'
    slots 'undo_available(bool)'

    UNTITLED = 'Untitled'
    UNTITLED_TAB_TEXT = "  #{UNTITLED}  "
    # Mapping of the human readable configuration name to an array containing the
    # yaml file name and typical location of the configuration file
    CONFIGURATION_FILES = {
      "System Configuration" =>
        ["system", "/config/system/system.txt"],
      "Target Configuration" =>
        ["target", "/config/targets/TARGET/target.txt"],
      "Server Configuration" =>
        ["cmd_tlm_server", "/config/tools/cmd_tlm_server/cmd_tlm_server.txt"],
      "Command and Telemetry Configuration" =>
        ["command_telemetry", "/config/targets/TARGET/cmd_tlm/*.txt"],
      "Screen Definition" =>
        ["screen", "/config/targets/TARGET/screens/*.txt"],
      "Separator" => [nil, nil],
      "Data Viewer Configuration" =>
        ["data_viewer", "/config/tools/data_viewer/data_viewer.txt"],
      "Handbook Creator Configuration" =>
        ["handbook_creator", "/config/tools/handbook_creator/handbook_creator.txt"],
      "Launcher Configuration" =>
        ["launcher", "/config/tools/launcher/launcher.txt"],
      "Limits Monitor Configuration" =>
        ["limits_monitor", "/config/tools/limits_monitor/limits_monitor.txt"],
      "Script Runner Configuration" =>
        ["script_runner", "/config/tools/script_runner/script_runner.txt"],
      "Table Manager Configuration" =>
        ["table_manager", "/config/tools/table_manager/table_manager.txt"],
      "Test Runner Configuration" =>
        ["test_runner", "/config/tools/test_runner/test_runner.txt"],
      "Telemetry Extractor Configuration" =>
        ["tlm_extractor", "/config/tools/tlm_extractor/tlm_extractor.txt"],
      "Telemetry Grapher Configuration" =>
        ["tlm_grapher", "/config/tools/tlm_grapher/tlm_grapher.txt"],
      "Telemetry Viewer Configuration" =>
        ["tlm_viewer", "/config/tools/tlm_viewer/tlm_viewer.txt"],
    }

    def initialize(options)
      # All code before super is executed twice in RubyQt Based classes
      super(options) # MUST BE FIRST
      Cosmos.load_cosmos_icon("config_editor.png")
      setAcceptDrops(true) # Allow dropping in files

      @procedure_dir = Cosmos::USERPATH
      @file_type = "none"

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()

      if options.filename
        file_open(options.filename)
      else
        create_tab()
      end
    end

    def initialize_actions
      super()

      # File actions
      @file_new = Qt::Action.new(Cosmos.get_icon('file.png'), tr('&New'), self)
      @file_new_keyseq = Qt::KeySequence.new(tr('Ctrl+N'))
      @file_new.shortcut  = @file_new_keyseq
      @file_new.statusTip = tr('Start a new file')
      @file_new.connect(SIGNAL('triggered()')) { file_new() }

      @file_close = Qt::Action.new(tr('&Close'), self)
      @file_close_keyseq = Qt::KeySequence.new(tr('Ctrl+W'))
      @file_close.shortcut  = @file_close_keyseq
      @file_close.statusTip = tr('Close the file')
      @file_close.connect(SIGNAL('triggered()')) { file_close() }

      @file_reload = Qt::Action.new(tr('&Reload'), self)
      @file_reload_keyseq = Qt::KeySequence.new(tr('Ctrl+R'))
      @file_reload.shortcut  = @file_reload_keyseq
      @file_reload.statusTip = tr('Reload a file')
      @file_reload.connect(SIGNAL('triggered()')) { file_reload() }

      @file_save = Qt::Action.new(Cosmos.get_icon('save.png'), tr('&Save'), self)
      @file_save_keyseq = Qt::KeySequence.new(tr('Ctrl+S'))
      @file_save.shortcut  = @file_save_keyseq
      @file_save.statusTip = tr('Save the file')
      @file_save.connect(SIGNAL('triggered()')) { file_save(false) }

      @file_save_as = Qt::Action.new(Cosmos.get_icon('save_as.png'), tr('Save &As'), self)
      @file_save_as.statusTip = tr('Save the file')
      @file_save_as.connect(SIGNAL('triggered()')) { file_save(true) }

      # Edit actions
      @edit_undo = Qt::Action.new(Cosmos.get_icon('undo.png'), tr('&Undo'), self)
      @edit_undo_keyseq = Qt::KeySequence.new(tr('Ctrl+Z'))
      @edit_undo.shortcut  = @edit_undo_keyseq
      @edit_undo.statusTip = tr('Undo')
      @edit_undo.connect(SIGNAL('triggered()')) { active_config_editor_frame().undo }

      @edit_redo = Qt::Action.new(Cosmos.get_icon('redo.png'), tr('&Redo'), self)
      @edit_redo_keyseq = Qt::KeySequence.new(tr('Ctrl+Y'))
      @edit_redo.shortcut  = @edit_redo_keyseq
      @edit_redo.statusTip = tr('Redo')
      @edit_redo.connect(SIGNAL('triggered()')) { active_config_editor_frame().redo }

      @edit_cut = Qt::Action.new(Cosmos.get_icon('cut.png'), tr('Cu&t'), self)
      @edit_cut_keyseq = Qt::KeySequence.new(tr('Ctrl+X'))
      @edit_cut.shortcut  = @edit_cut_keyseq
      @edit_cut.statusTip = tr('Cut')
      @edit_cut.connect(SIGNAL('triggered()')) { active_config_editor_frame().cut }

      @edit_copy = Qt::Action.new(Cosmos.get_icon('copy.png'), tr('&Copy'), self)
      @edit_copy_keyseq = Qt::KeySequence.new(tr('Ctrl+C'))
      @edit_copy.shortcut  = @edit_copy_keyseq
      @edit_copy.statusTip = tr('Copy')
      @edit_copy.connect(SIGNAL('triggered()')) { active_config_editor_frame().copy }

      @edit_paste = Qt::Action.new(tr('&Paste'), self)
      @edit_paste_keyseq = Qt::KeySequence.new(tr('Ctrl+V'))
      @edit_paste.shortcut  = @edit_paste_keyseq
      @edit_paste.statusTip = tr('Paste')
      @edit_paste.connect(SIGNAL('triggered()')) { active_config_editor_frame().paste }

      @edit_select_all = Qt::Action.new(tr('Select &All'), self)
      @edit_select_all_keyseq = Qt::KeySequence.new(tr('Ctrl+A'))
      @edit_select_all.shortcut  = @edit_select_all_keyseq
      @edit_select_all.statusTip = tr('Select All')
      @edit_select_all.connect(SIGNAL('triggered()')) { active_config_editor_frame().select_all }

      @edit_comment = Qt::Action.new(tr('Comment/Uncomment &Lines'), self)
      @edit_comment_keyseq = Qt::KeySequence.new(tr('Ctrl+K'))
      @edit_comment.shortcut  = @edit_comment_keyseq
      @edit_comment.statusTip = tr('Comment/Uncomment Lines')
      @edit_comment.connect(SIGNAL('triggered()')) { active_config_editor_frame().comment_or_uncomment_lines }

      # Search Actions
      @search_find = Qt::Action.new(Cosmos.get_icon('search.png'), tr('&Find'), self)
      @search_find_keyseq = Qt::KeySequence.new(tr('Ctrl+F'))
      @search_find.shortcut  = @search_find_keyseq
      @search_find.statusTip = tr('Find text')
      @search_find.connect(SIGNAL('triggered()')) do
        FindReplaceDialog.show_find(self)
      end

      @search_find_next = Qt::Action.new(tr('Find &Next'), self)
      @search_find_next_keyseq = Qt::KeySequence.new(tr('F3'))
      @search_find_next.shortcut  = @search_find_next_keyseq
      @search_find_next.statusTip = tr('Find next instance')
      @search_find_next.connect(SIGNAL('triggered()')) do
        FindReplaceDialog.find_next(self)
      end

      @search_find_previous = Qt::Action.new(tr('Find &Previous'), self)
      @search_find_previous_keyseq = Qt::KeySequence.new(tr('Shift+F3'))
      @search_find_previous.shortcut  = @search_find_previous_keyseq
      @search_find_previous.statusTip = tr('Find previous instance')
      @search_find_previous.connect(SIGNAL('triggered()')) do
        FindReplaceDialog.find_previous(self)
      end

      @search_replace = Qt::Action.new(tr('&Replace'), self)
      @search_replace_keyseq = Qt::KeySequence.new(tr('Ctrl+H'))
      @search_replace.shortcut  = @search_replace_keyseq
      @search_replace.statusTip = tr('Replace')
      @search_replace.connect(SIGNAL('triggered()')) do
        FindReplaceDialog.show_replace(self)
      end

      @type_group = Qt::ActionGroup.new(self)
      CONFIGURATION_FILES.each do |name, info|
        if name == 'Separator'
          action = Qt::Action.new(@type_group)
          action.setSeparator(true)
        else
          action = Qt::Action.new(name, @type_group)
          action.statusTip = info[1] # Path
          action.setCheckable(true)
        end
      end
      # Throw Unknown on the end after a separator
      action = Qt::Action.new(@type_group)
      action.setSeparator(true)
      action = Qt::Action.new("Unknown", @type_group)
      action.setCheckable(true)

      @type_group.connect(SIGNAL('triggered(QAction*)')) do |action|
        active_config_editor_frame.set_file_type(action.text)
        update_cursor()
      end

      @create_target = Qt::Action.new(tr('&Create Target'), self)
      @create_target.statusTip = tr('Create a new COSMOS target')
      @create_target.connect(SIGNAL('triggered()')) { create_target() }
    end

    def initialize_menus
      # File Menu
      @file_menu = menuBar.addMenu(tr('&File'))
      @file_menu.addAction(@file_new)

      open_action = Qt::Action.new(self)
      open_action.shortcut = Qt::KeySequence.new(tr('Ctrl+O'))
      open_action.connect(SIGNAL('triggered()')) { file_open(@procedure_dir) }
      self.addAction(open_action)

      @file_open = @file_menu.addMenu(tr('&Open'))
      @file_open.setIcon(Cosmos.get_icon('open.png'))
      target_dirs_action(@file_open, File.join(Cosmos::USERPATH,'config'), '', method(:file_open))

      @file_menu.addAction(@file_close)
      @file_menu.addAction(@file_reload)
      @file_menu.addSeparator()
      @file_menu.addAction(@file_save)
      @file_menu.addAction(@file_save_as)
      @file_menu.addSeparator()
      @file_menu.addAction(@exit_action)

      # Edit Menu
      mode_menu = menuBar.addMenu(tr('&Edit'))
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

      # Search Menu
      view_menu = menuBar.addMenu(tr('&Search'))
      view_menu.addAction(@search_find)
      view_menu.addAction(@search_find_next)
      view_menu.addAction(@search_find_previous)
      view_menu.addAction(@search_replace)

      # File Type Menu
      type_menu = menuBar.addMenu(tr('File &Type'))
      type_menu.addActions(@type_group.actions)

      # Actions Menu
      actions_menu = menuBar.addMenu(tr('&Actions'))
      actions_menu.addAction(@create_target)

      # Help Menu
      @about_string = "Config Editor allows the user to edit COSMOS configuration "\
        "files with contextual help. "\

      initialize_help_menu()
    end

    def initialize_central_widget
      # Create a splitter to hold the file tree and tab widget
      @splitter = Qt::Splitter.new(Qt::Horizontal, self)

      @fs_model = Qt::FileSystemModel.new
      @fs_model.setRootPath(Cosmos::USERPATH)
      @tree_view = MyTreeView.new(@splitter)
      @tree_view.setModel(@fs_model)
      @tree_view.setRootIndex(@fs_model.index(Cosmos::USERPATH))
      @tree_view.setColumnHidden(1, true) # Size
      @tree_view.setColumnHidden(2, true) # Type
      @tree_view.setColumnHidden(3, true) # Date Modified
      @tree_view.connect(SIGNAL('activated(const QModelIndex&)')) do |index|
        select_or_load_file(@fs_model.filePath(index))
      end
      @tree_view.connect(SIGNAL('clicked(const QModelIndex&)')) do |index|
        select_or_load_file(@fs_model.filePath(index))
      end
      @tree_view.setContextMenuPolicy(Qt::CustomContextMenu)
      @tree_view.connect(SIGNAL('customContextMenuRequested(const QPoint&)')) do |point|
        tree_context_menu(point)
      end
      @tree_view.keyPressCallback = lambda do |event|
        case event.key
        when Qt::Key_Delete
          delete_path(@fs_model.filePath(@tree_view.currentIndex()))
        end
        true # call super
      end

      @tab_book = Qt::TabWidget.new(@splitter)
      @tab_book.setMovable(true)
      @tab_book.setContextMenuPolicy(Qt::CustomContextMenu)
      connect(@tab_book,
              SIGNAL('customContextMenuRequested(const QPoint&)'),
              self,
              SLOT('tab_context_menu(const QPoint&)'))
      connect(@tab_book,
              SIGNAL('currentChanged(int)'),
              self,
              SLOT('handle_tab_change(int)'))
      @splitter.setSizes([200, 800]) # Rough split of the widget
      setCentralWidget(@splitter)

      # Display a blank message to force the statusBar to show
      statusBar.showMessage("")
      @status_bar_right_label = Qt::Label.new
      statusBar.addPermanentWidget(@status_bar_right_label)
    end

    def select_or_load_file(file_path)
      return if File.directory?(file_path)
      found = false
      # If the file is already open select the tab
      @tab_book.tabs.each_with_index do |tab, index|
        if tab.filename == file_path
          found = true
          @tab_book.setCurrentIndex(index)
        end
      end
      file_open(file_path) unless found
    end

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

    def tree_context_menu(point)
      menu = Qt::Menu.new()

      delete_action = Qt::Action.new(tr("Delete"), self)
      delete_action.statusTip = tr("Delete file")
      delete_action.connect(SIGNAL('triggered()')) do
        delete_path(@fs_model.filePath(@tree_view.indexAt(point)))
      end
      menu.addAction(delete_action)

      menu.exec(@tree_view.mapToGlobal(point))
      menu.dispose
    end

    def delete_path(path)
      case Qt::MessageBox.warning(self, "Delete!", "Are you sure you want to delete #{path}?",
      Qt::MessageBox::Yes | Qt::MessageBox::No, # buttons
      Qt::MessageBox::Yes) # default button
      when Qt::MessageBox::Yes
        FileUtils.rm_rf path
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
        filename = Qt::FileDialog.getOpenFileName(self, "Select File", filename)
      end
      unless filename.nil? || filename.empty?
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
      update_tree()
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
        if active_config_editor_frame().filename.empty?
          active_config_editor_frame().set_text('')
        else
          active_config_editor_frame().set_text_from_file(active_config_editor_frame().filename)
        end
        @tab_book.currentTab.modified = false
        update_title()
      end
    end

    # File->Save and File->Save As
    def file_save(save_as = false)
      saved = false
      filename = active_config_editor_frame().filename
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
          active_config_editor_frame().filename = filename
          File.open(filename, "w") {|file| file.write(active_config_editor_frame().text)}
          saved = true
          update_title()
          update_tree()
          statusBar.showMessage(tr("#{filename} saved"))
          @procedure_dir = File.dirname(filename)
          @procedure_dir << '/' if @procedure_dir[-1..-1] != '/' and @procedure_dir[-1..-1] != '\\'
        rescue => error
          statusBar.showMessage(tr("Error Saving File : #{error.class} : #{error.message}"))
        end
      end

      return saved
    end

    # File->Close
    def file_close
      if prompt_for_save_if_needed('Save Current File?')
        if @tab_book.count > 1
          close_active_tab()
        else
          @tab_book.setTabText(0, UNTITLED_TAB_TEXT)
          @tab_book.currentTab.clear
        end
        update_title()
      end
    end

    ###########################################
    # Actions
    ###########################################

    def create_target()
      qt_boolean = Qt::Boolean.new
      target = Qt::InputDialog::getText(self, "Target Name",
        "Enter the name of the target.\nUse underscores to separate words.\n"\
        "Try to keep target names relatively short.\n\nFor example: PWR_SUPPLY\n",
        Qt::LineEdit::Normal, '', qt_boolean)
      return if qt_boolean.nil? # Cancelled
      target.upcase!
      target_folder = File.join(Cosmos::USERPATH, 'config', 'targets', target)
      if File.exist?(target_folder)
        Qt::MessageBox.warning(self, "Existing Target", "The specified target already exists!")
        return
      end
      Dir.mkdir(target_folder)
      %w(cmd_tlm lib procedures screens sequences tables tools).each do |folder|
        Dir.mkdir File.join(target_folder, folder)
      end
      File.open(File.join(target_folder, 'cmd_tlm', 'cmd.txt'), 'w') do |file|
        file.puts "COMMAND #{target} NOOP BIG_ENDIAN \"No operation\""
        file.puts "  APPEND_ID_PARAMETER OPCODE 16 UINT 0x0 0xFFFF 0x1 \"Noop opcode\""
      end
      File.open(File.join(target_folder, 'cmd_tlm', 'tlm.txt'), 'w') do |file|
        file.puts "TELEMETRY #{target} STATUS BIG_ENDIAN \"Status telemetry\""
        file.puts "  APPEND_ID_ITEM OPCODE 16 UINT 0x1 \"Opcode which identifies this packet\""
        file.puts "  APPEND_ITEM COUNT 16 UINT \"Packet counter\""
        file.puts "  APPEND_ITEM VALUE 0 STRING \"String which consumes the rest of the packet\""
      end
      lib_filename = File.join(target_folder, 'lib', "#{target.downcase}.rb")
      File.open(lib_filename, 'w') do |file|
        file.puts "require 'cosmos'"
        file.puts "\n"
        file.puts "class #{lib_filename.filename_to_class_name}"
        file.puts "  attr_reader :tgt_name"
        file.puts "\n"
        file.puts "  # It is good practice to pass in the name of the target when instantiating"
        file.puts "  # the library. This way if the target name changes by COSMOS target name"
        file.puts "  # substitution or by simply renaming in the filesystem, the library continues"
        file.puts "  # to work simply by passing in the new name."
        file.puts "  def initialize(tgt_name = '#{target}')"
        file.puts "    @tgt_name = tgt_name"
        file.puts "  end"
        file.puts "\n"
        file.puts "  def noop"
        file.puts "    count = tlm(\"\#{@tgt_name} STATUS COUNT\")"
        file.puts "    cmd(\"\#{@tgt_name} NOOP\")"
        file.puts "    # Wait 5s for the counter to increment. Note the double equals!"
        file.puts "    wait_check(\"\#{@tgt_name} STATUS COUNT == \#{count + 1}\", 5)"
        file.puts "  end"
        file.puts "end"
      end
      File.open(File.join(target_folder, 'procedures', "#{target.downcase}_noop.rb"), 'w') do |file|
        file.puts "require 'cosmos'"
        file.puts "require '#{File.basename(lib_filename)}'"
        file.puts "\n"
        file.puts "#{target.downcase} = #{lib_filename.filename_to_class_name}.new"
        file.puts "#{target.downcase}.noop"
      end
      File.open(File.join(target_folder, 'target.txt'), 'w') do |file|
        file.puts "# Ignored Parameters"
        file.puts "IGNORE_PARAMETER OPCODE"
        file.puts "\n"
        file.puts "# Ignored Items"
        file.puts "IGNORE_ITEM OPCODE"
        file.puts "\n"
        file.puts "# Automatically substitute the target name in screen definitions"
        file.puts "AUTO_SCREEN_SUBSTITUTE"
      end
      cmd_tlm = File.join(target_folder, 'cmd_tlm_server.txt')
      File.open(cmd_tlm, 'w') do |file|
        file.puts "# This is a segment of the main cmd_tlm_server.txt that will be used with"
        file.puts "# AUTO_INTERFACE_TARGETS or INTERFACE_TARGET"
        file.puts "\n"
        file.puts "# NOTE: This line must be modified to match how your actual target connects."
        file.puts "# See http://cosmosrb.com/docs/interfaces/ for more information."
        file.puts "INTERFACE #{target}_INT tcpip_client_interface.rb localhost 8080 8080 10.0 nil BURST 4 0xDEADBEEF"
        file.puts "  TARGET #{target}"
        file.puts "  # Add in the OverrideProtocol to allow override_tlm(\"#{target} STATUS STRING = 'HI'\")"
        file.puts "  PROTOCOL READ_WRITE OverrideProtocol"
      end
      file_open(cmd_tlm)
    end

    ###########################################
    # Callbacks
    ###########################################

    # Called by the FindReplaceDialog to get the text to search
    def search_text
      active_config_editor_frame().editor
    end

    def undo_available(bool)
      update_title()
    end

    def closeEvent(event)
      if prompt_for_save_if_needed_on_close()
        super(event)
      else
        event.ignore()
      end
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
    end

    # Handle the user changing tabs
    def handle_tab_change(index)
      update_title()
      update_type_group()
      update_tree()
    end

    def handle_script_keypress(event)
      update_title()
      if event.matches(Qt::KeySequence::NextChild)
        index = @tab_book.currentIndex + 1
        index = 0 if index >= @tab_book.count
        @tab_book.setCurrentIndex(index)
      elsif event.matches(Qt::KeySequence::PreviousChild)
        index = @tab_book.currentIndex - 1
        index = @tab_book.count - 1 if index < 0
        @tab_book.setCurrentIndex(index)
      end
    end

    def tab_context_menu(point)
      index = 0
      @tab_book.tabBar.count.times do
        break if @tab_book.tabBar.tabRect(index).contains(point)
        index += 1
      end

      return if (index == @tab_book.tabBar.count)

      # Bring the right clicked tab to the front
      @tab_book.setCurrentIndex(index)

      menu = Qt::Menu.new()

      new_action = Qt::Action.new(tr("&New"), self)
      new_action.statusTip = tr("Create a new file")
      new_action.connect(SIGNAL('triggered()')) { file_new() }
      menu.addAction(new_action)

      close_action = Qt::Action.new(tr("&Close"), self)
      close_action.statusTip = tr("Close the file")
      close_action.connect(SIGNAL('triggered()')) { file_close() }
      menu.addAction(close_action)

      save_action = Qt::Action.new(tr("&Save"), self)
      save_action.statusTip = tr("Save the file")
      save_action.connect(SIGNAL('triggered()')) { file_save(false) }
      menu.addAction(save_action)

      save_action = Qt::Action.new(tr("Save &As"), self)
      save_action.statusTip = tr("Save the file as")
      save_action.connect(SIGNAL('triggered()')) { file_save(true) }
      menu.addAction(save_action)

      menu.exec(@tab_book.mapToGlobal(point))
      menu.dispose
    end

    #############################################################
    # Helper Methods
    #############################################################

    def show_message(message, right_label = nil)
      statusBar.showMessage(message)
      if right_label
        @status_bar_right_label.text = right_label
      else
        @status_bar_right_label.text = ''
      end
    end

    def update_cursor
      num = active_config_editor_frame.line_number
      col = active_config_editor_frame.column_number
      status = "#{num}:#{col}  #{active_config_editor_frame.line_keyword}"
      show_message(status, active_config_editor_frame.file_type)
    end

    def update_type_group
      @type_group.actions[-1].setChecked(true)
      @type_group.actions.each do |action|
        if action.text == active_config_editor_frame.file_type
          action.setChecked(true)
        end
      end
      update_cursor()
    end

    # Updates the title appropriately to show the tabs filename and modified status
    def update_title
      if @tab_book.currentTab.filename.empty?
        self.setWindowTitle("Config Editor : #{UNTITLED}")
      else
        self.setWindowTitle("Config Editor : #{@tab_book.currentTab.filename}")
      end
      self.setWindowTitle(self.windowTitle << '*') if @tab_book.currentTab.modified
      update_cursor()
    end

    def update_tree
      @tree_view.setCurrentIndex(@fs_model.index(@tab_book.currentTab.filename))
    end

    # Returns the frame of the active tab
    def active_config_editor_frame
      @tab_book.currentTab
    end

    # Creates a new tab
    def create_tab(filename = '')
      if filename.empty?
        tab_item_name = UNTITLED_TAB_TEXT
      else
        tab_item_name = '  ' + File.basename(filename) + '  '
      end

      config_editor_frame = ConfigEditorFrame.new(self)
      config_editor_frame.setContentsMargins(5,5,5,5)
      connect(config_editor_frame,
              SIGNAL('undoAvailable(bool)'),
              self,
              SLOT('undo_available(bool)'))
      config_editor_frame.set_text_from_file(filename) unless filename.empty?
      config_editor_frame.filename = filename
      # Register a keypress handler so we can Ctrl-Tab our way through the tabs
      config_editor_frame.key_press_callback = method(:handle_script_keypress)
      # Update the title if the frame changes so we can add/remove the asterix
      config_editor_frame.connect(SIGNAL('modificationChanged(bool)')) { update_title() }
      config_editor_frame.connect(SIGNAL('cursorPositionChanged()')) { update_cursor() }
      config_editor_frame.connect(SIGNAL('file_type_changed()')) { update_type_group() }

      @tab_book.addTab(config_editor_frame, tab_item_name)
      @tab_book.setCurrentIndex(@tab_book.count-1) # index is 0 based
      # Set the focus on the input now that we've added the tab
      config_editor_frame.setFocus
      update_title()
    end

    # Closes the active tab
    def close_active_tab
      if @tab_book.count > 1
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
            message = "Save changes to '#{UNTITLED}'?"
          else
            message = "Save changes to '#{tab.filename}'?"
          end
          safe_to_continue = prompt_for_save_if_needed(message)
          #~ break unless safe_to_continue
        end
      end
      return safe_to_continue
    end

    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.width = 80
          options.height = 600
          options.title = "Config Editor : #{UNTITLED}"
          options.auto_size = false
          option_parser.separator "Config Editor Specific Options:"
          option_parser.on("-f", "--file FILENAME", "Open the specified configuration file") do |arg|
            options.filename = arg
          end
        end
        super(option_parser, options)
      end
    end
  end
end
