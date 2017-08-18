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

    # Get a packet which was previously subscribed to by
    # subscribe_packet_data. This method can block waiting for new packets or
    # not based on the second parameter. It returns a single Cosmos::Packet instance
    # and will return nil when no more packets are buffered (assuming non_block
    # is false).
    # Usage:
    #   get_packet(id, <true or false to block>)
    def get_packet(id, non_block = false)
      packet = nil
      # The get_packet_data in the Script module (defined in telemetry.rb)
      # returns a Ruby time after the packet_name. This is different that the API.
      buffer, target_name, packet_name, time, rx_count = get_packet_data(id, non_block)
      if buffer
        packet = System.telemetry.packet(target_name, packet_name).clone
        packet.buffer = buffer
        packet.received_time = time
        packet.received_count = rx_count
      end
      packet
    end

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

    def prompt(string)
      prompt_to_continue(string)
    end

    def message_box(string, *buttons)
      prompt_message_box(string, buttons)
    end

    def vertical_message_box(string, *buttons)
      prompt_vertical_message_box(string, buttons)
    end

    def combo_box(string, *options)
      prompt_combo_box(string, options)
    end

    def _file_dialog(message, directory, select_files = true)
      answer = ''
      files = Dir["#{directory}/*"]
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
    def save_file_dialog(directory = Cosmos::USERPATH, message = "Save File")
      _file_dialog(message, directory)
    end
    def open_file_dialog(directory = Cosmos::USERPATH, message = "Open File")
      _file_dialog(message, directory)
    end
    def open_files_dialog(directory = Cosmos::USERPATH, message = "Open File(s)")
      _file_dialog(message, directory)
    end
    def open_directory_dialog(directory = Cosmos::USERPATH, message = "Open Directory")
      _file_dialog(message, directory, false)
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

    def prompt_to_continue(string)
      print "#{string}: "
      gets.chomp
    end

    def prompt_message_box(string, buttons)
      print "#{string} (#{buttons.join(", ")}): "
      gets.chomp
    end

    def prompt_vertical_message_box(string, options)
      prompt_message_box(string, options)
    end

    def prompt_combo_box(string, options)
      prompt_message_box(string, options)
    end
  end
end
