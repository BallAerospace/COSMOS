# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/script/extract'
require 'cosmos/script/api_shared'

module Cosmos
  module Script
    private
    # Include various methods to extract fields from text
    include Extract

    # Include additional shared functionality
    include ApiShared

    def play_wav_file(wav_filename)
      Cosmos.play_wav_file(wav_filename)
    end

    def status_bar(message)
      script_runner = ObjectSpace.find(ScriptRunner) if defined? ScriptRunner
      script_runner.script_set_status(message) if script_runner
      test_runner = ObjectSpace.find(TestRunner) if defined? TestRunner
      test_runner.script_set_status(message) if test_runner
    end

    def ask_string(question, blank_or_default = false, password = false)
      answer = ''
      default = ''
      if blank_or_default != true && blank_or_default != false
        question << " (default = #{blank_or_default})"
        allow_blank = true
      else
        allow_blank = blank_or_default
      end
      while answer.empty?
        print question + " "
        answer = gets
        answer.chomp!
        break if allow_blank
      end
      answer = default if answer.empty? and !default.empty?
      return answer
    end

    def ask(question, blank_or_default = false, password = false)
      string = ask_string(question, blank_or_default, password)
      value = string.convert_to_value
      return value
    end

    def prompt(string, **options)
      prompt_to_continue(string, options)
    end

    def message_box(string, *buttons, **options)
      prompt_message_box(string, buttons, options)
    end

    def vertical_message_box(string, *buttons, **options)
      prompt_vertical_message_box(string, buttons, options)
    end

    def combo_box(string, *items, **options)
      prompt_combo_box(string, items, options)
    end

    def _file_dialog(message, directory, filter, select_files = true)
      answer = ''
      files = Dir["#{directory}/#{filter}"]
      if select_files
        files.select! {|f| !File.directory? f }
      else
        files.select! {|f| File.directory? f }
      end
      while answer.empty?
        print message + "\n" + files.join("\n") + "\n<Type file name>:"
        answer = gets
        answer.chomp!
      end
      return answer
    end
    def save_file_dialog(directory = Cosmos::USERPATH, message = "Save File", filter = "*")
      _file_dialog(message, directory, filter)
    end
    def open_file_dialog(directory = Cosmos::USERPATH, message = "Open File", filter = "*")
      _file_dialog(message, directory, filter)
    end
    def open_files_dialog(directory = Cosmos::USERPATH, message = "Open File(s)", filter = "*")
      _file_dialog(message, directory, filter)
    end
    def open_directory_dialog(directory = Cosmos::USERPATH, message = "Open Directory")
      _file_dialog(message, directory, "*", false)
    end

    def prompt_for_hazardous(target_name, cmd_name, hazardous_description)
      message = "Warning: Command #{target_name} #{cmd_name} is Hazardous. "
      message << "\n#{hazardous_description}\n" if hazardous_description
      message << "Send? (y,n): "
      print message
      answer = gets.chomp
      if answer.downcase == 'y'
        return true
      else
        return false
      end
    end

    def prompt_for_script_abort
      print "Stop running script? (y,n): "
      answer = gets.chomp
      if answer.downcase == 'y'
        exit
      else
        return false # Not aborted - Retry
      end
    end

    def prompt_to_continue(string, text_color: nil, background_color: nil, font_size: nil, font_family: nil, details: nil)
      print "#{string}: "
      print "Details: #{details}\n" if details
      gets.chomp
    end

    def prompt_message_box(string, buttons, text_color: nil, background_color: nil, font_size: nil, font_family: nil, details: nil)
      print "#{string} (#{buttons.join(", ")}): "
      print "Details: #{details}\n" if details
      gets.chomp
    end

    def prompt_vertical_message_box(string, buttons, options)
      prompt_message_box(string, buttons, options)
    end

    def prompt_combo_box(string, items, options)
      prompt_message_box(string, items, options)
    end
  end
end
