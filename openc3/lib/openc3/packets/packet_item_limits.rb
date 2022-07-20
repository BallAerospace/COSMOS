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

require 'openc3/packets/limits_response'

module OpenC3
  # Maintains knowledge of limits for a PacketItem
  class PacketItemLimits
    # Array of all limit states
    LIMITS_STATES = [:RED, :RED_HIGH, :RED_LOW, :YELLOW, :YELLOW_HIGH, :YELLOW_LOW, :GREEN, :GREEN_HIGH, :GREEN_LOW, :BLUE, :STALE, nil]
    # Array of all limit states which should be considered in error
    OUT_OF_LIMITS_STATES = [:RED, :RED_HIGH, :RED_LOW, :YELLOW, :YELLOW_HIGH, :YELLOW_LOW]

    # Hash of arrays - Hash key is uppercase symbol designating limits set.
    # :DEFAULT limits set is required if item has limits. nil indicates the
    # item does not have limits. For defined limits, each array in the hash
    # contains [:RED_LOW, :YELLOW_LOW, :YELLOW_HIGH, :RED_HIGH,
    # :GREEN_LOW (optional), GREEN_HIGH (optional)].
    # @return [Hash{Symbol=>Array}] Hash of all the limits defined for this
    #   item. Must include a hash key of :DEFAULT which returns the default
    #   limits.
    attr_reader :values

    # Every item effectively always has "limits" enabled because it can go from
    # :STALE to nil as needed. This flag indicates whether an item with defined
    # limit values can transition from nil to the various other states.
    #
    # @return [Boolean] Whether limits are enabled on this item
    attr_accessor :enabled

    # Current limits state of the item. One of nil, :STALE, :BLUE, :GREEN,
    # :GREEN_HIGH, :GREEN_LOW, :YELLOW, :YELLOW_HIGH, :YELLOW_LOW,
    # :RED, :RED_HIGH, :RED_LOW. Items initialize to :STALE and change states
    # as the item value changes. If the limits are disabled the state changes
    # to nil. If a packet becomes stale the items state changes to :STALE.
    # @return [Symbol, nil] Current limits state of the item
    attr_reader :state

    # @return [LimitsResponse] Response method to be called on limits changes
    attr_reader :response

    # @return [Integer] Number of out of limits samples at which the limits
    #   state will change
    attr_reader :persistence_setting

    # Current persistent count. The count will be reset to zero if the limits
    # state hasn't changed (i.e. remained :GREEN).
    # @return [Integer] Current running persistence count
    attr_reader :persistence_count

    # Create a PacketItemLimits
    def initialize
      @values = nil
      @enabled = false
      @state = :STALE
      @response = nil
      @persistence_setting = 1
      @persistence_count = 0
    end

    def values=(values)
      if values
        raise ArgumentError, "values must be a Hash but is a #{values.class}" unless Hash === values
        raise ArgumentError, "values must be a Hash with a :DEFAULT key" unless values.keys.include?(:DEFAULT)

        @values = values.clone
      else
        @values = nil
      end
    end

    def state=(state)
      raise ArgumentError, "state must be one of #{LIMITS_STATES} but is #{state}" unless LIMITS_STATES.include?(state)

      @state = state
    end

    def response=(response)
      if response
        raise ArgumentError, "response must be a OpenC3::LimitsResponse but is a #{response.class}" unless OpenC3::LimitsResponse === response

        @response = response.clone
      else
        @response = nil
      end
    end

    def persistence_setting=(persistence_setting)
      if 0.class == Integer
        # Ruby version >= 2.4.0
        raise ArgumentError, "persistence_setting must be an Integer but is a #{persistence_setting.class}" unless Integer === persistence_setting
      else
        # Ruby version < 2.4.0
        raise ArgumentError, "persistence_setting must be a Fixnum but is a #{persistence_setting.class}" unless Fixnum === persistence_setting
      end
      @persistence_setting = persistence_setting
    end

    def persistence_count=(persistence_count)
      if 0.class == Integer
        # Ruby version >= 2.4.0
        raise ArgumentError, "persistence_count must be an Integer but is a #{persistence_count.class}" unless Integer === persistence_count
      else
        # Ruby version < 2.4.0
        raise ArgumentError, "persistence_count must be a Fixnum but is a #{persistence_count.class}" unless Fixnum === persistence_count
      end
      @persistence_count = persistence_count
    end

    # Make a light weight clone of this limits
    def clone
      limits = super()
      limits.values = self.values.clone if self.values
      limits.response = self.response.clone if self.response
      limits
    end
    alias dup clone

    def as_json(*a)
      hash = {}
      hash['values'] = self.values
      hash['enabled'] = self.enabled
      hash['state'] = self.state
      if self.response
        hash['response'] = self.response.to_s
      else
        hash['response'] = nil
      end
      hash['persistence_setting'] = self.persistence_setting
      hash['persistence_count'] = self.persistence_count
      hash
    end

    def self.from_json(hash)
      limits = PacketItemLimits.new
      limits.values = hash['values'].transform_keys(&:to_sym) if hash['values']
      limits.enabled = hash['enabled']
      limits.state = hash['state'] ? hash['state'].to_sym : nil
      # Can't recreate a LimitsResponse class
      # limits.response = hash['response']
      limits.persistence_setting = hash['persistence_setting'] if hash['persistence_setting']
      limits.persistence_count = hash['persistence_count'] if hash['persistence_count']
      limits
    end
  end
end
