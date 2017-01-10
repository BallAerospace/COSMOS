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
require 'open3'

module Cosmos
  # Creates a dialog displaying the COSMOS copyright information. Also
  # calculates CRC checks across the entire project to determine if any of the
  # COSMOS core files have been modified. This ensures the COSMOS system has
  # not been modified since the last release.
  class LegalDialog < Qt::Dialog
    def initialize
      super() # MUST BE FIRST
      Cosmos.load_cosmos_icon

      self.window_title = 'Legal Agreement'
      layout = Qt::VBoxLayout.new
      self.layout = layout

      legal_image_filename = File.join(::Cosmos::USERPATH, 'config', 'data', 'legal.gif')
      legal_image_filename = File.join(::Cosmos::PATH, 'data', 'legal.gif') unless File.exist?(legal_image_filename)
      pixmap = Qt::Pixmap.new(legal_image_filename)
      label = Qt::Label.new
      label.setPixmap(pixmap)
      label.setFrameStyle(Qt::Frame::Box)
      layout.addWidget(label)

      version = Qt::Label.new("COSMOS Version: " + COSMOS_VERSION)
      version.setFont(Cosmos.getFont("Arial", 14))
      version_layout = Qt::HBoxLayout.new
      version_layout.addWidget(version, 0, Qt::AlignCenter)
      layout.addLayout(version_layout)

      legal_text = ''
      legal_text_filename = File.join(::Cosmos::USERPATH, 'config', 'data', 'legal.txt')
      legal_text_filename = File.join(::Cosmos::PATH, 'data', 'legal.txt') unless File.exist?(legal_text_filename)
      legal_text << File.read(legal_text_filename)
      legal_text.strip!
      legal_text.gsub!("\r", '') unless Kernel.is_windows?

      legal_label = Qt::Label.new(legal_text)
      legal_label.setWordWrap(true)
      legal_label.setFrameStyle(Qt::Frame::Box)
      legal_label.setStyleSheet("QLabel { background-color : white; padding: 5px; }");
      layout.addWidget(legal_label)

      @text_crc = Qt::TextEdit.new
      @text_crc.setMinimumHeight(100)
      @text_crc.setReadOnly(true)
      @text_crc.setFrameStyle(Qt::Frame::Box)
      layout.addWidget(@text_crc)

      project_error_count = check_all_crcs()

      ok_button = Qt::PushButton.new('Ok')
      connect(ok_button, SIGNAL('clicked()'), self, SLOT('accept()'))

      update_crc_button = Qt::PushButton.new('Update Project CRCs')
      update_crc_button.connect(SIGNAL('clicked()')) do
        Cosmos.set_working_dir do
          output, status = Open3.capture2e("rake crc")
          project_error_count = check_all_crcs()
          if status.success?
            Qt::MessageBox.information(self, 'Success', 'Project CRCs updated successfully')
          else
            Qt::MessageBox.critical(self, 'Error', "Project CRCs update failed.\n\n#{output}")
          end
        end
      end

      cancel_button = Qt::PushButton.new('Cancel')
      connect(cancel_button, SIGNAL('clicked()'), self, SLOT('reject()'))

      hlayout = Qt::HBoxLayout.new
      hlayout.addWidget(ok_button, 0, Qt::AlignLeft)
      hlayout.addWidget(update_crc_button, 0, Qt::AlignCenter) if update_crc_button
      hlayout.addWidget(cancel_button, 0, Qt::AlignRight)
      layout.addLayout(hlayout)

      self.show()
      self.raise()
      result = exec()
      dispose()
      exit if result != Qt::Dialog::Accepted
    end

    # Opens all the files listed in <Cosmos::PATH>/data/crc.txt and calculates their CRCs
    # against what is listed in the file to detect any modifications. Also
    # opens all files listed in <Cosmos::USERPATH/config/data/crc.txt to verify
    # the user defined COSMOS configuration files.
    # @return [String] Either a success message or warning about all files
    #   which did not match their expected CRCs.
    def check_all_crcs
      result_text = ''
      missing_text = ''
      core_file_count, core_error_count, _, _ = check_crcs(::Cosmos::PATH, File.join(::Cosmos::PATH,'data','crc.txt'), result_text, missing_text, 'CORE')
      project_file_count = 0
      project_error_count = 0
      official = true
      if File.exist?(File.join(::Cosmos::USERPATH,'config','data','crc.txt'))
        project_file_count, project_error_count, _, official = check_crcs(::Cosmos::USERPATH, File.join(::Cosmos::USERPATH,'config','data','crc.txt'), result_text, missing_text, 'PROJECT')
      end

      final_text = ''
      if core_error_count == 0 and project_error_count == 0
        if missing_text.empty? and official
          @text_crc.setTextColor(Cosmos::GREEN)
        else
          @text_crc.setTextColor(Cosmos::YELLOW)
        end
        result_text = "COSMOS Verified #{core_file_count} Core and #{project_file_count} Project CRCs\n"
        final_text = result_text + missing_text
      else
        @text_crc.setTextColor(Cosmos::YELLOW)
        if core_error_count > 0
          if project_error_count > 0
            final_text = "Warning: #{core_error_count} Core and #{project_error_count} Project CRC checks failed!\n" << result_text << missing_text
          else
            final_text = "Warning: #{core_error_count} Core CRC checks failed!\n" << result_text << missing_text
          end
        else # project_error_count > 0
          final_text = "Warning: #{project_error_count} Project CRC checks failed!\n" << result_text << missing_text
        end
      end
      final_text = "Warning: Project CRC file updated by user\n  Remove USER_MODIFIED from config/data/crc.txt to clear this warning\n" << final_text unless official
      @text_crc.text = final_text

      return project_error_count
    end

    # @param base_path [String] Path to prepend to all the files in crc.txt
    # @param filename [String] Full path to the crc.txt file
    # @param result_text [String] String to append results of CRC checks
    # @param missing_text [String] String to append missing files
    # @param file_type [String] Whether the COSMOS core or project files. Must
    #   be 'CORE' or 'PROJECT'.
    def check_crcs(base_path, filename, result_text, missing_text, file_type)
      file_count = 0
      error_count = 0
      missing_count = 0
      official = true
      crc = Crc32.new(Crc32::DEFAULT_POLY, Crc32::DEFAULT_SEED, true, false)
      File.open(filename, 'r') do |file|
        file.each_line do |line|
          split_line = line.strip.scan(ConfigParser::PARSING_REGEX)
          if split_line[0] == 'USER_MODIFIED'
            official = false
            next
          end
          filename = File.join(base_path, split_line[0].remove_quotes)
          if File.exist?(filename)
            expected_crc = Integer(split_line[1])
            file_data = nil
            File.open(filename, 'rb') do |crc_file|
              file_data = crc_file.read.gsub("\x0D\x0A", "\x0A")
            end
            file_crc = crc.calc(file_data)
            filename = filename.gsub(base_path + '/', '')
            if file_crc != expected_crc
              result_text << "#{file_type} #{filename}\n  CRC Expected: #{sprintf("0x%08X", expected_crc)}, CRC Calculated: #{sprintf("0x%08X", file_crc)}\n"
              error_count += 1
            end
            file_count += 1
          else
            missing_text << "#{file_type} #{filename} is missing\n"
            missing_count += 1
          end
        end
      end
      return file_count, error_count, missing_count, official
    end
  end
end
