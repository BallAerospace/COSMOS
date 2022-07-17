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

require 'redis'
require 'json'
require 'connection_pool'

if ENV['OPENC3_REDIS_CLUSTER']
  require 'openc3-enterprise/utilities/store'
  $openc3_enterprise = true
else
  $openc3_enterprise = false
end

module OpenC3
  class Store
    # Variable that holds the singleton instance
    @instance = nil

    # Mutex used to ensure that only one instance is created
    @@instance_mutex = Mutex.new

    attr_reader :redis_url
    attr_reader :redis_pool

    # Get the singleton instance
    def self.instance(pool_size = 100)
      # Logger.level = Logger::DEBUG
      return @instance if @instance

      @@instance_mutex.synchronize do
        @instance ||= self.new(pool_size)
        return @instance
      end
    end

    if RUBY_VERSION < "3"
      # Delegate all unknown class methods to delegate to the instance
      def self.method_missing(message, *args, &block)
        self.instance.public_send(message, *args, &block)
      end

      # Delegate all unknown methods to redis through the @redis_pool
      def method_missing(message, *args, &block)
        @redis_pool.with { |redis| redis.public_send(message, *args, &block) }
      end
    else
      # Delegate all unknown class methods to delegate to the instance
      def self.method_missing(message, *args, **kwargs, &block)
        self.instance.public_send(message, *args, **kwargs, &block)
      end

      # Delegate all unknown methods to redis through the @redis_pool
      def method_missing(message, *args, **kwargs, &block)
        @redis_pool.with { |redis| redis.public_send(message, *args, **kwargs, &block) }
      end
    end

    def initialize(pool_size = 10)
      Redis.exists_returns_integer = true
      @redis_username = ENV['OPENC3_REDIS_USERNAME']
      @redis_key = ENV['OPENC3_REDIS_PASSWORD']
      @redis_url = "redis://#{ENV['OPENC3_REDIS_HOSTNAME']}:#{ENV['OPENC3_REDIS_PORT']}"
      @redis_pool = ConnectionPool.new(size: pool_size) { build_redis() }
      @topic_offsets = {}
    end

    unless $openc3_enterprise
      def build_redis
        return Redis.new(url: @redis_url, username: @redis_username, password: @redis_key)
      end
    end

    ###########################################################################
    # Stream APIs
    ###########################################################################

    def initialize_streams(topics)
      @redis_pool.with do |redis|
        topics.each do |topic|
          # Create empty stream with maxlen 0
          redis.xadd(topic, { a: 'b' }, maxlen: 0)
        end
      end
    end

    def get_oldest_message(topic)
      @redis_pool.with do |redis|
        result = redis.xrange(topic, count: 1)
        if result and result.length > 0
          return result[0]
        else
          return nil
        end
      end
    end

    def get_newest_message(topic)
      @redis_pool.with do |redis|
        # Default in xrevrange is range end '+', start '-' which means get all
        # elements from higher ID to lower ID and since we're limiting to 1
        # we get the last element. See https://redis.io/commands/xrevrange.
        result = redis.xrevrange(topic, count: 1)
        if result and result.length > 0
          return result[0]
        else
          return nil
        end
      end
    end

    def get_last_offset(topic)
      @redis_pool.with do |redis|
        result = redis.xrevrange(topic, count: 1)
        if result and result[0] and result[0][0]
          result[0][0]
        else
          "0-0"
        end
      end
    end

    def update_topic_offsets(topics)
      offsets = []
      topics.each do |topic|
        # Normally we will just be grabbing the topic offset
        # this allows xread to get everything past this point
        last_id = @topic_offsets[topic]
        if last_id
          offsets << last_id
        else
          # If there is no topic offset this is the first call.
          # Get the last offset ID so we'll start getting everything from now on
          offsets << get_last_offset(topic)
          @topic_offsets[topic] = offsets[-1]
        end
      end
      return offsets
    end

    unless $openc3_enterprise
      def read_topics(topics, offsets = nil, timeout_ms = 1000, count = nil)
        # Logger.debug "read_topics: #{topics}, #{offsets} pool:#{@redis_pool}"
        @redis_pool.with do |redis|
          offsets = update_topic_offsets(topics) unless offsets
          result = redis.xread(topics, offsets, block: timeout_ms, count: count)
          if result and result.length > 0
            result.each do |topic, messages|
              messages.each do |msg_id, msg_hash|
                @topic_offsets[topic] = msg_id
                yield topic, msg_id, msg_hash, redis if block_given?
              end
            end
          end
          # Logger.debug "result:#{result}" if result and result.length > 0
          return result
        end
      end
    end

    # Add new entry to the redis stream.
    # > https://www.rubydoc.info/github/redis/redis-rb/Redis:xadd
    #
    # @example Without options
    #   store.write_topic('MANGO__TOPIC', {'message' => 'something'})
    # @example With options
    #   store.write_topic('MANGO__TOPIC', {'message' => 'something'}, id: '0-0', maxlen: 1000, approximate: true)
    #
    # @param topic [String] the stream / topic
    # @param msg_hash [Hash]   one or multiple field-value pairs
    #
    # @option opts [String]  :id          the entry id, default value is `*`, it means auto generation,
    #   if `nil` id is passed it will be changed to `*`
    # @option opts [Integer] :maxlen      max length of entries, default value is `nil`, it means will grow forever
    # @option opts [Boolean] :approximate whether to add `~` modifier of maxlen or not, default value is `true`
    #
    # @return [String] the entry id
    def write_topic(topic, msg_hash, id = '*', maxlen = nil, approximate = true)
      id = '*' if id.nil?
      # Logger.debug "write_topic topic:#{topic} id:#{id} hash:#{msg_hash}"
      @redis_pool.with do |redis|
        return redis.xadd(topic, msg_hash, id: id, maxlen: maxlen, approximate: approximate)
      end
    end

    # Trims older entries of the redis stream if needed.
    # > https://www.rubydoc.info/github/redis/redis-rb/Redis:xtrim
    #
    # @example Without options
    #   store.trim_topic('MANGO__TOPIC', 1000)
    # @example With options
    #   store.trim_topic('MANGO__TOPIC', 1000, approximate: true, limit: 0)
    #
    # @param topic  [String]  the stream key
    # @param minid  [Integer] mid id length of entries to trim
    # @param limit  [Boolean] whether to add `~` modifier of maxlen or not
    #
    # @return [Integer] the number of entries actually deleted
    def trim_topic(topic, minid, approximate = true, limit: 0)
      @redis_pool.with do |redis|
        return redis.xtrim_minid(topic, minid, approximate: approximate, limit: limit)
      end
    end
  end

  class EphemeralStore < Store
    def initialize(pool_size = 10)
      super(pool_size)
      @redis_url = "redis://#{ENV['OPENC3_REDIS_EPHEMERAL_HOSTNAME']}:#{ENV['OPENC3_REDIS_EPHEMERAL_PORT']}"
      @redis_pool = ConnectionPool.new(size: pool_size) { build_redis() }
    end
  end
end

class Redis
  def xtrim_minid(key, minid, approximate: true, limit: nil)
    args = [:xtrim, key, :MINID, (approximate ? '~' : nil), minid].compact
    args.concat([:LIMIT, limit]) if limit
    synchronize { |client| client.call(args) }
  end
end
