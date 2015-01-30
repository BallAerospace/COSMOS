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

module Cosmos

  # Implements the logging tab in the Command and Telemetry Server GUI
  class LoggingTab

    def initialize(production)
      @production = production
      @logging_layouts = {}
    end

    # Create the logging tab and add it to the tab_widget
    #
    # @param tab_widget [Qt::TabWidget] The tab widget to add the tab to
    def populate(tab_widget)
      scroll = Qt::ScrollArea.new
      widget = Qt::Widget.new
      layout = Qt::VBoxLayout.new(widget)
      # Since the layout will be inside a scroll area
      # make sure it respects the sizes we set
      layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)

      populate_logging_actions(layout)

      # Add the cmd/tlm log files information
      populate_log_file_info(layout)

      # Set the scroll area widget last now that all the items have been layed out
      scroll.setWidget(widget)
      tab_widget.addTab(scroll, "Logging")
    end

    def update
      CmdTlmServer.packet_logging.all.each do |packet_log_writer_pair_name, packet_log_writer_pair|
        @logging_layouts[packet_log_writer_pair_name].itemAt(1, Qt::FormLayout::FieldRole).widget.setText(packet_log_writer_pair.cmd_log_writer.logging_enabled.to_s)
        @logging_layouts[packet_log_writer_pair_name].itemAt(2, Qt::FormLayout::FieldRole).widget.setText(packet_log_writer_pair.cmd_log_writer.queue.size.to_s)
        @logging_layouts[packet_log_writer_pair_name].itemAt(3, Qt::FormLayout::FieldRole).widget.setText(packet_log_writer_pair.cmd_log_writer.filename)
        file_size = 0
        begin
          file_size = File.size(packet_log_writer_pair.cmd_log_writer.filename) if packet_log_writer_pair.cmd_log_writer.filename
        rescue Exception
          # Do nothing on error
        end
        @logging_layouts[packet_log_writer_pair_name].itemAt(4, Qt::FormLayout::FieldRole).widget.setText(file_size.to_s)
        @logging_layouts[packet_log_writer_pair_name].itemAt(5, Qt::FormLayout::FieldRole).widget.setText(packet_log_writer_pair.tlm_log_writer.logging_enabled.to_s)
        @logging_layouts[packet_log_writer_pair_name].itemAt(6, Qt::FormLayout::FieldRole).widget.setText(packet_log_writer_pair.tlm_log_writer.queue.size.to_s)
        @logging_layouts[packet_log_writer_pair_name].itemAt(7, Qt::FormLayout::FieldRole).widget.setText(packet_log_writer_pair.tlm_log_writer.filename)
        file_size = 0
        begin
          file_size = File.size(packet_log_writer_pair.tlm_log_writer.filename) if packet_log_writer_pair.tlm_log_writer.filename
        rescue Exception
          # Do nothing on error
        end
        @logging_layouts[packet_log_writer_pair_name].itemAt(8, Qt::FormLayout::FieldRole).widget.setText(file_size.to_s)
      end
    end

    private

    def populate_logging_actions(layout)
      # Add all the action buttons
      actions = Qt::GroupBox.new(Qt::Object.tr("Actions"))
      actions_layout = Qt::VBoxLayout.new(actions)
      button_layout = Qt::GridLayout.new

      log_buttons = [
        ["Start Logging on All", [0,0], :start_logging],
        ["Stop Logging on All", [0,1], :stop_logging],
        ["Start Telemetry Logging on All", [1,0], :start_tlm_log],
        ["Stop Telemetry Logging on All", [1,1], :stop_tlm_log],
        ["Start Command Logging on All", [2,0], :start_cmd_log],
        ["Stop Command Logging on All", [2,1], :stop_cmd_log]
      ]

      log_buttons.each do |text, location, method|
        next if text =~ /Stop/ and @production
        button = Qt::PushButton.new(Qt::Object.tr(text))
        button_layout.addWidget(button, location[0], location[1])
        button.connect(SIGNAL('clicked()')) do
          begin
            CmdTlmServer.instance.send(method, 'ALL')
          rescue Exception => error
            statusBar.showMessage(Qt::Object.tr(error.message))
          end
        end
      end

      actions_layout.addLayout(button_layout)

      layout.addWidget(actions)
    end

    def create_log_layout(form_layout, log_writer, label_prefix)
      label = Qt::Label.new(Qt::Object.tr(log_writer.logging_enabled.to_s))
      label.setTextInteractionFlags(Qt::TextSelectableByMouse)
      form_layout.addRow("#{label_prefix} Logging:", label)
      label = Qt::Label.new(Qt::Object.tr(log_writer.queue.size.to_s))
      label.setTextInteractionFlags(Qt::TextSelectableByMouse)
      form_layout.addRow("#{label_prefix} Queue Size:", label)
      label = Qt::Label.new(Qt::Object.tr(log_writer.filename))
      label.setTextInteractionFlags(Qt::TextSelectableByMouse)
      form_layout.addRow("#{label_prefix} Filename:", label)
      file_size = 0
      begin
        file_size = File.size(log_writer.filename) if log_writer.filename
      rescue Exception
        # Do nothing on error
      end
      label = Qt::Label.new(Qt::Object.tr(file_size.to_s))
      label.setTextInteractionFlags(Qt::TextSelectableByMouse)
      form_layout.addRow("#{label_prefix} File Size:", label)
    end

    def populate_log_file_info(layout)
      CmdTlmServer.packet_logging.all.sort.each do |packet_log_writer_pair_name, packet_log_writer_pair|
        log = Qt::GroupBox.new("#{packet_log_writer_pair_name} Packet Log Writer")
        log_layout = Qt::VBoxLayout.new(log)
        interfaces = []
        CmdTlmServer.interfaces.all.each do |interface_name, interface|
          if interface.packet_log_writer_pairs.include?(packet_log_writer_pair)
            interfaces << interface.name
          end
        end

        form_layout = Qt::FormLayout.new
        @logging_layouts[packet_log_writer_pair_name] = form_layout
        label = Qt::Label.new(Qt::Object.tr(interfaces.join(", ")))
        label.setTextInteractionFlags(Qt::TextSelectableByMouse)
        form_layout.addRow("Interfaces:", label)
        create_log_layout(form_layout, packet_log_writer_pair.cmd_log_writer, 'Cmd')
        create_log_layout(form_layout, packet_log_writer_pair.tlm_log_writer, 'Tlm')

        button_layout = Qt::HBoxLayout.new
        start_button = Qt::PushButton.new(Qt::Object.tr('Start Cmd Logging'))
        button_layout.addWidget(start_button)
        start_button.connect(SIGNAL('clicked()')) do
          CmdTlmServer.instance.start_cmd_log(packet_log_writer_pair_name)
        end
        start_button = Qt::PushButton.new(Qt::Object.tr('Start Tlm Logging'))
        button_layout.addWidget(start_button)
        start_button.connect(SIGNAL('clicked()')) do
          CmdTlmServer.instance.start_tlm_log(packet_log_writer_pair_name)
        end
        if @production == false
          stop_button = Qt::PushButton.new(Qt::Object.tr('Stop Cmd Logging'))
          button_layout.addWidget(stop_button)
          stop_button.connect(SIGNAL('clicked()')) do
            CmdTlmServer.instance.stop_cmd_log(packet_log_writer_pair_name)
          end
          stop_button = Qt::PushButton.new(Qt::Object.tr('Stop Tlm Logging'))
          button_layout.addWidget(stop_button)
          stop_button.connect(SIGNAL('clicked()')) do
            CmdTlmServer.instance.stop_tlm_log(packet_log_writer_pair_name)
          end
        end
        form_layout.addRow("Actions:", button_layout)
        log_layout.addLayout(form_layout)
        layout.addWidget(log)
      end
      layout.addWidget(Qt::Label.new(Qt::Object.tr("Note: Buffered IO operations cause file size to not reflect total logged data size until the log file is closed.")))
    end

  end
end # module Cosmos
