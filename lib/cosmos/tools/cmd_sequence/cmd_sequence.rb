# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'time'
require 'cosmos'
Cosmos.catch_fatal_exception do
  require 'cosmos/script'
  require 'cosmos/config/config_parser'
  require 'cosmos/gui/qt_tool'
  require 'cosmos/gui/utilities/script_module_gui'
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/gui/dialogs/calendar_dialog'
  require 'cosmos/gui/widgets/realtime_button_bar'
  require 'cosmos/gui/choosers/file_chooser'
  require 'cosmos/gui/choosers/float_chooser'
  require 'cosmos/tools/cmd_sender/cmd_param_table_item_delegate'
  require 'cosmos/tools/cmd_sequence/sequence_item'
end

module Cosmos
  class SequenceList < Qt::Widget
    include Enumerable

    def initialize
      super()
      layout = Qt::VBoxLayout.new()
      layout.setContentsMargins(0, 0, 0, 0)
      layout.setSpacing(0)
      setLayout(layout)
      setSizePolicy(1, 0)
      layout.addWidget(create_header())
    end

    def create_header
      header = Qt::Widget.new
      header_layout = Qt::HBoxLayout.new
      header_layout.setContentsMargins(5, 5, 5, 5)
      header.setLayout(header_layout)
      time = Qt::Label.new("Time (Delay or Absolute)")
      time.setFixedWidth(130)
      header_layout.addWidget(time)
      command = Qt::Label.new("Command")
      header_layout.addWidget(command)
      header_layout.addStretch()
      header
    end

    def position(item)
      position = 0
      found = false
      Qt.execute_in_main_thread do
        # Start at 1 to avoid the header item
        (1...layout.count).each do |index|
          position = index
          if item == layout.itemAt(index).widget
            found = true
            break
          end
        end
      end
      # Subtract one for the header item so we're 0 based
      found ? position - 1 : -1
    end

    def add(command)
      layout.addWidget(SequenceItem.new(self, command))
    end

    def clear
      layout.removeAll
    end

    def each
      total_items = 1
      Qt.execute_in_main_thread { total_items = layout.count }
      (1...total_items).each do |index|
        item = nil
        Qt.execute_in_main_thread { item = layout.itemAt(index).widget }
        yield item
      end
    end

    # def swap(index1, index2)
    #   STDOUT.puts "swap:#{index1}, #{index2} count:#{layout.count}"
    #  widget1 = layout.takeAt(index1).widget
    #  index1 = widget1.index
    #  widget2 = layout.takeAt(index2).widget
    #  index2 = widget2.index
    #  widget2.index = index1
    #  widget1.index = index2
    #  layout.insertWidget(index1, widget2)
    #  layout.insertWidget(index2, widget1)
    # end

  #  def mousePressEvent(event)
  #    super(event)
  #    if event.button == Qt::LeftButton
  #      @dragStartPosition = event.pos
  #    end
  #    @expanded = !@expanded
  #    if @expanded
  #      @parameters.show
  #    else
  #      @parameters.hide
  #    end
  #  end
  #
  #  def mouseMoveEvent(event)
  #   super(event)
  #   return unless (event.buttons & Qt::LeftButton)
  #   return if (event.pos - @dragStartPosition).manhattanLength() < Qt::Application::startDragDistance()
  #
  #   mime = Qt::MimeData.new()
  #   mime.setText(@index.to_s)
  #   drag = Qt::Drag.new(self)
  #   drag.setMimeData(mime)
  #   drop = drag.exec(Qt::MoveAction)
  #  end
  #
  #  def dragEnterEvent(event)
  #   if event.mimeData.text != @text.to_s
  #     event.acceptProposedAction
  #     setStyleSheet("background-color:grey")
  #   end
  #  end
  #
  #  def dragLeaveEvent(event)
  #   setStyleSheet("background-color:")
  #  end
  #
  #  def dropEvent(event)
  #   setStyleSheet("background-color:white")
  #  end
  end

  class CmdSequence < QtTool
    MANUALLY = "MANUALLY ENTERED"

    def self.run(option_parser = nil, options = nil)
      unless option_parser && options
        option_parser, options = create_default_options()
        options.width = 600
        options.height = 425
        options.title = 'Command Sequence'
      end
      super(option_parser, options)
    end

    def initialize(options)
      # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      super(options)
      Cosmos.load_cosmos_icon("cmd_sequence.png")
      @procedure_dir = System.paths['PROCEDURES'][0]

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize() # defined in qt_tool

      # Bring up slash screen for long duration tasks after creation
      Splash.execute(self) do |splash|
        # Configure CosmosConfig to interact with splash screen
        ConfigParser.splash = splash

        System.commands
        Qt.execute_in_main_thread(true) do
          update_targets()
          @target_select.setCurrentText(options.packet[0]) if options.packet
          update_commands()
          @cmd_select.setCurrentText(options.packet[1]) if options.packet
        end

        # Unconfigure CosmosConfig to interact with splash screen
        ConfigParser.splash = nil
      end
    end

    def initialize_actions
      super()

      @file_new = Qt::Action.new(Cosmos.get_icon('file.png'), tr('&New'), self)
      @file_new_keyseq = Qt::KeySequence.new(tr('Ctrl+N'))
      @file_new.shortcut  = @file_new_keyseq
      @file_new.statusTip = tr('Start a new sequence')
      @file_new.connect(SIGNAL('triggered()')) { file_new() }

      @file_save = Qt::Action.new(Cosmos.get_icon('save.png'), tr('&Save'), self)
      @file_save_keyseq = Qt::KeySequence.new(tr('Ctrl+S'))
      @file_save.shortcut  = @file_save_keyseq
      @file_save.statusTip = tr('Save the sequence')
      @file_save.connect(SIGNAL('triggered()')) { file_save(false) }

      @file_save_as = Qt::Action.new(Cosmos.get_icon('save_as.png'), tr('Save &As'), self)
      @file_save_as.statusTip = tr('Save the sequence')
      @file_save_as.connect(SIGNAL('triggered()')) { file_save(true) }

      @export_action = Qt::Action.new(tr('&Export Sequence'), self)
      @export_action.shortcut = Qt::KeySequence.new(tr('Ctrl+E'))
      @export_action.statusTip = tr('Export the current sequence to a custom binary format')
      @export_action.connect(SIGNAL('triggered()')) { export() }

      @script_disconnect = Qt::Action.new(Cosmos.get_icon('disconnected.png'), tr('&Toggle Disconnect'), self)
      @script_disconnect_keyseq = Qt::KeySequence.new(tr('Ctrl+T'))
      @script_disconnect.shortcut  = @script_disconnect_keyseq
      @script_disconnect.statusTip = tr('Toggle disconnect from the server')
      @script_disconnect.connect(SIGNAL('triggered()')) do
        @server_config_file ||= CmdTlmServer::DEFAULT_CONFIG_FILE
        @server_config_file = toggle_disconnect(@server_config_file)
      end

      @expand_action = Qt::Action.new(tr('&Expand All'), self)
      @expand_action.shortcut = Qt::KeySequence.new(tr('Ctrl+E'))
      @expand_action.statusTip = tr('Expand all currently visible commands')
      @expand_action.connect(SIGNAL('triggered()')) do
        if @seq_top
          size = @seq_top[@currentRow][1].size
          (0..size-1).each do |i|
            @seq_top[@currentRow][1][i][3] = 1
          end
          refresh_command_view_widget(@currentRow)
        end
      end

      @collapse_action = Qt::Action.new(tr('&Collapse All'), self)
      @collapse_action.shortcut = Qt::KeySequence.new(tr('Ctrl+C'))
      @collapse_action.statusTip = tr('Collapse all currently visible commands')
      @collapse_action.connect(SIGNAL('triggered()')) do
        if @seq_top
          size = @seq_top[@currentRow][1].size
          (0..size-1).each do |i|
            @seq_top[@currentRow][1][i][3] = 0
          end
          refresh_command_view_widget(@currentRow)
        end
      end
    end

    def initialize_menus
      # File menu
      file_menu = menuBar.addMenu(tr('&File'))
      file_menu.addAction(@file_new)

      open_action = Qt::Action.new(self)
      open_action.shortcut = Qt::KeySequence.new(tr('Ctrl+O'))
      open_action.connect(SIGNAL('triggered()')) { file_open(@procedure_dir) }
      self.addAction(open_action)

      file_open = file_menu.addMenu(tr('&Open'))
      file_open.setIcon(Cosmos.get_icon('open.png'))
      target_dirs_action(file_open, System.paths['PROCEDURES'], 'procedures', method(:file_open))

      file_menu.addAction(@file_save)
      file_menu.addAction(@file_save_as)
      file_menu.addSeparator()
      file_menu.addAction(@exit_action)

      # Action Menu
      action_menu = menuBar.addMenu(tr('&Actions'))
      action_menu.addAction(@script_disconnect)
      action_menu.addAction(@expand_action)
      action_menu.addAction(@collapse_action)

      # Help Menu
      @about_string = "Sequence Generator allows the user to generate sequences of commands."
      initialize_help_menu()
    end

    def initialize_central_widget
      central_widget = Qt::Widget.new
      setCentralWidget(central_widget)
      central_layout = Qt::VBoxLayout.new
      central_widget.layout = central_layout

      # Realtime Button Bar
      @realtime_button_bar = RealtimeButtonBar.new(self)
      @realtime_button_bar.start_callback = method(:handle_start)
      @realtime_button_bar.pause_callback = method(:handle_pause)
      @realtime_button_bar.stop_callback  = method(:handle_stop)
      @realtime_button_bar.state = 'Stopped'
      central_layout.addWidget(@realtime_button_bar)

      # Set the target combobox selection
      @target_select = Qt::ComboBox.new
      @target_select.setMaxVisibleItems(6)
      @target_select.connect(SIGNAL('activated(const QString&)')) { |target| target_changed(target) } #, self, SLOT('target_changed(const QString&)'))
      target_label = Qt::Label.new(tr("&Target:"))
      target_label.setBuddy(@target_select)

      # Set the comamnd combobox selection
      @cmd_select = Qt::ComboBox.new
      @cmd_select.setMaxVisibleItems(20)
      cmd_label = Qt::Label.new(tr("&Command:"))
      cmd_label.setBuddy(@cmd_select)

      # Button to send command
      add = Qt::PushButton.new("Add")
      add.connect(SIGNAL('clicked()')) { add_command() }

      # Layout the top level selection
      select_layout = Qt::HBoxLayout.new
      select_layout.addWidget(target_label)
      select_layout.addWidget(@target_select, 1)
      select_layout.addWidget(cmd_label)
      select_layout.addWidget(@cmd_select, 1)
      select_layout.addWidget(add)
      central_layout.addLayout(select_layout)

      # Create a splitter to hold the sequence area and the script output text area
      splitter = Qt::Splitter.new(Qt::Vertical, self)
      central_layout.addWidget(splitter)

      # Initialize scroll area
      @sequence_list = SequenceList.new
      @sequence_index = 0

      scroll = Qt::ScrollArea.new()
      scroll.setSizePolicy(Qt::SizePolicy::Preferred, Qt::SizePolicy::Expanding)
      scroll.setWidgetResizable(true)
      scroll.setWidget(@sequence_list)
      connect(scroll.verticalScrollBar(), SIGNAL("valueChanged(int)"), @sequence_list, SLOT("update()"))
      splitter.addWidget(scroll)

      # Output Text
      bottom_frame = Qt::Widget.new
      bottom_layout = Qt::VBoxLayout.new
      bottom_layout.setContentsMargins(0,0,0,0)
      bottom_layout_label = Qt::Label.new("Script Output:")
      bottom_layout.addWidget(bottom_layout_label)
      @output = Qt::TextEdit.new
      @output.setReadOnly(true)
      bottom_layout.addWidget(@output)
      bottom_frame.setLayout(bottom_layout)
      splitter.addWidget(bottom_frame)
      splitter.setStretchFactor(0,1)
      splitter.setStretchFactor(1,0)

      statusBar.showMessage("")
    end

    def target_changed(target)
      update_commands()
    end

    def update_targets
      @target_select.clearItems()
      target_names = System.commands.target_names
      target_names_to_delete = []
      target_names.each do |target_name|
        found_non_hidden = false
        begin
          packets = System.commands.packets(target_name)
          packets.each do |packet_name, packet|
            found_non_hidden = true unless packet.hidden
          end
        rescue
          # Don't do anything
        end
        target_names_to_delete << target_name unless found_non_hidden
      end
      target_names_to_delete.each do |target_name|
        target_names.delete(target_name)
      end
      target_names.each do |target_name|
        @target_select.addItem(target_name)
      end
    end

    def update_commands
      @cmd_select.clearItems()
      target_name = @target_select.text
      if target_name
        commands = System.commands.packets(target_name)
        command_names = []
        commands.each do |command_name, command|
          command_names << command_name unless command.hidden
        end
        command_names.sort!
        command_names.each do |command_name|
          @cmd_select.addItem(command_name)
        end
      end
    end

    def add_command
      command = System.commands.packet(@target_select.text, @cmd_select.text)
      @sequence_list.add(command)
    end

    def handle_start
      case @realtime_button_bar.state
      when 'Stopped'
        @pause = false
        @go = false
        @realtime_button_bar.state = 'Running'
        @realtime_button_bar.start_button.setText('Go')
        @output.append("Executing Sequence at #{Time.now}")
        @run_thread = Thread.new do
          @sequence_list.each_with_index do |item, index|
            execute_item(item, index)
          end
          Qt.execute_in_main_thread do
            @output.append("")
            @realtime_button_bar.start_button.setText('Start')
            @realtime_button_bar.start_button.setEnabled(true)
            @realtime_button_bar.state = 'Stopped'
          end
        end
      when 'Paused'
        @realtime_button_bar.state = 'Running'
        @pause = false
      when 'Running'
        @realtime_button_bar.state = 'Running'
        @go = true
      end
    end

    def handle_pause
      @pause = true
      @realtime_button_bar.state = 'Paused'
      @realtime_button_bar.start_button.setEnabled(true)
    end

    def handle_stop
      Cosmos.kill_thread(nil, @run_thread)
      @realtime_button_bar.start_button.setEnabled(true)
      @realtime_button_bar.start_button.setText('Start')
      @realtime_button_bar.state = 'Stopped'
    end

    def execute_item(item, index)
      result = ''
      Qt.execute_in_main_thread do
        item.setStyleSheet("color: green")
        Qt::CoreApplication.processEvents()
      end

      # Check for the first item containing a date
      if index == 0 && item.time.include?('/')
        start_time = Time.parse(item.time)
        if start_time - Time.now > 0
          while start_time - Time.now > 0
            if @go
              @go = false
              break
            end
            if @pause
              sleep 0.1 while @pause
            else
              sleep 0.1
            end
          end
        else
          result = "WARNING: Start time #{start_time} has already passed!\n"
        end
      else
        start = Time.now
        while (Time.now - start) < item.time.to_f
          if @go
            @go = false
            break
          end
          if @pause
            sleep 0.1 while @pause
          else
            sleep 0.1
          end
        end
      end

      target, packet, params = item.command_parts
      output_string, _ = item.view_as_script
      result += Time.now.sys.formatted + ':  ' + output_string
      cmd_no_hazardous_check(target, packet, params)
    rescue DRb::DRbConnError
      result = "Error Connecting to Command and Telemetry Server"
    rescue Exception => err
      result = "Error sending #{target} #{packet} due to #{err}\n#{err.backtrace}"
    ensure
      Qt.execute_in_main_thread do
        item.setStyleSheet("")
        @output.append(result)
        @output.moveCursor(Qt::TextCursor::End)
        @output.ensureCursorVisible()
      end
    end

    def toggle_disconnect(config_file)
      if get_cmd_tlm_disconnect
        set_cmd_tlm_disconnect(false)
        self.setPalette(Cosmos::DEFAULT_PALETTE)
      else
        dialog = Qt::Dialog.new(self, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
        dialog.setWindowTitle(tr("Server Config File"))
        dialog_layout = Qt::VBoxLayout.new

        chooser = FileChooser.new(self, "Config File", config_file, 'Select',
                                  File.join('config', 'tools', 'cmd_tlm_server', config_file))
        chooser.callback = lambda do |filename|
          chooser.filename = File.basename(filename)
        end
        dialog_layout.addWidget(chooser)

        button_layout = Qt::HBoxLayout.new
        ok = Qt::PushButton.new("Ok")
        ok.setDefault(true)
        ok.connect(SIGNAL('clicked()')) do
          dialog.accept()
        end
        button_layout.addWidget(ok)
        cancel = Qt::PushButton.new("Cancel")
        cancel.connect(SIGNAL('clicked()')) do
          dialog.reject()
        end
        button_layout.addWidget(cancel)
        dialog_layout.addLayout(button_layout)

        dialog.setLayout(dialog_layout)
        if dialog.exec == Qt::Dialog::Accepted
          config_file = chooser.filename
          self.setPalette(Qt::Palette.new(Cosmos.getColor(170, 57, 57)))
          Splash.execute(self) do |splash|
            ConfigParser.splash = splash
            splash.message = "Initializing Command and Telemetry Server"
            set_cmd_tlm_disconnect(true, config_file)
            ConfigParser.splash = nil
          end
        end
        dialog.dispose
      end
      config_file
    end

    def file_new
      # TODO Check for changes and offer save
      @sequence_list.clear
    end

    def file_open(filename = nil)
      if File.directory?(filename)
        filename = Qt::FileDialog.getOpenFileName(self, "Select Script", filename)
      end
      unless filename.nil? || filename.empty?
        @sequence_list.add()

        @procedure_dir = File.dirname(filename)
        @procedure_dir << '/' if @procedure_dir[-1..-1] != '/' and @procedure_dir[-1..-1] != '\\'
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
          statusBar.showMessage(tr("#{filename} saved"))
          @procedure_dir = File.dirname(filename)
          @procedure_dir << '/' if @procedure_dir[-1..-1] != '/' and @procedure_dir[-1..-1] != '\\'
        rescue => error
          statusBar.showMessage(tr("Error Saving Script : #{error.class} : #{error.message}"))
        end
      end
      saved
    end
    #def menu_states_in_hex(checked)
    #  if not @param_widgets.nil?
    #    @param_widgets.each do |label, control, state_value_field, units, desc, required|
    #      if state_value_field
    #        text = state_value_field.text
    #        quotes_removed = text.remove_quotes
    #        if text == quotes_removed
    #          if checked
    #            if text.is_int?
    #              state_value_field.text = sprintf("0x%X", text.to_i)
    #            end
    #          else
    #            if text.is_hex?
    #              state_value_field.text = Integer(text).to_s
    #            end
    #          end
    #        end
    #      end
    #    end
    #  end
    #end #menu_states_in_hex

    def open_sequence2
      if @got_commands == 1
        tfd = TwoFileDialog.new()
        tfd.exec()

        seqDefFile = nil
        cmdSeqFile = nil

        if tfd.gotFiles

          seqDefFile = tfd.seqDefFile
          cmdSeqFile = tfd.cmdSeqFile

          param_arr = []
          temp_arr = []
          @seq_top = []
          sdef = File.open(seqDefFile, "rb")
          cdef = File.open(cmdSeqFile, "rb")
          (0..199).each do |i|
            statusBar.showMessage("Parsing files... #{i/2}%")
            seqid = IO.binread(seqDefFile, 2, i*8).unpack('S>').to_s.delete('[]').to_i
            numcmds = IO.binread(seqDefFile, 2, i*8+2).unpack('S>').to_s.delete('[]').to_i
            offset = IO.binread(seqDefFile, 4, i*8+4).unpack('L>').to_s.delete('[]').to_i
            temp_arr << [seqid, numcmds, offset]
            cmd_arr = []
            (1..numcmds).each do |c|
              delay = IO.binread(cmdSeqFile, 4, offset).unpack('L>').to_s.delete('[]').to_i
              appid = IO.binread(cmdSeqFile, 2, offset+4).unpack('S>').to_s.delete('[]').to_i
              opcode = IO.binread(cmdSeqFile, 2, offset+6).unpack('S>').to_s.delete('[]').to_i
              datalen = IO.binread(cmdSeqFile, 2, offset+8).unpack('S>').to_s.delete('[]').to_i
              databuf = IO.binread(cmdSeqFile, datalen, offset+10) unless datalen == 0
              offset = offset + 10 + datalen
              # Reverse lookup the opcod, get its parameters, read the data, and make the arrays.
              opcode_str = @opcode_lookup.key([appid, opcode])

              command = System.commands.build_cmd('SSV',opcode_str)
              buf = command.buffer
              buf[12..-3] = databuf unless datalen == 0
              command = System.commands.identify(buf, ['SSV'])
              params = get_cmd_param_list('SSV', opcode_str)
              param_arr = []
              params.each do |param_name, default, states, description, units_full, units_abbrev, required|
                if !System.targets['SSV'].ignored_parameters.include?(param_name)
                  default = command.read_item(command.items[param_name], :RAW)
                  param_arr << [param_name, default, states, description, units_full, units_abbrev, required]
                end
              end
              cmd_arr << [delay, opcode_str, @desc_lookup[opcode_str], 0, 0, param_arr]
            end
            @seq_top << [seqid, cmd_arr]
          end

          table_data = []
          temp_arr.each do |id, num, off|
            table_data << [id.to_s.delete("[]"), num.to_s.delete("[]"), off.to_s.delete("[]")]
          end
          @sequences.data = table_data
          @sequences.resizeColumnsToContents()
          width = @sequences.verticalHeader.width + @sequences.columnWidth(0) + @sequences.columnWidth(1) + @sequences.columnWidth(2) + @sequences.columnWidth(3) + 20
          @sequences.setMaximumWidth(width)
          @sequences.selectRow(0)
          statusBar.showMessage("")
          enable_buttons
        end
      else
        update_commands
        load_sequences unless @got_commands == 0
      end
    end

    def save_sequence2
      if @seq_top
        if check_duplicate_sequence_ids
          dupstr = ""
          @dupIDs.each do |x|
            dupstr = dupstr + ", " + x.to_s
          end
          dupstr = dupstr[1,dupstr.length-1]
          alert("Duplicate sequence ID's detected: #{dupstr}. Files cannot be saved until corrected.", "Error")
        else
          # No duplicates, save the files.
          tfd = TwoFileDialog.new(false)
          tfd.exec()
          seqDefFile = nil
          cmdSeqFile = nil
          if tfd.gotFiles
            prev_offset = 0
            offset = 0
            cmdSeqFile = File.open(tfd.cmdSeqFile, "wb")
            seqDefFile = File.open(tfd.seqDefFile, "wb")

            statusBar.showMessage("Writing files... ")
            @seq_top.each do |seqid, cmdarr|
              if seqid != 65535
                seqDefFile.write([seqid, cmdarr.size, cmdSeqFile.size].pack('S>S>L>'))
              else
                seqDefFile.write([65535, 0, 0].pack('S>S>L>'))
              end

              cmdarr.each do |delay, opcode_str, description, expanded, checked, paramarr|

                params = Hash.new()
                paramarr.each do |name, value, states, description, units_full, units_abbrev, required|
                  params[name] = value
                end
                rc = true
                begin
                  command = System.commands.build_cmd('SSV', opcode_str, params, rc)
                rescue
                  alert "Warning: " + $!.inspect
                  rc = false
                  retry
                end
                databuf = command.buffer[12..-3]

                # Write delay, appid, opcode, datalen, databuf to command sequence file
                appid = command.read_item(command.items['CCSDSAPID'])
                opcode = command.read_item(command.items['PKTID'])

                cmdSeqFile.write([delay].pack("L>"))
                cmdSeqFile.write([appid].pack("S>"))
                cmdSeqFile.write([opcode].pack("S>"))
                cmdSeqFile.write([databuf.size].pack("S>"))
                cmdSeqFile.write(databuf) unless databuf.size == 0

                prev_offset = offset
                offset = offset + databuf.size + 10
              end

              # Write seqid, numcommands, offset to sequence definition file
            end

            until cmdSeqFile.size >= (255*1024)
              cmdSeqFile.write([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0].pack("Q*"))
              statusBar.showMessage("Writing files... #{cmdSeqFile.size} / 262144 bytes")
            end
            until cmdSeqFile.size >= (262080)
              cmdSeqFile.write([0,0,0,0,0,0,0,0].pack("Q"))
              statusBar.showMessage("Writing files... #{cmdSeqFile.size} / 262144 bytes")
            end
            until cmdSeqFile.size == (262144)
              cmdSeqFile.write([0].pack("c"))
              statusBar.showMessage("Writing files... #{cmdSeqFile.size} / 262144 bytes")
            end
            statusBar.showMessage("")
            cmdSeqFile.close
            seqDefFile.close
          end
        end
      else
        alert("Error: No sequences are currently open.", "Error")
      end
    end #save_sequences

    def refresh_table_view_widget
      #TODO: create calculate offset function
      data = []
      i = -1
      unless @seq_top == nil
        @seq_top.each do |id, cmdarr|
          i += 1
          data << [id, cmdarr.length, calculate_offset(i)]
        end
      end
      # Initialize sequences table
      @sequences.data = data
      @sequences.resizeColumnsToContents()
      width = @sequences.verticalHeader.width + @sequences.columnWidth(0) + @sequences.columnWidth(1) + @sequences.columnWidth(2) + @sequences.columnWidth(3) + 20
      @sequences.setMaximumWidth(width)
      @sequences.selectRow(@currentRow)
    end

    def refresh_command_view_widget(curr = 0, curc = 0, prevr = 0, prevc = 0)
      @currentRow = curr

      vlayout = Qt::VBoxLayout.new()
      tw = Qt::Widget.new()
      tw.setLayout(vlayout)
      #tw.setSizePolicy(1, 0)
      connect(@scroll.verticalScrollBar(), SIGNAL("valueChanged(int)"), tw, SLOT("update()"))

      i = -1
      @seq_top.at(curr).at(1).each do |delay, opcode, desc, expanded, checked, param_arr|
        i += 1
        hlayout = Qt::HBoxLayout.new()
        cb = IndexCheckBox.new(i)
        cb.setCheckState(checked)
        cb.connect(SIGNAL('iStateChanged(int, int)')) do |idx, s|
          @seq_top.at(curr)[1][idx][4] = s
        end
        cb.setMaximumWidth(16)
        hlayout.addWidget(cb)

        ddw = DropDownWidget.new(i, opcode, delay, desc)
        group = Qt::GroupBox.new()
        group.hide() unless expanded == 1
        ddw.expandOrCollapse unless expanded == 0
        connect(ddw, SIGNAL('expand(int)')) do |idx|
          @seq_top.at(curr)[1][idx][3] = 1
          group.show()
        end
        connect(ddw, SIGNAL('collapse(int)')) do |idx|
          @seq_top.at(curr)[1][idx][3] = 0
          group.hide()
        end
        hlayout.addWidget(ddw)

        vlayout.addLayout(hlayout)

        # Update Parameters
        target_name = 'SSV'
        packet_name = opcode

        drawn_header = false

        @param_widgets = []
        index = 2
        param_grid = Qt::GridLayout.new()

        param_arr.each do |param_name, default, states, description, units_full, units_abbrev, required|

          target = System.targets[target_name]
          if target and target.ignored_parameters.include?(param_name)
            next
          end

          unless drawn_header
            param_grid.addWidget(Qt::Label.new("Name"), 0,0)
            param_grid.addWidget(Qt::Label.new("Value"), 0,1)
            param_grid.addWidget(Qt::Label.new("Units"), 0,2)
            param_grid.addWidget(Qt::Label.new("Description"), 0,3)
            # Make the grid prefer the Description column when allocating space
            param_grid.setColumnStretch(3,1)
            sep1 = Qt::Frame.new(param_grid.parentWidget)
            sep1.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
            param_grid.addWidget(sep1, 1,0)
            sep2 = Qt::Frame.new(param_grid.parentWidget)
            sep2.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
            param_grid.addWidget(sep2, 1,1)
            sep3 = Qt::Frame.new(param_grid.parentWidget)
            sep3.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
            param_grid.addWidget(sep3, 1,2)
            sep4 = Qt::Frame.new(param_grid.parentWidget)
            sep4.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
            param_grid.addWidget(sep4, 1,3)
            drawn_header = true
          end
          label = Qt::Label.new(param_name.to_s)
          param_grid.addWidget(label, index, 0)

          if states.nil?
            control = nil
            state_value_field = IndexLineEdit.new(i, index-2)
            # Don't set the default edit value if the parameter is required
            state_value_field.setText(default.to_s) unless required
            state_value_field.setAlignment(Qt::AlignRight)
            state_value_field.connect(SIGNAL('iTextChanged(int, int, const QString&)')) do |cmd_index, param_index, s|
              quotes_removed = s.remove_quotes
              if s == quotes_removed
                s = s.convert_to_value
              else
                s = quotes_removed
              end
              @seq_top[@currentRow][1][cmd_index][5][param_index][1] = s
            end
            param_grid.addWidget(state_value_field, index, 1)
          else
            control = Qt::ComboBox.new
            default_state = states.key(default)
            sorted_states = states.sort {|a, b| a[1] <=> b[1]}
            sorted_states.each do |state_name, state_value|
              control.addItem(state_name)
            end
            control.addItem(MANUALLY)
            if default_state
              control.setCurrentText(default_state)
            else
              control.setCurrentText(MANUALLY)
            end
            control.setMaxVisibleItems(6)

            state_value_field = IndexLineEdit.new(i, index-2)
            state_value_field.connect(SIGNAL('iTextChanged(int, int, const QString&)')) do |cmd_index, param_index, s|
              quotes_removed = s.remove_quotes
              if s == quotes_removed
                s = s.convert_to_value
              else
                s = quotes_removed
              end
              @seq_top[@currentRow][1][cmd_index][5][param_index][1] = s
            end
            state_value_field.connect(SIGNAL('textEdited(const QString&)')) do
              control.setCurrentText(MANUALLY)
            end

            if @states_in_hex.checked? && default.kind_of?(Integer)
              state_value_field.setText(sprintf("0x%X", default))
            else
              state_value_field.setText(default.to_s)
            end
            state_value_field.setAlignment(Qt::AlignRight)
            control.connect(SIGNAL('activated(const QString&)')) do
              value = states[control.text]
              if @states_in_hex.checked? && default.kind_of?(Integer)
                state_value_field.text = sprintf("0x%X", value)
              else
                state_value_field.text = value.to_s
              end
            end
            # If the parameter is required set the combobox to MANUAL and
            # clear the value field so they have to choose something
            if required
              control.setCurrentText(MANUALLY)
              state_value_field.clear
            end
            hframe = Qt::HBoxLayout.new
            hframe.addWidget(control)
            hframe.addWidget(state_value_field)
            param_grid.addLayout(hframe, index, 1)
          end
          units = Qt::Label.new(units_abbrev.to_s)
          param_grid.addWidget(units, index, 2)
          desc = Qt::Label.new(description)
          desc.setWordWrap(true)
          desc.sizePolicy.setHeightForWidth(true)
          param_grid.addWidget(desc, index, 3)
          @param_widgets << [label, control, state_value_field, units, desc, required]
          index += 1

        end
        group.setLayout(param_grid)
        #vlayout.addLayout(param_grid)
        vlayout.addWidget(group)
      end
      vlayout.addStretch(1)
      @scroll.setWidget(tw)
    end

  end
end
