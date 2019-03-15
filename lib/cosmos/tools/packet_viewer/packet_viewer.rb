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
  require 'cosmos/gui/dialogs/tlm_details_dialog'
  require 'cosmos/gui/dialogs/tlm_edit_dialog'
  require 'cosmos/gui/dialogs/tlm_graph_dialog'
  require 'cosmos/gui/dialogs/exception_dialog'
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/gui/widgets/full_text_search_line_edit'
  require 'cosmos/script'
end

module Cosmos

  class PacketViewer < QtTool
    slots 'file_options()'
    slots 'update_all()'
    slots 'mouse_over(int, int)'
    slots 'context_menu(const QPoint&)'

    def initialize(options)
      super(options) # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      Cosmos.load_cosmos_icon("packet_viewer.png")

      @table = nil
      @tlm_thread = nil
      @shutdown_tlm_thread = false
      @mode = :WITH_UNITS
      if options.rate
        @polling_rate = options.rate
      else
        @polling_rate = 1.0
      end
      @colorblind = false

      initialize_actions()
      initialize_menus()
      initialize_central_widget(options)
      complete_initialize()

      # Bring up slash screen for long duration tasks after creation
      Splash.execute(self) do |splash|
        # Configure CosmosConfig to interact with splash screen
        ConfigParser.splash = splash

        System.telemetry
        Qt.execute_in_main_thread(true) do
          update_targets()
          @target_select.setCurrentText(options.packet[0].upcase) if options.packet
          update_packets()
          @packet_select.setCurrentText(options.packet[1].upcase) if options.packet
          update_tlm_items()

          @search_box.completion_list = System.telemetry.all_item_strings(true, splash)
          @search_box.callback = lambda do |tlm|
            split_tlm = tlm.split(" ")
            if split_tlm.length == 3
              target_name = split_tlm[0].upcase
              @target_select.setCurrentText(target_name)
              update_packets()
              packet_name = split_tlm[1]
              @packet_select.setCurrentText(packet_name)
              item_name = split_tlm[2]
              update_tlm_items(item_name)
            end
          end
          toggle_replay_mode() if options.replay
        end

        # Unconfigure CosmosConfig to interact with splash screen
        ConfigParser.splash = nil
      end
    end

    def initialize_actions
      super()

      @edit_action = Qt::Action.new(Cosmos.get_icon('edit.png'),
                                    '&Edit Definition',
                                    self)
      @edit_keyseq = Qt::KeySequence.new('Ctrl+E')
      @edit_action.shortcut = @edit_keyseq
      @edit_action.statusTip = 'Open packet definition in a editor'
      @edit_action.connect(SIGNAL('triggered()')) { edit_definition }

      @reset_action = Qt::Action.new('&Reset', self)
      @reset_keyseq = Qt::KeySequence.new('Ctrl+R')
      @reset_action.shortcut = @reset_keyseq
      @reset_action.statusTip = 'Reset Connection'
      connect(@reset_action, SIGNAL('triggered()'), self, SLOT('update_all()'))

      @option_action = Qt::Action.new('O&ptions', self)
      @option_action.statusTip = 'Application Options'
      connect(@option_action, SIGNAL('triggered()'), self, SLOT('file_options()'))

      @replay_action = Qt::Action.new('Toggle Replay Mode', self)
      @replay_action.statusTip = 'Toggle Replay Mode'
      @replay_action.connect(SIGNAL('triggered()')) { toggle_replay_mode() }

      @color_blind_action = Qt::Action.new('Color&blind Mode', self)
      @color_blind_keyseq = Qt::KeySequence.new('Ctrl+B')
      @color_blind_action.shortcut  = @color_blind_keyseq
      @color_blind_action.statusTip = 'Enable text representation of colors in the values'
      @color_blind_action.setCheckable(true)
      @color_blind_action.connect(SIGNAL('triggered()')) do
        @colorblind = @color_blind_action.isChecked
      end

      @hide_ignored_action = Qt::Action.new('&Hide Ignored Items', self)
      @hide_ignored_keyseq = Qt::KeySequence.new('Ctrl+H')
      @hide_ignored_action.shortcut  = @hide_ignored_keyseq
      @hide_ignored_action.statusTip = 'Toggle showing and hiding ignored items'
      @hide_ignored_action.setCheckable(true)
      @hide_ignored_action.setChecked(false)
      @hide_ignored_action.connect(SIGNAL('triggered()')) { hide_ignored() }

      @derived_last_action = Qt::Action.new('&Display Derived Last', self)
      @derived_last_keyseq = Qt::KeySequence.new('Ctrl+D')
      @derived_last_action.shortcut  = @derived_last_keyseq
      @derived_last_action.statusTip = 'Display derived telemetry items last'
      @derived_last_action.setCheckable(true)
      @derived_last_action.setChecked(false)
      @derived_last_action.connect(SIGNAL('triggered()')) { update_tlm_items() }

      @formatted_tlm_units_action = Qt::Action.new('Formatted Telemetry With &Units', self)
      @formatted_tlm_units_action.statusTip = 'Formatted Telemetry with Units'
      @formatted_tlm_units_action.setCheckable(true)
      @formatted_tlm_units_action.setChecked(true)
      @formatted_tlm_units_action.connect(SIGNAL('triggered()')) do
        @mode = :WITH_UNITS
        self.window_title = "COSMOS Packet Viewer : Formatted Telemetry with Units"
      end

      @formatted_tlm_action = Qt::Action.new('&Formatted Telemetry', self)
      @formatted_tlm_action.statusTip = 'Formatted Telemetry'
      @formatted_tlm_action.setCheckable(true)
      @formatted_tlm_action.connect(SIGNAL('triggered()')) do
        @mode = :FORMATTED
        self.window_title = "COSMOS Packet Viewer : Formatted Telemetry"
      end

      @normal_tlm_action = Qt::Action.new('Normal &Converted Telemetry', self)
      @normal_tlm_action.statusTip = 'Normal Converted Telemetry'
      @normal_tlm_action.setCheckable(true)
      @normal_tlm_action.connect(SIGNAL('triggered()')) do
        @mode = :CONVERTED
        self.window_title = "COSMOS Packet Viewer : Coverted Telemetry"
      end

      @raw_tlm_action = Qt::Action.new('&Raw Telemetry', self)
      @raw_tlm_action.statusTip = 'Raw Unprocessed Telemetry'
      @raw_tlm_action.setCheckable(true)
      @raw_tlm_action.connect(SIGNAL('triggered()')) do
        @mode = :RAW
        self.window_title = "COSMOS Packet Viewer : Raw Telemetry"
      end

      # The formatting options are mutually exclusive so create an action group
      formatting_group = Qt::ActionGroup.new(self)
      formatting_group.addAction(@formatted_tlm_units_action)
      formatting_group.addAction(@formatted_tlm_action)
      formatting_group.addAction(@normal_tlm_action)
      formatting_group.addAction(@raw_tlm_action)
    end

    def initialize_menus
      # File Menu
      file_menu = menuBar.addMenu('&File')
      file_menu.addAction(@edit_action)
      file_menu.addAction(@reset_action)
      file_menu.addAction(@option_action)
      file_menu.addAction(@replay_action)
      file_menu.addSeparator()
      file_menu.addAction(@exit_action)

      # View Menu
      view_menu = menuBar.addMenu('&View')
      view_menu.addAction(@color_blind_action)
      view_menu.addAction(@hide_ignored_action)
      view_menu.addAction(@derived_last_action)
      view_menu.addSeparator.setText('Formatting')
      view_menu.addAction(@formatted_tlm_units_action)
      view_menu.addAction(@formatted_tlm_action)
      view_menu.addAction(@normal_tlm_action)
      view_menu.addAction(@raw_tlm_action)

      # Help Menu
      @about_string = "Packet Viewer provides a view of every telemetry packet in the system. Packets can be viewed in numerous represenations ranging from the raw data to formatted with units."
      initialize_help_menu()
    end

    def initialize_central_widget(options)
      # Create the central widget
      central_widget = Qt::Widget.new
      setCentralWidget(central_widget)

      # Create the top level vertical layout
      top_layout = Qt::VBoxLayout.new(central_widget)

      @replay_flag = Qt::Label.new("Replay Mode")
      @replay_flag.setStyleSheet("background:green;color:white;padding:5px;font-weight:bold;")
      top_layout.addWidget(@replay_flag)
      @replay_flag.hide

      # Set the target combobox selection
      @target_select = Qt::ComboBox.new
      @target_select.setMaxVisibleItems(6)
      @target_select.connect(SIGNAL('activated(const QString&)')) do
        update_packets()
        update_tlm_items()
      end
      target_label = Qt::Label.new("&Target:")
      target_label.setBuddy(@target_select)

      # Set the command combobox selection
      @packet_select = Qt::ComboBox.new
      @packet_select.setMaxVisibleItems(20)
      @packet_select.connect(SIGNAL('activated(const QString&)')) do
        update_tlm_items()
      end
      cmd_label = Qt::Label.new("&Packet:")
      cmd_label.setBuddy(@packet_select)

      # Mnemonic Search Box
      @search_box = FullTextSearchLineEdit.new(self)
      top_layout.addWidget(@search_box)

      # Layout the top level selection
      select_layout = Qt::HBoxLayout.new
      select_layout.addWidget(target_label)
      select_layout.addWidget(@target_select, 1)
      select_layout.addWidget(cmd_label)
      select_layout.addWidget(@packet_select, 1)
      top_layout.addLayout(select_layout)

      # Separator Between Telemetry Selection and Telemetry Description
      sep1 = Qt::Frame.new(central_widget)
      sep1.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      top_layout.addWidget(sep1)

      # Telemetry Description Label
      dec_label = Qt::Label.new("Description:")
      @description = Qt::Label.new('')
      desc_layout = Qt::HBoxLayout.new
      desc_layout.addWidget(dec_label)
      desc_layout.addWidget(@description, 1)
      top_layout.addLayout(desc_layout)

      # Separator Between Telemetry Selection and Description
      sep2 = Qt::Frame.new(central_widget)
      sep2.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Sunken)
      top_layout.addWidget(sep2)

      @frame = Qt::VBoxLayout.new
      top_layout.addLayout(@frame)
    end

    def file_options
      @polling_rate = Qt::InputDialog.getDouble(self, "Options", "Polling Rate (sec):",
                                                @polling_rate, 0, 1000, 1, nil)
    end

    def toggle_replay_mode
      set_replay_mode(!get_replay_mode())
      if get_replay_mode()
        @replay_flag.show
      else
        @replay_flag.hide
      end
    end

    def hide_ignored
      if @hide_ignored_action.isChecked
        @ignored_rows.each {|row| @table.setRowHidden(row, true) }
      else
        @ignored_rows.each {|row| @table.setRowHidden(row, false) }
      end
    end

    def edit_definition
      # Grab all the cmd_tlm_files and processes them in reverse sort order
      # because typically we'll have cmd.txt and tlm.txt and we want to process
      # tlm.txt first
      found = false
      System.targets[@target_select.text].cmd_tlm_files.sort.reverse.each do |filename|
        # Skip partials which begin with an underscore
        next if File.basename(filename)[0] == '_'
        file = File.read(filename)
        # Wild card the target name because it is not used and is often aliased
        if file =~ /TELEMETRY\s+.*\s+#{@packet_select.text}/
          Cosmos.run_cosmos_tool('ConfigEditor', "-f #{filename}")
          found = true
          break
        end
      end
      # A packet definition might not be found due to ERB templates or other
      # strange things they're doing. Pop up a warning and make them go look.
      if !found
        target_name = System.targets[@target_select.text].original_name
        Qt::MessageBox.warning(self, "Definition Not Found",
                               "Could not find definition for #{@target_select.text} #{@packet_select.text}.\n"\
                               "Perhaps some ERB code is preventing automatic detection.\n"\
                               "You should manually explore the files in config/targets/#{target_name}/cmd_tlm.")
      end
    end

    def update_all
      update_targets()
      update_packets()
      update_tlm_items()
    end

    def update_targets
      @target_select.clearItems

      System.telemetry.target_names.each do |target_name|
        packets = System.telemetry.packets(target_name)
        has_non_hidden = false
        packets.each do |packet_name, packet|
          next if packet.hidden
          has_non_hidden = true
          break
        end
        @target_select.addItem(target_name) if has_non_hidden
      end
    end

    def update_packets
      @packet_select.clearItems
      @packets = []
      begin
        packets = System.telemetry.packets(@target_select.text)
      rescue
        # Unknown target or no telemetry packets
        packets = []
      end
      packets.each do |packet_name, packet|
        @packets << [packet_name, packet.description] unless packet.hidden
      end
      @packets.sort
      @packets = [[""]] if @packets.empty?
      @packets.each do |packet_name, description|
        @packet_select.addItem(packet_name)
      end
      if not @packets.empty?
        @packet_select.setCurrentText(@packets[0][0])
      end
    end

    def update_tlm_items(featured_item_name = nil)
      target_name = @target_select.text
      packet_name = @packet_select.text

      if @tlm_thread
        @shutdown_tlm_thread = true
        Qt.execute_in_main_thread(false, 0.001, true) {update_tlm_items(featured_item_name)}
        return
      end

      # Update Telemetry Description
      @description.text = ""
      @packets.each do |name, description|
        if name == packet_name
          @description.text = description.to_s
          break
        end
      end

      # Destory and recreate a new table widget
      @table.dispose if @table

      # Table for Telemetry Items
      @table = Qt::TableWidget.new()

      # Update Telemetry Items
      tlm_items = []
      begin
        @derived_row = 0
        if @derived_last_action.isChecked
          derived = []
          System.telemetry.items(target_name, packet_name).each do |item|
            if item.data_type == :DERIVED
              derived << [item.name, item.states, item.description, true]
            else
              tlm_items << [item.name, item.states, item.description, false]
              @derived_row += 1
            end
          end
          tlm_items.concat(derived) # Tack the derived onto the end
        else
          System.telemetry.items(target_name, packet_name).each do |item|
            tlm_items << [item.name, item.states, item.description, item.data_type == :DERIVED]
          end
        end
      rescue
        # Unknown packet
      end

      @table.setRowCount(tlm_items.length)
      @table.setColumnCount(2)
      # Force the last section (the values) to fill all available space in the frame
      @table.horizontalHeader.setStretchLastSection(true)
      @table.setHorizontalHeaderLabels(%w(Item Value))
      @descriptions = []

      row = 0
      featured_row = -1
      @ignored_rows = []
      tlm_items.each do |tlm_name, states, description, derived|
        featured_row = row if featured_item_name == tlm_name
        @ignored_rows << row if System.targets[target_name].ignored_items.include?(tlm_name)
        tlm_name = "*#{tlm_name}" if derived
        item = Qt::TableWidgetItem.new("#{tlm_name}:")
        item.setTextAlignment(Qt::AlignRight)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable)
        @table.setItem(row, 0, item)
        item = Qt::TableWidgetItem.new("0.0")
        item.setTextAlignment(Qt::AlignRight)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
        @table.setItem(row, 1, item)
        @descriptions[row] = []
        @descriptions[row][0] = description
        @descriptions[row][1] = description
        row += 1
      end
      hide_ignored()

      @table.resizeColumnsToContents()
      @table.resizeRowsToContents()
      if featured_row != -1
        # Selecting the row also scrolls to it so the item is displayed
        @table.selectRow(featured_row)
        # Fire up a thread to clear the selection cuz it's kind of annoying
        Thread.new do
          sleep 1
          Qt.execute_in_main_thread { @table.clearSelection }
        end
      end

      @frame.addWidget(@table)

      # Handle Table Clicks
      @table.setMouseTracking(true)
      connect(@table, SIGNAL('cellEntered(int, int)'),
              self, SLOT('mouse_over(int, int)'))
      @table.setContextMenuPolicy(Qt::CustomContextMenu)
      connect(@table, SIGNAL('customContextMenuRequested(const QPoint&)'),
              self, SLOT('context_menu(const QPoint&)'))

      # Start Update Thread
      update_needed = false
      @tlm_thread = Thread.new do
        begin
          while true
            time = Time.now.sys
            break if @shutdown_tlm_thread

            begin
              tlm_items = get_tlm_packet(target_name || '', packet_name || '', @mode)
            rescue DRb::DRbConnError => error
              Qt.execute_in_main_thread(true) do
                statusBar.showMessage("Error Connecting to Command and Telemetry Server")
              end
              tlm_items = nil
              update_needed = false
            rescue RuntimeError => error
              Qt.execute_in_main_thread(true) do
                Cosmos.handle_critical_exception(error)
                statusBar.showMessage("Packet #{target_name} #{packet_name} Error: #{error}")
              end
              tlm_items = nil
              update_needed = true
            end

            break if @shutdown_tlm_thread

            Qt.execute_in_main_thread(true) do
              # If we need an update (which indicates we've reconnected to the server)
              # Then we call update_all which will update all the telemetry items
              # and kill and respawn this thread
              if update_needed
                update_all()
              end

              if tlm_items
                # Start with wherever the first derived item is
                # See above where we populate tlm_items
                row = @derived_row
                tlm_items.each do |name, value, limits_state|
                  text = value.to_s
                  # If derived is last we need to reset the row to 0
                  # to start populating the real items at the top
                  if row == (tlm_items.length)
                    row = 0
                  end

                  case limits_state
                  when :GREEN, :GREEN_HIGH
                    @table.item(row, 1).textColor = Cosmos::GREEN
                    text << ' (G)' if @colorblind
                  when :GREEN_LOW
                    @table.item(row, 1).textColor = Cosmos::GREEN
                    text << ' (g)' if @colorblind
                  when :YELLOW, :YELLOW_HIGH
                    @table.item(row, 1).textColor = Cosmos::YELLOW
                    text << ' (Y)' if @colorblind
                  when :YELLOW_LOW
                    @table.item(row, 1).textColor = Cosmos::YELLOW
                    text << ' (y)' if @colorblind
                  when :RED, :RED_HIGH
                    @table.item(row, 1).textColor = Cosmos::RED
                    text << ' (R)' if @colorblind
                  when :RED_LOW
                    @table.item(row, 1).textColor = Cosmos::RED
                    text << ' (r)' if @colorblind
                  when :BLUE
                    @table.item(row, 1).textColor = Cosmos::BLUE
                    text << ' (B)' if @colorblind
                  when :STALE
                    @table.item(row, 1).textColor = Cosmos::PURPLE
                    text << ' ($)' if @colorblind
                  else
                    @table.item(row, 1).textColor = Cosmos::BLACK
                  end

                  @table.item(row,1).setText(text)
                  row += 1
                end
              end
            end
            # Delay for 1/10 of polling rate
            10.times do
              break if @shutdown_tlm_thread
              sleep(@polling_rate.to_f / 10.0) if (Time.now.sys - time < @polling_rate)
            end
          end
        rescue Exception => error
          Qt.execute_in_main_thread(true) do
            ExceptionDialog.new(self, error, "COSMOS Packet Viewer : Telemetry Thread")
          end
        end
        @shutdown_tlm_thread = false
        @tlm_thread = nil
      end
    end

    def mouse_over(row, col)
      statusBar.showMessage(@descriptions[row][col])
    end

    def context_menu(point)
      target_name = @target_select.currentText
      packet_name = @packet_select.currentText
      item = @table.itemAt(point)
      if item
        item_name = @table.item(item.row, 0).text[0..-2] # Remove :
        item_name = item_name[1..-1] if item_name[0] == '*'
        if target_name.length > 0 and packet_name.length > 0 and item_name.length > 0
          menu = Qt::Menu.new()

          details_action = Qt::Action.new("Details #{target_name} #{packet_name} #{item_name}", self)
          details_action.statusTip = "Popup details about #{target_name} #{packet_name} #{item_name}"
          details_action.connect(SIGNAL('triggered()')) do
            TlmDetailsDialog.new(nil, target_name, packet_name, item_name)
            @table.clearSelection
          end
          menu.addAction(details_action)

          edit_action = Qt::Action.new("Edit #{target_name} #{packet_name} #{item_name}", self)
          edit_action.statusTip = "Edit Settings for #{target_name} #{packet_name} #{item_name}"
          edit_action.connect(SIGNAL('triggered()')) do
            TlmEditDialog.new(self, target_name, packet_name, item_name)
            @table.clearSelection
          end
          menu.addAction(edit_action)

          graph_action = Qt::Action.new("Graph #{target_name} #{packet_name} #{item_name}", self)
          graph_action.statusTip = "Create a new COSMOS graph of #{target_name} #{packet_name} #{item_name}"
          graph_action.connect(SIGNAL('triggered()')) do
            @table.clearSelection
            TlmGraphDialog.new(self, target_name, packet_name, item_name, get_replay_mode())
          end
          menu.addAction(graph_action)

          menu.exec(@table.mapToGlobal(point))
          menu.dispose
        end
      end
    end

    def closeEvent(event)
      if @tlm_thread
        @shutdown_tlm_thread = true
        Qt.execute_in_main_thread(false, 0.001, true) { close() }
        event.ignore
        return
      end
      super(event)
    end

    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.width = 325
          options.height = 200
          options.title = 'Packet Viewer : Formatted Telemetry with Units'
          option_parser.separator "Packet Viewer Specific Options:"
          option_parser.on("-p", "--packet 'TARGET_NAME PACKET_NAME'",
                           "Start viewing the specified packet") do |arg|
            split = arg.split
            if split.length != 2
              puts "Packet must be specified as 'TARGET_NAME PACKET_NAME' in quotes"
              exit
            end
            options.packet = split
          end
          option_parser.on("-r", "--rate PERIOD",
                           "Set the polling rate to PERIOD (unit seconds)") do |arg|
            options.rate = Float(arg)
          end
          options.replay = false
          option_parser.on("--replay", "Start Packet Viewer in Replay mode") do
            options.replay = true
          end
        end
        super(option_parser, options)
      end
    end
  end
end
