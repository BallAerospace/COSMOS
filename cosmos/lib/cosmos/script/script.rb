# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos'
require 'cosmos/api/api'
require 'cosmos/io/json_drb_object'
require 'cosmos/script/api_shared'
require 'cosmos/script/commands'
require 'cosmos/script/limits'
require 'cosmos/script/exceptions'

$api_server = nil
$disconnect = false
$cosmos_scope = 'DEFAULT'
$cosmos_token = nil

module Cosmos
  module Script
    private
    include ApiShared

    # All methods are private so they can only be called by themselves and not
    # on another object. This is important for the JsonDrbObject class which we
    # use to communicate with the server. JsonDrbObject implements method_missing
    # to forward calls to the remote service. If these methods were not private,
    # they would be included on the $api_server global and would be
    # called directly instead of being forwarded over the JsonDrb connection to
    # the real server.

    # For each of the Api methods determine if they haven't previously been defined by
    # one of the script files. If not define them and proxy to the $api_server.
    Api::WHITELIST.each do |method|
      unless private_instance_methods(false).include?(method.intern)
        define_method(method.intern) do |*args, **kwargs|
          $api_server.method_missing(method.intern, *args, **kwargs)
        end
      end
    end

    # Called when this module is mixed in using "include Cosmos::Script"
    def self.included(base)
      initialize_script()
    end

    def initialize_script
      shutdown_script()
      $disconnect = false
      $api_server = ServerProxy.new
    end

    def shutdown_script
      $api_server.shutdown if $api_server
      $api_server = nil
    end

    def disconnect_script
      $disconnect = true
    end

    def play_wav_file(wav_filename)
      # NOOP
    end

    def status_bar(message)
      # NOOP
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

    def message_box(string, *buttons, **options)
      print "#{string} (#{buttons.join(", ")}): "
      print "Details: #{details}\n" if details
      gets.chomp
    end

    def vertical_message_box(string, *buttons, **options)
      message_box(string, *buttons, **options)
    end

    def combo_box(string, *items, **options)
      message_box(string, *items, **options)
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

    def prompt(string, text_color: nil, background_color: nil, font_size: nil, font_family: nil, details: nil)
      print "#{string}: "
      print "Details: #{details}\n" if details
      gets.chomp
    end
  end

  # Provides a proxy to the JsonDRbObject which communicates with the API server
  class ServerProxy
    # Create a JsonDRbObject connection to the API server
    def initialize
      @json_drb = JsonDRbObject.new(ENV['COSMOS_DEVEL'] ? '127.0.0.1' : 'cosmos-api', 2901)
    end

    # Ruby method which captures any method calls on this object. This allows
    # us to proxy the methods to the API server through the JsonDRbObject.
    def method_missing(method_name, *method_params, **kw_params)
      # Must call shutdown and disconnect on the JsonDRbObject itself
      # to avoid it being sent to the API
      case method_name
      when :shutdown
        @json_drb.shutdown
      else
        @json_drb.method_missing(method_name, *method_params, **kw_params, scope: $cosmos_scope)
      end
    end
  end
end
