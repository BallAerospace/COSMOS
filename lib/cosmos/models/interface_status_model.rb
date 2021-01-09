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

require 'cosmos/models/model'

module Cosmos
  class InterfaceStatusModel < Model
    INTERFACES_PRIMARY_KEY = 'cosmos_interface_status'
    ROUTERS_PRIMARY_KEY = 'cosmos_router_status'

    attr_accessor :state
    attr_accessor :clients
    attr_accessor :txsize
    attr_accessor :rxsize
    attr_accessor :txbytes
    attr_accessor :rxbytes
    attr_accessor :cmdcnt
    attr_accessor :tlmcnt

    def initialize(
      name:,
      state:,
      clients: 0,
      txsize: 0,
      rxsize: 0,
      txbytes: 0,
      rxbytes: 0,
      cmdcnt: 0,
      tlmcnt: 0,
      updated_at: nil,
      plugin: nil,
      scope:)
      interface_or_router = self.class.name.to_s.split("Model")[0].upcase.split("::")[-1]
      if interface_or_router == 'INTERFACESTATUS'
        super("#{scope}__#{INTERFACES_PRIMARY_KEY}", name: name, updated_at: updated_at, plugin: plugin, scope: scope)
      else
        super("#{scope}__#{ROUTERS_PRIMARY_KEY}", name: name, updated_at: updated_at, plugin: plugin, scope: scope)
      end
      @state = state
      @clients = clients
      @txsize = txsize
      @rxsize = rxsize
      @txbytes = txbytes
      @rxbytes = rxbytes
      @cmdcnt = cmdcnt
      @tlmcnt = tlmcnt
    end

    def as_json
      {
        'name' => @name,
        'state' => @state,
        'clients' => @clients,
        'txsize' => @txsize,
        'rxsize' => @rxsize,
        'txbytes' => @txbytes,
        'rxbytes' => @rxbytes,
        'cmdcnt' => @cmdcnt,
        'tlmcnt' => @tlmcnt,
        'plugin' => @plugin,
        'updated_at' => @updated_at
      }
    end

    def self.get(name:, scope:)
      interface_or_router = self.name.to_s.split("Model")[0].upcase.split("::")[-1]
      if interface_or_router == 'INTERFACESTATUS'
        super("#{scope}__#{INTERFACES_PRIMARY_KEY}", name: name)
      else
        super("#{scope}__#{ROUTERS_PRIMARY_KEY}", name: name)
      end
    end

    def self.names(scope:)
      interface_or_router = self.name.to_s.split("Model")[0].upcase.split("::")[-1]
      if interface_or_router == 'INTERFACESTATUS'
        super("#{scope}__#{INTERFACES_PRIMARY_KEY}")
      else
        super("#{scope}__#{ROUTERS_PRIMARY_KEY}")
      end
    end

    def self.all(scope:)
      interface_or_router = self.name.to_s.split("Model")[0].upcase.split("::")[-1]
      if interface_or_router == 'INTERFACESTATUS'
        super("#{scope}__#{INTERFACES_PRIMARY_KEY}")
      else
        super("#{scope}__#{ROUTERS_PRIMARY_KEY}")
      end
    end

  end
end