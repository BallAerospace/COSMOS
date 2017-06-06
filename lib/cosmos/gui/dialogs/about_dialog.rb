# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos
  # Help->About dialog which is part of all COSMOS tools. Displays information
  # about licenses, software versions, and environment variables. This dialog
  # also creates a {PryDialog} when the letters 'p', 'r', 'y' are typed. See
  # {PryDialog} for more details.
  class AboutDialog < Qt::Dialog
    # About text to display in the dialog
    ABOUT_COSMOS = "COSMOS application icons are courtesy of http://icons8.com.\n"\
      "COSMOS application sounds are courtesy of http://www.freesfx.co.uk.\n"\
      "\n"\
      "COSMOS utilizes the QtRuby (http://rubyforge.org/projects/korundum) "\
        "library under the GNU Lesser General Public License. "\
        "QtRuby is a Ruby extension module that provides an "\
        "interface to the Qt Gui Toolkit (http://qt-project.org) by Digia "\
        "under the GNU Lesser General Public License.\n"\
      "\n"\
      "Ruby Version: ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE} "\
        "patchlevel #{RUBY_PATCHLEVEL}) [#{RUBY_PLATFORM}]\n"\
      "Rubygems Version: #{Gem::VERSION}\n"\
      "Qt Version: #{Qt::qVersion}\n"\
      "Cosmos::PATH: #{Cosmos::PATH}\n"\
      "Cosmos::USERPATH: #{Cosmos::USERPATH}\n"\
      "\n"\
      "Environment Variables:\n"\
      "RUBYLIB: #{ENV['RUBYLIB']}\n"\
      "RUBYOPT: #{ENV['RUBYOPT']}\n"\
      "GEM_PATH: #{ENV['GEM_PATH']}\n"\
      "GEM_HOME: #{ENV['GEM_HOME']}\n"\
      "\n"\
      "Loaded Gems:\n"
    Gem.loaded_specs.values.map {|x| ABOUT_COSMOS << "#{x.name} #{x.version} #{x.platform}\n"}
    @@pry_dialogs = []

    # @param parent [Qt::Widget] Part of the dialog (the application)
    # @param about_string [String] Application specific informational text
    def initialize(parent, about_string)
      super(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      @saved_text = ''
      setWindowTitle('About')

      filename = File.join(::Cosmos::USERPATH, 'config', 'data', 'cosmos_word.gif')
      filename = File.join(::Cosmos::PATH, 'data', 'cosmos_word.gif') unless File.exist?(filename)
      word_icon = Qt::Label.new
      word_icon.setPixmap(Qt::Pixmap.new(filename))

      copyright = Qt::Label.new("Copyright 2014 - Ball Aerospace & Technologies Corp.")
      copyright.setFont(Cosmos.getFont("Arial", 12))
      authors = Qt::Label.new("Created by Ryan Melton (ryanmelt) and Jason Thomas (jmthomas)")
      authors.setFont(Cosmos.getFont("Arial", 12))

      cosmos_layout = Qt::GridLayout.new
      version = Qt::Label.new("Version: " + COSMOS_VERSION)
      version.setFont(Cosmos.getFont("Arial", 14))
      open_cosmos_code = Qt::PushButton.new("Open COSMOS Gem Code") do
        connect(SIGNAL('clicked()')) { Cosmos.open_file_browser(Cosmos::PATH) }
      end
      cosmos_layout.addWidget(version, 0, 0)
      cosmos_layout.addWidget(open_cosmos_code, 0, 1)

      if USER_VERSION && USER_VERSION != 'Unofficial'
        user_version = Qt::Label.new("Project Version: " + USER_VERSION)
        user_version.setFont(Cosmos.getFont("Arial", 14))
        cosmos_layout.addWidget(user_version, 1, 0)
      end
      open_user_code = Qt::PushButton.new("Open Project Code") do
        connect(SIGNAL('clicked()')) { Cosmos.open_file_browser(Cosmos::USERPATH) }
      end
      cosmos_layout.addWidget(open_user_code, 1, 1)

      icon_layout = Qt::VBoxLayout.new do
        addWidget(word_icon)
        addWidget(copyright)
        addWidget(authors)
        addLayout(cosmos_layout)
        addStretch
      end

      # Get COSMOS Configurable About Text
      filename = File.join(Cosmos::USERPATH, 'config', 'data', 'about.txt')
      filename = File.join(Cosmos::PATH, 'data', 'about.txt') unless File.exist?(filename)
      configurable_about_text = File.read(filename)
      configurable_about_text.gsub!("\r", '') unless Kernel.is_windows?
      if Kernel.is_windows?
        configurable_about_text << "\n" \
          "Main Application x:#{parent.x} y:#{parent.y} width:#{parent.frameGeometry.width + 16} " \
          "height:#{parent.frameGeometry.height + 38}\n\n" + ABOUT_COSMOS
      else
        configurable_about_text << "\n" \
          "Main Application x:#{parent.x} y:#{parent.y} width:#{parent.frameGeometry.width} " \
          "height:#{parent.frameGeometry.height}\n\n" + ABOUT_COSMOS
      end

      # Set the application about text
      about = Qt::Label.new(about_string + "\n\n" + configurable_about_text)
      about.setAlignment(Qt::AlignTop)
      about.setWordWrap(true)

      dialog = self
      ok = Qt::PushButton.new('Ok') do
        connect(SIGNAL('clicked()')) { dialog.done(0) }
      end

      button_layout = Qt::HBoxLayout.new do
        addStretch
        addWidget(ok)
        addStretch
      end

      self.layout = Qt::VBoxLayout.new do
        scroll_area = Qt::ScrollArea.new
        scroll_area.setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff)
        addWidget(scroll_area)
        scroll_widget = Qt::Widget.new
        scroll_area.setWidget(scroll_widget)
        interior_layout = Qt::VBoxLayout.new
        interior_layout.addLayout(icon_layout)
        interior_layout.addWidget(about)
        scroll_widget.setLayout(interior_layout)
        scroll_area.setMinimumWidth(scroll_widget.minimumSizeHint.width + 20)
        scroll_widget.adjustSize
        addLayout(button_layout)
      end

      setMaximumWidth(800)
      ok.setFocus
      self.raise()
      exec()
      dispose()
    end

    # Register key press events to listen for 'p', 'r', 'y' and popup a {PryDialog}
    # @param event [Qt::Event] The keypress event
    def keyPressEvent(event)
      @saved_text << event.text.to_s
      if @saved_text[0] == 'p'
        if @saved_text[1]
          if @saved_text[1] == 'r'
            if @saved_text[2]
              if @saved_text[2] == 'y'
                self.done(0)
                @@pry_dialogs << PryDialog.new(nil, binding)
                return
              end
              @saved_text = ''
            end
          else
            @saved_text = ''
          end
        end
      else
        @saved_text = ''
      end
      super(event)
    end
  end
end
