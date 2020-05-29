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
$disconnected_targets = nil
$disconnect_all_targets = false
$cmd_tlm_replay_mode = false

module Cosmos
  # Error raised by the API when a check fails
  class CheckError < RuntimeError; end
  # Error raised when a Script should be stopped
  class StopScript < StandardError; end
  # Error raised when a TestCase should be skipped by TestRunner
  class SkipTestCase < StandardError; end

  # Provides a proxy to both a disconnected CmdTlmServer instance and the real
  # JsonDRbObject which communicates with the real CmdTlmServer. If targets
  # are disconnected their method calls are forwarded to the disconnected
  # CmdTlmServer while all other calls are forwarded through to the real
  # server by the JsonDRbObject.
  class ServerProxy
    # Creates a disconnected CmdTlmServer object if there are any
    # $disconnected_targets defined. Also creates a JsonDRbObject
    # connected to Replay (if $cmd_tlm_replay_mode) or to the
    # Command and Telemetry Server.
    def initialize(config_file)
      if $disconnected_targets
        # Start up a standalone CTS in disconnected mode
        @disconnected = CmdTlmServer.new(config_file, false, true)
      end
      # Start a Json connect to the real server
      if $cmd_tlm_replay_mode
        @cmd_tlm_server = JsonDRbObject.new('127.0.0.1', 7777) # System.connect_hosts['REPLAY_API'], System.ports['REPLAY_API'])
      else
        @cmd_tlm_server = JsonDRbObject.new('127.0.0.1', 7777) # System.connect_hosts['CTS_API'], System.ports['CTS_API'])
      end
    end

    # Ruby method which captures any method calls on this object. This allows
    # us to proxy the methods to either the disconnected CmdTlmServer object
    # or to the real server through the JsonDRbObject.
    def method_missing(method_name, *method_params)
      # Must call shutdown and disconnect on the JsonDrbObject itself
      # to avoid it being sent to the CmdTlmServer
      case method_name
      when :shutdown
        @cmd_tlm_server.shutdown
        @disconnected.stop if @disconnected
      when :disconnect
        @cmd_tlm_server.disconnect
      else
        if $disconnect_all_targets
          return @disconnected.send(method_name, *method_params)
        elsif $disconnected_targets
          name_string = nil
          if method_params[0].is_a?(String)
            name_string = method_params[0]
          elsif method_params[0].is_a?(Array)
            if method_params[0][0].is_a?(Array)
              if method_params[0][0][0].is_a?(String)
                name_string = method_params[0][0][0]
              end
            elsif method_params[0][0].is_a?(String)
              name_string = method_params[0][0]
            end
          end
          if name_string
            target = name_string.split(" ")[0]
            if $disconnected_targets.include?(target)
              return @disconnected.send(method_name, *method_params)
            end
          end
        end
        @cmd_tlm_server.method_missing(method_name, *method_params)
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
      $disconnected_targets = nil
      $disconnect_all_targets = false
      $cmd_tlm_replay_mode = false
      $cmd_tlm_server = nil
      initialize_script_module()
    end

    def initialize_script_module(config_file = CmdTlmServer::DEFAULT_CONFIG_FILE)
      shutdown_cmd_tlm()
      $cmd_tlm_server = ServerProxy.new(config_file)
    end

    def shutdown_cmd_tlm
      $cmd_tlm_server.shutdown if $cmd_tlm_server
    end

    def set_disconnected_targets(targets, all = false, config_file = CmdTlmServer::DEFAULT_CONFIG_FILE)
      $disconnected_targets = targets
      $disconnect_all_targets = all
      initialize_script_module(config_file)
    end

    def get_disconnected_targets
      return $disconnected_targets
    end

    def clear_disconnected_targets
      $disconnected_targets = nil
      $disconnect_all_targets = false
    end

    def script_disconnect
      $cmd_tlm_server.disconnect if $cmd_tlm_server
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
