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

require 'redis'
require 'json'
require 'connection_pool'

if ENV['COSMOS_REDIS_CLUSTER']
  require 'enterprise-cosmos/utilities/store'
  $enterprise_cosmos = true
else
  $enterprise_cosmos = false
end

module Cosmos
  class Store
    # Variable that holds the singleton instance
    @@instance = nil

    # Mutex used to ensure that only one instance is created
    @@instance_mutex = Mutex.new

    attr_reader :redis_url
    attr_reader :redis_pool

    # Get the singleton instance
    def self.instance(pool_size = 100)
      # Logger.level = Logger::DEBUG
      return @@instance if @@instance

      @@instance_mutex.synchronize do
        @@instance ||= self.new(pool_size)
        return @@instance
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
      @redis_username = ENV['COSMOS_REDIS_USERNAME']
      @redis_key = ENV['COSMOS_REDIS_PASSWORD']
      @redis_url = "redis://#{ENV['COSMOS_REDIS_HOSTNAME']}:#{ENV['COSMOS_REDIS_PORT']}"
      @redis_pool = ConnectionPool.new(size: pool_size) { build_redis() }
      @topic_offsets = {}
    end

    unless $enterprise_cosmos
      def build_redis
        return Redis.new(url: @redis_url, username: @redis_username, password: @redis_key)
      end
    end

    def get_cmd_item(target_name, packet_name, param_name, type: :WITH_UNITS, scope: $cosmos_scope)
      msg_id, msg_hash = read_topic_last("#{scope}__DECOMCMD__{#{target_name}}__#{packet_name}")
      if msg_id
        # TODO: We now have these reserved items directly on command packets
        # Do we still calculate from msg_hash['time'] or use the times directly?
        #
        # if param_name == 'RECEIVED_TIMESECONDS' || param_name == 'PACKET_TIMESECONDS'
        #   Time.from_nsec_from_epoch(msg_hash['time'].to_i).to_f
        # elsif param_name == 'RECEIVED_TIMEFORMATTED' || param_name == 'PACKET_TIMEFORMATTED'
        #   Time.from_nsec_from_epoch(msg_hash['time'].to_i).formatted
        if param_name == 'RECEIVED_COUNT'
          msg_hash['received_count'].to_i
        else
          json = msg_hash['json_data']
          hash = JSON.parse(json)
          # Start from the most complex down to the basic raw value
          value = hash["#{param_name}__U"]
          return value if value && type == :WITH_UNITS

          value = hash["#{param_name}__F"]
          return value if value && (type == :WITH_UNITS || type == :FORMATTED)

          value = hash["#{param_name}__C"]
          return value if value && (type == :WITH_UNITS || type == :FORMATTED || type == :CONVERTED)

          return hash[param_name]
        end
      end
    end

    ###########################################################################
    # Stream APIs
    ###########################################################################

    def self.initialize_streams(topics)
      self.instance.initialize_streams(topics)
    end

    def initialize_streams(topics)
      @redis_pool.with do |redis|
        topics.each do |topic|
          # Create empty stream with maxlen 0
          redis.xadd(topic, { a: 'b' }, maxlen: 0)
        end
      end
    end

    def self.get_oldest_message(topic)
      self.instance.get_oldest_message(topic)
    end

    def get_oldest_message(topic)
      @redis_pool.with do |redis|
        result = redis.xrange(topic, count: 1)
        return result[0]
      end
    end

    def self.get_newest_message(topic)
      self.instance.get_newest_message(topic)
    end

    def get_newest_message(topic)
      @redis_pool.with do |redis|
        result = redis.xrevrange(topic, count: 1)
        return result[0]
      end
    end

    def self.get_last_offset(topic)
      self.instance.get_last_offset(topic)
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

    def self.read_topic_last(topic)
      self.instance.read_topic_last(topic)
    end

    def read_topic_last(topic)
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

    # TODO: Currently unused
    # def decrement_id(id)
    #   time, sequence = id.split('-')
    #   if sequence == '0'
    #     "#{time.to_i - 1}-18446744073709551615"
    #   else
    #     "#{time}-#{sequence.to_i - 1}"
    #   end
    # end

    def self.update_topic_offsets(topics)
      self.instance.update_topic_offsets(topics)
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

    def self.read_topics(topics, offsets = nil, timeout_ms = 1000, &block)
      self.instance.read_topics(topics, offsets, timeout_ms, &block)
    end
    unless $enterprise_cosmos
      def read_topics(topics, offsets = nil, timeout_ms = 1000)
        # Logger.debug "read_topics: #{topics}, #{offsets} pool:#{@redis_pool}"
        @redis_pool.with do |redis|
          offsets = update_topic_offsets(topics) unless offsets
          result = redis.xread(topics, offsets, block: timeout_ms)
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
    #   COSMOS::Store().write_topic('MANGO__TOPIC', {'message' => 'something'})
    # @example With options
    #   COSMOS::Store().write_topic('MANGO__TOPIC', {'message' => 'something'}, id: '0-0', maxlen: 1000, approximate: false)
    #
    # @param topic [String] the stream / topic
    # @param msg_hash [Hash]   one or multiple field-value pairs
    #
    # @option opts [String]  :id          the entry id, default value is `*`, it means auto generation
    # @option opts [Integer] :maxlen      max length of entries
    # @option opts [Boolean] :approximate whether to add `~` modifier of maxlen or not
    #
    # @return [String] the entry id
    def self.write_topic(topic, msg_hash, id = '*', maxlen = nil, approximate = true)
      self.instance.write_topic(topic, msg_hash, id, maxlen, approximate)
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
    #   COSMOS::Store.trim_topic('MANGO__TOPIC', 1000)
    # @example With options
    #   COSMOS::Store.trim_topic('MANGO__TOPIC', 1000, approximate: true, limit: 0)
    #
    # @param topic  [String]  the stream key
    # @param minid  [Integer] max length of entries to trim
    # @param limit  [Boolean] whether to add `~` modifier of maxlen or not
    #
    # @return [Integer] the number of entries actually deleted
    def self.trim_topic(topic, minid, approximate = true, limit: 0)
      self.instance.trim_topic(topic, minid, approximate, limit: limit)
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

    # Execute any Redis command. Args must be an array (e.g. ["KEYS", "*"])
    def self.execute_raw(args)
      self.instance.execute_raw(args)
    end

    # Execute any Redis command. Args must be an array (e.g. ["KEYS", "*"])
    def execute_raw(args)
      synchronize { |client| client.call(args) }
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
