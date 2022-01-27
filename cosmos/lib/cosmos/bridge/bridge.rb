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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos'
require 'cosmos/bridge/bridge_config'
require 'cosmos/bridge/bridge_interface_thread'
require 'cosmos/bridge/bridge_router_thread'

module Cosmos
  class Bridge
    def initialize(filename)
      @config = BridgeConfig.new(filename)
      @threads = []

      # Start Interface Threads
      @config.interfaces.each do |interface_name, interface|
        @threads << BridgeInterfaceThread.new(interface)
        @threads[-1].start
      end

      # Start Router Threads
      @config.routers.each do |router_name, router|
        @threads << BridgeRouterThread.new(router)
        @threads[-1].start
      end

      at_exit() do
        shutdown()
      end
    end

    def shutdown
      @threads.each do |thread|
        thread.stop
      end
    end
  end
end
