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
require 'cosmos/gui/qt_tool'
require 'cosmos/gui/utilities/classification_banner'
require 'cosmos/script'
require 'cosmos/tools/tlm_viewer/widgets'
require 'tempfile'

module Cosmos

  class Screen < Qt::MainWindow
    # The list of all open screens so they can be shutdown when
    # close_all_screens is called
    @@open_screens = []

    attr_accessor :full_name, :width, :height, :window, :replay_flag, :original_target_name

    include ClassificationBanner

    class Widgets
      # Flag to indicate all screens should close
      @@closing_all = false

      attr_accessor :named, :item, :non_item, :invalid, :items, :value_types, :polling_period, :mode

      def self.closing_all= (value)
        @@closing_all = value
      end

      def initialize(screen, mode, local_binding = nil)
        @screen = screen
        # The telemetry viewer mode. Must be :REALTIME or basically anything else?
        @mode = mode
        # Local binding to evaluate LOCAL target
        @local_binding = local_binding
        # Hash of only the named widgets identifed by the NAMED_WIDGET keyword
        @named = {}
        # Array of all widgets which take a value
        @item = []
        # Array of all widgets which do NOT take a value
        @non_item = []
        # Array of all the invalid items detected while parsing the config file
        @invalid = []
        # Array of all the items used by the item_widgets
        @items = []
        # Array of all the value types associated with the items
        @value_types = []
        # Latest limits set returned by the value update thread
        @limits_set = :DEFAULT
        # Current limits set which is compared against the one returned by the
        # value update thread
        @current_limits_set = :DEFAULT
        # Whether the value update thread is alive and running
        @alive = true
        # Values returned from the value update thread which are used to
        # update all the item_widgets
        @values = nil
        # Limits states returned from the value update thread which are used to
        # update all the item_widgets
        @limits_states = nil
        # Mutex used to synchronize the value update thread and updating the GUI
        @mutex = Mutex.new
        # Polling period of the value update thread
        @polling_period = nil
        # The value update thread instance
        @value_thread = nil
        # Used to gracefully break out of the value thread
        @value_sleeper = Sleeper.new
      end

      def widgets
        @item + @non_item
      end

      def process_settings
        widgets().each do |widget|
          widget.process_settings
        end
      end

      def add_widget(klass, parameters, widget, widget_name, substitute, original_target_name, force_substitute)
        # Add to item or non_item widgets
        if klass.takes_value? and substitute != 'LOCAL' and parameters[0] != 'LOCAL'
          if substitute and (original_target_name == parameters[0].upcase or force_substitute)
            @items << [substitute, parameters[1], parameters[2]]
          else
            @items << [parameters[0], parameters[1], parameters[2]]
          end
          @value_types << widget.value_type
          @item << widget
        else
          @non_item << widget
        end

        # Add to named widgets if necessary
        @named[widget_name] = widget if widget_name
      end

      def update_limits_set
        if @limits_set != @current_limits_set
          @current_limits_set = @limits_set
          @item.each do |widget|
            widget.limits_set = @current_limits_set
          end
        end
      end

      def start_updates
        @value_thread = Thread.new do
          begin
            while(true)
              break if @@closing_all or !@alive
              time = Time.now.sys

              if !@item.empty?
                begin
                  # Gather item values for value widgets
                  if @mode == :REALTIME
                    values, limits_states, limits_settings, limits_set = get_tlm_values(@items, @value_types)
                    index = 0
                    @items.each do |target_name, packet_name, item_name|
                      begin
                        System.limits.set(target_name, packet_name, item_name, limits_settings[index][0], limits_settings[index][1], limits_settings[index][2], limits_settings[index][3], limits_settings[index][4], limits_settings[index][5], limits_set) if limits_settings[index]
                      rescue
                        # This can fail if we missed setting the DEFAULT limits set earlier - Oh well
                      end
                      index += 1
                    end
                  end
                  @mutex.synchronize do
                    @values = values
                    @limits_states = limits_states
                    @limits_set = limits_set
                  end
                rescue DRb::DRbConnError
                  break if @@closing_all or !@alive
                  break if @value_sleeper.sleep(1)
                  next
                end
              end

              Qt.execute_in_main_thread {update_gui()} if @alive and (@mode == :REALTIME)
              delta = Time.now.sys - time
              break if @@closing_all or !@alive
              if @polling_period - delta > 0
                break if @value_sleeper.sleep(@polling_period - delta)
              else
                break if @value_sleeper.sleep(0.1) # Minimum delay
              end
            end
          rescue Exception => error
            @alive = false
            Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(@screen, error, "Screen - Value Update Thread", false)}
            Thread.exit
          end
        end
      end

      def update_gui
        begin
          if @alive
            if !@item.empty?
              # Handle change in limits set
              update_limits_set()

              # Update widgets with values and limits_states
              @mutex.synchronize do
                (0..(@values.length - 1)).each do |index|
                  @item[index].limits_state = @limits_states[index]
                  @item[index].value = @values[index]
                end
              end
            end

            # Update non_item widgets
            @non_item.each do |widget|
              if widget.class.takes_value?
                # LOCAL value
                eval_binding = @local_binding
                begin
                  eval_binding = ScriptRunnerFrame.instance.script_binding
                  @local_binding = eval_binding
                rescue Exception
                  # Fall back on @local_binding
                end

                begin
                  widget.limits_state = nil
                  widget.value = eval_binding.eval(widget.item_name)
                rescue Exception
                  # Bad local variable or binding no longer valid
                  widget.limits_state = :STALE
                  widget.value = widget.value
                end
              else
                widget.update_widget
              end
            end
          end
        rescue Exception => error
          @alive = false
          Qt.execute_in_main_thread(true) {|| ExceptionDialog.new(@screen, error, "Screen - update_gui", false)}
          Thread.exit
        end
      end

      def shutdown
        @alive = false
        Cosmos.kill_thread(self, @value_thread, 2, 0.1, 2)

        # Shutdown All Widgets
        widgets().each do |widget|
          widget.shutdown()
        end
      end

      def graceful_kill
        @value_sleeper.cancel
      end
    end

    def initialize(full_name, filename_or_screen_def, notify_on_close = nil, mode = :REALTIME, x_pos = nil, y_pos = nil, original_target_name = nil, substitute = nil, force_substitute = false, single_screen = false, local_binding = nil)
      super(nil)
      # The full name of the widget which goes in the title
      @full_name = full_name
      # The method 'notify' will be called on this object if it is given
      @notify_on_close = notify_on_close
      # X position to display the screen
      @x_pos = x_pos
      # Y position to display the screen
      @y_pos = y_pos
      # Original target name where this screen is defined
      @original_target_name = original_target_name.to_s.upcase
      # Substitute target name to use when actually retrieving data
      @substitute = substitute
      # Whether to automatically substitute the target name when requesting
      # telemetry
      @force_substitute = force_substitute
      # Whether this screen was launched as a command line option to be
      # displayed as a stand alone screen and not launched as a part of the
      # regular TlmViewer application
      @single_screen = single_screen
      # Binding for use with LOCAL LOCAL
      @local_binding = local_binding

      # Read the application wide stylesheet if it exists
      app_style = File.join(Cosmos::USERPATH, 'config', 'tools', 'application.css')
      setStyleSheet(File.read(app_style)) if File.exist? app_style

      @replay_flag = nil
      @widgets = Widgets.new(self, mode, @local_binding)
      @window = process(filename_or_screen_def)
      @@open_screens << self if @window

      # Add a banner based on system configuration
      add_classification_banner
    end

    def widgets
      @widgets.widgets
    end

    def named_widgets
      @widgets.named
    end

    def mode
      @widgets.mode
    end

    def process(filename_or_screen_def)
      layout_stack = []
      layout_stack[0] = nil

      top_widget = nil
      current_widget = nil
      global_settings = {}
      global_subsettings = {}

      if File.exist?(filename_or_screen_def) or !filename_or_screen_def.to_s.index("SCREEN")
        tempfile = false
        filename = filename_or_screen_def
      else
        tempfile = Tempfile.new('screen')
        tempfile.write(filename_or_screen_def)
        tempfile.close
        filename = tempfile.path
      end

      begin
        parser = ConfigParser.new("http://cosmosrb.com/docs/screens/")
        parser.instance_variable_set(:@original_target_name, @original_target_name)
        name = @substitute ? @substitute : @original_target_name
        parser.instance_variable_set(:@target_name, name)
        parser.parse_file(filename) do |keyword, parameters|

          if keyword
            case keyword
            when 'SCREEN'
              parser.verify_num_parameters(3, 4, "#{keyword} <Width or AUTO> <Height or AUTO> <Polling Period> <FIXED>")
              @width = parameters[0].to_i
              @height = parameters[1].to_i
              @widgets.polling_period = parameters[2].to_f
              if parameters.length == 4
                @fixed = true
              else
                @fixed = false
              end

              setWindowTitle(@full_name)
              top_widget = Qt::Widget.new()
              setCentralWidget(top_widget)
              frame = Qt::VBoxLayout.new()
              top_widget.setLayout(frame)

              @replay_flag = Qt::Label.new("Replay Mode")
              @replay_flag.setStyleSheet("background:green;color:white;padding:5px;font-weight:bold;")
              frame.addWidget(@replay_flag)
              @replay_flag.hide unless get_replay_mode()

              layout_stack[0] = frame
              Cosmos.load_cosmos_icon if @single_screen
            when 'END'
              parser.verify_num_parameters(0, 0, "#{keyword}")
              current_widget = layout_stack.pop()
              # Call the complete method to allow layout widgets to do things
              # once all their children have been added
              # Need the respond_to? to protect against the top level widget
              # added by the SCREEN code above. It adds a Qt::VBoxLayout
              # to the stack and that class doesn't have a complete method.
              current_widget.complete() if current_widget.respond_to? :complete
            when 'SETTING'
              next unless current_widget
              parser.verify_num_parameters(1, nil, "#{keyword} <Setting Name> <Setting Values... (optional)>")
              if parameters.length > 1
                current_widget.set_setting(parameters[0], parameters[1..-1])
              else
                current_widget.set_setting(parameters[0], [])
              end
            when 'SUBSETTING'
              next unless current_widget
              parser.verify_num_parameters(2, nil, "#{keyword} <Widget Index (0..?)> <Setting Name> <Setting Values... (optional)>")
              if parameters.length > 2
                current_widget.set_subsetting(parameters[0], parameters[1], parameters[2..-1])
              else
                current_widget.set_subsetting(parameters[0], parameters[1], [])
              end
            when 'GLOBAL_SETTING'
              parser.verify_num_parameters(2, nil, "#{keyword} <Widget Type> <Setting Name> <Setting Values... (optional)>")
              klass = Cosmos.require_class(parameters[0].to_s.downcase + '_widget')
              global_settings[klass] ||= []
              global_settings[klass] << parameters[1..-1]
            when 'GLOBAL_SUBSETTING'
              parser.verify_num_parameters(3, nil, "#{keyword} <Widget Type> <Widget Index (0..?)> <Setting Name> <Setting Values... (optional)>")
              klass = Cosmos.require_class(parameters[0].to_s.downcase + '_widget')
              global_subsettings[klass] ||= []
              global_subsettings[klass] << [parameters[1]].concat(parameters[2..-1])
            when 'STAY_ON_TOP'
              setWindowFlags(windowFlags() | Qt::WindowStaysOnTopHint)
            else
              current_widget = process_widget(parser, keyword, parameters, layout_stack, global_settings, global_subsettings)
            end # case keyword
          end # if keyword

        end # parser.parse_file
      rescue Exception => err
        begin
          raise $!, "In file #{filename} at line #{parser.line_number}:\n\n#{$!}", $!.backtrace
        rescue Exception => err
          ExceptionDialog.new(self, err, "Screen #{File.basename(filename)}", false)
        end
        shutdown()
        return nil
      ensure
        tempfile.unlink if tempfile
      end

      unless @widgets.invalid.empty?
        Qt::MessageBox.information(self, "Screen #{@full_name}", "In #{filename}, the following telemetry items could not be created: \n" + @widgets.invalid.join("\n"))
      end

      # Process all settings before we show the screen
      @widgets.process_settings

      if @width > 0 and @height > 0
        resize(@width, @height)
      elsif @width <= 0 and height > 0
        resize(self.width, @height)
      elsif @width > 0 and height <= 0
        resize(@width, self.height)
      end
      if @fixed
        setWindowFlags(windowFlags() | Qt::MSWindowsFixedSizeDialogHint)
        setFixedSize(self.width, self.height)
      end

      if @x_pos or @y_pos
        x = @x_pos || 0
        y = @y_pos || 0
        move(x,y)
      end
      show()

      # Start the update thread now that the screen is displayed
      @widgets.start_updates()

      return self
    end

    def process_widget(parser, keyword, parameters, layout_stack, global_settings, global_subsettings)
      widget_name = nil
      if keyword == 'NAMED_WIDGET'
        parser.verify_num_parameters(2, nil, "#{keyword} <Widget Name> <Widget Type> <Widget Settings... (optional)>")
        widget_name = parameters[0].upcase
        keyword = parameters[1].upcase
        parameters = parameters[2..-1]
      else
        parser.verify_num_parameters(0, nil, "#{keyword} <Widget Settings... (optional)>")
      end

      widget = nil
      klass = Cosmos.require_class(keyword.downcase + '_widget')
      if klass.takes_value?
        parser.verify_num_parameters(3, nil, "#{keyword} <Target Name> <Packet Name> <Item Name> <Widget Settings... (optional)>")
        begin
          if @substitute and (@original_target_name == parameters[0].upcase or @force_substitute)
            if @substitute != 'LOCAL' or parameters[1] != 'LOCAL'
              System.telemetry.packet_and_item(@substitute, parameters[1], parameters[2])
            end
            widget = klass.new(layout_stack[-1], @substitute, *parameters[1..(parameters.length - 1)])
          else
            if parameters[0] != 'LOCAL' or parameters[1] != 'LOCAL'
              System.telemetry.packet_and_item(*parameters[0..2])
            end
            widget = klass.new(layout_stack[-1], *parameters)
          end
        rescue => err
          @widgets.invalid << "#{parser.line_number}: #{parameters.join(" ").strip} due to #{err.message}"
          return nil
        end
      else
        if parameters[0] != nil
          widget = klass.new(layout_stack[-1], *parameters)
        else
          widget = klass.new(layout_stack[-1])
        end
      end

      # Assign screen
      widget.screen = self

      # Assign polling period
      if @widgets.polling_period
        widget.polling_period = @widgets.polling_period
      else
        raise "SCREEN keyword must appear before any widgets"
      end

      # Add to Layout Stack if Necessary
      if klass.layout_manager?
        layout_stack.push(widget)
      end

      # Apply Global Settings
      global_settings.each do |global_klass, settings|
        if widget.class == global_klass
          settings.each do |setting|
            if setting.length > 1
              widget.set_setting(setting[0], setting[1..-1])
            else
              widget.set_setting(setting[0], [])
            end
          end
        end
      end

      # Apply Global Subsettings
      global_subsettings.each do |global_klass, settings|
        if widget.class == global_klass
          settings.each do |setting|
            widget_index = setting[0]
            if setting.length > 2
              widget.set_subsetting(widget_index, setting[1], setting[2..-1])
            else
              widget.set_subsetting(widget_index, setting[1], [])
            end
          end
        end
      end

      @widgets.add_widget(klass, parameters, widget, widget_name, @substitute, @original_target_name, @force_substitute)

      return widget
    end

    def closeEvent(event)
      super(event)
      @@open_screens.delete(self)
      shutdown()
    end

    def shutdown
      # Shutdown Value Gathering Thread
      @widgets.shutdown

      # Notify Owner if Necessary
      @notify_on_close.notify(self) if @notify_on_close

      if @single_screen
        QtTool.restore_io
      end

      self.dispose

      @window = nil
    end

    def get_named_widget(widget_name)
      @widgets.named[widget_name.upcase]
    end

    def get_target_name(target_name)
      if @substitute and (@original_target_name == target_name.upcase or @force_substitute)
        @substitute
      else
        target_name
      end
    end

    def graceful_kill
      @widgets.graceful_kill
    end

    def close
      Qt.execute_in_main_thread(true) do
        if @window
          super()
          @window = nil
        end
      end
    end

    def self.open_screens
      @@open_screens
    end

    def self.close_all_screens(closer)
      Widgets.closing_all = true
      screens = @@open_screens.clone
      screens.each do |screen|
        screen.window.graceful_kill if screen.window
      end
      screens.each do |screen|
        begin
          screen.window.close
        rescue
          # Screen probably already closed - continue
        end
      end
      Widgets.closing_all = false
    end

    def self.update_replay_mode
      screens = @@open_screens.clone
      replay_mode = get_replay_mode()
      screens.each do |screen|
        begin
          if replay_mode
            screen.replay_flag.show if screen.replay_flag
          else
            screen.replay_flag.hide if screen.replay_flag
          end
        rescue
          # Oh well
        end
      end
    end

  end
end
