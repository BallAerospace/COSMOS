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
  require 'cosmos/gui/dialogs/progress_dialog'
  require 'cosmos/gui/dialogs/tlm_details_dialog'
  require 'cosmos/tools/table_manager/table_config'
  require 'cosmos/tools/table_manager/table_manager_core'
end

class Qt::ComboBox
  def wheelEvent(param)
    self.nativeParentWidget.wheelEvent(param)
  end
end

# Override the default COSMOS setting which makes table cells read only
Cosmos.disable_warnings do
  class Qt::TableWidgetItem
    def initialize(string = "")
      super(string)
    end
  end
end

module Cosmos
  # This class applies to all items in the table but its only purpose is to
  # determine if table cells should be rendered as comboboxes. Any table items
  # with states are rendered as comboboxes.
  class ComboBoxItemDelegate < Qt::StyledItemDelegate
    # Create the combobox widget to display the values
    # @param parent [Qt::Widget] Parent to created widget
    # @param option [Qt::StyleOptionViewItem] Style options (not used)
    # @param index [Qt::ModelIndex] Indicates which table item is active
    def createEditor(parent, option, index)
      table = TableManager.instance.core.config.table(TableManager.instance.current_table_name)
      gui_table = TableManager.instance.tabbook.tab(TableManager.instance.current_table_name)
      if table.type == :TWO_DIMENSIONAL
        item_name = gui_table.horizontalHeaderItem(index.column).text + index.row.to_s
        item = table.get_item(item_name)
      else
        item_name = gui_table.verticalHeaderItem(index.row).text
        item = table.get_item(item_name)
      end
      if item.states && item.editable
        combo = Qt::ComboBox.new(parent)
        combo.addItems(item.states.keys.sort)
        combo.setCurrentText(table.read(item.name).to_s)
        connect(combo, SIGNAL('activated(int)')) do
          emit commitData(combo)
          gui_table.closeEditor(combo, 0)
        end
        return combo
      else
        return super(parent, option, index)
      end
    end

    # Gets the current item from the combobox if it exists and writes it back
    # to the model.
    # @param editor [Qt::Widget] Editor widget
    # @param model [Qt::AbstractItemModel] Model to write the gui data to
    # @param index [Qt::ModelIndex] Where in the model to update the data
    def setModelData(editor, model, index)
      if Qt::ComboBox === editor
        model.setData(index, Qt::Variant.new(editor.currentText), Qt::EditRole)
      else
        super(editor, model, index)
      end
    end

    # Sets the current item in the combobox based on the model data
    # @param editor [Qt::Widget] Editor widget
    # @param index [Qt::ModelIndex] Where in the model to grab the data
    def setEditorData(editor, index)
      if Qt::ComboBox === editor
        v = index.data(Qt::EditRole)
        combo_index = editor.findText(v.toString)
        if combo_index >= 0
          editor.setCurrentIndex(combo_index)
        else
          editor.setCurrentIndex(0)
        end
      else
        super(editor, index)
      end
    end
  end

  # A dialog box containing a text field and ok button
  class HexDumpDialog < Qt::Dialog
    # @param parent [Qt::Widget] Dialog parent
    def initialize(parent)
      super(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      setWindowTitle("Hex Dump")

      @text = Qt::PlainTextEdit.new
      @text.setWordWrapMode(Qt::TextOption::NoWrap)
      if Kernel.is_windows?
        @text.setFont(Cosmos.getFont('courier', 10))
      else
        @text.setFont(Cosmos.getFont('courier', 14))
      end
      @text.setReadOnly(true)

      layout = Qt::VBoxLayout.new
      layout.addWidget(@text)

      button_layout = Qt::HBoxLayout.new
      ok_button = Qt::PushButton.new('OK')
      ok_button.connect(SIGNAL('clicked()')) { self.accept }
      button_layout.addStretch
      button_layout.addWidget(ok_button)
      button_layout.addStretch

      layout.addLayout(button_layout)
      setLayout(layout)
      resize(650, 250)
    end

    # @param title [String] Dialog title
    # @param text [String] Dialog text box is overwritten with this string
    def set_title_and_text(title, text)
      self.setWindowTitle(title)
      @text.setPlainText(text)
    end

    # @param width [Integer]
    # @param height [Integer]
    def set_size(width, height)
      resize(width, height)
    end
  end

  class ProgressDialog
    def progress=(increment)
      set_overall_progress(increment / 100.0)
    end
  end

  # TableManager uses text based configuration files (see TableConfig) to define
  # both the structure of the binary file and how it should be displayed. It
  # takes this this configuration information to dynamically build a tabbed GUI
  # containing the visual representation of the binary data.
  # In addition to displaying binary data it can also create the binary
  # representation given the text configuration file. It can display the binary
  # data as a hex dump and creates human readable reports of the given data.
  class TableManager < QtTool
    # Error raised when there is a problem saving a table
    class SaveError < StandardError; end
    # Error raised when there is a problem displaying a table
    class DisplayError < StandardError; end

    # @return [TableManagerCore] TableManagerCore instance
    attr_reader :core
    # @return [Qt::TabWidget] TabWidget which holds the table tabs
    attr_reader :tabbook
    # @return [Qt::VBoxLayout] Top level vertical layout for the application
    attr_reader :top_layout

    # @return [TableManager] Instance of the TableManager class
    def self.instance
      @@instance
    end

    # Entry point into the application
    #
    # @param option_parser [OptionParser] Parses the command line options
    # @param options [OpenStruct] Contains all the parsed options
    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser && options
          option_parser, options = create_default_options()
          options.width = 800
          options.height = 600
          options.title = "Table Manager"
          options.auto_size = false
          options.no_tables = false
          option_parser.separator "Table Manager Specific Options:"
          option_parser.on("-n", "--notables", "Do not include table file editing options. This will remove the 'Table' menu.") do
            options.no_tables = true
          end
          option_parser.on("-c", "--create FILE", "Use the specified definition file to create the table") do |arg|
            options.create = arg
          end
          option_parser.on("-o", "--output DIRECTORY", "Create files in the specified directory (required with --create)") do |arg|
            options.output_dir = File.expand_path(arg)
          end
          option_parser.on("--convert FILE", "Convert the specified configuration file to the new format") do |arg|
            options.convert = arg
          end
        end
        super(option_parser, options)
      end
    end

    # Called after parsing all the command line options passed to the
    # application. Returns false to operate without a GUI when certain command
    # line options are specified.
    #
    # @param options [OpenStruct] The application options as configured in the
    #   command line
    # @return [Boolean] Whether to contine running the application
    def self.post_options_parsed_hook(options)
      if options.create and options.output_dir
        normalize_config_options(options)
        core = TableManagerCore.new
        create_path = self.config_path(options, options.create, ".txt", "table_manager")
        core.file_new(create_path, options.output_dir)
        return false
      end
      if options.convert
        normalize_config_options(options)
        if options.convert.include?("/")
          parts = options.convert.split("/")
        else
          parts = options.convert.split("\\")
        end
        parts[-1] = "converted_#{parts[-1]}"
        filename = parts.join(File::SEPARATOR)
        File.open(filename, 'w') do |out|
          config = File.read(options.convert).split("\n")
          config.each do |line|
            /TABLE\s+(\".*\")\s+(\".*\")\s+(ONE_DIMENSIONAL)\s+(.*_ENDIAN)/.match(line) do |m|
              out.puts "TABLE #{m[1]} #{m[4]} #{m[3]} #{m[2]}"
            end
            /TABLE\s+(\".*\")\s+(\".*\")\s+(TWO_DIMENSIONAL)\s+(.*_ENDIAN)/.match(line) do |m|
              rows = config.select {|item| item.strip =~ /^DEFAULT/ }.length
              out.puts "TABLE #{m[1]} #{m[4]} #{m[3]} #{rows} #{m[2]}"
            end
            /PARAMETER\s+(\".*\")\s+(\".*\")\s+(.*)\s+(\d+)\s+(.*)\s+(.*)\s+(.*)\s+(.*)\s?/.match(line) do |m|
              out.puts "  APPEND_PARAMETER #{m[1]} #{m[4]} #{m[3]} #{m[6]} #{m[7]} #{m[8]} #{m[2]}"
              if m[5].include?('CHECK')
                out.puts "    STATE UNCHECKED #{m[6]}"
                out.puts "    STATE CHECKED #{m[7]}"
              end
              if m[5].include?('HEX')
                out.puts '    FORMAT_STRING "0x%0X"'
              end
              if m[5].include?('-U')
                out.puts '    UNEDITABLE'
              end
            end
            if line.strip !~ /^(TABLE|PARAMETER|DEFAULT)/
              out.puts line
            end
          end
        end
        puts "Created #{filename}"
        return false
      end
      true
    end

    # Create a TableManager instance by initializing the globals,
    # setting the program icon, creating the menu, and laying out the GUI elements.
    def initialize(options)
      super(options) # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      @app_title = options.title
      @app_icon_filename = 'table_manager.png'
      Cosmos.load_cosmos_icon(@app_icon_filename)

      @system_def_path = File.join(::Cosmos::USERPATH, %w(config tools table_manager))
      @system_bin_path = System.paths['TABLES']
      @def_path = @system_def_path
      @bin_path = @system_bin_path
      @core = TableManagerCore.new
      @@instance = self

      initialize_actions(options.no_tables)
      initialize_menus(options.no_tables)
      initialize_central_widget()
      complete_initialize()
      setMinimumSize(400, 250)

      statusBar.showMessage("Ready") # Show message to initialize status bar
    end

    def initialize_actions(no_tables = false)
      super()

      # File Menu Actions
      new_action = Qt::Action.new(self)
      new_action.shortcut = Qt::KeySequence.new(Qt::KeySequence::New)
      new_action.connect(SIGNAL('triggered()')) { file_new(@def_path) }
      self.addAction(new_action) # Add it to the application

      open_action = Qt::Action.new(self)
      open_action.shortcut = Qt::KeySequence.new(Qt::KeySequence::Open)
      open_action.connect(SIGNAL('triggered()')) { file_open(@bin_path) }
      self.addAction(open_action) # Add it to the application

      @file_open_both = Qt::Action.new(Cosmos.get_icon('open.png'), 'Open &Both', self)
      @file_open_both.statusTip = 'Specify both the binary file and the definition file to open'
      @file_open_both.connect(SIGNAL('triggered()')) { file_open_both() }

      @file_save = Qt::Action.new(Cosmos.get_icon('save.png'), '&Save File', self)
      @file_save_keyseq = Qt::KeySequence.new(Qt::KeySequence::Save)
      @file_save.shortcut = @file_save_keyseq
      @file_save.statusTip = 'Save the displayed data back to the binary file'
      @file_save.connect(SIGNAL('triggered()')) { file_save() }

      @file_save_as = Qt::Action.new(Cosmos.get_icon('save_as.png'), 'Save File &As', self)
      @file_save_as_keyseq = Qt::KeySequence.new(Qt::KeySequence::SaveAs)
      @file_save_as.shortcut = @file_save_as_keyseq
      @file_save_as.statusTip = 'Save the displayed data to a new binary file'
      @file_save_as.connect(SIGNAL('triggered()')) { file_save(true) }

      @file_close = Qt::Action.new(Cosmos.get_icon('close.png'), '&Close File', self)
      @file_close_keyseq = Qt::KeySequence.new("Ctrl+W") # Qt::KeySequence::Close is Alt-F4 on Windows
      @file_close.shortcut = @file_close_keyseq
      @file_close.statusTip = 'Close the current file'
      @file_close.connect(SIGNAL('triggered()')) { file_close() }

      @file_check = Qt::Action.new(Cosmos.get_icon('checkmark.png'), '&Check All', self)
      @file_check_keyseq = Qt::KeySequence.new('Ctrl+K')
      @file_check.shortcut = @file_check_keyseq
      @file_check.statusTip = 'Check each data value against verification criteria'
      @file_check.connect(SIGNAL('triggered()')) { file_check() }

      @file_hex = Qt::Action.new('&Hex Dump', self)
      @file_hex_keyseq = Qt::KeySequence.new('Ctrl+H')
      @file_hex.shortcut = @file_hex_keyseq
      @file_hex.statusTip = 'Display a hex representation of the binary file'
      @file_hex.connect(SIGNAL('triggered()')) { display_hex(:file) }

      @file_report = Qt::Action.new('Create &Report', self)
      @file_report_keyseq = Qt::KeySequence.new('Ctrl+R')
      @file_report.shortcut = @file_report_keyseq
      @file_report.statusTip = 'Create a text file report describing the binary data'
      @file_report.connect(SIGNAL('triggered()')) { file_report() }

      unless no_tables
        # Table Menu Actions
        @table_check = Qt::Action.new(Cosmos.get_icon('checkmark.png'), '&Check', self)
        @table_check.statusTip = 'Check each data value against verification criteria'
        @table_check.connect(SIGNAL('triggered()')) { table_check() }

        @table_default = Qt::Action.new('&Default', self)
        @table_default_keyseq = Qt::KeySequence.new('Ctrl+D')
        @table_default.shortcut = @table_default_keyseq
        @table_default.statusTip = 'Revert all data values to their defaults'
        @table_default.connect(SIGNAL('triggered()')) { table_default() }

        @table_hex = Qt::Action.new('&Hex Dump', self)
        @table_hex.statusTip = 'Display a hex representation of the table'
        @table_hex.connect(SIGNAL('triggered()')) { display_hex(:table) }

        @table_save = Qt::Action.new('&Save Table Binary', self)
        @table_save.statusTip = 'Save the current table to a stand alone binary file'
        @table_save.connect(SIGNAL('triggered()')) { table_save() }

        @table_commit = Qt::Action.new('Commit to Existing &File', self)
        @table_commit.statusTip = 'Incorporate the current table data into a binary file which already contains the table'
        @table_commit.connect(SIGNAL('triggered()')) { table_commit() }
      end
    end

    def initialize_menus(no_tables = false)
      file_menu = menuBar.addMenu('&File')

      file_new = file_menu.addMenu(Cosmos.get_icon('file.png'), "&New File") # \tCtrl-N displays shortcut
      target_dirs_action(file_new, @system_def_path, 'tools/table_manager', method(:file_new))

      file_open = file_menu.addMenu(Cosmos.get_icon('open.png'), "&Open") # \tCtrl-O displays shortcut
      target_dirs_action(file_open, @system_bin_path, 'tables', method(:file_open))

      file_menu.addAction(@file_open_both)
      file_menu.addAction(@file_close)
      file_menu.addAction(@file_save)
      file_menu.addAction(@file_save_as)
      file_menu.addSeparator()
      file_menu.addAction(@file_check)
      file_menu.addAction(@file_hex)
      file_menu.addAction(@file_report)
      file_menu.addSeparator()
      file_menu.addAction(@exit_action)

      unless no_tables
        table_menu = menuBar.addMenu('&Table')
        table_menu.addAction(@table_check)
        table_menu.addAction(@table_default)
        table_menu.addAction(@table_hex)
        table_menu.addSeparator()
        table_menu.addAction(@table_save)
        table_menu.addAction(@table_commit)
      end

      # Help Menu
      @about_string = "TableManager is a generic binary file editor. "
      @about_string << "It features a text file driven interface to define binary files and their preferred display type. "
      @about_string << "This text file is then used to dynamically construct a spreadsheet type interface to "
      @about_string << "allow easy editing of the underlying binary structure."

      initialize_help_menu()
    end

    def initialize_central_widget
      central_widget = Qt::Widget.new
      setCentralWidget(central_widget)
      @top_layout = Qt::VBoxLayout.new(central_widget)

      # Create the information pane with the filenames
      filename_layout = Qt::FormLayout.new
      @table_def_label = Qt::Label.new("")
      filename_layout.addRow("Definition File:", @table_def_label)
      @table_bin_label = Qt::Label.new("")
      filename_layout.addRow("Binary File:", @table_bin_label)
      @top_layout.addLayout(filename_layout)

      # Separator before editor
      sep1 = Qt::Frame.new(central_widget)
      sep1.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      @top_layout.addWidget(sep1)

      @tabbook = Qt::TabWidget.new
      @top_layout.addWidget(@tabbook)

      @check_icons = []
      @check_icons << Cosmos.get_icon("CheckBoxEmpty.gif")
      @check_icons << Cosmos.get_icon("CheckBoxCheck.gif")
    end

    # Menu option to create a new table binary file based on a table definition file.
    #
    # @param def_path [String] Path to a directory containing definition files
    def file_new(def_path)
      return if abort_on_modified()

      filenames = Qt::FileDialog.getOpenFileNames(self, "Open Binary Definition Text File(s)",
                                                  def_path, "Config File (*.txt)\nAll Files (*)")
      return if filenames.length == 0 # User cancelled dialog

      bin_path = bin_path_from_def_path(File.dirname(filenames[0]))
      output_path = Qt::FileDialog.getExistingDirectory(self, "Select Output Directory", bin_path)
      return unless output_path # User cancelled dialog

      return if abort_on_check_for_existing(filenames, output_path)

      success = false
      bin_files = []
      ProgressDialog.execute(self, 'Create New Files', 500, 50, true, false, false, false, false) do |dialog|
        begin
          filenames.each do |filename|
            bin_files << @core.file_new(filename, output_path) do |progress|
              dialog.set_overall_progress(progress)
            end
          end
          success = true
          dialog.close_done
        rescue => err
          Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(self, err, "File New Errors", false)}
          dialog.close_done
        end
      end
      if success
        file_close()
        file_open(bin_files[0], filenames[0])
      end
    rescue TableManagerCore::CoreError => err
      Qt::MessageBox.warning(self, "File New Errors", err.message)
    rescue => err
      ExceptionDialog.new(self, err, "File New Errors", false)
    end

    # Menu option that opens a binary file (and it's associated definition
    # file) for display in the GUI.
    #
    # @param bin_path [String] Path to the binary file or a directory
    #   containing binary files
    # @param def_path [String] Path to the definition file. If nil, the
    #   definition file will be looked up automatically.
    # @param user_select_definition [Boolean] If true, the user will be
    #   required to select the definition file. It will not be automatically
    #   looked up.
    def file_open(bin_path, def_path = nil, user_select_definition = false)
      return if abort_on_modified()

      if File.directory?(bin_path)
        bin_path = Qt::FileDialog.getOpenFileName(self, "Open Binary", bin_path,
                                                  "Binary File (*.bin *.dat);;All Files (*)")
        return unless bin_path
      end

      unless def_path
        def_path = def_path_from_bin_path(bin_path)
        def_path = get_best_def_path(def_path, bin_path) unless user_select_definition
      end
      if !def_path || !File.file?(def_path)
        def_path = Qt::FileDialog.getOpenFileName(self, "Open Definition File", def_path,
                                                  "Definition File (*.txt);;All Files (*)")
      end
      return unless def_path

      Qt::Application.setOverrideCursor(Qt::Cursor.new(Qt::WaitCursor))
      begin
        @core.file_open(bin_path, def_path)
      rescue TableManagerCore::MismatchError => err
        # Mismatch errors are recoverable so just warn the user
        Qt::MessageBox.information(self, "Table Open Error", err.message)
      end
      @def_path = File.dirname(def_path)
      @bin_path = File.dirname(bin_path)
      display_all_gui_data()
      @table_bin_label.text = bin_path
      @table_def_label.text = def_path
      Qt::Application.restoreOverrideCursor()
    rescue TableManagerCore::CoreError => err
      Qt::Application.restoreOverrideCursor()
      Qt::MessageBox.warning(self, "File Open Errors", err.message)
    rescue => err
      Qt::Application.restoreOverrideCursor()
      ExceptionDialog.new(self, err, "File Open Errors", false)
    end

    # Menu option to require the user to specify both the binary and the
    # definition file to parse it
    def file_open_both
      file_open(@bin_path, nil, true)
    end

    # Menu option to close the open table
    def file_close
      return if abort_on_modified()
      @core.reset
      @table_bin_label.text = ''
      @table_def_label.text = ''
      reset_gui()
    rescue TableManagerCore::CoreError => err
      Qt::MessageBox.warning(self, "File Close Errors", err.message)
    rescue => err
      ExceptionDialog.new(self, err, "File Close Errors", false)
    end

    # Menu option to save the binary data to a file.
    # It first commits the GUI data to the internal data structures and checks
    # for errors. If none are found, it saves the data to the table binary file.
    def file_save(save_as = false)
      return unless file_check(false)
      filename = @table_bin_label.text
      if save_as
        filename = Qt::FileDialog.getSaveFileName(self, "File Save", @table_bin_label.text,
                                                  "Binary File (*.bin *.dat);;All Files (*)")
        return unless filename
        @table_bin_label.text = filename
      end

      @core.file_save(filename)
      @bin_path = File.dirname(filename)

      display_all_gui_data()
      @table_bin_label.text = filename
      statusBar.showMessage("File Saved Successfully")
    rescue TableManagerCore::CoreError, SaveError => err
      Qt::MessageBox.warning(self, "File Save Errors", err.message)
    rescue => err
      ExceptionDialog.new(self, err, "File Save Errors", false)
    end

    # Menu option to check every table's values against their allowable ranges
    #
    # @param success_dialog [Boolean] Whether to display a dialog indicating
    #   success. If false simply return true.
    # @return [Boolean] Whether the file check was successful
    def file_check(success_dialog = true)
      return false if abort_on_no_current_table()
      save_all_gui_data()
      Qt::MessageBox.information(self, "File Check", @core.file_check()) if success_dialog
      true
    rescue TableManagerCore::CoreError, SaveError => err
      Qt::MessageBox.warning(self, "File Check Errors", err.message)
      false
    rescue => err
      ExceptionDialog.new(self, err, "Unknown File Check Errors", false)
      false
    end

    # Menu option to create a text file report of all the table data
    def file_report
      return unless file_check(false)
      report_path = @core.file_report(@table_bin_label.text, @table_def_label.text)

      dialog = Qt::Dialog.new(self, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      dialog.setWindowTitle("File Report")
      dialog_layout = Qt::VBoxLayout.new
      dialog_layout.addWidget(Qt::Label.new("Report file created: #{report_path}"))
      button_layout = Qt::HBoxLayout.new
      ok_button = Qt::PushButton.new('&Ok')
      ok_button.connect(SIGNAL('clicked()')) { dialog.accept }
      ok_button.setEnabled(true)
      button_layout.addWidget(ok_button)
      button_layout.addStretch(1)
      open_button = Qt::PushButton.new('Open in &Editor')
      open_button.connect(SIGNAL('clicked()')) { Cosmos.open_in_text_editor(report_path) }
      button_layout.addWidget(open_button)
      if Kernel.is_windows?
        open_excel_button = Qt::PushButton.new('Open in E&xcel')
        open_excel_button.connect(SIGNAL('clicked()')) { system("start Excel.exe \"#{report_path}\"") }
        button_layout.addWidget(open_excel_button)
      end
      dialog_layout.addLayout(button_layout)
      dialog.setLayout(dialog_layout)
      dialog.exec
    rescue TableManagerCore::CoreError, SaveError => err
      Qt::MessageBox.warning(self, "File Report Errors", err.message)
    rescue => err
      ExceptionDialog.new(self, err, "File Report Errors", false)
    end

    # Menu option to display a dialog containing a hex dump of all table values
    def display_hex(type)
      return if abort_on_no_current_table()
      dialog = HexDumpDialog.new(self)
      if type == :file
        str = @core.file_hex()
        title = File.basename(@table_bin_label.text)
      else # :table
        str = @core.table_hex(current_table_name)
        title = current_table_name
      end
      dialog.set_title_and_text("#{title} Hex Dump", str)
      dialog.exec
      dialog.dispose
    rescue TableManagerCore::CoreError => err
      Qt::MessageBox.warning(self, "Display Hex Errors", err.message)
    rescue => err
      ExceptionDialog.new(self, err, "Display Hex Errors", false)
    end

    # Menu option to check the table values against their allowable ranges
    def table_check
      return if abort_on_no_current_table()
      save_gui_data(current_table_name)
      result = @core.table_check(current_table_name)
      if result.empty?
        result = "All parameters are within their constraints."
      end
      Qt::MessageBox.information(self, "Table Check", result)
    rescue TableManagerCore::CoreError, SaveError => err
      Qt::MessageBox.warning(self, "Table Check Errors", err.message)
    rescue => err
      ExceptionDialog.new(self, err, "Table Check Errors", false)
    end

    # Menu option to set all the table items to their default values
    def table_default
      return if abort_on_no_current_table()
      @core.table_default(current_table_name)
      set_table_modified(true)
      display_gui_data(current_table_name)
    rescue TableManagerCore::CoreError, DisplayError => err
      Qt::MessageBox.warning(self, "Table Default Errors", err.message)
    rescue => err
      ExceptionDialog.new(self, err, "Table Default Errors", false)
    end

    # Menu option to save the currently displayed table as a stand alone binary file
    def table_save
      return if abort_on_no_current_table()
      save_gui_data(current_table_name)
      filename = File.join(@bin_path, "#{current_table_name.split.collect(&:capitalize).join}Table.dat")
      filename = Qt::FileDialog.getSaveFileName(self, "File Save", filename,
                                               "Binary File (*.bin *.dat);;All Files (*)")
      return unless filename
      @core.table_save(current_table_name, filename)
    rescue TableManagerCore::CoreError, SaveError => err
      Qt::MessageBox.warning(self, "Table Save Errors", err.message)
    rescue => err
      ExceptionDialog.new(self, err, "Table Save Errors", false)
    end

    # Menu option to save the currently displayed table to an existing table binary file
    # containing that table.
    def table_commit
      return if abort_on_no_current_table()
      return if abort_on_modified()
      save_gui_data(current_table_name)

      bin_path = Qt::FileDialog.getOpenFileName(self, "Open Binary", @bin_path,
                                                "Binary File (*.bin *.dat);;All Files (*)")
      return unless bin_path
      def_path = def_path_from_bin_path(bin_path)
      def_path = get_best_def_path(def_path, bin_path)
      if !def_path || !File.file?(def_path)
        def_path = Qt::FileDialog.getOpenFileName(self, "Open Definition File", def_path,
                                                  "Definition File (*.txt);;All Files (*)")
      end
      return unless def_path

      @core.table_commit(current_table_name, bin_path, def_path)
    rescue TableManagerCore::CoreError, SaveError, DisplayError => err
      Qt::MessageBox.warning(self, "Table Commit Errors", err.message)
    rescue => err
      ExceptionDialog.new(self, err, "Table Commit Errors", false)
    end

    def current_table_name
      @tabbook.current_name
    end

    # Saves all the information in the given gui table name to the underlying
    # binary structure (although it does not commit it to disk).
    def save_gui_data(name)
      table = @core.config.table(name)
      gui_table = @tabbook.tab(name)
      return unless table && gui_table

      result = ""

      # First go through the gui and set the underlying data to what is displayed
      (0...table.num_rows).each do |r|
        (0...table.num_columns).each do |c|
          if table.type == :TWO_DIMENSIONAL
            item = table.get_item("#{gui_table.horizontalHeaderItem(c).text}#{r}")
          else # table is ONE_DIMENSIONAL
            item = table.get_item(gui_table.verticalHeaderItem(r).text)
          end
          next if item.hidden

          begin
            value = get_item_value(item, gui_table.item(r, c))

            # If there is a read conversion we first read the converted value before writing.
            # This is to prevent writing the displayed value (which has the conversion applied)
            # back to the binary data if they are already equal.
            if item.read_conversion
              converted = table.read(item.name, :CONVERTED)
              table.write(item.name, value) if converted != value
            else
              table.write(item.name, value)
            end
            if item.range && !item.range.include?(table.read(item.name, :RAW))
              if gui_table.item(r, c).text.upcase.start_with?("0X") # display as hex
                min = "0x#{item.range.min.to_s(16).upcase}"
                max = "0x#{item.range.max.to_s(16).upcase}"
              else
                min = item.range.min
                max = item.range.max
              end
              raise "out of range. Minimum is #{min}. Maximum is #{max}"
            end

          # if we have a problem casting the value it probably means the user put in garbage
          # in this case force the range check to fail
          rescue => error
            text = gui_table.item(r, c).text
            if text.upcase.start_with?("0X") # display as hex
              default = "0x#{item.default.to_s(16).upcase}"
            else
              default = item.default
            end
            result << "Error saving #{item.name} value of #{text} due to #{error.message}. Default value is #{default}.\n\n"
          end
        end # end each table column
      end # end each table row
      raise SaveError, result unless result.empty?
    end

    def closeEvent(event)
      if abort_on_modified()
        event.ignore()
      else
        super(event)
      end
    end

    protected

    # Determine the binary directory path given the definition directory path
    #
    # @param def_path [String] Path to the definition directory
    def bin_path_from_def_path(def_path)
      if def_path.include?('targets') # target directory path
        bin_path = File.expand_path(File.join(def_path, '..', '..', 'tables'))
      else
        bin_path = @system_bin_path
      end
    end

    # Determine the definition directory path given the binary directory path
    #
    # @param bin_path [String] Path to the binary directory
    def def_path_from_bin_path(bin_path)
      if bin_path.include?('targets') # target directory path
        def_path = File.expand_path(File.join(File.dirname(bin_path), '..', 'tools', 'table_manager'))
      else
        def_path = @system_def_path
      end
    end

    # Looks in a directory for a definition file for the given binary file.
    # The definition file name up to the _def.txt must be fully contained in
    # the given binary file. For example: XXX_YYY1_def.txt will be returned for
    # a binary file name of XXX_YYY1_Extra.bin. A binary file of XXX_YYY2.bin
    # will not match.
    #
    # @param def_path [String] Path to the definition files
    # @param bin_path [String] Path to the binary file
    # @return [String|nil] Path to the best definition file or nil
    def get_best_def_path(def_path, bin_path)
      return nil unless (File.exist?(def_path) && File.exist?(bin_path))
      bin_path = File.basename(bin_path).split('.')[0]
      def_file = nil

      Dir.foreach(def_path) do |possible_def_file|
        # only bother checking definition files
        index = possible_def_file.index('_def.txt')
        next unless index

        base_name = possible_def_file[0...index]
        if bin_path.index(base_name)
          # If we've already found a def_file and now found another match we
          # clear the first and stop the search. Force the user to decide.
          if def_file
            def_file = nil
            break
          end
          def_file = File.join(def_path, possible_def_file)
        end
      end
      # Return the original path if we couldn't find anything
      def_file = def_path unless def_file
      def_file
    end

    def abort_on_check_for_existing(filenames, output_path)
      user_abort = false
      filenames.each do |def_file|
        if File.basename(def_file) =~ /_def\.txt/
          basename = File.basename(def_file)[0...-8] # Get the basename without the _def.txt
        else
          basename = File.basename(def_file).split('.')[0...-1].join('.') # Get the basename without the extension
        end

        output_filename = File.join(output_path, "#{basename}.dat")
        if abort_on_existing_file(output_filename)
          user_abort = true
          break # No need to continue processing
        end
      end
      user_abort
    end

    def abort_on_existing_file(filename)
      user_abort = false
      if File.exist?(filename)
        result = Qt::MessageBox.question(self, "File New",
          "#{filename} already exists. Overwrite?",
          Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::Yes)
        if result != Qt::MessageBox::Yes
          user_abort = true
        end
      end
      user_abort
    end

    def abort_on_modified
      user_abort = false
      if self.windowTitle.include?("*")
        result = Qt::MessageBox.warning(self, "Table Modified",
          "Table has been modified. Continue and discard all changes?",
          Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::No)
        if result != Qt::MessageBox::Yes
          user_abort = true
        end
      end
      user_abort
    end

    def abort_on_no_current_table
      user_abort = false
      unless current_table_name
        Qt::MessageBox.information(self, "No current table", "Please open a table.")
        user_abort = true
      end
      user_abort
    end

    # Delete all the tabs in the table manager gui and initialize globals to
    # prepare for the next table to load.
    def reset_gui
      set_table_modified(false)
      @tabbook.tabs.each_with_index do |tab, index|
        tab.dispose
        @tabbook.removeTab(index)
      end
    end

    def save_all_gui_data
      result = ''
      @core.config.tables.each do |table_name, table|
        begin
          save_gui_data(table_name)
        rescue SaveError => err
          result << "\nErrors in #{table_name}:\n#{err.message}"
        end
      end
      raise SaveError, result.lstrip unless result.empty?
    end

    def display_all_gui_data
      reset_gui()
      @core.config.tables.each do |table_name, table|
        create_table_tab(table)
        display_gui_data(table_name)
      end
    end

    def display_gui_data(table_name)
      table = @core.config.table(table_name)
      gui_table = @tabbook.tab(table_name)
      return unless table && gui_table

      gui_table.blockSignals(true) # block signals while we programatically update it
      # Cancel any table selections so the text will be visible when it is refreshed
      gui_table.clearSelection

      set_table_headers(table, gui_table)

      row = 0
      column = 0
      table.sorted_items.each do |item|
        next if item.hidden
        update_gui_item(table_name, table, gui_table, item, row, column)

        if table.type == :TWO_DIMENSIONAL
          # only increment our row when we've processed all the columns
          if column == table.num_columns - 1
            row += 1
            column = 0
          else
            column += 1
          end
        else
          row += 1
        end
      end

      gui_table.resizeColumnsToContents()
      gui_table.resizeRowsToContents()
      gui_table.blockSignals(false)
    end

    # Updates the table by setting the value in the table to the properly formatted value.
    def update_gui_item(table_name, table, gui_table, item, row, column)
      value = table.read(item.name, :FORMATTED)
      # Handle binary strings
      value = "0x" + value.simple_formatted unless value.is_printable?

      if item.states && item.states.keys.sort == %w(CHECKED UNCHECKED)
        table_item = create_checkable_table_item(item, value)
      else
        table_item = create_table_item(item, value)
      end
      gui_table.setItem(row, column, table_item)
    end

    def get_item_value(item, gui_item)
      value = nil
      if (gui_item.flags & Qt::ItemIsUserCheckable) != 0
        check_state = gui_item.checkState
        case check_state
        when Qt::Checked
          value = item.states["CHECKED"]
        when Qt::Unchecked
          value = item.states["UNCHECKED"]
        when Qt::PartiallyChecked
          value = gui_item.text # convert_to_value?
        end
      else
        if (item.data_type == :STRING || item.data_type == :BLOCK) && gui_item.text.upcase.start_with?("0X")
          value = gui_item.text.hex_to_byte_string
        else
          text = gui_item.text
          quotes_removed = text.remove_quotes
          if text == quotes_removed
            value = text.convert_to_value
          else
            value = quotes_removed
          end
        end
      end
      value
    end

    def set_table_modified(modified)
      title = modified ? "#{@app_title} *" : @app_title
      self.setWindowTitle(title)
    end

    def table_item_changed(table_item)
      set_table_modified(true)
      # If there is a checkbox value that contains a value that doesn't map to
      # the checked or unchecked state, that value is displayed next to the
      # "PartiallyChecked" checkbox. Once the user clicks to check or uncheck,
      # the original value will disappear due to the following code:
      table = @core.config.table(current_table_name)
      gui_table = @tabbook.tab(current_table_name)
      if table.type == :TWO_DIMENSIONAL
        item_name = gui_table.horizontalHeaderItem(table_item.column).text + table_item.row.to_s
      else
        item_name = gui_table.verticalHeaderItem(table_item.row).text
      end
      item = table.get_item(item_name)
      if item.states && item.states.keys.sort == %w(CHECKED UNCHECKED)
        table_item.setText('')
      end
    end

    def set_table_headers(table, gui_table)
      items = table.sorted_items
      if table.type == :TWO_DIMENSIONAL
        row_headers = []
        (0...table.num_rows).each {|i| row_headers << "#{i + 1}" }
        gui_table.setVerticalHeaderLabels(row_headers)

        column_headers = []
        (0...table.num_columns).each {|i| column_headers << items[i].name[0...-1] unless items[i].hidden }
        gui_table.setHorizontalHeaderLabels(column_headers)
      else
        row_headers = []
        items.each {|item| row_headers << item.name unless item.hidden }
        gui_table.setVerticalHeaderLabels(row_headers)
        gui_table.setHorizontalHeaderLabels(["Value"])
      end
    end

    def create_checkable_table_item(item, value)
      table_item = Qt::TableWidgetItem.new()
      if item.editable
        table_item.setFlags(Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsUserCheckable | Qt::ItemIsTristate)
      else
        table_item.setFlags(Qt::ItemIsUserCheckable | Qt::ItemIsTristate)
      end
      if value == "CHECKED"
        table_item.setCheckState(Qt::Checked)
      elsif value == "UNCHECKED"
        table_item.setCheckState(Qt::Unchecked)
      else # The value doesn't match our defined states
        table_item.setText(value) # Display the actual value
        table_item.setCheckState(Qt::PartiallyChecked) # Mark it partial since we can't tell
      end
      table_item
    end

    def create_table_item(item, value)
      table_item = Qt::TableWidgetItem.new(value)
      if item.editable
        table_item.setFlags(Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
      else
        table_item.setFlags(Qt::NoItemFlags)
      end
      table_item
    end

    def context_menu(point)
      begin
        table = @core.config.table(current_table_name)
        gui_table = @tabbook.tab(current_table_name)
        if table && gui_table
          table_item = gui_table.itemAt(point)
          if table_item
            menu = Qt::Menu.new()

            if table.type == :TWO_DIMENSIONAL
              item_name = gui_table.horizontalHeaderItem(table_item.column).text + table_item.row.to_s
            else
              item_name = gui_table.verticalHeaderItem(table_item.row).text
            end
            details_action = Qt::Action.new("Details", self)
            details_action.statusTip = "Popup details about #{current_table_name} #{item_name}"
            details_action.connect(SIGNAL('triggered()')) do
              TlmDetailsDialog.new(nil,
                                   'TABLE',
                                   current_table_name.upcase,
                                   item_name,
                                   table)
            end
            menu.addAction(details_action)

            default_action = Qt::Action.new("Default", self)
            default_action.statusTip = "Set item to default value"
            default_action.connect(SIGNAL('triggered()')) do
              item = table.get_item(item_name)
              table.write(item.name, item.default)
              update_gui_item(current_table_name, table, gui_table, item, table_item.row, table_item.column)
            end
            menu.addAction(default_action)

            global_point = gui_table.mapToGlobal(point)
            global_point.x += gui_table.verticalHeader.width
            menu.exec(global_point)
            menu.dispose
          end
        end
      rescue => err
        ExceptionDialog.new(self, err, "context_menu Errors", false)
      end
    end

    # Creates a tab in the table manager gui
    #
    # @param table [Table] Table to display
    def create_table_tab(table)
      @table = Qt::TableWidget.new(self)
      delegate = ComboBoxItemDelegate.new(@table)
      @table.setItemDelegate(delegate)
      @table.setEditTriggers(Qt::AbstractItemView::AllEditTriggers)
      @table.setSelectionMode(Qt::AbstractItemView::NoSelection)
      #@table.setAlternatingRowColors(true)
      @tabbook.addTab(@table, table.table_name)

      @table.setRowCount(table.num_rows)
      @table.setColumnCount(table.num_columns)
      @table.setMouseTracking(true)
      @table.connect(SIGNAL('cellEntered(int, int)')) {|row, col| mouse_over(row, col) }
      @table.connect(SIGNAL('itemChanged(QTableWidgetItem*)')) {|item| table_item_changed(item) }
      @table.setContextMenuPolicy(Qt::CustomContextMenu)
      @table.connect(SIGNAL('customContextMenuRequested(const QPoint&)')) {|point| context_menu(point) }
    rescue => err
      ExceptionDialog.new(self, err, "Create New Table Tab Errors", false)
    end

    def mouse_over(row, col)
      return unless current_table_name
      table = @core.config.table(current_table_name)
      gui_table = @tabbook.tab(current_table_name)
      if table && gui_table
        if table.type == :TWO_DIMENSIONAL
          item_name = gui_table.horizontalHeaderItem(col).text + row.to_s
          item = table.get_item(item_name)
          statusBar.showMessage(item.description)
        else
          item_name = gui_table.verticalHeaderItem(row).text
          item = table.get_item(item_name)
          statusBar.showMessage(item.description)
        end
      end
    rescue
      statusBar.showMessage('')
    end
  end
end
