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
      end
    end

    # Create the application menu actions
    def initialize_actions
      super()
      @hide_ignored_action = Qt::Action.new('&Hide Ignored Items', self)
      @hide_ignored_keyseq = Qt::KeySequence.new('Ctrl+H')
      @hide_ignored_action.shortcut  = @hide_ignored_keyseq
      @hide_ignored_action.statusTip = 'Do not include ignored items in command and telemetry handbooks'
      @hide_ignored_action.setCheckable(true)
      @hide_ignored_action.setChecked(false)

      @copy_assets_action = Qt::Action.new('&Copy Assets to Output', self)
      @copy_assets_action.statusTip = 'Copy the default assets to the output directory'
      @copy_assets_action.connect(SIGNAL('triggered()')) { copy_assets(true) }
    end

    # Create the application menus and add the actions to the menu
    def initialize_menus
      @file_menu = menuBar.addMenu('&File')
      @file_menu.addAction(@hide_ignored_action)
      @file_menu.addAction(@copy_assets_action)
      @file_menu.addAction(@exit_action)

      @about_string = "Handbook Creator creates Command and Telemetry Handbooks"
      initialize_help_menu()
    end

    # Create the application with several buttons to create handbooks (HTML & PDF)
    # and open the generated HTML output in a browser.
    def initialize_central_widget
      @central_widget = Qt::Widget.new
      setCentralWidget(@central_widget)

      @top_layout = Qt::VBoxLayout.new

      @html_button = Qt::PushButton.new(Cosmos.get_icon('html-32.png'), 'Create HTML Handbooks')
      @html_button.setStyleSheet("text-align:left")
      @html_button.connect(SIGNAL('clicked()')) do
        begin
          copy_assets()
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
        copy_assets()
        create_pdfs(false, @hide_ignored_action.isChecked)
      end
      @top_layout.addWidget(@pdf_button)

      @html_pdf_button = Qt::PushButton.new('Create HTML and PDF Handbooks')
      @html_pdf_button.setStyleSheet("text-align:left")
      @html_pdf_button.connect(SIGNAL('clicked()')) do
        begin
          copy_assets()
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

    # Copy the assets (css, fonts, images, javascript) from the project config directory
    # into the outputs/handbooks directory. When called as a part of generating the output
    # files this copy will not occur if the assets directory already exists in case it has
    # been modified by the user. This is also called from a menu option which can copy over
    # existing output assets if permitted by the user.
    def copy_assets(menu_request = false)
      source_path = File.join(::Cosmos::USERPATH,'config','tools','handbook_creator','assets')
      output_path = File.join(System.paths['HANDBOOKS'], 'assets')
      if menu_request
        if File.exist?(output_path)
          if Qt::MessageBox.warning(self, "Warning!", "#{output_path} already exists. Overwrite?",
            Qt::MessageBox::Yes | Qt::MessageBox::No) == Qt::MessageBox::No
            return
          else
            FileUtils.cp_r(source_path, System.paths['HANDBOOKS'])
          end
        else
          FileUtils.cp_r(source_path, System.paths['HANDBOOKS'])
        end
      else
        FileUtils.cp_r(source_path, System.paths['HANDBOOKS']) unless File.exist?(output_path)
      end
    end

    # Create the PDFs inside a progress dialog as this action takes a significant amount of time
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

    def self.run(option_parser = nil, options = nil)
      Cosmos.catch_fatal_exception do
        unless option_parser and options
          option_parser, options = create_default_options()
          options.title = "Handbook Creator"
          options.config_file = true # config_file is required
        end
        super(option_parser, options)
      end
    end
  end
end
