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
  require 'cosmos/gui/dialogs/progress_dialog'
  require 'cosmos/tools/handbook_creator/handbook_creator_config'
end

module Cosmos
  # Creates command and telemetry handbooks from the COSMOS definitions in
  # both HTML and PDF format.
  class HandbookCreator < QtTool
    def initialize(options)
      super(options) # MUST BE FIRST - All code before super is executed twice in RubyQt Based classes
      Cosmos.load_cosmos_icon("handbook_creator.png")

      initialize_actions()
      initialize_menus()
      initialize_central_widget()
      complete_initialize()

      # Bring up slash screen for long duration tasks after creation
      Splash.execute(self) do |splash|
        ConfigParser.splash = splash
        System.commands
        @config = HandbookCreatorConfig.new(options.config_file)
        ConfigParser.splash = nil
        # Copy the assets to the local outputs directory
        FileUtils.cp_r(File.join(::Cosmos::USERPATH,'config','tools','handbook_creator','assets'), System.paths['HANDBOOKS'])
      end
    end

    def initialize_actions
      super()
      @hide_ignored_action = Qt::Action.new('&Hide Ignored Items', self)
      @hide_ignored_keyseq = Qt::KeySequence.new('Ctrl+H')
      @hide_ignored_action.shortcut  = @hide_ignored_keyseq
      @hide_ignored_action.statusTip = 'Do not include ignored items in command and telemetry handbooks'
      @hide_ignored_action.setCheckable(true)
      @hide_ignored_action.setChecked(false)
    end

    def initialize_menus
      # File Menu
      @file_menu = menuBar.addMenu('&File')
      @file_menu.addAction(@hide_ignored_action)
      @file_menu.addAction(@exit_action)

      # Help Menu
      @about_string = "Handbook Creator creates Command and Telemetry Handbooks"
      initialize_help_menu()
    end

    def create_pdfs(both, hide_ignored)
      success = false
      ProgressDialog.execute(self, 'PDF Creation Progress', 700, 600, true, false, true, true, false) do |progress_dialog|
        begin
          success = @config.create_pdf(hide_ignored, progress_dialog)
          if success
            msg = "\n\n"
            msg << "HTML and " if both
            msg << "PDF Handbooks created successfully"
            progress_dialog.append_text(msg)
          else
            progress_dialog.append_text("\nPDF Handbooks could not be created.\n\nIs wkhtmltopdf in your PATH and are all existing pdfs closed?\n\nUsing version 0.11.0_rc1 of wkhtmltox is recommended which can be found at: http://download.gna.org/wkhtmltopdf/obsolete/\n\nVersion 0.12.x has shown issues with Handbook Creator's default templates.")
          end
        rescue => error
          progress_dialog.append_text("\n\nError processing:\n#{error.formatted}")
        ensure
          progress_dialog.complete
        end
      end
    rescue Exception => err
      Cosmos.handle_critical_exception(err)
    end

    def initialize_central_widget
      # Create the central widget
      @central_widget = Qt::Widget.new
      setCentralWidget(@central_widget)

      @top_layout = Qt::VBoxLayout.new

      @html_button = Qt::PushButton.new(Cosmos.get_icon('html-32.png'), 'Create HTML Handbooks')
      @html_button.setStyleSheet("text-align:left")
      @html_button.connect(SIGNAL('clicked()')) do
        begin
          @config.create_html(@hide_ignored_action.isChecked)
          Qt::MessageBox.information(self, 'Done', 'HTML Handbooks created successfully')
        rescue Exception => err
          Cosmos.handle_critical_exception(err)
        end
      end
      @top_layout.addWidget(@html_button)

      @pdf_button = Qt::PushButton.new(Cosmos.get_icon('pdf-32.png'), 'Create PDF Handbooks')
      @pdf_button.setStyleSheet("text-align:left")
      @pdf_button.connect(SIGNAL('clicked()')) do
        create_pdfs(false, @hide_ignored_action.isChecked)
      end
      @top_layout.addWidget(@pdf_button)

      @html_pdf_button = Qt::PushButton.new('Create HTML and PDF Handbooks')
      @html_pdf_button.setStyleSheet("text-align:left")
      @html_pdf_button.connect(SIGNAL('clicked()')) do
        begin
          @config.create_html(@hide_ignored_action.isChecked)
          create_pdfs(true, @hide_ignored_action.isChecked)
        rescue Exception => err
          Cosmos.handle_critical_exception(err)
        end
      end
      @top_layout.addWidget(@html_pdf_button)

      @open_button = Qt::PushButton.new(Cosmos.get_icon('open_in_browser-32.png'), 'Open in Web Browser')
      @open_button.setStyleSheet("text-align:left")
      @open_button.connect(SIGNAL('clicked()')) do
        begin
          Cosmos.open_in_web_browser(File.join(System.paths['HANDBOOKS'], @config.pages[0].filename))
        rescue Exception => err
          Cosmos.handle_critical_exception(err)
        end
      end
      @top_layout.addWidget(@open_button)

      @central_widget.setLayout(@top_layout)
    end

    # Runs the application
    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.title = "Handbook Creator"
          options.config_file = File.join(Cosmos::USERPATH, 'config', 'tools', 'handbook_creator', 'handbook_creator.txt')
          option_parser.on("-c", "--config FILE", "Use the specified configuration file") do |arg|
            options.config_file = File.join(Cosmos::USERPATH, 'config', 'tools', 'handbook_creator', arg)
          end
        end
        super(option_parser, options)
      end
    end
  end
end
