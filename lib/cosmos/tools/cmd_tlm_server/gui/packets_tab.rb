# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/dialogs/cmd_tlm_raw_dialog'

module Cosmos

  # Implements the packets tab in the Command and Telemetry Server GUI
  class PacketsTab
    COMMANDS = "Commands"
    TELEMETRY = "Telemetry"

    def initialize(server_gui)
      @server_gui = server_gui
      @packets_table = {}
    end

    def populate_commands(tab_widget)
      populate(COMMANDS, System.commands, tab_widget)
    end

    def populate_telemetry(tab_widget)
      populate(TELEMETRY, System.telemetry, tab_widget)
    end

    def update(name)
      cmd_tlm = nil
      cmd_tlm = System.commands if name == COMMANDS
      cmd_tlm = System.telemetry if name == TELEMETRY
      return if cmd_tlm.nil? || cmd_tlm.target_names.empty?

      row = 0
      cmd_tlm.target_names.each do |target_name|
        packets = cmd_tlm.packets(target_name)
        packets.sort.each do |packet_name, packet|
          next if packet.hidden
          @packets_table[name].item(row, 2).setText(packet.received_count.to_s)
          row += 1
        end
      end
      packet = cmd_tlm.packet('UNKNOWN', 'UNKNOWN')
      @packets_table[name].item(row, 2).setText(packet.received_count.to_s)
      row += 1
    end

    private

    def populate(name, cmd_tlm, tab_widget)
      return if cmd_tlm.target_names.empty?

      count = 0
      cmd_tlm.target_names.each do |target_name|
        packets = cmd_tlm.packets(target_name)
        packets.each do |packet_name, packet|
          count += 1 unless packet.hidden
        end
      end
      count += 1 # For UNKNOWN UNKNOWN

      scroll = Qt::ScrollArea.new
      widget = Qt::Widget.new
      layout = Qt::VBoxLayout.new(widget)
      # Since the layout will be inside a scroll area
      # make sure it respects the sizes we set
      layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)

      table = Qt::TableWidget.new()
      table.verticalHeader.hide()
      table.setRowCount(count)
      column_cnt = 5
      table.setColumnCount(column_cnt)
      # Force the last section to fill all available space in the frame
      #~ table.horizontalHeader.setStretchLastSection(true)
      headers = ["Target Name", "Packet Name", "Packet Count", "View Raw"]
      headers << "View in Command Sender" if name == COMMANDS
      headers << "View in Packet Viewer" if name == TELEMETRY
      table.setHorizontalHeaderLabels(headers)

      populate_packets_table(name, cmd_tlm, table)
      table.displayFullSize

      layout.addWidget(table)
      scroll.setWidget(widget)
      tab_name = "Cmd Packets" if name == COMMANDS
      tab_name = "Tlm Packets" if name == TELEMETRY
      tab_widget.addTab(scroll, tab_name)

      @packets_table[name] = table
    end

    def populate_packets_table(name, cmd_tlm, table)
      row = 0
      target_names = cmd_tlm.target_names
      target_names << 'UNKNOWN'.freeze
      target_names.each do |target_name|
        packets = cmd_tlm.packets(target_name)
        packets.sort.each do |packet_name, packet|
          packet.received_count ||= 0
          next if packet.hidden
          target_name_widget = Qt::TableWidgetItem.new(Qt::Object.tr(target_name))
          target_name_widget.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
          table.setItem(row, 0, target_name_widget)
          table.setItem(row, 1, Qt::TableWidgetItem.new(Qt::Object.tr(packet_name)))
          packet_count = Qt::TableWidgetItem.new(Qt::Object.tr(packet.received_count.to_s))
          packet_count.setTextAlignment(Qt::AlignCenter)
          table.setItem(row, 2, packet_count)
          view_raw = Qt::PushButton.new("View Raw")
          view_raw.connect(SIGNAL('clicked()')) do
            @raw_dialogs ||= []
            @raw_dialogs << CmdRawDialog.new(@server_gui, target_name, packet_name) if name == COMMANDS
            @raw_dialogs << TlmRawDialog.new(@server_gui, target_name, packet_name) if name == TELEMETRY
          end
          table.setCellWidget(row, 3, view_raw)

          if name == COMMANDS
            add_tool_button(table, row, target_name, packet_name, "Command Sender")
          elsif name == TELEMETRY
            add_tool_button(table, row, target_name, packet_name, "Packet Viewer")
          end

          row += 1
        end
      end
    end

    def add_tool_button(table, row, target_name, packet_name, tool_name)
      if target_name != 'UNKNOWN' and packet_name != 'UNKNOWN'
        view_pv = Qt::PushButton.new("View in #{tool_name}")
        view_pv.connect(SIGNAL('clicked()')) do
          tool_name = tool_name.split.join.gsub("Command","Cmd") # remove space and convert name
          if Kernel.is_windows?
            Cosmos.run_process("rubyw tools/#{tool_name} -p \"#{target_name} #{packet_name}\" --system #{File.basename(System.initial_filename)}")
          elsif Kernel.is_mac? and File.exist?("tools/mac/#{tool_name}.app")
            Cosmos.run_process("open tools/mac/#{tool_name}.app --args -p \"#{target_name} #{packet_name}\" --system #{File.basename(System.initial_filename)}")
          else
            Cosmos.run_process("ruby tools/#{tool_name} -p \"#{target_name} #{packet_name}\" --system #{File.basename(System.initial_filename)}")
          end
        end
        table.setCellWidget(row, 4, view_pv)
      else
        table_widget = Qt::TableWidgetItem.new(Qt::Object.tr('N/A'))
        table_widget.setTextAlignment(Qt::AlignCenter)
        table.setItem(row, 4, table_widget)
      end
    end

  end
end # module Cosmos
