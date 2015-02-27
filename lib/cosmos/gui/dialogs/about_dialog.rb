# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  class AboutDialog < Qt::Dialog
    ABOUT_COSMOS = ''
    ABOUT_COSMOS << "COSMOS application icons are courtesy of http://icons8.com.\n"
    ABOUT_COSMOS << "\n"
    ABOUT_COSMOS << "COSMOS utilizes the QtRuby (http://rubyforge.org/projects/korundum) library under "
    ABOUT_COSMOS << "the GNU Lesser General Public License. QtRuby is a Ruby extension module that provides an "
    ABOUT_COSMOS << "interface to the Qt Gui Toolkit (http://qt-project.org) by Digia "
    ABOUT_COSMOS << "under the GNU Lesser General Public License.\n"
    ABOUT_COSMOS << "\n"
    ABOUT_COSMOS << "Ruby Version: ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE} patchlevel #{RUBY_PATCHLEVEL}) [#{RUBY_PLATFORM}]\n"
    ABOUT_COSMOS << "Rubygems Version: #{Gem::VERSION}\n"
    ABOUT_COSMOS << "Qt Version: #{Qt::qVersion}\n"
    ABOUT_COSMOS << "Cosmos::PATH: #{Cosmos::PATH}\n"
    ABOUT_COSMOS << "Cosmos::USERPATH: #{Cosmos::USERPATH}\n"
    ABOUT_COSMOS << "\n"
    ABOUT_COSMOS << "Environment Variables:\n"
    ABOUT_COSMOS << "RUBYLIB: #{ENV['RUBYLIB']}\n"
    ABOUT_COSMOS << "RUBYOPT: #{ENV['RUBYOPT']}\n"
    ABOUT_COSMOS << "GEM_PATH: #{ENV['GEM_PATH']}\n"
    ABOUT_COSMOS << "GEM_HOME: #{ENV['GEM_HOME']}\n"
    ABOUT_COSMOS << "\n"
    ABOUT_COSMOS << "Loaded Gems:\n"
    Gem.loaded_specs.values.map {|x| ABOUT_COSMOS << "#{x.name} #{x.version} #{x.platform}\n"}

    @@pry_dialogs = []

    def initialize (parent, about_string)
      super(parent, Qt::WindowTitleHint | Qt::WindowSystemMenuHint)
      @saved_text = ''
      setWindowTitle('About')

      # Get Word Icon
      filename = File.join(::Cosmos::USERPATH, 'config', 'data', 'cosmos_word.gif')
      filename = File.join(::Cosmos::PATH, 'data', 'cosmos_word.gif') unless File.exist?(filename)
      word_icon = Qt::Label.new
      word_icon.setPixmap(Qt::Pixmap.new(filename))

      copyright = Qt::Label.new("Copyright 2014 - Ball Aerospace & Technologies Corp.")
      authors = Qt::Label.new("Created by Ryan Melton (ryanmelt) and Jason Thomas (jmthomas)")
      ver = Qt::Label.new("Version: " + COSMOS_VERSION)
      user_ver = nil
      user_ver = Qt::Label.new("User Version: " + USER_VERSION) if defined? USER_VERSION and USER_VERSION != 'Unofficial'
      icon_layout = Qt::VBoxLayout.new do
        addWidget(word_icon)
        addWidget(copyright)
        addWidget(authors)
        addWidget(ver)
        addWidget(user_ver) if user_ver
        addStretch
      end

      # Get COSMOS Configurable About Text
      filename = File.join(Cosmos::USERPATH, 'config', 'data', 'about.txt')
      filename = File.join(Cosmos::PATH, 'data', 'about.txt') unless File.exist?(filename)
      configurable_about_text = File.read(filename)
      configurable_about_text.gsub!("\r", '') unless Kernel.is_windows?
      if Kernel.is_windows?
        configurable_about_text += "\n" + "Main Application x:#{parent.x} y:#{parent.y} width:#{parent.frameGeometry.width + 16} height:#{parent.frameGeometry.height + 38}\n\n" +  ABOUT_COSMOS
      else
        configurable_about_text += "\n" + "Main Application x:#{parent.x} y:#{parent.y} width:#{parent.frameGeometry.width} height:#{parent.frameGeometry.height}\n\n" +  ABOUT_COSMOS      end

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
        if scroll_widget.minimumSizeHint.height < 800
          scroll_area.setMinimumHeight(scroll_widget.minimumSizeHint.height + 80)
          scroll_area.setMinimumWidth(scroll_widget.minimumSizeHint.width)
        else
          scroll_area.setMinimumWidth(scroll_widget.minimumSizeHint.width + 20)
        end
        scroll_widget.adjustSize
        addLayout(button_layout)
      end

      setMaximumWidth(600)
      self.raise()
      exec()
      dispose()
    end

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

  end # class AboutDialog

end # module Cosmos
