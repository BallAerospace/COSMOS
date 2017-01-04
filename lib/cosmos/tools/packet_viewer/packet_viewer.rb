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
  require 'cosmos/gui/dialogs/tlm_details_dialog'
  require 'cosmos/gui/dialogs/tlm_edit_dialog'
  require 'cosmos/gui/dialogs/exception_dialog'
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/gui/widgets/full_text_search_line_edit'
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
        end

        # Unconfigure CosmosConfig to interact with splash screen
        ConfigParser.splash = nil
      end
    end

    def initialize_actions
      super()

      @reset_action = Qt::Action.new(tr('&Reset'), self)
      @reset_keyseq = Qt::KeySequence.new(tr('Ctrl+R'))
      @reset_action.shortcut = @reset_keyseq
      @reset_action.statusTip = tr('Reset Connection')
      connect(@reset_action, SIGNAL('triggered()'), self, SLOT('update_all()'))

      @option_action = Qt::Action.new(tr('O&ptions'), self)
      @option_action.statusTip = tr('Application Options')
      connect(@option_action, SIGNAL('triggered()'), self, SLOT('file_options()'))

      @color_blind_action = Qt::Action.new(tr('Color&blind Mode'), self)
      @color_blind_keyseq = Qt::KeySequence.new(tr('Ctrl+B'))
      @color_blind_action.shortcut  = @color_blind_keyseq
      @color_blind_action.statusTip = tr('Enable text representation of colors in the values')
      @color_blind_action.setCheckable(true)
      @color_blind_action.connect(SIGNAL('triggered()')) do
        @colorblind = @color_blind_action.isChecked
      end

      @hide_ignored_action = Qt::Action.new(tr('&Hide Ignored Items'), self)
      @hide_ignored_keyseq = Qt::KeySequence.new(tr('Ctrl+H'))
      @hide_ignored_action.shortcut  = @hide_ignored_keyseq
      @hide_ignored_action.statusTip = tr('Toggle showing and hiding ignored items')
      @hide_ignored_action.setCheckable(true)
      @hide_ignored_action.setChecked(false)
      @hide_ignored_action.connect(SIGNAL('triggered()')) do
        if @hide_ignored_action.isChecked
          @ignored_rows.each {|row| @table.setRowHidden(row, true) }
        else
          @ignored_rows.each {|row| @table.setRowHidden(row, false) }
        end
      end

      @derived_last_action = Qt::Action.new(tr('&Display Derived Last'), self)
      @derived_last_keyseq = Qt::KeySequence.new(tr('Ctrl+D'))
      @derived_last_action.shortcut  = @derived_last_keyseq
      @derived_last_action.statusTip = tr('Display derived telemetry items last')
      @derived_last_action.setCheckable(true)
      @derived_last_action.setChecked(false)
      @derived_last_action.connect(SIGNAL('triggered()')) { update_tlm_items() }

      @formatted_tlm_units_action = Qt::Action.new(tr('Formatted Telemetry With &Units'), self)
      @formatted_tlm_units_action.statusTip = tr('Formatted Telemetry with Units')
      @formatted_tlm_units_action.setCheckable(true)
      @formatted_tlm_units_action.setChecked(true)
      @formatted_tlm_units_action.connect(SIGNAL('triggered()')) do
        @mode = :WITH_UNITS
        self.window_title = "COSMOS Packet Viewer : Formatted Telemetry with Units"
      end

      @formatted_tlm_action = Qt::Action.new(tr('&Formatted Telemetry'), self)
      @formatted_tlm_action.statusTip = tr('Formatted Telemetry')
      @formatted_tlm_action.setCheckable(true)
      @formatted_tlm_action.connect(SIGNAL('triggered()')) do
        @mode = :FORMATTED
        self.window_title = "COSMOS Packet Viewer : Formatted Telemetry"
      end

      @normal_tlm_action = Qt::Action.new(tr('Normal &Converted Telemetry'), self)
      @normal_tlm_action.statusTip = tr('Normal Converted Telemetry')
      @normal_tlm_action.setCheckable(true)
      @normal_tlm_action.connect(SIGNAL('triggered()')) do
        @mode = :CONVERTED
        self.window_title = "COSMOS Packet Viewer : Coverted Telemetry"
      end

      @raw_tlm_action = Qt::Action.new(tr('&Raw Telemetry'), self)
      @raw_tlm_action.statusTip = tr('Raw Unprocessed Telemetry')
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
      file_menu = menuBar.addMenu(tr('&File'))
      file_menu.addAction(@reset_action)
      file_menu.addAction(@option_action)
      file_menu.addSeparator()
      file_menu.addAction(@exit_action)

      # View Menu
      view_menu = menuBar.addMenu(tr('&View'))
      view_menu.addAction(@color_blind_action)
      view_menu.addAction(@hide_ignored_action)
      view_menu.addAction(@derived_last_action)
      view_menu.addSeparator.setText(tr('Formatting'));
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

      # Set the target combobox selection
      @target_select = Qt::ComboBox.new
      @target_select.setMaxVisibleItems(6)
      @target_select.connect(SIGNAL('activated(const QString&)')) do
        update_packets()
        update_tlm_items()
      end
      target_label = Qt::Label.new(tr("&Target:"))
      target_label.setBuddy(@target_select)

      # Set the command combobox selection
      @packet_select = Qt::ComboBox.new
      @packet_select.setMaxVisibleItems(20)
      @packet_select.connect(SIGNAL('activated(const QString&)')) do
        update_tlm_items()
      end
      cmd_label = Qt::Label.new(tr("&Packet:"))
      cmd_label.setBuddy(@packet_select)

      # Mnemonic Search Box
      @search_layout = Qt::HBoxLayout.new
      @search_box = FullTextSearchLineEdit.new(self)
      @search_box.setStyleSheet("padding-right: 20px;padding-left: 5px;background: url(#{File.join(Cosmos::PATH, 'data', 'search-14.png')});background-position: right;background-repeat: no-repeat;")
      @search_layout.addWidget(@search_box)
      top_layout.addLayout(@search_layout)

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
      dec_label = Qt::Label.new(tr("Description:"))
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
      @polling_rate = Qt::InputDialog.getDouble(self, tr("Options"), tr("Polling Rate (sec):"),
                                                @polling_rate, 0, 1000, 1, nil)
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
              derived << [item.name, item.states, item.description]
            else
              tlm_items << [item.name, item.states, item.description]
              @derived_row += 1
            end
          end
          tlm_items.concat(derived) # Tack the derived onto the end
        else
          System.telemetry.items(target_name, packet_name).each do |item|
            tlm_items << [item.name, item.states, item.description]
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
      featured_item = nil
      @ignored_rows = []
      tlm_items.each do |tlm_name, states, description|
        @ignored_rows << row if System.targets[target_name].ignored_items.include?(tlm_name)
        item = Qt::TableWidgetItem.new(tr("#{tlm_name}:"))
        item.setTextAlignment(Qt::AlignRight)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable)
        @table.setItem(row, 0, item)
        item = Qt::TableWidgetItem.new(tr("0.0"))
        item.setTextAlignment(Qt::AlignRight)
        item.setFlags(Qt::NoItemFlags | Qt::ItemIsSelectable | Qt::ItemIsEnabled)
        @table.setItem(row, 1, item)
        @descriptions[row] = []
        @descriptions[row][0] = description
        @descriptions[row][1] = description
        row += 1
        featured_item = item if featured_item_name == tlm_name
      end

      @table.resizeColumnsToContents()
      @table.resizeRowsToContents()
      @table.scrollToItem(featured_item) if featured_item
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
            time = Time.now
            break if @shutdown_tlm_thread

            begin
              tlm_items = get_tlm_packet(target_name || '', packet_name || '', @mode)
            rescue DRb::DRbConnError => error
              Qt.execute_in_main_thread(true) do
                statusBar.showMessage(tr("Error Connecting to Command and Telemetry Server"))
              end
              tlm_items = nil
              update_needed = false
            rescue RuntimeError => error
              Qt.execute_in_main_thread(true) do
                Cosmos.handle_critical_exception(error)
                statusBar.showMessage(tr("Packet #{target_name} #{packet_name} Error: #{error}"))
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
              sleep(@polling_rate.to_f / 10.0) if (Time.now - time < @polling_rate)
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
      statusBar.showMessage(tr(@descriptions[row][col]))
    end

    def context_menu(point)
      target_name = @target_select.currentText
      packet_name = @packet_select.currentText
      item = @table.itemAt(point)
      if item
        item_name = @table.item(item.row, 0).text[0..-2] # Remove :
        if target_name.length > 0 and packet_name.length > 0 and item_name.length > 0
          menu = Qt::Menu.new()

          details_action = Qt::Action.new(tr("Details #{target_name} #{packet_name} #{item_name}"), self)
          details_action.statusTip = tr("Popup details about #{target_name} #{packet_name} #{item_name}")
          details_action.connect(SIGNAL('triggered()')) do
            TlmDetailsDialog.new(nil, target_name, packet_name, item_name)
            @table.clearSelection
          end
          menu.addAction(details_action)

          edit_action = Qt::Action.new(tr("Edit #{target_name} #{packet_name} #{item_name}"), self)
          edit_action.statusTip = tr("Edit Settings for #{target_name} #{packet_name} #{item_name}")
          edit_action.connect(SIGNAL('triggered()')) do
            TlmEditDialog.new(self, target_name, packet_name, item_name)
            @table.clearSelection
          end
          menu.addAction(edit_action)

          graph_action = Qt::Action.new(tr("Graph #{target_name} #{packet_name} #{item_name}"), self)
          graph_action.statusTip = tr("Create a new COSMOS graph of #{target_name} #{packet_name} #{item_name}")
          graph_action.connect(SIGNAL('triggered()')) do
            @table.clearSelection
            if Kernel.is_windows?
              Cosmos.run_process("rubyw tools/TlmGrapher -i \"#{target_name} #{packet_name} #{item_name}\" --system #{File.basename(System.initial_filename)}")
            elsif Kernel.is_mac? and File.exist?("tools/mac/TlmGrapher.app")
              Cosmos.run_process("open tools/mac/TlmGrapher.app --args -i \"#{target_name} #{packet_name} #{item_name}\" --system #{File.basename(System.initial_filename)}")
            else
              Cosmos.run_process("ruby tools/TlmGrapher -i \"#{target_name} #{packet_name} #{item_name}\" --system #{File.basename(System.initial_filename)}")
            end
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
        end

        super(option_parser, options)
      end
    end

  end # class PacketViewer

end # module Cosmos

