# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/io/json_drb_object'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server'
require 'cosmos/script/cmd_tlm_server'
require 'cosmos/script/replay'
require 'cosmos/script/commands'
require 'cosmos/script/telemetry'
require 'cosmos/script/limits'
require 'cosmos/script/scripting'
require 'cosmos/script/tools'

$cmd_tlm_server = nil
$disconnect = nil
$cmd_tlm_replay_mode = false
$cosmos_scope = 'DEFAULT'

module Cosmos
  # Provides a proxy to the JsonDRbObject which communicates with the API server
  class ServerProxy
    # Create a JsonDRbObject connected to Replay (if $cmd_tlm_replay_mode) or to the
    # Command and Telemetry Server.
    def initialize
      # Start a JsonDRbObject to connect to the server
      if $cmd_tlm_replay_mode
        @cmd_tlm_server = JsonDRbObject.new(ENV['COSMOS_DEVEL'] ? '127.0.0.1' : 'cosmos-cmd-tlm-api', 7777) # System.connect_hosts['REPLAY_API'], System.ports['REPLAY_API'])
      else
        @cmd_tlm_server = JsonDRbObject.new(ENV['COSMOS_DEVEL'] ? '127.0.0.1' : 'cosmos-cmd-tlm-api', 7777) # System.connect_hosts['CTS_API'], System.ports['CTS_API'])
      end
    end

    # Ruby method which captures any method calls on this object. This allows
    # us to proxy the methods to the API server through the JsonDRbObject.
    def method_missing(method_name, *method_params, **kw_params)
      # Must call shutdown and disconnect on the JsonDRbObject itself
      # to avoid it being sent to the CmdTlmServer
      case method_name
      when :shutdown
        @cmd_tlm_server.shutdown
      when :disconnect
        @cmd_tlm_server.disconnect
      else
        @cmd_tlm_server.method_missing(method_name, *method_params, scope: $cosmos_scope)
      end
    end
  end

  module Script
    # All methods are private so they can only be called by themselves and not
    # on another object. This is important for the JsonDrbObject class which we
    # use to communicate with the server. JsonDrbObject implements method_missing
    # to forward calls to the remote service. If these methods were not private,
    # they would be included on the $cmd_tlm_server global and would be
    # called directly instead of being forwarded over the JsonDrb connection to
    # the real server.
    private

    # Called when this module is mixed in using "include Cosmos::Script"
    def self.included(base)
      $disconnect = nil
      $cmd_tlm_replay_mode = false
      $cmd_tlm_server = nil
      initialize_script_module()
    end

    def initialize_script_module
      shutdown_cmd_tlm()
      $cmd_tlm_server = ServerProxy.new
    end

    def shutdown_cmd_tlm
      $cmd_tlm_server.shutdown if $cmd_tlm_server
    end

    def disconnect_script
      $disconnect = true
      initialize_script_module()
    end

    def set_replay_mode(replay_mode)
      if replay_mode != $cmd_tlm_replay_mode
        $cmd_tlm_replay_mode = replay_mode
        initialize_script_module()
      end
    end

    def get_replay_mode
      $cmd_tlm_replay_mode
    end
  end
end
