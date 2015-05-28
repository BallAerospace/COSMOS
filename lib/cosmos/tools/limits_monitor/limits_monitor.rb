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
  require 'cosmos/gui/dialogs/splash'
  require 'cosmos/gui/dialogs/cmd_tlm_raw_dialog'
  require 'cosmos/script'
  require 'cosmos/tools/tlm_viewer/widgets/labelvaluelimitsbar_widget'
end

class Array
  def includes_item?(item)
    found, index = find_item(item)
    return found
  end

  def delete_item(item)
    found, index = find_item(item)
    self.delete_at(index) if found
    return index
  end

  private
  def find_item(item)
    found = false
    index = 0
    self.each do |target_name, packet_name, item_name|
      if ((target_name == item[0]) &&
          (packet_name == item[1]) &&
          # If the item name is nil we're dealing with a packet
          (item_name == item[2] || item_name.nil?))
        found = true
        break
      end
      index += 1
    end
    return found, index
  end
end

module Cosmos

  # The LimitsMonitor application displays all the out of limits items
  # encountered by the COSMOS server. It provides the ability to ignore and
  # restore limits as well as logs all limits events.
  class LimitsMonitor < QtTool
    slots 'options()'
    slots 'reset()'
    slots 'handle_edit_ignored_items()'
    slots 'handle_save_ignored_items()'
    slots 'handle_open_ignored_items()'

    # Set up class variables, tab-book with main panel and log panel, menus, and
    # status bar on main panel.
    #
    # @param options [Options] Contains the options for the window.
    def initialize(options)
      super(options)
      Cosmos.load_cosmos_icon("limits_monitor.png")

      @out_of_limits_items = []
      @queue_id = nil
      @limits_set = nil
      @widgets = []
      @widget_hframes = []
      @value_limits_set = nil
      @items = []
      @new_items = []
      @initialized = false
      @overall_limits_state = :STALE
      @ignored_items = []
      @ignored_filename = nil
      @colorblind = false
      @new_widgets = []
      @buttons = []
      @cancel_thread = false
      @limits_sleeper = Sleeper.new
      @value_sleeper = Sleeper.new

      statusBar.showMessage(tr(""))

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()

      # Process config file if present
      process_config(File.join(::Cosmos::USERPATH, 'config', 'tools', 'limits_monitor', options.config_file)) if options.config_file

      # Start thread to monitor limits
      value_thread()
      limits_thread()
    end # initialize

    def initialize_actions
      super()

      @options_action = Qt::Action.new(tr('O&ptions'), self)
      @options_action.statusTip = tr('Open the options dialog')
      connect(@options_action, SIGNAL('triggered()'), self, SLOT('options()'))

      @reset_action = Qt::Action.new(tr('&Reset'), self)
      @reset_action_keyseq = Qt::KeySequence.new(tr('Ctrl+R'))
      @reset_action.shortcut = @reset_action_keyseq
      @reset_action.statusTip = tr('Reset connection and clear all items. This does not modify the ignored items.')
      connect(@reset_action, SIGNAL('triggered()'), self, SLOT('reset()'))

      @open_ignored_action = Qt::Action.new(Cosmos.get_icon('open.png'),
                                            tr('&Open Config'), self)
      @open_ignored_action_keyseq = Qt::KeySequence.new(tr('Ctrl+O'))
      @open_ignored_action.shortcut = @open_ignored_action_keyseq
      @open_ignored_action.statusTip = tr('Open ignored telemetry items configuration file')
      connect(@open_ignored_action, SIGNAL('triggered()'), self, SLOT('handle_open_ignored_items()'))

      @save_ignored_action = Qt::Action.new(Cosmos.get_icon('save.png'),
                                            tr('&Save Config'), self)
      @save_ignored_action_keyseq = Qt::KeySequence.new(tr('Ctrl+S'))
      @save_ignored_action.shortcut = @save_ignored_action_keyseq
      @save_ignored_action.statusTip = tr('Save all ignored telemetry items in a configuration file')
      connect(@save_ignored_action, SIGNAL('triggered()'), self, SLOT('handle_save_ignored_items()'))

      @edit_ignored_action = Qt::Action.new(tr('&Edit Ignored'), self)
      @edit_ignored_action.shortcut = Qt::KeySequence.new(tr('Ctrl+E'))
      @edit_ignored_action.statusTip = tr('Edit the ignored telemetry items list')
      connect(@edit_ignored_action, SIGNAL('triggered()'), self, SLOT('handle_edit_ignored_items()'))
    end

    def initialize_menus
      @file_menu = menuBar.addMenu(tr('&File'))
      @file_menu.addAction(@open_ignored_action)
      @file_menu.addAction(@save_ignored_action)
      @file_menu.addAction(@edit_ignored_action)
      @file_menu.addSeparator()
      @file_menu.addAction(@reset_action)
      @file_menu.addAction(@options_action)
      @file_menu.addSeparator()
      @file_menu.addAction(@exit_action)

      # Help Menu
      @about_string = "Limits Monitor displays all telemetry items that are or have been out of limits since it was started or reset."

      initialize_help_menu()
    end

    def initialize_central_widget
      @tabbook = Qt::TabWidget.new(self)
      setCentralWidget(@tabbook)
      @widget = Qt::Widget.new
      @layout = Qt::VBoxLayout.new(@widget)

      @monitored_state_text_field = Qt::LineEdit.new(self)
      @monitored_state_text_field.setText('Stale')
      @monitored_state_text_field.setAlignment(Qt::AlignCenter)
      @monitored_state_text_field.setReadOnly(true)
      @palette = Qt::Palette.new()
      @palette.setColor(Qt::Palette::Base, Qt::Color.new(255,0,255))
      @monitored_state_text_field.setPalette(@palette)
      @state_label = Qt::Label.new('Monitored Limits State: ')

      @monitored_state_frame = Qt::HBoxLayout.new
      @monitored_state_frame.addWidget(@state_label)
      @monitored_state_frame.addWidget(@monitored_state_text_field)
      label = Qt::Label.new
      filename = File.join(::Cosmos::PATH, 'data', 'spinner.gif')
      movie = Qt::Movie.new(filename)
      label.setMovie(movie)
      movie.start
      @monitored_state_frame.addWidget(label)

      @monitored_state_frame.setAlignment(Qt::AlignTop)

      @scroll = Qt::ScrollArea.new
      @scroll_widget = Qt::Widget.new
      @scroll_layout = Qt::VBoxLayout.new(@scroll_widget)
      @scroll_layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)

      @scroll.setWidget(@scroll_widget)

      @layout.addLayout(@monitored_state_frame)
      @layout.addWidget(@scroll)

      @log_output = Qt::PlainTextEdit.new
      @log_output.setReadOnly(true)
      @log_output.setMaximumBlockCount(100)

      @tabbook.addTab(@widget, "Limits")
      @tabbook.addTab(@log_output, "Log")
    end

    # Slot to add items to the front panel when they are out of limits.
    #
    # @param target_name [String] Target name of out of limits item.
    # @param packet_name [String] Packet name of out of limits item.
    # @param item_name [String] Item name of out of limits item.
    def add_items(target_name, packet_name, item_name)
      Qt.execute_in_main_thread(true) do
        hlayout = Qt::HBoxLayout.new
        hlayout.setSpacing(0)
        hlayout.setContentsMargins(0,0,0,0)
        @scroll_layout.addLayout(hlayout)

        item = [target_name, packet_name, item_name]
        if item_name
          new_widget = LabelvaluelimitsbarWidget.new(hlayout, target_name, packet_name, item_name)
          new_widget.set_setting('COLORBLIND', [@colorblind])
          new_widget.process_settings
          # Only update new widgets for the value widgets
          @new_widgets << new_widget
        else
          new_widget = LabelWidget.new(hlayout, "#{target_name} #{packet_name}")
        end

        ignore_button = Qt::PushButton.new('Ignore')
        ignore_button.connect(SIGNAL('clicked()')) do
          ignore_item(item)
        end

        hlayout.addWidget(ignore_button)

        @widget_hframes << hlayout
        @widgets << new_widget
        @buttons << ignore_button
      end
    end

    # Slot to update the log panel with limits change information.
    #
    # @param to_add [String] Text string with information about which item is out of
    #   limits, what its value is, and what limit was broken (red_low, yellow_low, etc.)
    # @param color [int] Integer representing color of text to add.
    def update_log(to_add, color)
      return if @cancel_thread
      Qt.execute_in_main_thread(true) do
        @tf = Qt::TextCharFormat.new
        case color
        when 0
          brush = Cosmos.getBrush(Cosmos::GREEN)
        when 1
          brush = Cosmos.getBrush(Cosmos::YELLOW)
        when 2
          brush = Cosmos.getBrush(Cosmos::RED)
        when 3
          brush = Cosmos.getBrush(Cosmos::BLUE)
        else
          brush = Cosmos.getBrush(Cosmos::BLACK)
        end
        @tf.setForeground(brush)
        @log_output.setCurrentCharFormat(@tf)
        @log_output.appendPlainText(to_add.chomp)
        @tf.dispose
      end
    end

    # Slot to handle the options menu item when selected.
    def options
      Qt::Dialog.new(self) do |dialog|
        dialog.setWindowTitle('Options')

        colorblind_box = Qt::CheckBox.new('Colorblind Mode Enabled', self)
        if (@colorblind)
          colorblind_box.setCheckState(Qt::Checked)
        end

        ok = Qt::PushButton.new('Ok') do
          connect(SIGNAL('clicked()')) { dialog.accept }
        end

        cancel = Qt::PushButton.new('Cancel') do
          connect(SIGNAL('clicked()')) { dialog.reject }
        end

        buttons = Qt::HBoxLayout.new do
          addWidget(ok)
          addWidget(cancel)
        end

        dialog.layout = Qt::VBoxLayout.new do
          addWidget(colorblind_box)
          addLayout(buttons)
        end

        case dialog.exec
        when Qt::Dialog::Accepted
          if (colorblind_box.checkState() == Qt::Checked)
            @colorblind = true
          else
            @colorblind = false
          end
          @widgets.each do |widget|
            widget.set_setting('COLORBLIND', [@colorblind])
            widget.process_settings
          end
        end
        dialog.dispose
      end
    end

    # Slot to handle the resent menu item when selected.
    def reset
      @initialized = false
    end

    # Sets up the thread to monitor for broken limits and add them to the log and
    # front panel when found.
    def limits_thread
      @limits_thread = Thread.new do
        begin
          while true
            break if @cancel_thread
            begin
              initialized = nil
              break if @cancel_thread
              Qt.execute_in_main_thread(true) do
                initialized = @initialized
              end
              unless initialized
                @limits_set = nil
                break if @cancel_thread
                Qt.execute_in_main_thread(true) do
                  @out_of_limits_items = []
                end
                unsubscribe_limits_events(@queue_id) if @queue_id
                @queue_id = nil

                handle_reset()

                # Get the current limits set
                @limits_set = get_limits_set()

                # Subscribe to limits notifications
                @queue_id = subscribe_limits_events(100000)

                # Get initial list of out of limits items
                items = get_out_of_limits()
                unless items.empty?
                  break if @cancel_thread
                  Qt.execute_in_main_thread(true) do
                    items.each do |item|
                      unless @ignored_items.includes_item?(item) and !@items.includes_item?(item)
                        @new_items << [item[0], item[1], item[2]]
                        @out_of_limits_items << [item[0], item[1], item[2]]
                      end
                    end
                    handle_new_items()
                  end
                end
                get_stale(true).each do |target, packet|
                  item = [target, packet, nil]
                  unless @ignored_items.includes_item?(item) and !@items.includes_item?(item)
                    @new_items << item
                    @out_of_limits_items << item
                  end
                end

                break if @cancel_thread
                Qt.execute_in_main_thread(true) do
                  @initialized = true
                  if @ignored_items.empty?
                    statusBar.showMessage(tr(""))
                  else
                    statusBar.showMessage('Warning: Some Telemetry Items are Ignored')
                  end
                end

              end

              begin
                break if @cancel_thread
                type, data = get_limits_event(@queue_id, true)
                break if @cancel_thread
              rescue ThreadError
                break if @cancel_thread
                break if @limits_sleeper.sleep(1)
                next
              end

              break if @cancel_thread

              case type
              when :LIMITS_CHANGE
                item = [data[0], data[1], data[2]]
                if data[4] != :GREEN and data[4] != :GREEN_HIGH and data[4] != :GREEN_LOW and data[4] != :BLUE and data[4] != nil
                  case data[4]
                  when :YELLOW, :YELLOW_HIGH, :YELLOW_LOW
                    to_print = Time.now.formatted << '  ' << "WARN: #{data[0]} #{data[1]} #{data[2]} = #{tlm(data[0], data[1], data[2])} is #{data[4]}\n"
                    update_log(to_print, 1)
                  when :RED, :RED_HIGH, :RED_LOW
                    to_print = Time.now.formatted << '  ' << "ERROR: #{data[0]} #{data[1]} #{data[2]} = #{tlm(data[0], data[1], data[2])} is #{data[4]}\n"
                    update_log(to_print, 2)
                  end

                  # Limits changed to non-green
                  unless @out_of_limits_items.includes_item?(item) or @ignored_items.includes_item?(item)
                    @out_of_limits_items << item
                    @new_items << item
                    handle_new_items()
                  end
                elsif data[4] == :GREEN or data[4] == :GREEN_HIGH or data[4] == :GREEN_LOW or data[4] == :BLUE
                  to_print = Time.now.formatted << '  ' << "INFO: #{data[0]} #{data[1]} #{data[2]} = #{tlm(data[0], data[1], data[2])} returned to GREEN\n"

                  if data[4] == :BLUE
                    update_log(to_print, 3)
                  else
                    update_log(to_print, 0)
                  end
                end

              when :LIMITS_SET
                if @limits_set != data
                  break if @cancel_thread
                  Qt.execute_in_main_thread(true) do
                    statusBar.showMessage('Limits Set Changed - Reseting')
                    @initialized = false
                    to_print = Time.now.formatted << '  ' << "INFO: Limits Set Changed to: #{data}\n"
                    update_log(to_print, 4)
                  end
                  break if @cancel_thread
                end

              when :LIMITS_SETTINGS
                begin
                  System.limits.set(data[0], data[1], data[2], data[6], data[7], data[8], data[9], data[10], data[11], data[3], data[4], data[5])
                  break if @cancel_thread
                  Qt.execute_in_main_thread(true) do
                    statusBar.showMessage('Limits Settings Changed - Reseting')
                    @initialized = false
                    to_print = Time.now.formatted << '  ' << "INFO: Limits Settings Changed: #{data}\n"
                    update_log(to_print, 4)
                  end
                  break if @cancel_thread
                rescue
                  # This can fail if we missed setting the DEFAULT limits set earlier - Oh well
                end

              when :STALE_PACKET
                # A packet has gone stale: target, packet
                item = [data[0], data[1], nil]
                # First check if this packet has limits items and should count
                if get_stale(true).include?([data[0], data[1]])
                  # Now check if we already know about it
                  unless @out_of_limits_items.includes_item?(item) or @ignored_items.includes_item?(item)
                    @out_of_limits_items << item
                    @new_items << item
                    handle_new_items()
                  end
                end

                to_print = Time.now.formatted << '  ' << "INFO: Packet #{data[0]} #{data[1]} is STALE\n"
                update_log(to_print, 4)
              end

            rescue DRb::DRbConnError
              break if @cancel_thread
              @queue_id = nil
              break if @cancel_thread
              Qt.execute_in_main_thread(true) do
                statusBar.showMessage('Error Connecting to Command and Telemetry Server - Reseting')
                @initialized = false
              end
              break if @cancel_thread
              break if @limits_sleeper.sleep(1)
            end
          end # loop
        rescue Exception => error
          Cosmos.handle_fatal_exception(error)
        end
      end
    end

    # Sets up the thread to monitor the limits values and update them when they
    # change, as well as updating the status bar at the top of the front panel.
    def value_thread
      @value_thread = Thread.new do
        begin
          while true
            break if @cancel_thread
            unless @items.empty?
              Qt.execute_in_main_thread(true) do
                begin
                  items = @items.reject {|item| item[2].nil? }
                  # Gather items for  widgets
                  values, limits_states, limits_settings, limits_set = get_tlm_values(items, :WITH_UNITS)
                  index = 0
                  items.each do |target_name, packet_name, item_name|
                    begin
                      System.limits.set(target_name, packet_name, item_name, limits_settings[index][0], limits_settings[index][1], limits_settings[index][2], limits_settings[index][3], limits_settings[index][4], limits_settings[index][5], limits_set) if limits_settings[index]
                    rescue
                      # This can fail if we missed setting the DEFAULT limits set earlier - Oh well
                    end
                    index += 1
                  end

                  # Handle change in limits set
                  if limits_set != @value_limits_set
                    @value_limits_set = limits_set
                    @widgets.each do |widget|
                      widget.limits_set = @value_limits_set
                    end
                  end

                  # Update widgets with values and limits_states
                  @overall_limits_state = :STALE
                  index = 0
                  @widgets.each do |widget|
                    if widget.is_a? LabelWidget
                      next
                    end
                    widget.value = values[index]
                    widget.limits_state = limits_states[index]
                    index += 1
                  end

                  # Update overall limits state
                  modify_overall_limits_state(get_overall_limits_state(@ignored_items))
                  update_overall_limits_state()
                rescue DRb::DRbConnError
                  # Do nothing
                end
              end
            else
              @overall_limits_state = :STALE
              break if @cancel_thread
              Qt.execute_in_main_thread(true) do
                begin
                  modify_overall_limits_state(get_overall_limits_state(@ignored_items))
                rescue DRb::DRbConnError
                  # Do nothing
                end
                update_overall_limits_state()
              end
            end

            # Sleep until next polling period
            break if @value_sleeper.sleep(1)
          end
        rescue Exception => error
          Cosmos.handle_fatal_exception(error)
        end
      end
    end

    # Checks for the current worst limits state.
    #
    # @param limits_state [Symbol] State of the current limit being checked.
    def modify_overall_limits_state(limits_state)
      case @overall_limits_state
      when :STALE
        @overall_limits_state = limits_state
      when :BLUE
        if limits_state != nil and limits_state != :STALE
          @overall_limits_state = limits_state
        end
      when :GREEN, :GREEN_HIGH, :GREEN_LOW
        if limits_state != nil and limits_state != :STALE and limits_state != :BLUE
          @overall_limits_state = limits_state
        end
      when :YELLOW, :YELLOW_HIGH, :YELLOW_LOW
        if limits_state == :RED or limits_state == :RED_HIGH or limits_state == :RED_LOW
          @overall_limits_state = limits_state
        end
      end
    end

    # Changes the limits state on the status bar at the top of the screen.
    def update_overall_limits_state
      text = ''
      case @overall_limits_state
      when :STALE
        palette = Cosmos.getPalette(Cosmos.getColor(0, 0, 0), Cosmos.getColor(255,0,255))
        @monitored_state_text_field.setPalette(palette)
        text = 'Stale'
      when :GREEN, :GREEN_HIGH, :GREEN_LOW
        palette = Cosmos.getPalette(Cosmos.getColor(0, 0, 0), Cosmos.getColor(0,255,0))
        @monitored_state_text_field.setPalette(palette)
        text = 'Green'
      when :YELLOW, :YELLOW_HIGH, :YELLOW_LOW
        palette = Cosmos.getPalette(Cosmos.getColor(0, 0, 0), Cosmos.getColor(255,255,0))
        @monitored_state_text_field.setPalette(palette)
        text = 'Yellow'
      when :RED, :RED_HIGH, :RED_LOW
        palette = Cosmos.getPalette(Cosmos.getColor(0, 0, 0), Cosmos.getColor(255,0,0))
        @monitored_state_text_field.setPalette(palette)
        text = 'Red'
      when :BLUE
        palette = Cosmos.getPalette(Cosmos.getColor(0, 0, 0), Cosmos.getColor(0,0,255))
        @monitored_state_text_field.setPalette(palette)
        text = 'Blue'
      end
      text << ' - Some Items Ignored' unless @ignored_items.empty?
      @monitored_state_text_field.text = text
    end

    def handle_edit_ignored_items
      items = []
      index = 0
      @ignored_items.each do |target_name, packet_name, item_name|
        item = Qt::ListWidgetItem.new("#{target_name} #{packet_name} #{item_name}")
        item.setData(Qt::UserRole, Qt::Variant.new(@ignored_items[index]))
        items << item
        index += 1
      end

      Qt::Dialog.new(self) do |dialog|
        dialog.setWindowTitle('Ignored Telemetry Items')
        list = Qt::ListWidget.new
        # Allow multiple sections
        list.setSelectionMode(Qt::AbstractItemView::ExtendedSelection)
        items.each {|item| list.addItem(item) }

        shortcut = Qt::Shortcut.new(Qt::KeySequence.new(Qt::KeySequence::Delete), list)
        list.connect(shortcut, SIGNAL('activated()')) do
          items = list.selectedItems()
          (0...items.length).each do |index|
            @ignored_items.delete_item(items[index].data(Qt::UserRole).value)
            @initialized = false
          end
          list.remove_selected_items
        end

        ok = Qt::PushButton.new('Ok') do
          connect(SIGNAL('clicked()')) { dialog.done(0) }
        end
        remove = Qt::PushButton.new('Remove Selected') do
          connect(SIGNAL('clicked()')) { shortcut.activated() }
        end
        button_layout = Qt::HBoxLayout.new do
          addWidget(ok)
          addStretch(1)
          addWidget(remove)
        end
        dialog.layout = Qt::VBoxLayout.new do
          addWidget(list)
          addLayout(button_layout)
        end
        dialog.resize(500, 200)
        dialog.exec
        dialog.dispose
      end
    end

    # Slot to handle when the save ignored items menu option is selected.
    def handle_save_ignored_items
      if @ignored_filename
        filename = Qt::FileDialog.getSaveFileName(self, 'Save As...', @ignored_filename, 'Configuration Files (*.txt)')
      else
        filename = Qt::FileDialog.getSaveFileName(self, 'Save As...', File.join(::Cosmos::USERPATH, 'config', 'tools', 'limits_monitor', 'limits_monitor.txt'), 'Configuration Files (*.txt)')
      end
      unless filename.nil? or filename.empty?
        begin
          File.open(filename, "w") do |file|
            @ignored_items.each do |target, pkt_name, item_name|
              file.puts("IGNORE #{target} #{pkt_name} #{item_name}")
            end
          end
          statusBar.showMessage("#{filename} saved")
        rescue => e
          statusBar.showMessage("Error Saving Configuration : #{e.message}")
        end
      end
    end

    # Slot to handle when the load ignored items menu option is selected.
    def handle_open_ignored_items
      if @ignored_filename
        filename = Qt::FileDialog::getOpenFileName(self, "Open Configuration File", @ignored_filename)
      else
        filename = Qt::FileDialog::getOpenFileName(self, "Open Configuration File", File.join(::Cosmos::USERPATH, 'config', 'tools', 'limits_monitor', 'limits_monitor.txt'))
      end
      unless filename.nil? or filename.empty?
        process_config(filename)
      end
    end

    # Handle config file if present.
    #
    # @param filename [String] Filename for the config file if present.
    def process_config(filename)
      @initialized = false
      @ignored_items = []

      begin
        parser = ConfigParser.new
        parser.parse_file(filename) do |keyword, params|
          case keyword
          when 'IGNORE'
            ignore_item([params[0], params[1], params[2]])
          end
        end
        statusBar.showMessage("#{filename} loaded")
      rescue => e
        statusBar.showMessage("Error Loading Configuration : #{e.message}")
      end
    end

    # Update front panel to ignore an item when the corresponding button is pressed.
    #
    # @param item [Array] Array containing the target, packet, and item name of the
    #   item to ignore.
    def ignore_item(item)
      Qt.execute_in_main_thread(true) do
        @ignored_items << item
        delete_index = @items.delete_item(item)
        if delete_index
          hframe_to_dispose = @widget_hframes[delete_index]
          widget_to_dispose = @widgets[delete_index]
          button_to_dispose = @buttons[delete_index]
          @widgets.delete_at(delete_index)
          @buttons.delete_at(delete_index)
          @widget_hframes.delete_at(delete_index)
          @scroll_layout.removeItem(hframe_to_dispose)
          widget_to_dispose.dispose
          button_to_dispose.dispose
          hframe_to_dispose.dispose
          @scroll.repaint
        end
        statusBar.showMessage('Warning: Some Telemetry Items are Ignored')
      end
    end

    # Process any new items that become out of limits.
    def handle_new_items
      @new_widgets = []

      Qt.execute_in_main_thread(true) do
        @new_items.each do |target, pkt_name, item_name|
          # Create widgets for new items
          add_items(target, pkt_name, item_name)
        end
      end

      # Set initial values

      Qt.execute_in_main_thread(true) do
        begin
          items = @new_items.reject {|item| item[2].nil? }
          values, limits_states, limits_settings, limits_set = get_tlm_values(items, :WITH_UNITS)
          index = 0
          items.each do |target_name, packet_name, item_name|
            begin
              System.limits.set(target_name, packet_name, item_name, limits_settings[index][0], limits_settings[index][1], limits_settings[index][2], limits_settings[index][3], limits_settings[index][4], limits_settings[index][5], limits_set) if limits_settings[index]
            rescue
              # This can fail if we missed setting the DEFAULT limits set earlier - Oh well
            end
            index += 1
          end

          index = 0
          @new_widgets.each do |widget|
            limits_state = limits_states[index]
            widget.limits_set = limits_set
            widget.limits_state = limits_state
            widget.value = values[index]
            index += 1
            modify_overall_limits_state(limits_state)
          end

          update_overall_limits_state()

          @new_items.each do |item|
            @items << item
          end
          @new_items = []
        rescue DRb::DRbConnError
          statusBar.showMessage('Error Connecting to Command and Telemetry Server - Reseting')
          @initialized = false
        end
      end
    end

    # Reset front panel and log when the reset menu option is selected.
    def handle_reset
      Qt.execute_in_main_thread(true) do
        @widgets.each {|widget| widget.dispose}
        @buttons.each {|button| button.dispose}
        @widget_hframes.each do |hframe|
          @scroll_layout.removeItem(hframe)
          hframe.dispose
        end
        @scroll.repaint

        @widgets = []
        @new_widgets = []
        @buttons = []
        @widget_hframes = []
        @items = []
        @value_limits_set = :DEFAULT

        @overall_limits_state = :STALE
        update_overall_limits_state()
      end
    end

    # Handle the window closing.
    def closeEvent(event)
      @cancel_thread = true
      @value_sleeper.cancel
      @limits_sleeper.cancel
      shutdown_cmd_tlm()
      Cosmos.kill_thread(self, @limits_thread, 2)
      Cosmos.kill_thread(self, @value_thread, 2)
      super(event)
    end

    # Gracefully kill threads
    def graceful_kill
      Qt::CoreApplication.processEvents()
    end

    # Initialize tool options.
    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.width = 600
          options.height = 500
          options.remember_geometry = false
          options.title = "Limits Monitor"
          options.auto_size = false
          options.config_file = nil
          options.production = false
          options.no_prompt = false
          option_parser.separator "Limits Monitor Specific Options:"
          option_parser.on("-c", "--config FILE", "Use the specified configuration file") do |arg|
            options.config_file = arg
          end
        end

        super(option_parser, options)
      end
    end

  end # class LimitsMonitor

end # module Cosmos
