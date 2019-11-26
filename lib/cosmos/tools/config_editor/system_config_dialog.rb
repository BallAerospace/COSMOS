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
        build_system_config()
      end
      self.dispose()
    end

    def build_system_config
      new_suffix = @system_name.text.downcase.gsub(' ','_')
      existing_system = @system_combo.text
      # Look for system_xxx.txt where we find the 'xxx' as the existing suffix
      if existing = existing_system.scan(/.*?_(.*)\.txt/)[0]
        existing_suffix = existing[0]
      else
        existing_suffix = nil
      end

      # First determine all the new files and make sure they don't already exist
      new_system = File.join(Cosmos::USERPATH, 'config', 'system', "system_#{new_suffix}.txt")
      return if file_exist?(new_system)
      cmd_tlm_server_path = File.join('config', 'tools', 'cmd_tlm_server')
      new_cmd_tlm_server = File.join(Cosmos::USERPATH, cmd_tlm_server_path, "cmd_tlm_server_#{new_suffix}.txt")
      return if file_exist?(new_cmd_tlm_server)
      launcher_path = File.join('config', 'tools', 'launcher')
      new_launcher = File.join(Cosmos::USERPATH, launcher_path, "launcher_#{new_suffix}.txt")
      return if file_exist?(new_launcher)
      new_batch = File.join(Cosmos::USERPATH, "Launcher#{@system_name.text.gsub(' ','')}.bat")
      return if file_exist?(new_batch)

      # Create the new system.txt. We know the existing exists so simply copy it.
      File.open(new_system, 'w') do |file|
        file.puts File.read(File.join(::Cosmos::USERPATH, 'config', 'system', existing_system))
      end

      # Create the new cmd_tlm_server config and update the TITLE
      data = get_config_contents(existing_suffix, cmd_tlm_server_path, 'cmd_tlm_server')
      data.sub!(/\s*TITLE.*/, "TITLE 'COSMOS Command and Telemetry Server - #{@system_name.text} Configuration'")
      File.open(new_cmd_tlm_server, 'w') {|file| file.puts data }

      # Create the new launcher config and update the TITLE and Server LAUNCH commands
      data = get_config_contents(existing_suffix, launcher_path, 'launcher')
      data.sub!(/\s*TITLE.*/, "TITLE 'Launcher - #{@system_name.text} Configuration'")
      data.gsub!(/LAUNCH\s+(\w+)/, "LAUNCH \\1 --system system_#{new_suffix}.txt")
      # Convert all --config to -c to make it easier to replace in the next step
      data.gsub!(/(.*LAUNCH\s+CmdTlmServer.*)(--config)(.*)/, "\\1-c\\3")
      data.gsub!(/(.*LAUNCH\s+CmdTlmServer.*)-c\s+(\w+)(.*)/, "\\1-c cmd_tlm_server_#{new_suffix}\\3")
      File.open(new_launcher, 'w') {|file| file.puts data }
      
      File.open(new_batch, 'w') do |file|
        file.puts "call tools\\Launcher.bat --config launcher_#{new_suffix}.txt --system system_#{new_suffix}.txt"
      end

      @parent.file_open(new_batch)
      @parent.file_open(new_launcher)
      @parent.file_open(new_cmd_tlm_server)
      @parent.file_open(new_system)
      Qt::MessageBox.information(self, "System Config Creation Success",
        "The new system configuration was successfully created.\n\n"\
        "The newly created files have been opened for further customization.")
      end

    def file_exist?(path)
      if File.exist?(path)
        Qt::MessageBox.warning(self, "Config file exists!", "#{path} already exists!")
        return true
      else
        return false
      end
    end

    def get_config_contents(existing_suffix, base_path, file_name)
      contents = ''
      if existing_suffix
        existing_file = File.join(Cosmos::USERPATH, base_path, "#{file_name}_#{existing_suffix}.txt")
        if File.exist?(existing_file)
          contents = File.read(existing_file)
        end
      else
        # Otherwise see if there is a basic one we can copy
        basic_config = File.join(Cosmos::USERPATH, base_path, "#{file_name}.txt")
        if File.exist?(basic_config)
          contents = File.read(basic_config)
        else
          # Otherwise use the install config
          contents = File.read(File.join(Cosmos::PATH, 'install', base_path, "#{file_name}.txt"))
        end
      end
      return contents
    end
  end
end
