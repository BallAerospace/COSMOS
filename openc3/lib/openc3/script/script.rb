# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'openc3'
require 'openc3/api/api'
require 'openc3/io/json_drb_object'
require 'openc3/script/api_shared'
require 'openc3/script/calendar'
require 'openc3/script/commands'
require 'openc3/script/limits'
require 'openc3/script/exceptions'
require 'openc3/script/storage'
require 'openc3/utilities/authentication'

$api_server = nil
$disconnect = false
$openc3_scope = ENV['OPENC3_SCOPE'] || 'DEFAULT'
$openc3_in_cluster = false

module OpenC3
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

    # Called when this module is mixed in using "include OpenC3::Script"
    def self.included(base)
      initialize_script()
    end

    def initialize_script
      shutdown_script()
      $disconnect = false
      $api_server = ServerProxy.new
      if $api_server.generate_url =~ /openc3-cmd-tlm-api/
        $openc3_in_cluster = true
      else
        $openc3_in_cluster = false
      end
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

    def _file_dialog(title, message, filter:)
      answer = ''
      path = "./*"
      path += filter if filter
      files = Dir[path]
      files.select! { |f| !File.directory? f }
      while answer.empty?
        print "#{title}\n#{message}\n#{files.join("\n")}\n<Type file name>:"
        answer = gets
        answer.chomp!
      end
      return answer
    end

    def open_file_dialog(title, message = "Open File", filter:)
      _file_dialog(title, message, filter)
    end

    def open_files_dialog(title, message = "Open File(s)", filter:)
      _file_dialog(title, message, filter)
    end

    def prompt_for_hazardous(target_name, cmd_name, hazardous_description)
      loop do
        message = "Warning: Command #{target_name} #{cmd_name} is Hazardous. "
        message << "\n#{hazardous_description}\n" if hazardous_description
        message << "Send? (y): "
        print message
        answer = gets.chomp
        if answer.downcase == 'y'
          return true
        end
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
    # pull openc3-cmd-tlm-api url from environment variables
    def generate_url
      schema = ENV['OPENC3_API_SCHEMA'] || 'http'
      hostname = ENV['OPENC3_API_HOSTNAME'] || (ENV['OPENC3_DEVEL'] ? '127.0.0.1' : 'openc3-cmd-tlm-api')
      port = ENV['OPENC3_API_PORT'] || '2901'
      port = port.to_i
      return "#{schema}://#{hostname}:#{port}"
    end

    # pull openc3-cmd-tlm-api timeout from environment variables
    def generate_timeout
      timeout = ENV['OPENC3_API_TIMEOUT'] || '1.0'
      return timeout.to_f
    end

    # generate the auth object
    def generate_auth
      if ENV['OPENC3_API_USER'].nil?
        return OpenC3Authentication.new()
      else
        return OpenC3KeycloakAuthentication.new(ENV['OPENC3_KEYCLOAK_URL'])
      end
    end

    # Create a JsonDRbObject connection to the API server
    def initialize
      @json_drb = JsonDRbObject.new(
        url: generate_url(),
        timeout: generate_timeout(),
        authentication: generate_auth()
      )
    end

    # Ruby method which captures any method calls on this object. This allows
    # us to proxy the methods to the API server through the JsonDRbObject.
    def method_missing(method_name, *method_params, **kw_params)
      # Must call shutdown and disconnect on the JsonDRbObject itself
      # to avoid it being sent to the API
      case method_name
      when :shutdown
        @json_drb.shutdown
      when :request
        @json_drb.request(*method_params, **kw_params, scope: $openc3_scope)
      else
        if $disconnect
          result = nil
          # If :disconnect is there delete it and return the value
          # If it is not there, delete returns nil
          disconnect = kw_params.delete(:disconnect)
          # The only commands allowed through in disconnect mode are read-only
          # Thus we allow the get, list, tlm and limits_enabled and subscribe methods
          if method_name =~ /get_\w*|list_\w*|^tlm|limits_enabled|subscribe/
            result = @json_drb.method_missing(method_name, *method_params, **kw_params, scope: $openc3_scope)
          end
          # If they overrode the return value using the disconnect keyword then return that
          return disconnect ? disconnect : result
        else
          @json_drb.method_missing(method_name, *method_params, **kw_params, scope: $openc3_scope)
        end
      end
    end
  end
end
