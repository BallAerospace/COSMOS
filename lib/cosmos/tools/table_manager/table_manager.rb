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
  require 'cosmos/tools/table_manager/table_config'
  require 'cosmos/tools/table_manager/table_manager_core'
  require 'cosmos/gui/dialogs/tlm_details_dialog'
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

  class ComboBoxItemDelegate < Qt::StyledItemDelegate
    def initialize(parent)
      @table = parent
      super(parent)
    end

    def createEditor(parent, option, index)
      table = TableManager.instance.core.config.get_table(TableManager.instance.currently_displayed_table_name)
      gui_table = TableManager.instance.gui_tables[TableManager.instance.currently_displayed_table_name]
      if table.type == :TWO_DIMENSIONAL
        item_name = gui_table.horizontalHeaderItem(index.column).text + index.row.to_s
        item = table.get_item(item_name)
      else
        item_name = gui_table.verticalHeaderItem(index.row).text
        item = table.get_item(item_name)
      end
      if item.display_type == :STATE and item.editable
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

    def setModelData(editor, model, index)
      if Qt::ComboBox === editor
        model.setData(index, Qt::Variant.new(editor.currentText), Qt::EditRole)
      else
        super(editor, model, index)
      end
    end

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
  class TextDialog < Qt::Dialog
    def initialize(parent)
      super(parent)

      layout = Qt::VBoxLayout.new

      @text = Qt::PlainTextEdit.new
      if Kernel.is_windows?
        @text.setFont(Cosmos.getFont('courier', 10))
      else
        @text.setFont(Cosmos.getFont('courier', 14))
      end
      @text.setReadOnly(true)

      layout.addWidget(@text)

      button_layout = Qt::HBoxLayout.new
      ok_button = Qt::PushButton.new('OK')
      ok_button.connect(SIGNAL('clicked()')) { self.accept }
      button_layout.addStretch
      button_layout.addWidget(ok_button)
      button_layout.addStretch

      layout.addLayout(button_layout)
      setLayout(layout)
    end

    # Set the title of the dialog box and the text contents
    def set_title_and_text(title, text)
      self.setWindowTitle(title)
      @text.setPlainText(text)
    end

    # Set the size of the dialog box
    def set_size(width, height)
      resize(width, height)
    end
  end

  class ProgressDialog
    def progress=(increment)
      set_overall_progress(increment / 100.0)
    end
  end

  # TableManager uses text based configuration files (see TableConfig) to define both
  # the structure of the binary file and how it should be displayed. It takes this configuration
  # information to dynamically build a tabbed GUI containing the visual representation of the binary data.
  # In addition to displaying binary data it can also create the binary representation given
  # the text configuration file. It can display the binary data as a hex dump and creates
  # human readable reports of the given data.
  class TableManager < QtTool
    slots 'handle_tab_change(int)'
    slots 'mouse_over(int, int)'
    slots 'click_callback(QTableWidgetItem*)'
    slots 'context_menu(const QPoint&)'

    attr_reader :core

    # Hash of all the created tables with the table name as the key value
    attr_reader :gui_tables

    # Array of all the created tables ordered by the way they were created.
    # Thus they are ordered the same as the text configuration file.
    attr_reader :ordered_gui_table_names

    # Place holder for the current table
    attr_reader :table

    # The currently displayed table name
    attr_reader :currently_displayed_table_name

    # Label containing the full path name of the table definition file
    attr_reader :table_def_label

    # Label containing the full path name of the table binary file
    attr_reader :table_bin_label

    # Top vertical layout where subclasses can put their own widgets
    attr_accessor :top_layout

    # File name of the png icon to use for the application.
    # The application looks in the COSMOS PATH and USERPATH directories for the icon.
    # This must be overloaded before calling super() in the initialize
    # function to allow Table Manager to use the new file name.
    attr_accessor :app_icon_filename

    # Create a TableManager instance by initializing the globals,
    # setting the program icon, creating the menu, and laying out the GUI elements.
    def initialize(options)
      super(options) # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      @app_icon_filename = 'table_manager.png'
      Cosmos.load_cosmos_icon(@app_icon_filename)

      initialize_actions(options.no_tables)
      initialize_menus(options.no_tables)
      initialize_central_widget()
      complete_initialize()
      setMinimumSize(500, 300)

      statusBar.showMessage(tr("Ready")) # Show message to initialize status bar

      @def_path = File.join(::Cosmos::USERPATH, %w(config tools table_manager))
      @bin_path = System.paths['TABLES']
      @gui_tables = Hash.new
      @ordered_gui_table_names = Array.new
      @currently_displayed_table_name = ""
      @core = TableManagerCore.new
      @@instance = self
    end

    def self.instance
      @@instance
    end

    def initialize_actions(no_tables = false)
      super()

      # File Menu Actions
      @file_new = Qt::Action.new(Cosmos.get_icon('file.png'), tr('&New File'), self)
      @file_new_keyseq = Qt::KeySequence.new(Qt::KeySequence::New)
      @file_new.shortcut = @file_new_keyseq
      @file_new.statusTip = tr('Create new binary file based on definition')
      @file_new.connect(SIGNAL('triggered()')) { file_new() }

      @file_open = Qt::Action.new(Cosmos.get_icon('open.png'), tr('&Open File'), self)
      @file_open_keyseq = Qt::KeySequence.new(Qt::KeySequence::Open)
      @file_open.shortcut = @file_open_keyseq
      @file_open.statusTip = tr('Open binary file for display and editing')
      @file_open.connect(SIGNAL('triggered()')) { file_open() }

      @file_save = Qt::Action.new(Cosmos.get_icon('save.png'), tr('&Save File'), self)
      @file_save_keyseq = Qt::KeySequence.new(Qt::KeySequence::Save)
      @file_save.shortcut = @file_save_keyseq
      @file_save.statusTip = tr('Save the displayed data back to the binary file')
      @file_save.connect(SIGNAL('triggered()')) { file_save(false) }

      @file_save_as = Qt::Action.new(Cosmos.get_icon('save_as.png'), tr('Save File &As'), self)
      @file_save_as_keyseq = Qt::KeySequence.new(Qt::KeySequence::SaveAs)
      @file_save_as.shortcut = @file_save_as_keyseq
      @file_save_as.statusTip = tr('Save the displayed data to a new binary file')
      @file_save_as.connect(SIGNAL('triggered()')) { file_save(true) }

      @file_check = Qt::Action.new(Cosmos.get_icon('checkmark.png'), tr('&Check All'), self)
      @file_check_keyseq = Qt::KeySequence.new(tr('Ctrl+K'))
      @file_check.shortcut = @file_check_keyseq
      @file_check.statusTip = tr('Check each data value against verification criteria')
      @file_check.connect(SIGNAL('triggered()')) { file_check() }

      @file_hex = Qt::Action.new(tr('&Hex Dump'), self)
      @file_hex_keyseq = Qt::KeySequence.new(tr('Ctrl+H'))
      @file_hex.shortcut = @file_hex_keyseq
      @file_hex.statusTip = tr('Display a hex representation of the binary file')
      @file_hex.connect(SIGNAL('triggered()')) { display_hex(:file) }

      @file_report = Qt::Action.new(tr('Create &Report'), self)
      @file_report_keyseq = Qt::KeySequence.new(tr('Ctrl+R'))
      @file_report.shortcut = @file_report_keyseq
      @file_report.statusTip = tr('Create a text file report describing the binary data')
      @file_report.connect(SIGNAL('triggered()')) { file_report() }

      unless no_tables
        # Table Menu Actions
        @table_check = Qt::Action.new(Cosmos.get_icon('checkmark.png'), tr('&Check'), self)
        @table_check.statusTip = tr('Check each data value against verification criteria')
        @table_check.connect(SIGNAL('triggered()')) { table_check() }

        @table_default = Qt::Action.new(tr('&Default'), self)
        @table_default_keyseq = Qt::KeySequence.new(tr('Ctrl+D'))
        @table_default.shortcut = @table_default_keyseq
        @table_default.statusTip = tr('Revert all data values to their defaults')
        @table_default.connect(SIGNAL('triggered()')) { table_default() }

        @table_hex = Qt::Action.new(tr('&Hex Dump'), self)
        @table_hex.statusTip = tr('Display a hex representation of the table')
        @table_hex.connect(SIGNAL('triggered()')) { display_hex(:table) }

        @table_save = Qt::Action.new(tr('&Save Table Binary'), self)
        @table_save.statusTip = tr('Save the current table to a stand alone binary file')
        @table_save.connect(SIGNAL('triggered()')) { table_save() }

        @table_commit = Qt::Action.new(tr('Commit to Existing &File'), self)
        @table_commit.statusTip = tr('Incorporate the current table data into a binary file which already contains the table')
        @table_commit.connect(SIGNAL('triggered()')) { table_commit() }

        @table_update = Qt::Action.new(tr('&Update Definition'), self)
        @table_update.statusTip = tr('Change the defaults in the definition file to the displayed table data')
        @table_update.connect(SIGNAL('triggered()')) { table_update() }
      end
    end

    def initialize_menus(no_tables = false)
      # File Menu
      file_menu = menuBar.addMenu(tr('&File'))
      file_menu.addAction(@file_new)
      file_menu.addAction(@file_open)
      file_menu.addAction(@file_save)
      file_menu.addAction(@file_save_as)
      file_menu.addSeparator()
      file_menu.addAction(@file_check)
      file_menu.addAction(@file_hex)
      file_menu.addAction(@file_report)
      file_menu.addSeparator()
      file_menu.addAction(@exit_action)

      unless no_tables
        # Table Menu
        table_menu = menuBar.addMenu(tr('&Table'))
        table_menu.addAction(@table_check)
        table_menu.addAction(@table_default)
        table_menu.addAction(@table_hex)
        table_menu.addSeparator()
        table_menu.addAction(@table_save)
        table_menu.addAction(@table_commit)
        table_menu.addAction(@table_update)
      end

      # Help Menu
      @about_string = "TableManager is a generic binary file editor. "
      @about_string << "It features a text file driven interface to define binary files and their preferred display type. "
      @about_string << "This text file is then used to dynamically construct a spreadsheet type interface to "
      @about_string << "allow easy editing of the underlying binary structure."

      initialize_help_menu()
    end

    def initialize_central_widget
      # Create the central widget
      @central_widget = Qt::Widget.new
      setCentralWidget(@central_widget)

      # Create the top level vertical layout
      @top_layout = Qt::VBoxLayout.new(@central_widget)

      # Create the information pane with the filenames
      @filename_layout = Qt::FormLayout.new
      @table_def_label = Qt::Label.new("")
      @filename_layout.addRow(tr("Definition File:"), @table_def_label)
      @table_bin_label = Qt::Label.new("")
      @filename_layout.addRow(tr("Binary File:"), @table_bin_label)
      @top_layout.addLayout(@filename_layout)

      # Separator before editor
      @sep1 = Qt::Frame.new(@central_widget)
      @sep1.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      @top_layout.addWidget(@sep1)

      @tabbook = Qt::TabWidget.new
      connect(@tabbook, SIGNAL('currentChanged(int)'), self, SLOT('handle_tab_change(int)'))
      @top_layout.addWidget(@tabbook)

      @check_icons = []
      @check_icons << Cosmos.get_icon("CheckBoxEmpty.gif")
      @check_icons << Cosmos.get_icon("CheckBoxCheck.gif")
    end

    # Menu option to check every table tab's values against their allowable ranges
    def file_check
      begin
        result = ""
        @ordered_gui_table_names.each do |name|
          save_result = save_gui_data(name)
          check_result = @core.table_check(name)
          if not save_result.nil? or not check_result.empty?
            result << "Error(s) in #{name}:\n" << save_result.to_s << check_result.to_s
          end
        end
        if result.empty?
          result = "All parameters are within their constraints."
        end
        Qt::MessageBox.information(self, "File Check", result)
      rescue => err
        ExceptionDialog.new(self, err, "File Check Errors", false)
      end
    end

    # Menu option to check the table values against their allowable ranges
    def table_check
      begin
        save_result = save_gui_data(@currently_displayed_table_name)
        check_result = @core.table_check(@currently_displayed_table_name)
        if save_result.nil? and check_result.empty?
          result = "All parameters are within their constraints."
        elsif save_result.nil?
          result = check_result
        elsif check_result.nil?
          result = save_result
        else
          result = save_result << check_result
        end

        Qt::MessageBox.information(self, "Table Check", result)
      rescue => err
        ExceptionDialog.new(self, err, "Table Check Errors", false)
      end
    end

    # Menu option to set all the table items to their default values
    def table_default
      begin
        @core.table_default(@currently_displayed_table_name)
      rescue => err
        ExceptionDialog.new(self, err, "Table Default Errors", false)
      end
      begin
        display_gui_data(@currently_displayed_table_name)
      rescue => err
        ExceptionDialog.new(self, err, "Table Default Errors", false)
      end
    end

    # Menu option to create a text file report of all the table data
    def file_report
      begin
        @ordered_gui_table_names.each do |name|
          save_gui_data(name)
        end

        @core.file_report
        statusBar.showMessage(tr("File Report Created Successfully"))
      rescue => err
        ExceptionDialog.new(self, err, "File Report Errors", false)
      end
    end

    # Saves the binary data to a file.
    # It first commits the GUI data to the internal data structures and checks
    # for errors. If none are found, it saves the data to the table binary file.
    def file_save(save_as = false)
      begin
        @ordered_gui_table_names.each do |name|
          save_gui_data(name)
        end

        filename = @table_bin_label.text
        if save_as
          filename = Qt::FileDialog.getSaveFileName(self,
                                                  "File Save",
                                                  @table_bin_label.text,
                                                  "Binary File (*.bin *.dat);;All Files (*)")

          # Check for an empty string which indicates the user clicked "Cancel" on the dialog
          return if filename.to_s.empty?
          @table_bin_label.text = filename
        end

        begin
          @core.file_save(filename)
        rescue => error
          Qt::MessageBox.information(self, "File Save Errors", error.message)
          return
        end

        @ordered_gui_table_names.each do |name|
          display_gui_data(name)
        end

        statusBar.showMessage(tr("File Saved Successfully"))
      rescue => err
        ExceptionDialog.new(self, err, "File Save Errors", false)
      end
    end

    # Menu option to display a dialog containing a hex dump of all table values
    def display_hex(type)
      begin
        dialog = TextDialog.new(self)
        if type == :file
          str = @core.file_hex()
          title = File.basename(@table_bin_label.text)
        else
          str = @core.table_hex(@currently_displayed_table_name)
          title = @currently_displayed_table_name
        end
        dialog.set_title_and_text("#{title} Hex Dump", str)
        dialog.set_size(650, 400)
        dialog.exec
        dialog.dispose
      rescue => err
        ExceptionDialog.new(self, err, "Display Hex Errors", false)
      end
    end

    # Menu option to save the currently displayed table to an existing table binary file
    # containing that table.
    def table_commit
      begin
        save_gui_data(@currently_displayed_table_name)

        # Ask for the file to save the current table to
        bin_file, def_file = get_binary_and_definition_file_paths()
        if bin_file.nil? or def_file.nil? then return 1 end

        @core.table_commit(@currently_displayed_table_name, bin_file, def_file)

        # Update the labels
        @table_bin_label.text = bin_file
        @table_def_label.text = def_file

        # Display the new table
        delete_tabs()
        @core.config.get_all_tables.each do |table|
          create_table_tab(table)
          display_gui_data(table.name)
        end
        @currently_displayed_table_name = @ordered_gui_table_names[0]
        @currently_displayed_table_name ||= '' # ensure it's not nil
      rescue => err
        ExceptionDialog.new(self, err, "Table Commit Errors", false)
      end
    end

    # Menu option to save the currently displayed table as a stand alone binary file
    def table_save
      begin
        save_gui_data(@currently_displayed_table_name)

        filename = Qt::FileDialog.getSaveFileName(self,
                                                "File Save",
                                                File.join(@bin_path, "#{@currently_displayed_table_name.gsub(/\s/,'')}.dat"),
                                                "Binary File (*.bin *.dat);;All Files (*)")
        # Check for a 0 length string which indicates the user clicked "Cancel" on the dialog
        if filename.to_s.strip.length != 0
          @bin_path = File.dirname(filename)
          @core.table_save(@currently_displayed_table_name, filename)
        end
      rescue => err
        ExceptionDialog.new(self, err, "Table Save Errors", false)
      end
    end

    # Menu option to update the definition file defaults with the currently
    # displayed table values
    def table_update
      begin
        save_gui_data(@currently_displayed_table_name)

        result = Qt::MessageBox.question(self, "Update Table Definition File",
          "Are you sure you want to update the table definition file. This action is irreversable!",
          Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::Yes)
        if result == Qt::MessageBox::Yes
          @core.table_update_def(@currently_displayed_table_name)
        end # end if result == MBOX_CLICKED_YES
      rescue => err
        ExceptionDialog.new(self, err, "Table Update Errors", false)
      end
    end

    # Menu option that opens a dialog to allows the user to select a table binary
    # file named XXX.dat. The associated table definition file (XXX_def.txt)
    # is then opened and parsed to determine how to display the binary file in the gui.
    def file_open(bin_file = nil, def_file = nil)
      begin
        unless bin_file and def_file
          bin_file, def_file = get_binary_and_definition_file_paths()
        end

        # Do nothing if the binary or definition files are not found
        if bin_file.nil? or def_file.nil? then return end

        # Update the labels
        @table_bin_label.text = bin_file
        @table_def_label.text = def_file

        # open the file
        begin
          @core.file_open(def_file, bin_file)
        rescue => err
          if err.message.include?("Binary")
            Qt::MessageBox.information(self, "Table Open Error", err.message)
          else
            ExceptionDialog.new(self, err, "Table Open Errors", false)
          end
        end

        Qt::Application.setOverrideCursor(Qt::Cursor.new(Qt::WaitCursor))

        # display the file
        delete_tabs()
        @core.config.get_all_tables.each do |table|
          create_table_tab(table)
          display_gui_data(table.name)
        end
        @currently_displayed_table_name = @ordered_gui_table_names[0]
        @currently_displayed_table_name ||= '' # ensure it's not nil

        Qt::Application.restoreOverrideCursor()
      rescue => err
        ExceptionDialog.new(self, err, "File Open Errors", false)
      end
    end

    # Menu option to close the open table
    def file_close
      begin
        @core.reset
        @table_bin_label.text = ''
        @table_def_label.text = ''
        delete_tabs()
      rescue => err
        ExceptionDialog.new(self, err, "File New Errors", false)
      end
    end

    # Menu option to create a new table binary file based on a table definition file.
    def file_new
      if !@currently_displayed_table_name.empty?
        result = Qt::MessageBox.question(self, "File New",
          "Creating new files will close the currently open file.  Are you sure?",
          Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::Yes)
        if result != Qt::MessageBox::Yes
          return
        end
      end

      begin
        success = nil
        bin_files = []
        filenames = Qt::FileDialog.getOpenFileNames(self,
                                                  "Open Binary Definition Text File(s)",
                                                  @def_path,
                                                  "Config File (*.txt)\nAll Files (*)")

        # Check for a 0 length string which indicates the user clicked "Cancel" on the dialog
        if filenames and filenames.length != 0
          @def_path = File.dirname(filenames[0])
          file_close()
          output_dir = Qt::FileDialog.getExistingDirectory(self, "Select Output Directory", @bin_path)
          if output_dir
            @bin_path = output_dir
            filenames.each do |def_file|
              if File.basename(def_file) =~ /_def\.txt/
                basename = File.basename(def_file)[0...-8] # Get the basename without the _def.txt
              else
                basename = File.basename(def_file).split('.')[0...-1].join('.') # Get the basename without the extension
              end

              # Set the current_bin so the file_report function works correctly
              output_filename = File.join(output_dir, "#{basename}.dat")
              if File.exist?(output_filename)
                result = Qt::MessageBox.question(self, "File New",
                  "File: #{output_filename} already exists.  Overwrite?",
                  Qt::MessageBox::Yes | Qt::MessageBox::No, Qt::MessageBox::Yes)
                if result != Qt::MessageBox::Yes
                  return
                end
              end
            end

            ProgressDialog.execute(self, 'Create New Files', 500, 50, true, false, false, false, false) do |dialog|
              # create the file
              begin
                bin_files = @core.file_new(filenames, output_dir, dialog) do |progress|
                  dialog.set_overall_progress(progress)
                end
                success = true
                dialog.close_done
              rescue => err
                Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(self, err, "File New Errors", false)}
                dialog.close_done
              end
            end
          end # end output_dir.nil? (user did NOT click cancel on dialog)
          file_open(bin_files[0] ,filenames[0]) if success
        end # end filename != 0 (user did NOT click cancel on dialog)
      rescue => err
        ExceptionDialog.new(self, err, "File New Errors", false)
      end
    end

    # Called when the user selects another tab in the gui
    def handle_tab_change(index)
      @currently_displayed_table_name = @ordered_gui_table_names[index]
      @currently_displayed_table_name ||= '' # ensure it's not nil
    end

    def mouse_over(row, col)
      return if @currently_displayed_table_name.empty?
      table = @core.config.get_table(@currently_displayed_table_name)
      gui_table = @gui_tables[@currently_displayed_table_name]
      if table and gui_table
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
    end

    def click_callback(item)
      table = @core.config.get_table(@currently_displayed_table_name)
      gui_table = @gui_tables[@currently_displayed_table_name]
      gui_table.editItem(item) if (item.flags & Qt::ItemIsEditable) != 0
    end

    def context_menu(point)
      begin
        table = @core.config.get_table(@currently_displayed_table_name)
        gui_table = @gui_tables[@currently_displayed_table_name]
        if table and gui_table
          table_item = gui_table.itemAt(point)
          if table_item
            menu = Qt::Menu.new()

            if table.type == :TWO_DIMENSIONAL
              item_name = gui_table.horizontalHeaderItem(table_item.column).text + table_item.row.to_s
            else
              item_name = gui_table.verticalHeaderItem(table_item.row).text
            end
            details_action = Qt::Action.new(tr("Details"), self)
            details_action.statusTip = tr("Popup details about #{@currently_displayed_table_name} #{item_name}")
            details_action.connect(SIGNAL('triggered()')) do
              TlmDetailsDialog.new(nil,
                                   'TABLE',
                                   @currently_displayed_table_name.upcase,
                                   item_name,
                                   table)
            end
            menu.addAction(details_action)

            default_action = Qt::Action.new(tr("Default"), self)
            default_action.statusTip = tr("Set item to default value")
            default_action.connect(SIGNAL('triggered()')) do
              item = table.get_item(item_name)
              table.write(item.name, item.default)
              update_gui_item(@currently_displayed_table_name, table, item, table_item.row, table_item.column)
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
    def create_table_tab(table_definition)
      STDOUT.puts "table:#{table_definition}"
      begin
        # Table
        @table = Qt::TableWidget.new(self)
        delegate = ComboBoxItemDelegate.new(@table)
        @table.setItemDelegate(delegate)
        @table.setEditTriggers(Qt::AbstractItemView::AllEditTriggers)
        @table.setSelectionMode(Qt::AbstractItemView::NoSelection)
        #@table.setAlternatingRowColors(true)
        @gui_tables[table_definition.name] = @table
        @ordered_gui_table_names << table_definition.name
        @tabbook.addTab(@table, table_definition.name)

        @table.setRowCount(table_definition.num_rows)
        @table.setColumnCount(table_definition.num_columns)
        @table.setMouseTracking(true)
        connect(@table, SIGNAL('cellEntered(int, int)'), self, SLOT('mouse_over(int, int)'))
        connect(@table, SIGNAL('itemClicked(QTableWidgetItem*)'), self, SLOT('click_callback(QTableWidgetItem*)'))
        @table.setContextMenuPolicy(Qt::CustomContextMenu)
        connect(@table, SIGNAL('customContextMenuRequested(const QPoint&)'), self, SLOT('context_menu(const QPoint&)'))
      rescue => err
        ExceptionDialog.new(self, err, "create_table_tab Errors", false)
      end
    end

    # Saves all the information in the given gui table name to the underlying
    # binary structure (although it does not commit it to disk).
    def save_gui_data(name)
      gui_table = @gui_tables[name]
      table = @core.config.get_table(name)
      result = ""

      # Cancel any table selections so the text will be visible when it is refreshed
      gui_table.clearSelection

      # don't do anything if we can't find the table
      if gui_table.nil? or table.nil? then return end

      # First go through the gui and set the underlying data to what is displayed
      (0...table.num_rows).each do |r|
        (0...table.num_columns).each do |c|
          if table.type == :TWO_DIMENSIONAL
            # get the table item definition so we know how to save it
            item_def = table.get_item("#{gui_table.horizontalHeaderItem(c).text}#{r}")
          else # table is ONE_DIMENSIONAL
            # get the table item definition so we know how to save it
            item_def = table.get_item(gui_table.verticalHeaderItem(r).text)
          end

          # determine how to convert the display value to the actual value
          begin
            case item_def.display_type
            when :DEC
              if item_def.data_type == :FLOAT
                x = Float(gui_table.item(r,c).text)
              else
                x = Integer(gui_table.item(r,c).text)
              end

            when :HEX
              x = Integer(gui_table.item(r,c).text)

            when :CHECK
              # the ItemData will be 0 for unchecked (corresponds with min value),
              # and 1 for checked (corresponds with max value)
              if gui_table.item(r,c).checkState == Qt::Checked
                x = item_def.range.end.to_i
              else
                x = item_def.range.begin.to_i
              end

            when :STATE
              x = item_def.states[gui_table.item(r,c).text]

            when :STRING, :NONE
              x = gui_table.item(r,c).text

            end

            # If there is a read conversion we first read the converted value before writing.
            # This is to prevent writing the displayed value (which has the conversion applied)
            # back to the binary data if they are already equal.
            if item_def.read_conversion
              converted = table.read(item_def.name, :CONVERTED)
              table.write(item_def.name, x) if converted != x
            else
              table.write(item_def.name, x)
            end

          # if we have a problem casting the value it probably means the user put in garbage
          # in this case force the range check to fail
          rescue => error
            text = gui_table.item(r,c).text
            result << "Error saving #{item_def.name} value of '#{text}' due to #{error.message}.\nDefault value is '#{item_def.default}'\n"
          end
        end # end each table column
      end # end each table row
      if result == ""
        result = nil
      end
      result
    end

    # Determines how to display all the binary table data based on
    # the table definition and displays it using the various gui elements.
    def display_gui_data(name)
      config = @core.config.get_table(name)
      gui_table = @gui_tables[name]

      # Cancel any table selections so the text will be visible when it is refreshed
      gui_table.clearSelection

      # if we can't find the table do nothing
      if config.nil? or gui_table.nil? then return end

      items = config.sorted_items

      if config.type == :TWO_DIMENSIONAL
        row_headers = []
        (0...config.num_rows).each {|i| row_headers << "#{i+1}" }
        gui_table.setVerticalHeaderLabels(row_headers)

        column_headers = []
        (0...config.num_columns).each {|i| column_headers << items[i].name[0...-1] }
        gui_table.setHorizontalHeaderLabels(column_headers)
      else
        row_headers = []
        items.each {|item_def| row_headers << item_def.name }
        gui_table.setVerticalHeaderLabels(row_headers)
        gui_table.setHorizontalHeaderLabels(["Value"])
      end

      table_row = 0
      table_column = 0

      items.each do |item_def|
        update_gui_item(name, config, item_def, table_row, table_column)

        if config.type == :TWO_DIMENSIONAL
          # only increment our row when we've processed all the columns
          if table_column == config.num_columns - 1
            table_row += 1
            table_column = 0
          else
            table_column += 1
          end
        else
          table_row += 1
        end
      end

      gui_table.resizeColumnsToContents()
      gui_table.resizeRowsToContents()
    end

    # Updates the table by setting the value in the table to the properly formatted value.
    def update_gui_item(table_name, config, item_def, table_row, table_column)
      gui_table = @gui_tables[table_name]

      case item_def.display_type
      when :STATE
        item = Qt::TableWidgetItem.new
        item.setData(Qt::DisplayRole, Qt::Variant.new(config.read(item_def.name)))
        gui_table.setItem(table_row, table_column, item)
        if item_def.editable
          gui_table.item(table_row, table_column).setFlags(Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
        else
          gui_table.item(table_row, table_column).setFlags(Qt::NoItemFlags)
        end

      when :CHECK
        gui_table.setItem(table_row, table_column, Qt::TableWidgetItem.new(config.read(item_def.name)))
        # the ItemData will be 0 for unchecked (corresponds with min value),
        # and 1 for checked (corresponds with max value)
        if config.read(item_def.name) == item_def.range.begin
          gui_table.item(table_row, table_column).setCheckState(Qt::Unchecked)
        else
          gui_table.item(table_row, table_column).setCheckState(Qt::Checked)
        end
        if item_def.editable
          gui_table.item(table_row, table_column).setFlags(Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsUserCheckable)
        else
          gui_table.item(table_row, table_column).setFlags(Qt::NoItemFlags)
        end

      when :STRING, :NONE, :DEC
        gui_table.setItem(table_row, table_column, Qt::TableWidgetItem.new(tr(config.read(item_def.name).to_s)))
        if item_def.editable
          gui_table.item(table_row, table_column).setFlags(Qt::ItemIsSelectable | Qt::ItemIsEditable | Qt::ItemIsEnabled)
        else
          gui_table.item(table_row, table_column).setFlags(Qt::NoItemFlags)
        end

      when :HEX
        case item_def.bit_size
        when 8
          x = sprintf("%02X", config.read(item_def.name).to_s)
          # if the number was negative x will have .. and possibly another
          # F in the string which we remove by taking the last 4 digits
          x = /\w{2}$/.match(x)[0]
        when 16
          x = sprintf("%04X", config.read(item_def.name).to_s)
          # if the number was negative x will have .. and possibly another
          # F in the string which we remove by taking the last 4 digits
          x = /\w{4}$/.match(x)[0]
        else
          x = sprintf("%08X", config.read(item_def.name).to_s)
          # if the number was negative x will have .. and possibly another
          # F in the string which we remove by taking the last 8 digits
          x = /\w{8}$/.match(x)[0]
        end
        x = Integer("0x#{x}") # convert to Integer
        gui_table.setItem(table_row, table_column, Qt::TableWidgetItem.new(tr("0x%X" % x)))
        if item_def.editable
          gui_table.item(table_row, table_column).setFlags(Qt::ItemIsSelectable | Qt::ItemIsEditable | Qt::ItemIsEnabled)
        else
          gui_table.item(table_row, table_column).setFlags(Qt::NoItemFlags)
        end
      end
    end

    # Looks in a directory for a definition file for the given binary file.
    # The definition file name up to the _def.txt must be fully contained in
    # the given binary file. For example: XXX_YYY1_def.txt will be returned for
    # a binary file name of XXX_YYY1_Extra.bin. A binary file of XXX_YYY2.bin
    # will not match.
    #
    # @return [String|nil] Path to the best definition file or nil
    def get_best_definition_file(path, bin_file)
      def_file = nil

      # compare the filename with all possibilities in the directory
      Dir.foreach(path) do |possible_def_file|
        # only bother checking definition files
        index = possible_def_file.index('_def.txt')
        next unless index

        base_name = possible_def_file[0...index]
        if bin_file.index(base_name)
          # If we've already found a def_file and now found another match we
          # clear the first and stop the search. Force the user to decide.
          if def_file
            def_file = nil
            break
          end
          def_file = File.join(path, possible_def_file)
        end
      end # each file in the directory

      return def_file
    end

    # Prompts the user to select a binary table file to open.
    # (e.g. MyBinary_TC2.dat or MyBinaryJMT = MyBinary_def.dat)
    # Returns both the path to the binary file and the table definition file or
    # nil for both if either can not be found.
    def get_binary_and_definition_file_paths
      bin_file = nil
      def_file = nil

      bin_file = Qt::FileDialog.getOpenFileName(
        self, "Open Binary", @bin_path, "Binary File (*.bin *.dat);;All Files (*)")
      unless bin_file.nil? or bin_file.empty?
        @bin_path = File.dirname(bin_file)
        bin_file_base = File.basename(bin_file).split('.')[0]

        # Look in the binary file's base directory
        def_file = get_best_definition_file(File.dirname(bin_file), bin_file_base)
        def_found = !def_file.nil?

        if not def_found
          # Look in the stored definition file directory
          def_file = get_best_definition_file(@def_path, bin_file_base)
          def_found = !def_file.nil?
        end

        if def_found # if the definition file was automatically found
          return bin_file, def_file
        else # the definition file was not automatically found
          result = Qt::MessageBox.question(self, "Manually Open Definition File",
            "The definition text file for #{File.basename(bin_file)} could not be found.\nWould you like to manually locate it?",
            Qt::MessageBox::Yes | Qt::MessageBox::No | Qt::MessageBox::Cancel, Qt::MessageBox::Yes)
          if result == Qt::MessageBox::Yes
            def_file = Qt::FileDialog.getOpenFileName(self,
                                                    "Open Definition File",
                                                    @def_path,
                                                    "Definition File (*.txt)\nAll Files (*)")
            unless def_file.nil? or def_file.empty?
              if File.basename(def_file) =~ /\.txt/
                @def_path = File.dirname(def_file)
                return bin_file, def_file
              else
                Qt::MessageBox.information(self, "Open Definition File Errors",
                  "Definition file #{File.basename(def_file)} does not have .txt extension")
              end
            end # the user clicked Cancel on the File Open dialog
          end # the user clicked No when prompted to find the definition file
        end # end if the definition file wasn't found
      end # end if the user did not click Cancel on the Open dialog
      return nil, nil
    end

    # Delete all the tabs in the table manager gui and initialize globals to
    # prepare for the next table to load.
    def delete_tabs
      @gui_tables = Hash.new
      @ordered_gui_table_names = Array.new
      @currently_displayed_table_name = ""

      @tabbook.tabs.each_with_index do |tab, index|
        tab.dispose
        @tabbook.removeTab(index)
      end
    end

    def self.post_options_parsed_hook(options)
      if options.create
        core = TableManagerCore.new
        core.file_new([options.create], options.output_dir)
        false
      else
        true
      end
    end

    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
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
          option_parser.on("-o", "--output DIRECTORY", "Create files in the specified directory") do |arg|
            options.output_dir = arg
          end
        end
        super(option_parser, options)
      end
    end
  end

end # module Cosmos

