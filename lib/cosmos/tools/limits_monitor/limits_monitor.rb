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
  require 'cosmos/tools/tlm_viewer/widgets/label_widget'
  require 'pathname'
end

# Extend Array to search for and delete telemetry items.
# Telemetry items are Arrays of [target name, packet name, item name].
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

  class LimitsItems
    # @return [Array<String,String,String>] Target name, packet name, item name
    attr_reader :ignored
    # @return [Boolean] Whether the limits items have been fetched from the server
    attr_reader :initialized
    # @return [Boolean] Whether to display an item with a colorblind option
    attr_accessor :colorblind
    # @return [Boolean] Whether to display an item with operational limits while it's
    #   currently green. If false, items are not displayed until they go yellow
    #   or red. If true, items are displayed when transitioning from blue to green.
    attr_accessor :monitor_operational

    UNKNOWN_ARRAY = ['UNKNOWN', 'UNKNOWN', nil]

    # @param new_item_callback [Proc] Method to create a new item in the GUI
    # @param update_item_callback [Proc] Method to update an item in the GUI
    # @param clear_items_callback [Proc] Method to clear all items in the GUI
    def initialize(new_item_callback, update_item_callback, clear_items_callback)
      @new_item_callback = new_item_callback
      @update_item_callback = update_item_callback
      @clear_items_callback = clear_items_callback
      @ignored = []
      @items = {}
      @out_of_limits = []
      @queue_id = nil
      @limits_set = :DEFAULT
      @colorblind = false
      @monitor_operational = true
      request_reset()
    end

    # Request that the limits items be refreshed from the server
    def request_reset
      @initialized = false
    end

    # Ignore an item. Don't display it in the GUI if it goes out of limits
    # and don't have it count towards the overall limit state. Still display
    # its limits transitions in the log.
    #
    # @param item [Array<String,String,String>] Target name, packet name,
    #   item name to ignore
    def ignore(item)
      index = @out_of_limits.delete_item(item)
      @items.delete("#{item[0]} #{item[1]} #{item[2]}") if index
      unless @ignored.includes_item?(item)
        @ignored << item
      end
    end

    # Remove an item from the ignored list to have it be displayed and
    # count towards the overall limits state.
    #
    # @param item [Array<String,String,String> Target name, packet name,
    #   item name to remove from ignored list
    def remove_ignored(item)
      index = @ignored.delete_item(item)
      if index
        # If we deleted a packet we need to recalculate the stale packets
        if item[2].empty?
          get_stale(true).each do |target, packet|
            stale_packet(target, packet)
          end
        # We deleted an item so get all the current out of limit items
        else
          get_out_of_limits().each do |target, packet, item, state|
            limits_change(target, packet, item, state)
          end
        end
      end
    rescue DRb::DRbConnError
      # Do nothing
    end

    # @return [Boolean] Whether there are any items being ignored
    def ignored_items?
      !@ignored.empty?
    end

    # @return [Symbol] The overall limits state. Returns :STALE if there
    #   is no connection to the server.
    def overall_state
      get_overall_limits_state(@ignored)
    rescue DRb::DRbConnError
      :STALE
    end

    # Calls get_limits_event to process all the server limits events that
    # were subscribed to. This method should be called continuously until
    # it returns nil which indicates no more events.
    #
    # @return [Array<String,Symbol] String describing the event and a symbol
    #   indicating how the event string should be colored (:BLACK, :BLUE,
    #   :GREEN, :YELLOW, or :RED)
    def process_events
      result = nil
      type = nil
      data = nil
      begin
        reset() unless @initialized
        # Get events non-blocking which is why we rescue ThreadError
        type, data = get_limits_event(@queue_id, true)
      rescue ThreadError
        # Do nothing (nominal exception if there are no events)
      rescue DRb::DRbConnError
        # The server is down so request a reset
        request_reset()
      end
      return result unless type

      case type
      when :LIMITS_CHANGE
        # The most common event: target, packet, item, state
        result = limits_change(data[0], data[1], data[2], data[4])

      when :LIMITS_SET
        # Check if the overall limits set changed. If so we need to reset
        # to incorporate all the new limits.
        if @limits_set != data
          request_reset()
          result = ["INFO: Limits Set Changed to: #{data}\n", :BLACK]
        end

      when :LIMITS_SETTINGS
        # The limits settings for an individual item changed. Set our local tool
        # knowledge of the limits to match the server.
        begin
          System.limits.set(data[0], data[1], data[2], data[6], data[7], data[8], data[9], data[10], data[11], data[3], data[4], data[5])
          result = ["INFO: Limits Settings Changed: #{data}\n", :BLACK]
        rescue
          # This can fail if we missed setting the DEFAULT limits set earlier
        end

      when :STALE_PACKET
        # A packet has gone stale: target, packet
        result = stale_packet(data[0], data[1])
      end
      result
    end

    # Update the values for all the out of limits items being tracked.
    def update_values
      # Reject any out of limits packets as they don't have values
      items = @out_of_limits.reject {|item| item[2].nil? }

      values, limits_states, limits_settings, limits_set = get_tlm_values(items, :WITH_UNITS)
      index = 0
      items.each do |target_name, packet_name, item_name|
        begin
          # Update the limits settings each time we update values
          # to stay in sync with the Server. Responding to :LIMITS_SETTINGS
          # events isn't enough since we don't get those upon startup.
          System.limits.set(target_name, packet_name, item_name,
            limits_settings[index][0], limits_settings[index][1],
            limits_settings[index][2], limits_settings[index][3],
            limits_settings[index][4], limits_settings[index][5],
            limits_set) if limits_settings[index]
        rescue
          # This can fail if we missed setting the DEFAULT limits set earlier
        end
        name = "#{target_name} #{packet_name} #{item_name}"
        @update_item_callback.call(@items[name], values[index], limits_states[index], limits_set)
        index += 1
      end
    rescue DRb::DRbConnError
      # Do nothing
    end

    # Load a new configuration of ignored items and packets and reset
    #
    # @param filename [String] Configuration file base name which will be
    #   expanded to find a file in the config/tools/limits_monitor dir.
    # @return [String] Message indicating success or fail
    def open_config(filename)
      return "" unless filename
      return "Configuration file #{filename} not found!" unless File.exist?(filename)

      @ignored = []
      begin
        parser = ConfigParser.new
        parser.parse_file(filename) do |keyword, params|
          case keyword
          # TODO: Eventually we can deprecate 'IGNORE' in favor
          # of 'IGNORE_ITEM' now that we also have 'IGNORE_PACKET'
          when 'IGNORE', 'IGNORE_ITEM'
            @ignored << ([params[0], params[1], params[2]])
          when 'IGNORE_PACKET'
            @ignored << ([params[0], params[1], nil])
          when 'COLOR_BLIND'
            @colorblind = true
          when 'IGNORE_OPERATIONAL_LIMITS'
            @monitor_operational = false
          end
        end
        result = "#{filename} loaded. "
        result << "Warning: Some items ignored" if ignored_items?
      rescue => e
        result = "Error loading configuration : #{e.message}"
      end
      # Since we may have loaded new ignored items we need to reset
      request_reset()
      result
    end

    # Save the current configuration of ignored items and packets.
    #
    # @param filename [String] Configuration file to save.
    # @return [String] Message indicating success or fail
    def save_config(filename)
      begin
        File.open(filename, "w") do |file|
          if @colorblind
            file.puts("COLOR_BLIND")
          end
          unless @monitor_operational
            file.puts("IGNORE_OPERATIONAL_LIMITS")
          end
          @ignored.each do |target, pkt_name, item_name|
            if item_name
              file.puts("IGNORE_ITEM #{target} #{pkt_name} #{item_name}")
            else
              file.puts("IGNORE_PACKET #{target} #{pkt_name}")
            end
          end
        end
        result = "#{filename} saved"
      rescue => e
        result = "Error saving configuration : #{e.message}"
      end
      result
    end

    private

    # Clear all tracked out of limits items and resubscribe to the server
    # limits events. Clear the GUI and re-create all out of limits items
    # and stale packets.
    #
    # Note this method can raise a DRb::DRbConnError error!
    def reset
      @items = {}
      @out_of_limits = []
      @limits_set = get_limits_set()
      unsubscribe_limits_events(@queue_id) if @queue_id
      @queue_id = subscribe_limits_events(100000)
      @clear_items_callback.call
      get_out_of_limits().each do |target, packet, item, state|
        limits_change(target, packet, item, state)
      end
      get_stale(true).each do |target, packet|
        stale_packet(target, packet)
      end

      @initialized = true
    end

    # Process a limits_change event by recoloring out of limits events
    # and creating a log message.
    def limits_change(target_name, packet_name, item_name, state)
      message = ''
      color = :BLACK
      item = [target_name, packet_name, item_name]

      case state
      when :YELLOW, :YELLOW_HIGH, :YELLOW_LOW
        message << "WARN: "
        color = :YELLOW
        out_of_limit(item)
      when :RED, :RED_HIGH, :RED_LOW
        message << "ERROR: "
        color = :RED
        out_of_limit(item)
      when :GREEN_HIGH, :GREEN_LOW
        message << "INFO: "
        color = :GREEN
        out_of_limit(item) if @monitor_operational
      when :GREEN
        message << "INFO: "
        color = :GREEN
      when :BLUE
        message << "INFO: "
        color = :BLUE
      end
      value = tlm(target_name, packet_name, item_name)
      message << "#{target_name} #{packet_name} #{item_name} = #{value} is #{state}\n"
      [message, color]
    end

    # Record the stale packet and generate a log message
    def stale_packet(target_name, packet_name)
      out_of_limit([target_name, packet_name, nil])
      return ["INFO: Packet #{target_name} #{packet_name} is STALE\n", :BLACK]
    end

    # Record an out of limits item and call the new item callback.
    # Existing out of limits and ignored items are not recorded.
    def out_of_limit(item)
      unless (@out_of_limits.includes_item?(item) || @ignored.includes_item?(item) || UNKNOWN_ARRAY.includes_item?(item))
        @out_of_limits << item
        @items["#{item[0]} #{item[1]} #{item[2]}"] = @new_item_callback.call(*item)
      end
    end
  end

  # The LimitsMonitor application displays all the out of limits items
  # encountered by the COSMOS server. It provides the ability to ignore and
  # restore limits as well as logs all limits events.
  class LimitsMonitor < QtTool
    attr_reader :limits_items

    # LimitsWidget displays either a stale packet using the Label widget
    # or more commonly an out of limits item using the Labelvaluelimitsbar
    # Widget.
    class LimitsWidget < Qt::Widget
      # @return [Widget] The widget which displays the value
      attr_accessor :value

      # @param parent [Qt::Widget] Parent widget (the LimitsMonitor tool)
      # @param target_name [String] Target name
      # @param packet_name [String] Packet name
      # @param item_name [String] Telemetry item name (nil for stale packets)
      def initialize(parent, target_name, packet_name, item_name)
        super(parent)
        @layout = Qt::HBoxLayout.new
        @layout.setSpacing(0)
        @layout.setContentsMargins(0,0,0,0)
        setLayout(@layout)

        item = [target_name, packet_name, item_name]
        if item_name
          @value = LabelvaluelimitsbarWidget.new(@layout, target_name, packet_name, item_name)
	  @value.set_setting('COLORBLIND', [parent.limits_items.colorblind])
          @value.process_settings
        else
          @value = LabelWidget.new(layout, "#{target_name} #{packet_name} is STALE")
        end

        @ignore_button = Qt::PushButton.new('Ignore')
        @ignore_button.connect(SIGNAL('clicked()')) { parent.ignore(self, item) }
        @layout.addWidget(@ignore_button)
      end

      # Update the widget's value, limits_state, and limits_set
      def set_values(value, limits_state, limits_set)
        if LabelvaluelimitsbarWidget === @value
          @value.value = value
          @value.limits_state = limits_state
          @value.limits_set = limits_set
        end
      end

      # Enable or disable Colorblind mode
      def set_colorblind(enabled)
        if LabelvaluelimitsbarWidget === @value
          @value.set_setting('COLORBLIND', [enabled])
          @value.process_settings
        end
      end

      # Dispose of the widget
      def dispose
        @ignore_button.dispose
        @value.dispose
        @layout.dispose
        super()
      end
    end

    # Create the main application GUI. Start the limits thread which responds to
    # asynchronous limits events from the server and the value thread which
    # polls the server at 1Hz for the out of limits items values.
    #
    # @param options [Options] Contains the options for the window.
    def initialize(options)
      super(options)
      Cosmos.load_cosmos_icon("limits_monitor.png")

      @cancel_thread = false
      @limits_sleeper = Sleeper.new
      @value_sleeper = Sleeper.new

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()

      @limits_items = LimitsItems.new(
        method(:new_gui_item), method(:update_gui_item), method(:clear_gui_items))
      result = @limits_items.open_config(options.config_file)
      statusBar.showMessage(tr(result))

      limits_thread()
      value_thread()
    end

    # Initialize all the actions in the application Menu
    def initialize_actions
      super

      @options_action = Qt::Action.new(tr('O&ptions'), self)
      @options_action.statusTip = tr('Open the options dialog')
      @options_action.connect(SIGNAL('triggered()')) { show_options_dialog() }

      @reset_action = Qt::Action.new(tr('&Reset'), self)
      @reset_action_keyseq = Qt::KeySequence.new(tr('Ctrl+R'))
      @reset_action.shortcut = @reset_action_keyseq
      @reset_action.statusTip = tr('Reset connection and clear all items. This does not modify the ignored items.')
      @reset_action.connect(SIGNAL('triggered()')) { @limits_items.request_reset() }

      @open_ignored_action = Qt::Action.new(Cosmos.get_icon('open.png'),
                                            tr('&Open Config'), self)
      @open_ignored_action_keyseq = Qt::KeySequence.new(tr('Ctrl+O'))
      @open_ignored_action.shortcut = @open_ignored_action_keyseq
      @open_ignored_action.statusTip = tr('Open ignored telemetry items configuration file')
      @open_ignored_action.connect(SIGNAL('triggered()')) { open_config_file() }

      @save_ignored_action = Qt::Action.new(Cosmos.get_icon('save.png'),
                                            tr('&Save Config'), self)
      @save_ignored_action_keyseq = Qt::KeySequence.new(tr('Ctrl+S'))
      @save_ignored_action.shortcut = @save_ignored_action_keyseq
      @save_ignored_action.statusTip = tr('Save all ignored telemetry items in a configuration file')
      @save_ignored_action.connect(SIGNAL('triggered()')) { save_config_file() }

      @edit_ignored_action = Qt::Action.new(tr('&Edit Ignored'), self)
      @edit_ignored_action_keyseq = Qt::KeySequence.new(tr('Ctrl+E'))
      @edit_ignored_action.shortcut = @edit_ignored_action_keyseq
      @edit_ignored_action.statusTip = tr('Edit the ignored telemetry items list')
      @edit_ignored_action.connect(SIGNAL('triggered()')) { edit_ignored_items() }
    end

    # Initialize the application menu bar options
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

    # Layout the main GUI tab widget with a view of all the out of limits items
    # in one tab and a log tab showing all limits events.
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
      @layout.addLayout(@monitored_state_frame)

      @scroll = Qt::ScrollArea.new
      @scroll_widget = Qt::Widget.new
      @scroll.setWidget(@scroll_widget)
      @scroll_layout = Qt::VBoxLayout.new(@scroll_widget)
      @scroll_layout.setSizeConstraint(Qt::Layout::SetMinAndMaxSize)
      @layout.addWidget(@scroll)

      @log_output = Qt::PlainTextEdit.new
      @log_output.setReadOnly(true)
      @log_output.setMaximumBlockCount(100)

      @tabbook.addTab(@widget, "Limits")
      @tabbook.addTab(@log_output, "Log")
    end

    def show_options_dialog
      Qt::Dialog.new(self) do |dialog|
        dialog.setWindowTitle('Options')

        colorblind_box = Qt::CheckBox.new('Colorblind Mode Enabled', self)
        colorblind_box.setCheckState(Qt::Checked) if @limits_items.colorblind
        operational_limit_box = Qt::CheckBox.new('Monitor Operational Limits', self)
        operational_limit_box.setCheckState(Qt::Checked) if @limits_items.monitor_operational

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
          addWidget(operational_limit_box)
          addLayout(buttons)
        end

        case dialog.exec
        when Qt::Dialog::Accepted
          if (operational_limit_box.checkState() == Qt::Checked)
            @limits_items.monitor_operational = true
          else
            @limits_items.monitor_operational = false
          end
          if (colorblind_box.checkState() == Qt::Checked)
            @limits_items.colorblind = true
          else
            @limits_items.colorblind = false
          end
          (0...@scroll_layout.count).each do |index|
            @scroll_layout.itemAt(index).widget.set_colorblind(@limits_items.colorblind)
          end
        end
        dialog.dispose
      end
    end

    # @return [String] Fully qualified path to the configuration file
    def default_config_path
      # If the config file has been set then just return it
      return @filename if @filename
      # This is the default path to the configuration files
      File.join(::Cosmos::USERPATH, 'config', 'tools', 'limits_monitor', 'limits_monitor.txt')
    end

    # Opens the configuration file and loads the ignored items
    def open_config_file
      filename = Qt::FileDialog::getOpenFileName(self,
        "Open Configuration File", default_config_path())
      unless filename.nil? || filename.empty?
        result = @limits_items.open_config(filename)
        statusBar.showMessage(tr(result))
      end
    end

    # Saves the ignored items to the configuration file
    def save_config_file
      filename = Qt::FileDialog.getSaveFileName(self,
        'Save As...', default_config_path(), 'Configuration Files (*.txt)')
      unless filename.nil? || filename.empty?
        result = @limits_items.save_config(filename)
        statusBar.showMessage(tr(result))
        @filename = filename
      end
    end

    # Opens a dialog to allow the user to remove ignored items
    def edit_ignored_items
      items = []
      index = 0
      @limits_items.ignored.each do |target_name, packet_name, item_name|
        item = Qt::ListWidgetItem.new("#{target_name} #{packet_name} #{item_name}")
        item.setData(Qt::UserRole, Qt::Variant.new(@limits_items.ignored[index]))
        items << item
        index += 1
      end

      Qt::Dialog.new(self) do |dialog|
        dialog.setWindowTitle('Ignored Telemetry Items')
        list = Qt::ListWidget.new
        list.setFocus()
        # Allow multiple sections
        list.setSelectionMode(Qt::AbstractItemView::ExtendedSelection)
        items.each {|item| list.addItem(item) }

        shortcut = Qt::Shortcut.new(Qt::KeySequence.new(Qt::KeySequence::Delete), list)
        list.connect(shortcut, SIGNAL('activated()')) do
          items = list.selectedItems()
          (0...items.length).each do |index|
            @limits_items.remove_ignored(items[index].data(Qt::UserRole).value)
          end
          list.remove_selected_items
          list.setCurrentRow(0)
        end
        # Preselect the first row (works if list is empty) so the keyboard
        # works instantly without having to click the list
        list.setCurrentRow(0)

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

    # Thread to monitor for broken limits and add them to the log and
    # front panel when found.
    def limits_thread
      result = nil
      color = nil
      @limits_thread = Thread.new do
        while true
          break if @cancel_thread
          Qt.execute_in_main_thread(true) do
            result, color = @limits_items.process_events()
          end
          if result
            update_log(result, color)
          else
            break if @limits_sleeper.sleep(1)
          end
        end
      end
    rescue Exception => error
      Cosmos.handle_fatal_exception(error)
    end

    # Add new out of limit item or stale packet
    #
    # @param target_name [String] Target name of out of limits item.
    # @param packet_name [String] Packet name of out of limits item.
    # @param item_name [String] Item name of out of limits item or nil
    #   if its a stale packet
    # @return [Qt::Widget] The new widget that was created
    def new_gui_item(target_name, packet_name, item_name)
      widget = nil
      Qt.execute_in_main_thread(true) do
        widget = LimitsWidget.new(self, target_name, packet_name, item_name)
        @scroll_layout.addWidget(widget)
      end
      widget
    end

    # Update a widget with new values
    #
    # @param widget [Qt::Widget] The widget to update
    # @param value [Object] Value to update
    # @param limits_state [Symbol] The items limits state, e.g. :GREEN, :RED, etc
    # @param limits_set [Symbol] The current limits set, e.g. :DEFAULT
    def update_gui_item(widget, value, limits_state, limits_set)
      Qt.execute_in_main_thread(true) do
        widget.set_values(value, limits_state, limits_set) if widget
      end
    end

    # Reset the GUI by clearing all items
    def clear_gui_items
      Qt.execute_in_main_thread(true) { @scroll_layout.removeAll }
    end

    # Update front panel to ignore an item when the corresponding button is pressed.
    #
    # @param item [Array<String,String,String] Array containing the target name,
    #   packet name, and item name of the item to ignore.
    def ignore(widget, item)
      @limits_items.ignore(item)
      Qt.execute_in_main_thread(true) do
        @scroll_layout.removeWidget(widget)
        widget.dispose
        @scroll_widget.adjustSize
        statusBar.showMessage('Warning: Some Telemetry Items are Ignored')
      end
    end

    # Update the log panel with limits change information.
    #
    # @param message [String] Text string with information about which item is out of
    #   limits, what its value is, and what limit was broken (red_low, yellow_low, etc.)
    # @param color [Symbol] Color of text to add.
    def update_log(message, color)
      return if @cancel_thread
      Qt.execute_in_main_thread(true) do
        @tf ||= Qt::TextCharFormat.new
        case color
        when :GREEN
          brush = Cosmos.getBrush(Cosmos::GREEN)
        when :YELLOW
          brush = Cosmos.getBrush(Cosmos::YELLOW)
        when :RED
          brush = Cosmos.getBrush(Cosmos::RED)
        when :BLUE
          brush = Cosmos.getBrush(Cosmos::BLUE)
        else # :BLACK
          brush = Cosmos.getBrush(Cosmos::BLACK)
        end
        @tf.setForeground(brush)
        @log_output.setCurrentCharFormat(@tf)
        @log_output.appendPlainText(message.chomp)
      end
    end

    # Thread to request the out of limits values and update them at 1Hz.
    # Also updates the status bar at the top of the front panel indicating
    # the overall limits value of the system.
    def value_thread
      @value_thread = Thread.new do
        while true
          break if @cancel_thread
          Qt.execute_in_main_thread(true) do
            if @limits_items.initialized
              @limits_items.update_values()
              update_overall_limits_state(@limits_items.overall_state())
            else
              # Set the status bar message to expire in 2s since this runs at 1Hz
              statusBar.showMessage('Error Connecting to Command and Telemetry Server', 2000)
            end
          end
          break if @value_sleeper.sleep(1)
        end
      end
    rescue Exception => error
      Cosmos.handle_fatal_exception(error)
    end

    # Changes the limits state on the status bar at the top of the screen.
    def update_overall_limits_state(state)
      Qt.execute_in_main_thread(true) do
        text = ''
        case state
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
        end
        text << ' - Some Items Ignored' if @limits_items.ignored_items?
        @monitored_state_text_field.text = text
      end
    end

    # Handle the window closing
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
