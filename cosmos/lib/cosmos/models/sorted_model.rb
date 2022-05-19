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

# https://www.rubydoc.info/gems/redis/Redis/Commands/SortedSets
# https://redis.io/docs/manual/data-types/data-types-tutorial/#sorted-sets

require 'cosmos/topics/calendar_topic'

module Cosmos
  class SortedModel < Model
    class SortedError < StandardError; end
    class SortedInputError < SortedError; end
    class SortedOverlapError < SortedError; end

    SORTED_TYPE = 'sorted'.freeze # To be overriden by base class
    PRIMARY_KEY = '__SORTED'.freeze # To be overriden by base class

    # MUST be overriden by any subclasses
    def self.pk(scope)
      puts "sorted pk:#{scope}#{PRIMARY_KEY}"
      return "#{scope}#{PRIMARY_KEY}"
    end

    # @return [String|nil] String of the saved json or nil if value not found under primary_key
    def self.get(value:, scope:)
      result = Store.zrangebyscore(self.pk(scope), value, value, :limit => [0, 1])
      return JSON.parse(result[0]) unless result.empty?
      nil
    end

    # @return [Array<Hash>] Array up to the limit of the models (as Hash objects) stored under the primary key
    def self.all(scope:, limit: 100)
      result = Store.zrange(self.pk(scope), 0, -1, :limit => [0, limit])
      result.map { |item| JSON.parse(item) }
    end

    # @param start [Integer] Start time to return values (inclusive)
    # @param stop [Integer] Stop time to return values (inclusive)
    # @return [Array|nil] Array up to 100 of this model or empty array
    def self.range(start:, stop:, scope:, limit: 100)
      if start > stop
        raise SortedInputError.new "start: #{start} must be before stop: #{stop}"
      end
      result = Store.zrangebyscore(self.pk(scope), start, stop, :limit => [0, limit])
      result.map { |item| JSON.parse(item) }
    end

    # @return [Integer] count of the members stored under the primary key
    def self.count(scope:)
      Store.zcard(self.pk(scope))
    end

    # Remove member from a sorted set
    # @return [Integer] count of the members removed, 0 if not found
    def self.destroy(scope:, value:)
      Store.zremrangebyscore(self.pk(scope), value, value)
    end

    # Remove members from min to max of the sorted set.
    # @return [Integer] count of the members removed
    def self.range_destroy(scope:, start:, stop:)
      Store.zremrangebyscore(self.pk(scope), start, stop)
    end

    # @param [Integer] value - value used to store data
    # @param [String] scope - Cosmos scope to track event to
    # @param [Anything] kwargs - Any kwargs to store in the JSON
    def initialize(value:, scope:, **kwargs)
      # Name becomes the value in the base class
      super(SortedModel.pk(scope), name: value.to_s, scope: scope, **kwargs)
      @value = value
    end

    # Update the Redis hash at primary_key based on the initial passed value
    # The member is set to the JSON generated via calling as_json
    def create
      if SortedModel.get(value: @value, scope: @scope)
        raise SortedOverlapError.new "no sorted value can overlap, value: #{@value}"
      end
      @updated_at = Time.now.to_nsec_from_epoch
      Store.zadd(@primary_key, @value, JSON.generate(as_json()))
    end

    # @return [Hash] JSON encoding of this model
    def as_json
      { **super(), 'value' => @value }
    end
  end
end
