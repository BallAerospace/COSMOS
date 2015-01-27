# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'
require 'cosmos/gui/qt_tool'
require 'cosmos/gui/dialogs/splash'
require 'cosmos/gui/dialogs/cmd_tlm_raw_dialog'
require 'cosmos/gui/dialogs/exception_dialog'
require 'cosmos/gui/dialogs/set_tlm_dialog'

module Cosmos

  # Implements the GUI functions of the Command and Telemetry Server. All the
  # QT calls are implemented here. The non-GUI functionality is contained in
  # the CmdTlmServer class.
  class CmdTlmServerGui < QtTool
    slots 'handle_tab_change(int)'

    STOPPED = 0
    RUNNING = 1
    ERROR = 2

    CMD = "Command"
    TLM = "Telemetry"

    # For the CTS we display all the tables as full size
    # Thus we don't want the table to absorb the scroll wheel events but
    # instead pass them up to the container so the entire window will scroll.
    class Qt::TableWidget
      def wheelEvent(event)
        event.ignore()
      end
    end

    def meta_callback(meta_target_name, meta_packet_name)
      Qt.execute_in_main_thread(true) do
        result = SetTlmDialog.execute(self, 'Enter Metadata', 'Set Metadata', 'Cancel', meta_target_name, meta_packet_name)
        exit(1) unless result
      end
    end

    def initialize(options)
      super(options) # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      Cosmos.load_cosmos_icon("cts.png")

      @production = options.production
      @no_prompt = options.no_prompt
      @message_log = nil
      @output_sleeper = Sleeper.new

      statusBar.showMessage(tr("")) # Show blank message to initialize status bar

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()

      Splash.execute(self) do |splash|
        ConfigParser.splash = splash
        splash.message = "Initializing #{CMD} and #{TLM} Server"

        # Start the thread that will process server messages and add them to the output text
        process_server_messages(options)

        CmdTlmServer.meta_callback = method(:meta_callback)
        cts = CmdTlmServer.new(options.config_file, @production)
        cts.stop_callback = method(:stop_callback)
        @message_log = CmdTlmServer.message_log

        # Now that we've started the server (CmdTlmServer.new) we can populate all the tabs
        splash.message = "Populating Tabs"
        Qt.execute_in_main_thread(true) do
          # Override the default title if one was given in the config file
          self.window_title = CmdTlmServer.title if CmdTlmServer.title
          splash.progress = 0
          populate_interfaces('Interfaces')
          splash.progress = 100/7 * 1
          populate_targets()
          splash.progress = 100/7 * 2
          populate_packets(CMD)
          splash.progress = 100/7 * 3
          populate_packets(TLM)
          splash.progress = 100/7 * 4
          populate_interfaces('Routers')
          splash.progress = 100/7 * 5
          populate_logging()
          splash.progress = 100/7 * 6
          populate_status()
          splash.progress = 100
        end
        ConfigParser.splash = nil
      end
    end

    def initialize_actions
      super()

      # Edit actions
      @edit_clear_counters = Qt::Action.new(tr('&Clear Counters'), self)
      @edit_clear_counters.statusTip = tr('Clear counters for all interfaces and targets')
      @edit_clear_counters.connect(SIGNAL('triggered()')) { edit_clear_counters() }
    end

    def initialize_menus
      @file_menu = menuBar.addMenu(tr('&File'))
      @file_menu.addAction(@exit_action)

      # Do not allow clear counters in production mode
      unless @production
        @edit_menu = menuBar.addMenu(tr('&Edit'))
        @edit_menu.addAction(@edit_clear_counters)
      end

      @about_string = "#{CMD} and #{TLM} Server is the heart of the COSMOS system. "
      @about_string << "It connects to the target and processes command and telemetry requests from other tools."

      initialize_help_menu()
    end

    ###########################################
    # Edit Menu Options
    ###########################################

    # Edit->Clear Counters
    def edit_clear_counters
      CmdTlmServer.clear_counters
    end

    def initialize_central_widget
      # Create the central widget
      @splitter = Qt::Splitter.new(Qt::Vertical, central_widget)
      setCentralWidget(@splitter)

      @tabbook = Qt::TabWidget.new
      connect(@tabbook, SIGNAL('currentChanged(int)'), self, SLOT('handle_tab_change(int)'))
      @splitter.addWidget(@tabbook)

      # Add the message output
      @output = Qt::PlainTextEdit.new
      @output.setReadOnly(true)
      @output.setMaximumBlockCount(10000) # 10000 lines of history will be displayed

      @splitter.addWidget(@output)
      # Set the stretch factor to give priority to the tabbook (index 0) instead of the output (index 1)
      @splitter.setStretchFactor(0, 1) # (index, stretch)

      # Override stdout to the message window
      # All code attempting to print into the GUI must use $stdout rather than STDOUT
      @string_output = StringIO.new("", "r+")
      $stdout = @string_output
      Logger.level = Logger::INFO

      @tab_thread = nil
    end

    def kill_tab_thread
      @tab_sleeper ||= nil
      @tab_sleeper.cancel if @tab_sleeper
      Cosmos.kill_thread(self, @tab_thread)
      @tab_thread = nil
    end

    def handle_tab_change(index)
      kill_tab_thread()
      @tab_sleeper = Sleeper.new
      case index
      when 0
        handle_interfaces_tab('Interfaces')
      when 1
        handle_targets_tab()
      when 2
        handle_packets_tab(CMD)
      when 3
        handle_packets_tab(TLM)
      when 4
        handle_interfaces_tab('Routers')
      when 5
        handle_logging_tab()
      when 6
        handle_status_tab()
      end
    end

    def populate_interfaces(name)
      @interfaces_table ||= {}

      if name == 'Routers'
        interfaces = CmdTlmServer.routers
      else
        interfaces = CmdTlmServer.interfaces
      end

      num_interfaces = interfaces.names.length
      if interfaces.names.length > 0
        scroll = Qt::ScrollArea.new
        scroll.setMinimumSize(800, 150)
        widget = Qt::Widget.new
        layout = Qt::VBoxLayout.new(widget)
        # Since the layout will be inside a scroll area make sure it respects the sizes we set
        layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)

        interfaces_table = Qt::TableWidget.new()
        interfaces_table.verticalHeader.hide()
        interfaces_table.setRowCount(num_interfaces)
        interfaces_table.setColumnCount(10)
        if name == 'Routers'
          interfaces_table.setHorizontalHeaderLabels(["Router", "Connect/Disconnect", "Connected?", "Clients", "Tx Q Size", "Rx Q Size", "   Bytes Tx   ", "   Bytes Rx   ", "  Cmd Pkts  ", "  Tlm Pkts  "])
        else
          interfaces_table.setHorizontalHeaderLabels(["Interface", "Connect/Disconnect", "Connected?", "Clients", "Tx Q Size", "Rx Q Size", "   Bytes Tx   ", "   Bytes Rx   ", "  Cmd Pkts  ", "  Tlm Pkts  "])
        end

        row = 0
        interfaces.all.each do |interface_name, interface|
          item = Qt::TableWidgetItem.new(tr(interface_name))
          item.setTextAlignment(Qt::AlignCenter)
          interfaces_table.setItem(row, 0, item)

          if interface.connected?
            button_text = 'Disconnect'
          elsif interface.thread.nil?
            button_text = 'Connect'
          else
            button_text = 'Cancel Connect'
          end
          button = Qt::PushButton.new(button_text)
          if name == 'Routers'
            button.connect(SIGNAL('clicked()')) do
              if interface.thread
                Logger.info "User disconnecting router #{interface_name}"
                CmdTlmServer.instance.disconnect_router(interface_name)
              else
                Logger.info "User connecting router #{interface_name}"
                CmdTlmServer.instance.connect_router(interface_name)
              end
            end
          else
            button.connect(SIGNAL('clicked()')) do
              if interface.thread
                Logger.info "User disconnecting interface #{interface_name}"
                CmdTlmServer.instance.disconnect_interface(interface_name)
              else
                Logger.info "User connecting interface #{interface_name}"
                CmdTlmServer.instance.connect_interface(interface_name)
              end
            end
          end
          button.setDisabled(true) if interface.disable_disconnect
          interfaces_table.setCellWidget(row, 1, button)

          state = Qt::TableWidgetItem.new
          if interface.connected?
            state.setText('true')
            state.textColor = Cosmos::GREEN
          elsif interface.thread
            state.setText('attempting')
            state.textColor = Cosmos::YELLOW
          else
            state.setText('false')
            state.textColor = Cosmos::BLACK
          end
          state.setTextAlignment(Qt::AlignCenter)
          interfaces_table.setItem(row, 2, state)

          num_clients = Qt::TableWidgetItem.new(tr(interface.num_clients.to_s))
          num_clients.setTextAlignment(Qt::AlignCenter)
          interfaces_table.setItem(row, 3, num_clients)

          write_queue_size = Qt::TableWidgetItem.new(tr(interface.write_queue_size.to_s))
          write_queue_size.setTextAlignment(Qt::AlignCenter)
          interfaces_table.setItem(row, 4, write_queue_size)

          read_queue_size = Qt::TableWidgetItem.new(tr(interface.read_queue_size.to_s))
          read_queue_size.setTextAlignment(Qt::AlignCenter)
          interfaces_table.setItem(row, 5, read_queue_size)

          bytes_written = Qt::TableWidgetItem.new(tr(interface.bytes_written.to_s))
          bytes_written.setTextAlignment(Qt::AlignCenter)
          interfaces_table.setItem(row, 6, bytes_written)

          bytes_read = Qt::TableWidgetItem.new(tr(interface.bytes_read.to_s))
          bytes_read.setTextAlignment(Qt::AlignCenter)
          interfaces_table.setItem(row, 7, bytes_read)

          write_count = Qt::TableWidgetItem.new(tr(interface.write_count.to_s))
          write_count.setTextAlignment(Qt::AlignCenter)
          interfaces_table.setItem(row, 8, write_count)

          read_count = Qt::TableWidgetItem.new(tr(interface.read_count.to_s))
          read_count.setTextAlignment(Qt::AlignCenter)
          interfaces_table.setItem(row, 9, read_count)

          row += 1
        end
        interfaces_table.displayFullSize

        layout.addWidget(interfaces_table)
        scroll.setWidget(widget)
        if name == 'Routers'
          @tabbook.addTab(scroll, "Routers")
          @interfaces_table['Routers'] = interfaces_table
        else
          @tabbook.addTab(scroll, "Interfaces")
          @interfaces_table['Interfaces'] = interfaces_table
        end
      end
    end

    def handle_interfaces_tab(name)
      @tab_thread = Thread.new do
        if @interfaces_table[name]
          begin
            while true
              Qt.execute_in_main_thread(true) do
                row = 0
                if name == 'Routers'
                  interfaces = CmdTlmServer.routers
                else
                  interfaces = CmdTlmServer.interfaces
                end
                interfaces.all.each do |interface_name, interface|
                  button = @interfaces_table[name].cellWidget(row,1)
                  state = @interfaces_table[name].item(row,2)
                  if interface.connected?
                    button.setText('Disconnect')
                    button.setDisabled(true) if interface.disable_disconnect
                    state.setText('true')
                    state.textColor = Cosmos::GREEN
                  elsif interface.thread
                    button.text = 'Cancel Connect'
                    button.setDisabled(false)
                    state.text = 'attempting'
                    state.textColor = Cosmos::RED
                  else
                    button.setText('Connect')
                    button.setDisabled(false)
                    state.setText('false')
                    state.textColor = Cosmos::BLACK
                  end
                  @interfaces_table[name].item(row,3).setText(interface.num_clients.to_s)
                  @interfaces_table[name].item(row,4).setText(interface.write_queue_size.to_s)
                  @interfaces_table[name].item(row,5).setText(interface.read_queue_size.to_s)
                  @interfaces_table[name].item(row,6).setText(interface.bytes_written.to_s)
                  @interfaces_table[name].item(row,7).setText(interface.bytes_read.to_s)
                  if name == 'Routers'
                    @interfaces_table[name].item(row,8).setText(interface.read_count.to_s)
                    @interfaces_table[name].item(row,9).setText(interface.write_count.to_s)
                  else
                    @interfaces_table[name].item(row,8).setText(interface.write_count.to_s)
                    @interfaces_table[name].item(row,9).setText(interface.read_count.to_s)
                  end
                  row += 1
                end
              end
              break if @tab_sleeper.sleep(1)
            end
          rescue Exception => error
            Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(self, error, "COSMOS CTS : #{name} Tab Thread")}
          end
        end
      end
    end

    def populate_targets
      num_targets = System.targets.length
      if num_targets > 0
        return if num_targets == 1 and System.targets['SYSTEM']
        num_targets -= 1 if System.targets['SYSTEM']

        scroll = Qt::ScrollArea.new
        widget = Qt::Widget.new
        layout = Qt::VBoxLayout.new(widget)
        # Since the layout will be inside a scroll area make sure it respects the sizes we set
        layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)

        @targets_table = Qt::TableWidget.new()
        @targets_table.verticalHeader.hide()
        @targets_table.setRowCount(num_targets)
        @targets_table.setColumnCount(4)
        @targets_table.setHorizontalHeaderLabels(["Target Name", "Interface", "#{CMD} Count", "#{TLM} Count"])

        row = 0
        System.targets.sort.each do |target_name, target|
          next if target_name == 'SYSTEM'
          target_name_widget = Qt::TableWidgetItem.new(tr(target_name))
          target_name_widget.setTextAlignment(Qt::AlignCenter)
          @targets_table.setItem(row, 0, target_name_widget)
          if target.interface
            interface_name_widget = Qt::TableWidgetItem.new(tr(target.interface.name.to_s))
          else
            interface_name_widget = Qt::TableWidgetItem.new(tr(''))
          end
          interface_name_widget.setTextAlignment(Qt::AlignCenter)
          @targets_table.setItem(row, 1, interface_name_widget)
          cmd_cnt = Qt::TableWidgetItem.new(tr(target.cmd_cnt.to_s))
          cmd_cnt.setTextAlignment(Qt::AlignCenter)
          @targets_table.setItem(row, 2, cmd_cnt)

          tlm_cnt = Qt::TableWidgetItem.new(tr(target.tlm_cnt.to_s))
          tlm_cnt.setTextAlignment(Qt::AlignCenter)
          @targets_table.setItem(row, 3, tlm_cnt)

          row += 1
        end
        @targets_table.displayFullSize

        layout.addWidget(@targets_table)
        scroll.setWidget(widget)
        @tabbook.addTab(scroll, "Targets")
      end
    end

    def handle_targets_tab
      @tab_thread = Thread.new do
        begin
          while true
            Qt.execute_in_main_thread(true) do
              row = 0
              System.targets.sort.each do |target_name, target|
                next if target_name == 'SYSTEM'
                @targets_table.item(row,2).setText(target.cmd_cnt.to_s)
                @targets_table.item(row,3).setText(target.tlm_cnt.to_s)
                row += 1
              end
            end
            break if @tab_sleeper.sleep(1)
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(self, error, "COSMOS CTS : Targets Tab Thread")}
        end
      end
    end

    def get_cmd_tlm_def(name)
      case name
        when CMD
          return System.commands
        when TLM
          return System.telemetry
      end
    end

    def populate_packets(name)
      cmd_tlm = get_cmd_tlm_def(name)

      unless cmd_tlm.target_names.empty?
        count = 0
        cmd_tlm.target_names.sort.each do |target_name|
          packets = cmd_tlm.packets(target_name)
          packets.each do |packet_name, packet|
            count += 1 unless packet.hidden
          end
        end

        scroll = Qt::ScrollArea.new
        widget = Qt::Widget.new
        layout = Qt::VBoxLayout.new(widget)
        # Since the layout will be inside a scroll area
        # make sure it respects the sizes we set
        layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)

        table = Qt::TableWidget.new()
        table.verticalHeader.hide()
        table.setRowCount(count)
        column_cnt = 4
        column_cnt += 1 if name == TLM
        table.setColumnCount(column_cnt)
        # Force the last section to fill all available space in the frame
        #~ table.horizontalHeader.setStretchLastSection(true)
        headers = ["Target Name", "Packet Name", "Packet Count", "View Raw"]
        headers << "View in Packet Viewer" if name == TLM
        table.setHorizontalHeaderLabels(headers)

        row = 0
        cmd_tlm.target_names.sort.each do |target_name|
          packets = cmd_tlm.packets(target_name)
          packets.sort.each do |packet_name, packet|
            packet.received_count ||= 0
            next if packet.hidden
            target_name_widget = Qt::TableWidgetItem.new(tr(target_name))
            target_name_widget.setTextAlignment(Qt::AlignRight | Qt::AlignVCenter)
            table.setItem(row, 0, target_name_widget)
            table.setItem(row, 1, Qt::TableWidgetItem.new(tr(packet_name)))
            packet_count = Qt::TableWidgetItem.new(tr(packet.received_count.to_s))
            packet_count.setTextAlignment(Qt::AlignCenter)
            table.setItem(row, 2, packet_count)
            view_raw = Qt::PushButton.new("View Raw")
            view_raw.connect(SIGNAL('clicked()')) do
              @raw_dialogs ||= []
              @raw_dialogs << CmdRawDialog.new(self, target_name, packet_name) if name == CMD
              @raw_dialogs << TlmRawDialog.new(self, target_name, packet_name) if name == TLM
            end
            table.setCellWidget(row, 3, view_raw)

            if name == TLM
              if target_name != 'UNKNOWN' and packet_name != 'UNKNOWN'
                view_pv = Qt::PushButton.new("View in Packet Viewer")
                view_pv.connect(SIGNAL('clicked()')) do
                  if Kernel.is_windows?
                    Cosmos.run_process("rubyw tools/PacketViewer -p \"#{target_name} #{packet_name}\" --system #{File.basename(System.initial_filename)}")
                  elsif Kernel.is_mac? and File.exist?("tools/mac/PacketViewer.app")
                    Cosmos.run_process("open tools/mac/PacketViewer.app --args -p \"#{target_name} #{packet_name}\" --system #{File.basename(System.initial_filename)}")
                  else
                    Cosmos.run_process("ruby tools/PacketViewer -p \"#{target_name} #{packet_name}\" --system #{File.basename(System.initial_filename)}")
                  end
                end
                table.setCellWidget(row, 4, view_pv)
              else
                table_widget = Qt::TableWidgetItem.new(tr('N/A'))
                table_widget.setTextAlignment(Qt::AlignCenter)
                table.setItem(row, 4, table_widget)
              end
            end

            row += 1
          end
        end
        table.displayFullSize

        layout.addWidget(table)
        scroll.setWidget(widget)
        tab_name = "Cmd Packets" if name == CMD
        tab_name = "Tlm Packets" if name == TLM
        @tabbook.addTab(scroll, tab_name)

        @packets_table ||= {}
        @packets_table[name] = table
      end
    end

    def handle_packets_tab(name)
      cmd_tlm = get_cmd_tlm_def(name)

      @tab_thread = Thread.new do
        begin
          unless cmd_tlm.target_names.empty?
            while true
              Qt.execute_in_main_thread(true) do
                row = 0
                cmd_tlm.target_names.sort.each do |target_name|
                  packets = cmd_tlm.packets(target_name)
                  packets.sort.each do |packet_name, packet|
                    next if packet.hidden
                    @packets_table[name].item(row, 2).setText(packet.received_count.to_s)
                    row += 1
                  end
                end
              end
              break if @tab_sleeper.sleep(1)
            end
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(self, error, "COSMOS CTS : #{name} Packets Tab Thread")}
        end
      end
    end

    def populate_logging_actions(layout)
      # Add all the action buttons
      actions = Qt::GroupBox.new(tr("Actions"))
      actions_layout = Qt::VBoxLayout.new(actions)
      button_layout = Qt::GridLayout.new

      log_buttons = [
        ["Start Logging on All", [0,0], :start_logging],
        ["Stop Logging on All", [0,1], :stop_logging],
        ["Start #{TLM} Logging on All", [1,0], :start_tlm_log],
        ["Stop #{TLM} Logging on All", [1,1], :stop_tlm_log],
        ["Start #{CMD} Logging on All", [2,0], :start_cmd_log],
        ["Stop #{CMD} Logging on All", [2,1], :stop_cmd_log]
      ]

      log_buttons.each do |text, location, method|
        next if text =~ /Stop/ and @production
        button = Qt::PushButton.new(tr(text))
        button_layout.addWidget(button, location[0], location[1])
        button.connect(SIGNAL('clicked()')) do
          begin
            CmdTlmServer.instance.send(method, 'ALL')
          rescue Exception => error
            statusBar.showMessage(tr(error.message))
          end
        end
      end

      actions_layout.addLayout(button_layout)

      layout.addWidget(actions)
    end

    def create_log_layout(form_layout, log_writer, label_prefix)
      label = Qt::Label.new(tr(log_writer.logging_enabled.to_s))
      label.setTextInteractionFlags(Qt::TextSelectableByMouse)
      form_layout.addRow("#{label_prefix} Logging:", label)
      label = Qt::Label.new(tr(log_writer.queue.size.to_s))
      label.setTextInteractionFlags(Qt::TextSelectableByMouse)
      form_layout.addRow("#{label_prefix} Queue Size:", label)
      label = Qt::Label.new(tr(log_writer.filename))
      label.setTextInteractionFlags(Qt::TextSelectableByMouse)
      form_layout.addRow("#{label_prefix} Filename:", label)
      file_size = 0
      begin
        file_size = File.size(log_writer.filename) if log_writer.filename
      rescue Exception
        # Do nothing on error
      end
      label = Qt::Label.new(tr(file_size.to_s))
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
        label = Qt::Label.new(tr(interfaces.join(", ")))
        label.setTextInteractionFlags(Qt::TextSelectableByMouse)
        form_layout.addRow("Interfaces:", label)
        create_log_layout(form_layout, packet_log_writer_pair.cmd_log_writer, 'Cmd')
        create_log_layout(form_layout, packet_log_writer_pair.tlm_log_writer, 'Tlm')

        button_layout = Qt::HBoxLayout.new
        start_button = Qt::PushButton.new(tr('Start Cmd Logging'))
        button_layout.addWidget(start_button)
        start_button.connect(SIGNAL('clicked()')) do
          CmdTlmServer.instance.start_cmd_log(packet_log_writer_pair_name)
        end
        start_button = Qt::PushButton.new(tr('Start Tlm Logging'))
        button_layout.addWidget(start_button)
        start_button.connect(SIGNAL('clicked()')) do
          CmdTlmServer.instance.start_tlm_log(packet_log_writer_pair_name)
        end
        if @production == false
          stop_button = Qt::PushButton.new(tr('Stop Cmd Logging'))
          button_layout.addWidget(stop_button)
          stop_button.connect(SIGNAL('clicked()')) do
            CmdTlmServer.instance.stop_cmd_log(packet_log_writer_pair_name)
          end
          stop_button = Qt::PushButton.new(tr('Stop Tlm Logging'))
          button_layout.addWidget(stop_button)
          stop_button.connect(SIGNAL('clicked()')) do
            CmdTlmServer.instance.stop_tlm_log(packet_log_writer_pair_name)
          end
        end
        form_layout.addRow("Actions:", button_layout)
        log_layout.addLayout(form_layout)
        layout.addWidget(log)
      end
      layout.addWidget(Qt::Label.new(tr("Note: Buffered IO operations cause file size to not reflect total logged data size until the log file is closed.")))
    end

    def populate_logging
      scroll = Qt::ScrollArea.new
      widget = Qt::Widget.new
      layout = Qt::VBoxLayout.new(widget)
      # Since the layout will be inside a scroll area
      # make sure it respects the sizes we set
      layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)

      populate_logging_actions(layout)

      # Create the hash which will hold the logging layouts
      @logging_layouts = {}

      # Add the cmd/tlm log files information
      populate_log_file_info(layout)

      # Set the scroll area widget last now that all the items have been layed out
      scroll.setWidget(widget)
      @tabbook.addTab(scroll, "Logging")
    end

    def update_filename_and_logging_state
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

    def handle_logging_tab
      @tab_thread = Thread.new do
        begin
          while true
            Qt.execute_in_main_thread(true) do
              update_filename_and_logging_state()
            end
            break if @tab_sleeper.sleep(1)
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(self, error, "COSMOS CTS : Logging Tab Thread")}
        end
      end
    end

    def populate_status
      scroll = Qt::ScrollArea.new
      widget = Qt::Widget.new
      layout = Qt::VBoxLayout.new(widget)

      limits = Qt::GroupBox.new(tr("Limits Status"))
      limits_layout = Qt::FormLayout.new(limits)
      current_limits_set = System.limits_set.to_s

      known_limits_sets = System.limits.sets
      known_limits_sets = known_limits_sets.map {|x| x.to_s}.sort
      current_index = known_limits_sets.index(current_limits_set.to_s)

      @limits_set_combo = Qt::ComboBox.new
      limits_layout.addRow("Limits Set:", @limits_set_combo)
      layout.addWidget(limits)

      known_limits_sets.sort.each do |limits_set|
        @limits_set_combo.addItem(limits_set.to_s)
      end
      @limits_set_combo.setMaxVisibleItems(6)
      @limits_set_combo.setCurrentIndex(current_index)
      # Only connect to the signal that is sent when the user chooses an item.
      # If the limits set is changed programatically the code in
      # handle_status_tab will pick up the change.
      @limits_set_combo.connect(SIGNAL('activated(int)')) do
        selected_limits_set = @limits_set_combo.currentText
        if selected_limits_set
          System.limits_set = selected_limits_set.intern if System.limits_set != selected_limits_set.intern
        end
      end

      api = Qt::GroupBox.new(tr("API Status"))
      api_layout = Qt::VBoxLayout.new(api)
      @api_table = Qt::TableWidget.new()
      @api_table.verticalHeader.hide()
      @api_table.setRowCount(1)
      @api_table.setColumnCount(6)
      @api_table.setHorizontalHeaderLabels(["Port", "Num Clients", "Requests", "Requests/Sec", "Avg Request Time", "Estimated Utilization"])

      @api_table.setItem(0, 0, Qt::TableWidgetItem.new(tr(System.ports['CTS_API'].to_s)))
      item0 = Qt::TableWidgetItem.new(tr(CmdTlmServer.json_drb.num_clients.to_s))
      item0.setTextAlignment(Qt::AlignCenter)
      @api_table.setItem(0, 1, item0)
      item = Qt::TableWidgetItem.new(tr(CmdTlmServer.json_drb.request_count.to_s))
      item.setTextAlignment(Qt::AlignCenter)
      @api_table.setItem(0, 2, item)
      item2 = Qt::TableWidgetItem.new("0.0")
      item2.setTextAlignment(Qt::AlignCenter)
      @api_table.setItem(0, 3, item2)
      item3 = Qt::TableWidgetItem.new("0.0")
      item3.setTextAlignment(Qt::AlignCenter)
      @api_table.setItem(0, 4, item3)
      item4 = Qt::TableWidgetItem.new("0.0")
      item4.setTextAlignment(Qt::AlignCenter)
      @api_table.setItem(0, 5, item4)
      @api_table.displayFullSize
      api_layout.addWidget(@api_table)
      layout.addWidget(api)

      system = Qt::GroupBox.new(tr("System Status"))
      system_layout = Qt::VBoxLayout.new(system)
      @system_table = Qt::TableWidget.new()
      @system_table.verticalHeader.hide()
      @system_table.setRowCount(1)
      @system_table.setColumnCount(4)
      @system_table.setHorizontalHeaderLabels(["Threads", "Total Objs", "Free Objs", "Allocated Objs"])

      item0 = Qt::TableWidgetItem.new("0")
      item0.setTextAlignment(Qt::AlignCenter)
      @system_table.setItem(0, 0, item0)
      item1 = Qt::TableWidgetItem.new("0.0")
      item1.setTextAlignment(Qt::AlignCenter)
      @system_table.setItem(0, 1, item1)
      item2 = Qt::TableWidgetItem.new("0.0")
      item2.setTextAlignment(Qt::AlignCenter)
      @system_table.setItem(0, 2, item2)
      item3 = Qt::TableWidgetItem.new("0.0")
      item3.setTextAlignment(Qt::AlignCenter)
      @system_table.setItem(0, 3, item3)
      @system_table.displayFullSize
      system_layout.addWidget(@system_table)
      layout.addWidget(system)

      background_tasks_groupbox = Qt::GroupBox.new(tr("Background Tasks"))
      background_tasks_layout = Qt::VBoxLayout.new(background_tasks_groupbox)
      @background_tasks_table = Qt::TableWidget.new()
      @background_tasks_table.verticalHeader.hide()
      @background_tasks_table.setRowCount(CmdTlmServer.background_tasks.all.length)
      @background_tasks_table.setColumnCount(3)
      @background_tasks_table.setHorizontalHeaderLabels(["Name", "State", "Status"])

      background_tasks = CmdTlmServer.background_tasks.all
      if background_tasks.length > 0
        row = 0
        background_tasks.each_with_index do |background_task, index|
          background_task_name = background_task.name
          background_task_name = "Background Task ##{index + 1}" unless background_task_name
          background_task_name_widget = Qt::TableWidgetItem.new(background_task_name)
          background_task_name_widget.setTextAlignment(Qt::AlignCenter)
          @background_tasks_table.setItem(row, 0, background_task_name_widget)
          if background_task.thread
            status = background_task.thread.status
            status = 'complete' if status == false
            background_task_state_widget = Qt::TableWidgetItem.new(status.to_s)
          else
            background_task_state_widget = Qt::TableWidgetItem.new('no thread')
          end
          background_task_state_widget.setTextAlignment(Qt::AlignCenter)
          background_task_state_widget.setSizeHint(Qt::Size.new(80, 30))
          @background_tasks_table.setItem(row, 1, background_task_state_widget)
          background_task_status_widget = Qt::TableWidgetItem.new(background_task.status.to_s)
          background_task_status_widget.setTextAlignment(Qt::AlignCenter)
          background_task_status_widget.setSizeHint(Qt::Size.new(500, 30))
          @background_tasks_table.setItem(row, 2, background_task_status_widget)

          row += 1
        end
      end
      @background_tasks_table.displayFullSize
      background_tasks_layout.addWidget(@background_tasks_table)
      layout.addWidget(background_tasks_groupbox)

      # Set the scroll area widget last now that all the items have been layed out
      scroll.setWidget(widget)
      @tabbook.addTab(scroll, "Status")
    end

    def handle_status_tab
      @tab_thread = Thread.new do
        begin
          if CmdTlmServer.json_drb
            previous_request_count = CmdTlmServer.json_drb.request_count
          else
            previous_request_count = 0
          end
          while true
            start_time = Time.now
            Qt.execute_in_main_thread(true) do
              # Update limits set
              current_limits_set = System.limits_set.to_s
              if @limits_set_combo.currentText != current_limits_set
                known_limits_sets = System.limits.sets
                known_limits_sets = known_limits_sets.map {|x| x.to_s}.sort
                current_index = known_limits_sets.index(current_limits_set.to_s)
                @limits_set_combo.clear
                known_limits_sets.sort.each do |limits_set|
                  @limits_set_combo.addItem(limits_set.to_s)
                end
                @limits_set_combo.setCurrentIndex(current_index)
              end

              # Update API status
              if CmdTlmServer.json_drb
                @api_table.item(0,1).setText(CmdTlmServer.json_drb.num_clients.to_s)
                @api_table.item(0,2).setText(CmdTlmServer.json_drb.request_count.to_s)
                request_count = CmdTlmServer.json_drb.request_count
                requests_per_second = request_count - previous_request_count
                @api_table.item(0,3).setText(requests_per_second.to_s)
                previous_request_count = request_count
                average_request_time = CmdTlmServer.json_drb.average_request_time
                @api_table.item(0,4).setText(sprintf("%0.6f s", average_request_time))
                estimated_utilization = requests_per_second * average_request_time * 100.0
                @api_table.item(0,5).setText(sprintf("%0.2f %", estimated_utilization))
              end

              # Update system status
              @system_table.item(0,0).setText(Thread.list.length.to_s)
              objs = ObjectSpace.count_objects
              @system_table.item(0,1).setText(objs[:TOTAL].to_s)
              @system_table.item(0,2).setText(objs[:FREE].to_s)
              total = 0
              objs.each do |key, val|
                next if key == :TOTAL || key == :FREE
                total += val
              end
              @system_table.item(0,3).setText(total.to_s)

              # Update background task status
              background_tasks = CmdTlmServer.background_tasks.all
              if background_tasks.length > 0
                row = 0
                background_tasks.each_with_index do |background_task, index|
                  if background_task.thread
                    status = background_task.thread.status
                    status = 'complete' if status == false
                    @background_tasks_table.item(row, 1).setText(status.to_s)
                  else
                    @background_tasks_table.item(row, 1).setText('no thread')
                  end
                  @background_tasks_table.item(row, 2).setText(background_task.status.to_s)
                  row += 1
                end
              end
            end
            total_time = Time.now - start_time
            if total_time > 0.0 and total_time < 1.0
              break if @tab_sleeper.sleep(1.0 - total_time)
            end
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(self, error, "COSMOS CTS : Settings Tab Thread")}
        end
      end
    end

    def closeEvent(event)
      # Create are you sure dialog
      if @no_prompt
        continue = true
      else
        msg = Qt::MessageBox.new(self)
        msg.setIcon(Qt::MessageBox::Question)
        msg.setText("Are you sure? All tools connected to this CmdTlmServer will lose connections and cease to function if the CmdTlmServer is closed.")
        msg.setWindowTitle('Confirm Close')
        msg.setStandardButtons(Qt::MessageBox::Yes | Qt::MessageBox::No)
        continue = false
        continue = true if msg.exec() == Qt::MessageBox::Yes
        msg.dispose
      end

      if continue
        kill_tab_thread()
        CmdTlmServer.instance.stop_logging('ALL')
        CmdTlmServer.instance.stop
        super(event)
      else
        event.ignore()
      end
    end

    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.width = 800
          options.height = 500
          # Set the default title which can be overridden in the config file
          options.title = "#{CMD} and #{TLM} Server"
          options.auto_size = false
          options.config_file = CmdTlmServer::DEFAULT_CONFIG_FILE
          options.production = false
          options.no_prompt = false
          option_parser.separator "CTS Specific Options:"
          option_parser.on("-c", "--config FILE", "Use the specified configuration file") do |arg|
            options.config_file = arg
          end
          option_parser.on("-p", "--production", "Run the server in production mode which disables the ability to stop logging.") do |arg|
            options.production = true
          end
          option_parser.on("-n", "--no-prompt", "Don't prompt with Are You Sure dialog on close.") do |arg|
            options.no_prompt = true
          end
        end

        super(option_parser, options)
      end
    end

    def process_server_messages(options)
      # Start thread to read server messages
      @output_thread = Thread.new do
        begin
          while !@message_log
            sleep(1)
          end
          while true
            handle_string_output()
            break if @output_sleeper.sleep(1)
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) do
            ExceptionDialog.new(self, error, "#{options.title}: Messages Thread")
          end
        end
      end
    end

    def handle_string_output
      if @string_output.string[-1..-1] == "\n"
        Qt.execute_in_main_thread(true) do
          lines_to_write = ''
          string = @string_output.string.clone
          @string_output.string = @string_output.string[string.length..-1]
          string.each_line {|out_line| @output.add_formatted_text(out_line); lines_to_write += out_line }
          @output.flush
          @message_log.write(lines_to_write)
        end
      end
    end

    def stop_callback
      handle_string_output()
      @output_sleeper.cancel
      Qt::CoreApplication.processEvents()
      Cosmos.kill_thread(self, @output_thread)
      handle_string_output()
    end

    def graceful_kill
      # Just to avoid warning
    end
  end # class CmdTlmServerGui

end # module Cosmos
