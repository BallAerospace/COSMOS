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
  require 'cosmos/gui/dialogs/calendar_dialog'
  require 'cosmos/tools/cmd_sender/cmd_param_table_item_delegate'
end

module Cosmos
  class SequenceItem < Qt::Frame # Inherit from Frame so we can use setFrameStyle
    MANUALLY = "MANUALLY ENTERED"

    # Custom LineEdit class that emits the calendar signal when it receives
    # focus and whose parent widget's index is 0. This allows the first
    # SequenceItem in the list to display a CalendarDialog when the time
    # is edited. All others simply edit the relative time delay.
    class TimeEdit < Qt::LineEdit
      signals 'calendar()'
      def initialize(value)
        super(value)
        setValidator(Qt::DoubleValidator.new(0, Float::MAX, 2))
      end
      def focusInEvent(e)
        # This items parentWidget is the SequenceItem whose parent is the
        # container with the position method. We want the position of the
        # SequenceItem so we pass in the parentWidget to see if it's first.
        if parentWidget.parent.position(parentWidget) == 0
          emit calendar()
        else
          super(e)
        end
      end
    end

    def initialize(parent, command)
      super()
      @parent = parent
      @command = command
      @table = nil
      @param_widgets = []

      setAutoFillBackground(true)
      setPalette(Cosmos.getPalette("black", "white"))
      setFrameStyle(Qt::Frame::Box)

      top_layout = Qt::VBoxLayout.new
      top_layout.setContentsMargins(0, 0, 0, 0)
      setLayout(top_layout)

      layout = Qt::HBoxLayout.new
      layout.setContentsMargins(0, 0, 0, 0)

      @time = TimeEdit.new(Time.now.formatted)
      fm = @time.fontMetrics
      @time.setFixedWidth(fm.boundingRect(Time.now.formatted).width + 10)
      @time.text = "0.00"
      @time.connect(SIGNAL('calendar()')) do
        state = @time.blockSignals(true)
        dialog = CalendarDialog.new(self, "Select Absolute Execution Time:", Time.now, true)
        case dialog.exec
        when Qt::Dialog::Accepted
          @time.text = dialog.time.formatted
        end
        @time.blockSignals(state)
      end
      layout.addWidget(@time)

      @cmd_name = Qt::Label.new("#{command.target_name} #{command.packet_name}")
      layout.addWidget(@cmd_name)
      @cmd_info = Qt::Label.new("")
      layout.addWidget(@cmd_info)
      layout.addStretch()

      delete = Qt::PushButton.new
      delete.setFixedSize(25, 25)
      delete_icon = Cosmos.get_icon('delete.png')
      delete.setIcon(delete_icon)
      delete.connect(SIGNAL('clicked()')) do
        emit destroyed()
        self.dispose
      end
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
      @show_ignored.connect(SIGNAL('toggled(bool)')) { update_cmd_params(bool) }

      @states_in_hex = Qt::Action.new(tr('&Display State Values in Hex'), self)
      @states_in_hex.statusTip = tr('Display states values in hex instead of decimal')
      @states_in_hex.setCheckable(true)
      @states_in_hex.setChecked(false)

      update_cmd_params()
      begin
        output, params = view_as_script
        @cmd_name.text = output[5..-3]
        hazardous, _ = System.commands.cmd_hazardous?(@command.target_name, @command.packet_name, params)
        @cmd_info.text = "(Hazarous)" if hazardous
      rescue => err
        # This rescue typically catches required parameters that haven't been
        # given yet so put it in the cmd_info to warn the user
        @cmd_info.text = "(#{err.message})"
      end
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
      @table.dispose if @table
      @table = nil

      # Update Parameters
      @param_widgets = []
      drawn_header = false

      row = 0
      shown_packet_items.each do |packet_item|
        next if target and target.ignored_parameters.include?(packet_item.name) && !@show_ignored.checked?
        value_item = nil
        state_value_item = nil

        unless drawn_header
          @table = Qt::TableWidget.new()
          @table.setSizePolicy(Qt::SizePolicy::Expanding, Qt::SizePolicy::Expanding)
          @table.setWordWrap(true)
          @table.setRowCount(shown_packet_items.length)
          @table.setColumnCount(5)
          @table.setHorizontalHeaderLabels(['Name', '         Value or State         ', '         ', 'Units', 'Description'])
          @table.horizontalHeader.setStretchLastSection(true)
          @table.verticalHeader.setVisible(false)
          @table.setItemDelegate(CmdParamTableItemDelegate.new(@table, @param_widgets))
          # @table.setContextMenuPolicy(Qt::CustomContextMenu)
          @table.verticalHeader.setResizeMode(Qt::HeaderView::ResizeToContents)
          @table.setEditTriggers(Qt::AbstractItemView::DoubleClicked | Qt::AbstractItemView::SelectedClicked | Qt::AbstractItemView::AnyKeyPressed)
          @table.setSelectionMode(Qt::AbstractItemView::NoSelection)
          # connect(@table, SIGNAL('customContextMenuRequested(const QPoint&)'), self, SLOT('context_menu(const QPoint&)'))
          # connect(@table, SIGNAL('itemClicked(QTableWidgetItem*)'), self, SLOT('click_callback(QTableWidgetItem*)'))
          drawn_header = true
        end

        # Parameter Name
        item = Qt::TableWidgetItem.new("#{packet_item.name}:")
        item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
        @table.setItem(row, 0, item)

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
          @table.setItem(row, 1, value_item)

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
          @table.setItem(row, 2, state_value_item)

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
          @table.setItem(row, 1, value_item)
          @table.setSpan(row, 1, 1, 2)
        end

        # Units
        item = Qt::TableWidgetItem.new(packet_item.units.to_s)
        item.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
        @table.setItem(row, 3, item)

        # Description
        item = Qt::TableWidgetItem.new(packet_item.description.to_s)
        item.setTextAlignment(Qt::AlignLeft | Qt::AlignVCenter)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
        @table.setItem(row, 4, item)

        @param_widgets << [packet_item, value_item, state_value_item]
        row += 1
      end

      if @table
        @table.connect(SIGNAL('itemChanged(QTableWidgetItem*)')) do |item|
          packet_item, value_item, state_value_item = @param_widgets[item.row]
          if item.column == 1
            if packet_item.states
              value = packet_item.states[value_item.text]
              @table.blockSignals(true)
              if @states_in_hex.checked? && value.kind_of?(Integer)
                state_value_item.setText(sprintf("0x%X", value))
              else
                state_value_item.setText(value.to_s)
              end
              @table.blockSignals(false)
            end
          elsif item.column == 2
            @table.blockSignals(true)
            @table.item(item.row, 1).setText(MANUALLY)
            @table.blockSignals(false)
          end
          begin
            output, params = view_as_script
            @cmd_name.text = output[5..-3]
            hazardous, _ = System.commands.cmd_hazardous?(@command.target_name, @command.packet_name, params)
            if hazardous
              @cmd_info.text = "(Hazarous)"
            else
              @cmd_info.text = ""
            end
          rescue => err
            statusBar.showMessage("Error #{err.message}")
            @cmd_info.text = ''
          end
        end
        @table_layout.addWidget(@table)
        @table.resizeColumnsToContents()
        @table.resizeRowsToContents()

        height = 0
        @table.rowCount.times do |x|
          height += @table.verticalHeader.sectionSize(x) + 1
        end
        height += @table.horizontalHeader.height + 1
        @table.setMaximumHeight(height)
      end
    end

    def mouseReleaseEvent(event)
      super(event)
      if event.button == Qt::LeftButton
        @expanded = !@expanded
        if @expanded
          @parameters.show
        else
          @parameters.hide
        end
      end
    end

    def view_as_script
      params = {}

      @param_widgets.each do |packet_item, value_item, state_value_item|
        text = ''
        Qt.execute_in_main_thread do
          text = value_item.text
          text = state_value_item.text if state_value_item && (text == MANUALLY)
        end
        quotes_removed = text.remove_quotes
        if text == quotes_removed
          params[packet_item.name] = text.convert_to_value
        else
          params[packet_item.name] = quotes_removed
        end
        raise "#{packet_item.name} is required" if quotes_removed == '' && packet_item.required
      end

      output_string = build_cmd_output_string(@command.target_name, @command.packet_name, params, false)
      if output_string =~ /[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\xFF]/
        output_string = output_string.inspect.remove_quotes
      end
      return output_string, params
    end

    def command_parts
      command, params = view_as_script
      return @command.target_name, @command.packet_name, params
    end

    def time
      time = ''
      Qt.execute_in_main_thread { time = @time.text }
      time
    end
  end
end
