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

module Cosmos
  # Creates a dialog asking to create a new system configuration.
  class SystemConfigDialog < Qt::Dialog
    def initialize(parent)
      super(parent) # MUST BE FIRST
      @parent = parent
      Cosmos.load_cosmos_icon

      self.window_title = 'Create System Configuration'
      layout = Qt::VBoxLayout.new
      self.layout = layout

      description = Qt::Label.new("Creating a new COSMOS system configuration allows you to reuse "\
        "an existing COSMOS configuration but include different targets and/or change configuration details.")
      description.setWordWrap(true)
      layout.addWidget(description)

      select = Qt::Label.new("Select an existing system.txt file to base the new configuration on:")
      select.setWordWrap(true)
      layout.addWidget(select)
      @system_combo = Qt::ComboBox.new
      Dir[File.join(::Cosmos::USERPATH, 'config', 'system', '*.txt')].each do |system|
        @system_combo.addItem(File.basename(system))
      end
      layout.addWidget(@system_combo)
      layout.addSpacing(10)
  
      name_label = Qt::Label.new("Enter a name for the new system configuration that is descriptive "\
        " but relatively short. For example, 'EMI', 'SW Test', etc:")
      name_label.setWordWrap(true)
      layout.addWidget(name_label)
      @system_name = Qt::LineEdit.new
      layout.addWidget(@system_name)
      layout.addSpacing(10)

      info = Qt::Label.new("This action will create a new COSMOS system.txt, "\
        "cmd_tlm_server.txt, launcher.txt, and Windows Batch file appended with the specified name. "\
        "For example, system_emi.txt, system_sw_test.txt, launcher_emi.txt, launcher_sw_test.txt, etc.")
      info.setWordWrap(true)
      layout.addWidget(info)

      ok_button = Qt::PushButton.new('Ok')
      connect(ok_button, SIGNAL('clicked()'), self, SLOT('accept()'))
      cancel_button = Qt::PushButton.new('Cancel')
      connect(cancel_button, SIGNAL('clicked()'), self, SLOT('reject()'))

      hlayout = Qt::HBoxLayout.new
      hlayout.addWidget(ok_button, 0, Qt::AlignLeft)
      hlayout.addWidget(cancel_button, 0, Qt::AlignRight)
      layout.addLayout(hlayout)

      resize(500, 300)

      self.show()
      self.raise()
      if self.exec() == Qt::Dialog::Accepted
        STDOUT.puts "system:#{@system_name.text}"
        build_system_config()
      end
      self.dispose()
    end

    def build_system_config
      new_system = File.join(Cosmos::USERPATH, 'config', 'system', "system_#{@system_name.text.downcase.gsub(' ','_')}.txt")
      if File.exist?(new_system)
        Qt::MessageBox.warning(self, "System config file exists!", "#{new_system} already exists!")
        return
      end
      File.open(new_system, 'w') do |file|
        file.puts File.read(File.join(::Cosmos::USERPATH, 'config', 'system', @system_combo.text))
      end
      @parent.file_open(new_system)
    end
  end
end
