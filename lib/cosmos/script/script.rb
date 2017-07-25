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
require 'cosmos/script/commands'
require 'cosmos/script/telemetry'
require 'cosmos/script/limits'
require 'cosmos/script/scripting'
require 'cosmos/script/tools'

$cmd_tlm_server = nil
$cmd_tlm_disconnect = false

module Cosmos
  class CheckError < RuntimeError; end
  class StopScript < StandardError; end
  class SkipTestCase < StandardError; end

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
      $cmd_tlm_disconnect = false
      $cmd_tlm_server = nil
      initialize_script_module()
    end

    def initialize_script_module(config_file = CmdTlmServer::DEFAULT_CONFIG_FILE)
      if $cmd_tlm_disconnect
        # Start up a standalone CTS in disconnected mode
        $cmd_tlm_server = CmdTlmServer.new(config_file, false, true)
      else
        # Start a Json connect to the real CTS server
        $cmd_tlm_server = JsonDRbObject.new(System.connect_hosts['CTS_API'], System.ports['CTS_API'])
      end
    end

    def shutdown_cmd_tlm
      $cmd_tlm_server.shutdown if $cmd_tlm_server && !$cmd_tlm_disconnect
    end

    def set_cmd_tlm_disconnect(disconnect = false, config_file = CmdTlmServer::DEFAULT_CONFIG_FILE)
      if disconnect != $cmd_tlm_disconnect
        $cmd_tlm_disconnect = disconnect
        initialize_script_module(config_file)
      end
    end

    def get_cmd_tlm_disconnect
      return $cmd_tlm_disconnect
    end

    def script_disconnect
      $cmd_tlm_server.disconnect if $cmd_tlm_server && !$cmd_tlm_disconnect
    end

  end
end
