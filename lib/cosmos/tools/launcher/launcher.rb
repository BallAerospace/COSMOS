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
  require 'cosmos/tools/launcher/launcher_config'
  require 'cosmos/tools/launcher/launcher_tool'
  require 'cosmos/tools/launcher/launcher_multitool'
  require 'cosmos/gui/dialogs/legal_dialog'
end

module Cosmos
  # Provides a group of buttons which can be configured to launch any of the
  # COSMOS tools as well as any custom applications.
  class Launcher < QtTool
    def initialize(options)
      super(options) # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes

      # Set environment variable of COSMOS_USERPATH so that all launched apps
      # know where to find the configuration
      ENV['COSMOS_USERPATH'] = Cosmos::USERPATH

      Cosmos.load_cosmos_icon("launcher.png")
      layout.setSizeConstraint(Qt::Layout::SetFixedSize)

      @about_string = "Launcher provides a list of applications to launch at the click of a button. "\
        "It can also launch multiple applications and configure their exact placement on the screen."
      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()
    end

    def initialize_menus
      @file_menu = menuBar().addMenu('&File')
      @file_menu.addAction(@exit_action)
      initialize_help_menu()
    end

    def initialize_central_widget
      begin
        config = LauncherConfig.new(@options.config_file)
      rescue => error
        ExceptionDialog.new(self, error, "Error parsing #{@options.config_file}")
      end

      self.window_title = config.title
      central_widget = Qt::Widget.new
      setCentralWidget(central_widget)

      # Create each button or divider
      default_icon_filename = 'COSMOS_64x64.png'
      widgets = []
      config.items.each do |item_type, text, shell_command_or_settings, capture_io, icon_filename, variable_parameters|
        case item_type
        when :TOOL, :MULTITOOL
          if @options.mini
            layout = Qt::HBoxLayout.new
          else
            layout = Qt::VBoxLayout.new
          end
          if icon_filename
            icon = Cosmos.get_icon(icon_filename)
          else
            icon = Cosmos.get_icon(default_icon_filename)
          end
          button = Qt::PushButton.new('')
          button.setIcon(icon)
          size = @options.mini ? 20 : 64
          button.setIconSize(Qt::Size.new(size, size))

          if item_type == :TOOL
            connect(button,
                    SIGNAL('clicked()'),
                    LauncherTool.new(self, text, shell_command_or_settings, capture_io, variable_parameters),
                    SLOT('button_clicked()'))
          else
            connect(button,
                    SIGNAL('clicked()'),
                    LauncherMultitool.new(self, shell_command_or_settings),
                    SLOT('button_clicked()'))
          end
          if Kernel.is_mac?
            size = @options.mini ? 40 : 84
            button.setFixedSize(size, size)
          else
            stylesheet = "padding:4px; text-align:center; " \
              "font-family:#{config.tool_font_settings[0]}; " \
              "font-size:#{config.tool_font_settings[1]}px"
            button.setStyleSheet(stylesheet)
            size = @options.mini ? 30 : 70
            button.setFixedSize(size, size)
          end
          label = Qt::Label.new(text)
          stylesheet = "text-align:center; " \
            "font-family:#{config.tool_font_settings[0]}; " \
            "font-size:#{config.tool_font_settings[1]}px"
          label.setStyleSheet(stylesheet)
          label.setObjectName("ButtonLabel")
          unless @options.mini
            label.wordWrap = true
            label.setFixedWidth(70)
            label.setSizePolicy(Qt::SizePolicy::Fixed, Qt::SizePolicy::Fixed)
            label.setMinimumSize(label.sizeHint)
            label.setAlignment(Qt::AlignHCenter)
          end
          layout.addWidget(button)
          layout.addWidget(label)
          unless @options.mini
            layout.setAlignment(button, Qt::AlignHCenter)
            layout.setAlignment(label, Qt::AlignHCenter)
          end
          widgets << layout

        when :DIVIDER
          divider = Qt::Frame.new
          divider.setObjectName("Divider")
          divider.setFrameStyle(Qt::Frame::HLine | Qt::Frame::Raised)
          divider.setLineWidth(1)
          divider.setMidLineWidth(1)
          widgets << divider

        when :LABEL
          label = Qt::Label.new(text)
          stylesheet = "text-align:center; " \
            "font-family:#{config.label_font_settings[0]}; " \
            "font-size:#{config.label_font_settings[1]}px"
          label.setStyleSheet(stylesheet)
          label.setObjectName("Label")
          widgets << label

        else
          raise "Unhandled item type from LauncherConfig: #{item_type}"
        end
      end

      # Add widgets to layout
      col = 0
      h_layout = nil
      v_layout = Qt::VBoxLayout.new
      central_widget.layout = v_layout
      widgets.each do |widget|
        if widget.is_a?(Qt::BoxLayout)
          unless h_layout
            h_layout = Qt::HBoxLayout.new
            v_layout.addLayout(h_layout)
            col = 0
          end
          widget.setAlignment(Qt::AlignTop | Qt::AlignLeft)
          h_layout.addLayout(widget)
          col += 1
          if col >= config.num_columns
            col = 0
            h_layout = nil
          end
        else
          # Divider or Label
          h_layout.addStretch(0) if h_layout
          v_layout.addWidget(widget)
          h_layout = nil
        end
      end
      h_layout.addStretch(0) if h_layout
    end

    def self.pre_window_new_hook(options)
      # Show legal dialog
      LegalDialog.new
    end

    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.title = 'Launcher'
          options.config_file = true # config_file is required
        end
        option_parser.separator "Launcher Specific Options:"
        option_parser.on("-m", "--mini", "Create mini launcher") do |arg|
          options.mini = true
        end

        super(option_parser, options)
      end
    end
  end
end
