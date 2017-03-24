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
  require 'cosmos/script'
  require 'cosmos/gui/qt_tool'
  require 'cosmos/config/config_parser'
  require 'cosmos/gui/utilities/script_module_gui'
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/tools/cmd_sequence/cmd_sequence_item_delegate'
end

module Cosmos
  class SequenceItem < Qt::Frame
    MANUALLY = "MANUALLY ENTERED"
    HEIGHT = 30
    attr_accessor :index

    def self.param_widgets
      @@param_widgets
    end

    def self.table
      @@table
    end

    def initialize(command, index)
      super()
      @command = command
      @index = index
      @@table = nil
      @@param_widgets = []

      #setFixedHeight(HEIGHT)
      setStyleSheet("background-color:white")
      setFrameStyle(Qt::Frame::Box)
      #setAcceptDrops(true)

      top_layout = Qt::VBoxLayout.new
      top_layout.setContentsMargins(0, 0, 0, 0)
      setLayout(top_layout)

      layout = Qt::HBoxLayout.new
      layout.setContentsMargins(0, 0, 0, 0)

      edit_time = Qt::PushButton.new
      edit_time.setFixedSize(25, 25)
      time_icon = Cosmos.get_icon('edit.png')
      edit_time.setIcon(time_icon)
      layout.addWidget(edit_time)

      time = Qt::LineEdit.new(Time.now.formatted)
      fm = time.fontMetrics
      time.setFixedWidth(fm.boundingRect(Time.now.formatted).width + 10)
      time.setEnabled(false)
      time.setReadOnly(true)

      layout.addWidget(time)
      layout.addWidget(Qt::Label.new(command.target_name))
      layout.addWidget(Qt::Label.new(command.packet_name))
      layout.addStretch()

      delete = Qt::PushButton.new
      delete.setFixedSize(25, 25)
      delete_icon = Cosmos.get_icon('delete.png')
      delete.setIcon(delete_icon)
      delete.connect(SIGNAL('clicked()')) { self.dispose }
      layout.addWidget(delete)
      top_layout.addLayout(layout)

      @parameters = Qt::Widget.new
      parameters_layout = Qt::VBoxLayout.new
      # Command Description Label
      dec_label = Qt::Label.new(tr("Description:"))
      description = Qt::Label.new(command.description)
      description.setWordWrap(true)
      desc_layout = Qt::HBoxLayout.new
      desc_layout.addWidget(dec_label)
      desc_layout.addWidget(description, 1)
      parameters_layout.addLayout(desc_layout)

      # Parameters Label
      param_label = Qt::Label.new(tr("Parameters:"))
      parameters_layout.addWidget(param_label)

      # Grid Layout for Parameters
      @table_layout = Qt::VBoxLayout.new
      parameters_layout.addLayout(@table_layout, 500)
      @parameters.setLayout(parameters_layout)
      @parameters.hide
      top_layout.addWidget(@parameters)
      @expanded = false

      @show_ignored = Qt::Action.new(tr('&Show Ignored Parameters'), self)
      @show_ignored.statusTip = tr('Show ignored parameters which are normally hidden')
      @show_ignored.setCheckable(true)
      @show_ignored.setChecked(false)
      #connect(@show_ignored, SIGNAL('toggled(bool)'), self, SLOT('update_cmd_params(bool)'))

      @states_in_hex = Qt::Action.new(tr('&Display State Values in Hex'), self)
      @states_in_hex.statusTip = tr('Display states values in hex instead of decimal')
      @states_in_hex.setCheckable(true)
      @states_in_hex.setChecked(false)

      update_cmd_params()
    end

    def update_cmd_params(ignored_toggle = nil)
      old_params = {}
      if ignored_toggle.nil?
        ignored_toggle = false
      else
        ignored_toggle = true
      end

      target = System.targets[@command.target_name]
      packet_items = @command.sorted_items
      shown_packet_items = []
      packet_items.each do |packet_item|
        next if target and target.ignored_parameters.include?(packet_item.name) && !@show_ignored.checked?
        shown_packet_items << packet_item
      end

      # Destroy the old table widget
      @@table.dispose if @@table
      @@table = nil

      # Update Parameters
      @@param_widgets = []
      drawn_header = false

      row = 0
      shown_packet_items.each do |packet_item|
        next if target and target.ignored_parameters.include?(packet_item.name) && !@show_ignored.checked?
        value_item = nil
        state_value_item = nil

        unless drawn_header
          @@table = Qt::TableWidget.new()
          @@table.setSizePolicy(Qt::SizePolicy::Expanding, Qt::SizePolicy::Expanding)
          @@table.setWordWrap(true)
          @@table.setRowCount(shown_packet_items.length)
          @@table.setColumnCount(5)
          @@table.setHorizontalHeaderLabels(['Name', '         Value or State         ', '         ', 'Units', 'Description'])
          @@table.horizontalHeader.setStretchLastSection(true)
          @@table.verticalHeader.setVisible(false)
          @@table.setItemDelegate(CmdSequenceItemDelegate.new(@@table))
          @@table.setContextMenuPolicy(Qt::CustomContextMenu)
          @@table.verticalHeader.setResizeMode(Qt::HeaderView::ResizeToContents)
          @@table.setEditTriggers(Qt::AbstractItemView::AllEditTriggers)
          @@table.setSelectionMode(Qt::AbstractItemView::NoSelection)
          connect(@@table, SIGNAL('customContextMenuRequested(const QPoint&)'), self, SLOT('context_menu(const QPoint&)'))
          connect(@@table, SIGNAL('itemClicked(QTableWidgetItem*)'), self, SLOT('click_callback(QTableWidgetItem*)'))
          drawn_header = true
        end

        # Parameter Name
        item = Qt::TableWidgetItem.new("#{packet_item.name}:")
        item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
        @@table.setItem(row, 0, item)

        if packet_item.states
          default_state = packet_item.states.key(packet_item.default)
          if old_params[packet_item.name]
            value_item = Qt::TableWidgetItem.new(old_params[packet_item.name][0])
          else
            if default_state
              value_item = Qt::TableWidgetItem.new(default_state.to_s)
            else
              value_item = Qt::TableWidgetItem.new(MANUALLY)
            end
          end
          value_item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
          value_item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
          @@table.setItem(row, 1, value_item)

          if old_params[packet_item.name]
            state_value_item = Qt::TableWidgetItem.new(old_params[packet_item.name][1])
          else
            if @states_in_hex.checked? && packet_item.default.kind_of?(Integer)
              state_value_item = Qt::TableWidgetItem.new(sprintf("0x%X", packet_item.default))
            else
              state_value_item = Qt::TableWidgetItem.new(packet_item.default.to_s)
            end
          end
          state_value_item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
          state_value_item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
          @@table.setItem(row, 2, state_value_item)

          # If the parameter is required set the combobox to MANUAL and
          # clear the value field so they have to choose something
          if packet_item.required and !old_params[packet_item.name]
            value_item.setText(MANUALLY)
            state_value_item.setText('')
          end
        else
          # Parameter Value
          if old_params[packet_item.name]
            value_item = Qt::TableWidgetItem.new(old_params[packet_item.name])
          else
            if packet_item.required
              value_item = Qt::TableWidgetItem.new('')
            else
              if packet_item.format_string
                begin
                  value_item = Qt::TableWidgetItem.new(sprintf(packet_item.format_string, packet_item.default))
                rescue
                  # Oh well - Don't use the format string
                  value_item = Qt::TableWidgetItem.new(packet_item.default.to_s)
                end
              else
                value_item = Qt::TableWidgetItem.new(packet_item.default.to_s)
              end
            end
          end
          value_item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
          value_item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled | Qt::ItemIsEditable)
          @@table.setItem(row, 1, value_item)
          @@table.setSpan(row, 1, 1, 2)
        end

        # Units
        item = Qt::TableWidgetItem.new(packet_item.units.to_s)
        item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
        @@table.setItem(row, 3, item)

        # Description
        item = Qt::TableWidgetItem.new(packet_item.description.to_s)
        item.setTextAlignment(Qt::AlignLeft | Qt::AlignVCenter)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
        @@table.setItem(row, 4, item)

        @@param_widgets << [packet_item, value_item, state_value_item]
        row += 1
      end

      if @@table
        @@table.connect(SIGNAL('itemChanged(QTableWidgetItem*)')) do |item|
          packet_item, value_item, state_value_item = @@param_widgets[item.row]
          if item.column == 1
            if packet_item.states
              value = packet_item.states[value_item.text]
              @@table.blockSignals(true)
              if @states_in_hex.checked? && value.kind_of?(Integer)
                state_value_item.setText(sprintf("0x%X", value))
              else
                state_value_item.setText(value.to_s)
              end
              @@table.blockSignals(false)
            end
          elsif item.column == 2
            @@table.blockSignals(true)
            @@table.item(item.row, 1).setText(MANUALLY)
            @@table.blockSignals(false)
          end
        end
        @table_layout.addWidget(@@table, 500)
        @@table.resizeColumnsToContents()
        @@table.resizeRowsToContents()
      end

      height = 0
      @@table.rowCount.times do |x|
        height += @@table.verticalHeader.sectionSize(x) + 1
      end
      height += @@table.horizontalHeader.height + 1
      @@table.setMaximumHeight(height)
    end

    # These methods are for drag and drop support. It kind of works but the
    # indexing is off. Would need more support to make it useful to drag
    # commands in between existing commands. Currently it only supports
    # swapping commands with each other.

    def mousePressEvent(event)
      super(event)
      if event.button == Qt::LeftButton
        @dragStartPosition = event.pos
      end
      @expanded = !@expanded
      if @expanded
        @parameters.show
      else
        @parameters.hide
      end
    end

    #def mouseMoveEvent(event)
    #  super(event)
    #  return unless (event.buttons & Qt::LeftButton)
    #  return if (event.pos - @dragStartPosition).manhattanLength() < Qt::Application::startDragDistance()

    #  mime = Qt::MimeData.new()
    #  mime.setText(@index.to_s)
    #  drag = Qt::Drag.new(self)
    #  drag.setMimeData(mime)
    #  drop = drag.exec(Qt::MoveAction)
    #end

    #def dragEnterEvent(event)
    #  if event.mimeData.text != @text.to_s
    #    event.acceptProposedAction
    #    setStyleSheet("background-color:grey")
    #  end
    #end

    #def dragLeaveEvent(event)
    #  setStyleSheet("background-color:white")
    #end

    #def dropEvent(event)
    #  setStyleSheet("background-color:white")
    #  parentWidget.swap(@index, event.mimeData.text.to_i)
    #end

    # Code to draw the drop down arrows. Not sure this is really needed.

    #def paintEvent(event)
    #  painter = Qt::Painter.new(self)
    #  painter.setPen(palette.foreground.color)
    #  rect = event.rect
    #  painter.fillRect(rect, Qt::lightGray)
    #  painter.drawRect(rect.left, rect.top, rect.right, rect.bottom)

    #  # Draw the expand/collapse arrow
    #  painter.fillRect(rect.right - 15, rect.top + 1, 15, 21, Qt::lightGray)
    #  path = Qt::PainterPath.new()
    #  middle = HEIGHT / 2
    #  if @expanded == 1
    #    path.moveTo(rect.right - 12, middle)
    #    path.lineTo(rect.right - 4, middle)
    #    path.lineTo(rect.right - 8, middle + 4)
    #    path.lineTo(rect.right - 12, middle)
    #  else
    #    path.moveTo(rect.right - 9, middle + 4)
    #    path.lineTo(rect.right - 9, middle - 4)
    #    path.lineTo(rect.right - 5, middle)
    #    path.lineTo(rect.right - 9, middle + 4)
    #  end
    #  painter.drawPath(path)
    #  painter.end
    #  painter.dispose
    #end

    def view_as_script
      params = {}

      @@param_widgets.each do |packet_item, value_item, state_value_item|
        text = value_item.text

        text = state_value_item.text if state_value_item and (text == MANUALLY or @cmd_raw.checked?)
        quotes_removed = text.remove_quotes
        if text == quotes_removed
          params[packet_item.name] = text.convert_to_value
        else
          params[packet_item.name] = quotes_removed
        end
        raise "#{packet_item.name} is required." if quotes_removed == '' and packet_item.required
      end
      statusBar.clearMessage()

      output_string = build_cmd_output_string(@command.target_name, @command.packet_name, params, false)
      if output_string =~ /[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\xFF]/
        output_string = output_string.inspect.remove_quotes
      end

      return output_string, params
    end
  end

  class SequenceList < Qt::Widget
  # Code for drag and drop support. Needs additional work. Also needs work to
  # add support for dragging a command in between existing commands.

  #  def swap(index1, index2)
  #    STDOUT.puts "swap:#{index1}, #{index2} count:#{layout.count}"
  #    widget1 = layout.takeAt(index1).widget
  #    index1 = widget1.index
  #    widget2 = layout.takeAt(index2).widget
  #    index2 = widget2.index
  #    widget2.index = index1
  #    widget1.index = index2
  #    layout.insertWidget(index1, widget2)
  #    layout.insertWidget(index2, widget1)
  #  end
  end

  class CmdSequence < QtTool
    attr_accessor :open_action, :open_flash_action, :new_action, :save_action, :sort_action, :save_flash_action, :alert_box, :scroll
    attr_accessor :commands, :seq_top, :opcode_lookup, :desc_lookup, :currentRow, :dupIDs, :versionID
    attr_accessor :b_change_commands, :b_insert_before, :b_insert_after, :b_delete_commands, :b_move_up, :b_move_down
    attr_accessor :b_change_seqid, :b_move_seq_up, :b_move_seq_down
    attr_accessor :got_commands

    slots 'refresh_command_view_widget(int, int, int, int)'

    #seq_top->0[ seqid, cmdarr[] ]
    #                     @->0[ delay, opcode, description, expanded, checked, paramarr[] ]
    #                                                                            @->0[ name, value, states, description, units_full, units_abbrev, required ]
    #                                                                               1[ name, value, states, description, units_full, units_abbrev, required ]
    #                                                                               2[ name, value, states, description, units_full, units_abbrev, required ]
    #                        1[ delay, opcode, description, expanded, checked, paramarr[] ]
    #                                                                            @->0[ name, value, states, description, units_full, units_abbrev, required ]
    #                        2[ delay, opcode, description, expanded, checked, paramarr[] ]
    #                        3[ delay, opcode, description, expanded, checked, paramarr[] ]
    #                                                                            @->0[ name, value, states, description, units_full, units_abbrev, required ]
    #         1[ seqid, cmdarr[] ]
    # and so on...

    MANUALLY = "MANUALLY ENTERED"

    def self.run(option_parser = nil, options = nil)
      unless option_parser && options
        option_parser, options = create_default_options()
        options.width = 800
        options.height = 425
        options.title = 'Command Sequence'
      end
      super(option_parser, options)
    end

    def initialize(options)
      # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      super(options)
      Cosmos.load_cosmos_icon("cmd_sequence.png")

      @currentRow = 0

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

      @new_action = Qt::Action.new(tr('&New'), self)
      @new_action.shortcut = Qt::KeySequence.new(tr('Ctrl+N'))
      @new_action.statusTip = tr('New Sequence')
      @new_action.connect(SIGNAL('triggered()')) { new_sequence() }

      @open_action = Qt::Action.new(tr('&Open'), self)
      @open_action.shortcut = Qt::KeySequence.new(tr('Ctrl+O'))
      @open_action.statusTip = tr('Open Sequence')
      @open_action.connect(SIGNAL('triggered()')) { open_sequence() }

      @save_action = Qt::Action.new(tr('&Save'), self)
      @save_action.shortcut = Qt::KeySequence.new(tr('Ctrl+S'))
      @save_action.statusTip = tr('Save Sequence')
      @save_action.connect(SIGNAL('triggered()')) { save_sequence() }

      # TODO Save As

      @export_action = Qt::Action.new(tr('&Export Sequence'), self)
      @export_action.shortcut = Qt::KeySequence.new(tr('Ctrl+E'))
      @export_action.statusTip = tr('Export the current sequence to a custom binary format')
      @export_action.connect(SIGNAL('triggered()')) { export() }

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
      file_menu.addAction(@new_action)
      file_menu.addAction(@open_action)
      file_menu.addAction(@save_action)
      file_menu.addSeparator()
      file_menu.addAction(@exit_action)

      # Action Menu
      action_menu = menuBar.addMenu(tr('&Actions'))
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

      # Initialize scroll area
      @sequence_index = 0
      @sequence_list = SequenceList.new()
      list_layout = Qt::VBoxLayout.new()
      @sequence_list.setLayout(list_layout)
      @sequence_list.setSizePolicy(1, 0)

      @scroll = Qt::ScrollArea.new()
      @scroll.setWidgetResizable(true)
      @scroll.setWidget(@sequence_list)
      connect(@scroll.verticalScrollBar(), SIGNAL("valueChanged(int)"), @sequence_list, SLOT("update()"))
      central_layout.addWidget(@scroll)

      statusBar.showMessage("")

      @versionID = 0
      @seq_top = nil
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
      @sequence_list.layout.addWidget(SequenceItem.new(command, @sequence_index))
      @sequence_index += 1
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

    def open_sequence
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

    def save_sequence
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

    def new_sequence
      if @got_commands == 1

        @seq_top = []
        param_arr = []

        (1..200).each do |i|
          cmd_arr = []
          #cmd_arr << [0, 'SQNOOP', @desc_lookup['SQNOOP'], 0, 0, param_arr]
          @seq_top << [65535, cmd_arr]
        end

        refresh_table_view_widget
        enable_buttons
      else
        update_commands
        new_sequences unless @got_commands == 0
      end
    end

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
