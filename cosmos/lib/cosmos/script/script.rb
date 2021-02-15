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
require 'cosmos/script/commands'
require 'cosmos/script/limits'

$api_server = nil
$disconnect = false
$cosmos_scope = 'DEFAULT'
$cosmos_token = nil

module Cosmos
  module Script
    private

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
          $api_server.send(method.intern, *args, **kwargs)
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
  end

  # Provides a proxy to the JsonDRbObject which communicates with the API server
  class ServerProxy
    # Create a JsonDRbObject connection to the API server
    def initialize
      @json_drb = JsonDRbObject.new(ENV['COSMOS_DEVEL'] ? '127.0.0.1' : 'cosmos-cmd-tlm-api', 7777)
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
