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
  require 'cosmos/gui/dialogs/cmd_details_dialog'
  require 'cosmos/tools/cmd_sender/cmd_params'
end

module Cosmos
  # Widget that represents an individual command that is sent as part of a
  # sequence. Items can have absolute execution times or a relative delay from
  # the previous item.
  class SequenceItem < Qt::Frame # Inherit from Frame so we can use setFrameStyle
    # Emit the modified signal to allow changes to propagate upwards
    signals 'modified()'
    MANUALLY = "MANUALLY ENTERED"

    # Create a new SequenceItem based on the given command with the given delay
    # @param time [String] Absolute time in YYYY/MM/DD HH:MM:SS format or a
    #   single float value representing the delta delay time
    def initialize(parent, target_name, packet_name, params = nil, time = nil)
      super()
      @cmd_params = CmdParams.new
      # Propagate the modified signal up
      @cmd_params.connect(SIGNAL('modified()')) do
        set_cmd_name_info()
        emit modified
      end
      @command = System.commands.packet(target_name, packet_name)
      @expanded = false
      @file_dir = System.paths['LOGS']

      setAutoFillBackground(true)
      setPalette(Cosmos.getPalette("black", "white"))
      setFrameStyle(Qt::Frame::Box)

      top_layout = Qt::VBoxLayout.new
      top_layout.setContentsMargins(2, 0, 0, 0)
      setLayout(top_layout)
      top_layout.addLayout(create_cmd_layout(target_name, packet_name, time))
      top_layout.addWidget(create_parameters())
      add_table(@cmd_params.update_cmd_params(@command, existing: params))
      set_cmd_name_info()
    end

    def add_table(table)
      return unless table
      table.setSizePolicy(Qt::SizePolicy.Minimum, Qt::SizePolicy.Minimum)
      table.setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOff)
      table.setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff)
      table.setFixedSize(table.horizontalHeader.length + table.verticalHeader.width,
                         2 + table.verticalHeader.length + table.horizontalHeader.height)
      @table_layout.addWidget(table)
    end

    def states_in_hex(checked)
      @cmd_params.states_in_hex(checked)
    end

    def show_ignored(checked)
      add_table(@cmd_params.update_cmd_params(@command, show_ignored: checked))
      set_cmd_name_info()
    end

    # Set or clear read only status on the item
    # @param bool [Boolean] Whether to make the item read only
    def read_only(bool)
      @time.setReadOnly(bool)
    end

    # Show the command parameters part of the GUI
    def expand
      @expanded = true
      @parameters.show
    end

    # Hide the command parameters part of the GUI
    def collapse
      @expanded = false
      @parameters.hide
    end

    # @return [String] Command to be executed with no quotes or other decorations
    def command_string
      output_string =  System.commands.build_cmd_output_string(@command.target_name, @command.packet_name, @cmd_params.params_text, false)
      if output_string =~ /[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F-\xFF]/
        output_string = output_string.inspect.remove_quotes
      end
      output_string[5..-3]
    end

    # @return [String] Absolute or relative time
    def time
      time = ''
      Qt.execute_in_main_thread { time = @time.text }
      time
    end

    def command
      System.commands.build_cmd(@command.target_name, @command.packet_name, @cmd_params.params_text, false)
    end

    # @return [String] Time and command string
    def save
      "COMMAND \"#{time}\" \"#{command_string}\""
    end

    # Handles showing and hiding the command parameters. Must be part of the
    # public API.
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

    protected

    # Create the command layout which holds the command name, information,
    # and the delete button to remove the sequence item.
    # @param target_name [String] Target name
    # @param packet_name [String] Packet name
    # @param time [String] Execution delay in absolute or relative time
    def create_cmd_layout(target_name, packet_name, time)
      cmd_layout = Qt::HBoxLayout.new
      cmd_layout.setContentsMargins(0, 0, 0, 0)
      cmd_layout.addWidget(create_time_edit(time))

      @cmd_name = Qt::Label.new("#{target_name} #{packet_name}")
      cmd_layout.addWidget(@cmd_name)
      @cmd_info = Qt::Label.new("") # Label for the hazardous designation
      cmd_layout.addWidget(@cmd_info)
      cmd_layout.addStretch()

      delete = Qt::PushButton.new
      delete.setFixedSize(25, 25)
      delete_icon = Cosmos.get_icon('delete.png')
      delete.setIcon(delete_icon)
      delete.connect(SIGNAL('clicked()')) do
        emit modified() # Tell the higher level that we're gone
        self.dispose
      end
      cmd_layout.addWidget(delete)
      cmd_layout
    end

    # Creates the time edit widget which holds the time delay. The widget is
    # a normal LineEdit which is edited as usual to enter a relative delay.
    # If the widget is right clicked it launches a CalendarDialog to allow the
    # user to select and absolute time to execute the sequence item.
    # @param time [String] The initial value for the time delay
    def create_time_edit(time)
      @time = Qt::LineEdit.new(Time.now.sys.formatted)
      fm = @time.fontMetrics
      # Set the width to support an absolute time
      @time.setFixedWidth(fm.boundingRect(Time.now.sys.formatted).width + 10)
      @time.text = time ? time : "0.00"
      # Setting the absolute time is via a Right-Click custom context menu
      @time.setContextMenuPolicy(Qt::CustomContextMenu)
      @time.connect(SIGNAL('customContextMenuRequested(const QPoint&)')) do
        dialog = CalendarDialog.new(@time, "Select Absolute Execution Time:", Time.now.sys, true)
        case dialog.exec
        when Qt::Dialog::Accepted
          @time.text = dialog.time.formatted
        end
      end
      @time.connect(SIGNAL('textChanged(const QString&)')) { emit modified }
      @time
    end

    # Create the parameters widget which holds the command description and
    # the table which contains all the command parameters
    def create_parameters
      @parameters = Qt::Widget.new
      parameters_layout = Qt::VBoxLayout.new
      # Command Description Label
      dec_label = Qt::Label.new("Description:")
      description = Qt::Label.new(@command.description)
      description.setWordWrap(true)
      desc_layout = Qt::HBoxLayout.new
      desc_layout.addWidget(dec_label)
      desc_layout.addWidget(description, 1)
      parameters_layout.addLayout(desc_layout)

      param_label = Qt::Label.new("Parameters:")
      parameters_layout.addWidget(param_label)
      @table_layout = Qt::VBoxLayout.new
      parameters_layout.addLayout(@table_layout, 500)
      @parameters.setLayout(parameters_layout)
      @parameters.hide
      @parameters
    end

    # Sets the @cmd_name label to the command that will be sent. Also udpates
    # the @cmd_info with whether this command is hazardous or not.
    def set_cmd_name_info
      Qt.execute_in_main_thread do
        @cmd_name.text = command_string
        hazardous, _ = System.commands.cmd_hazardous?(@command.target_name, @command.packet_name, @cmd_params.params_text)
        if hazardous
          @cmd_info.text = "(Hazardous)"
        else
          @cmd_info.text = ""
        end
      end
    rescue => error
      @cmd_info.text = "(Error)"
      Qt::MessageBox.warning(self, 'Error', "Error parsing #{@command.target_name} #{@command.packet_name} due to #{error.message}")
    end
  end
end
