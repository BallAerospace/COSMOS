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

require 'openc3/models/model'

module OpenC3
  # Stores the status about an interface. This class also implements logic
  # to handle status for a router since the functionality is identical
  # (only difference is the Redis key used).
  class InterfaceStatusModel < EphemeralModel
    INTERFACES_PRIMARY_KEY = 'openc3_interface_status'
    ROUTERS_PRIMARY_KEY = 'openc3_router_status'

    attr_accessor :state
    attr_accessor :clients
    attr_accessor :txsize
    attr_accessor :rxsize
    attr_accessor :txbytes
    attr_accessor :rxbytes
    attr_accessor :txcnt
    attr_accessor :rxcnt

    # NOTE: The following three class methods are used by the ModelController
    # and are reimplemented to enable various Model class methods to work
    def self.get(name:, scope:)
      super("#{scope}__#{_get_key}", name: name)
    end

    def self.names(scope:)
      super("#{scope}__#{_get_key}")
    end

    def self.all(scope:)
      super("#{scope}__#{_get_key}")
    end
    # END NOTE

    # Helper method to return the correct type based on class name
    def self._get_type
      self.name.to_s.split("Model")[0].upcase.split("::")[-1]
    end

    # Helper method to return the correct primary key based on class name
    def self._get_key
      type = _get_type
      case type
      when 'INTERFACESTATUS'
        INTERFACES_PRIMARY_KEY
      when 'ROUTERSTATUS'
        ROUTERS_PRIMARY_KEY
      else
        raise "Unknown type #{type} from class #{self.name}"
      end
    end

    def initialize(
      name:,
      state:,
      clients: 0,
      txsize: 0,
      rxsize: 0,
      txbytes: 0,
      rxbytes: 0,
      txcnt: 0,
      rxcnt: 0,
      updated_at: nil,
      plugin: nil,
      scope:
    )
      if self.class._get_type == 'INTERFACESTATUS'
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
      @txcnt = txcnt
      @rxcnt = rxcnt
    end

    def as_json(*a)
      {
        'name' => @name,
        'state' => @state,
        'clients' => @clients,
        'txsize' => @txsize,
        'rxsize' => @rxsize,
        'txbytes' => @txbytes,
        'rxbytes' => @rxbytes,
        'txcnt' => @txcnt,
        'rxcnt' => @rxcnt,
        'plugin' => @plugin,
        'updated_at' => @updated_at
      }
    end
  end
end
