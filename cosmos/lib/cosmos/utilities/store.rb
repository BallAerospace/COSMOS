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
require 'thread'
require 'connection_pool'

begin
  require 'enterprise-cosmos/utilities/store'
  $enterprise_cosmos = true
rescue LoadError
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
    def self.instance(pool_size = 10)
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
        self.instance.send(message, *args, &block)
      end
      # Delegate all unknown methods to redis through the @redis_pool
      def method_missing(message, *args, &block)
        @redis_pool.with { |redis| redis.send(message, *args, &block) }
      end
    else
      # Delegate all unknown class methods to delegate to the instance
      def self.method_missing(message, *args, **kwargs, &block)
        self.instance.send(message, *args, **kwargs, &block)
      end
      # Delegate all unknown methods to redis through the @redis_pool
      def method_missing(message, *args, **kwargs, &block)
        @redis_pool.with { |redis| redis.send(message, *args, **kwargs, &block) }
      end
    end

    def initialize(pool_size = 10)
      Redis.exists_returns_integer = true      
      @redis_url = ENV['COSMOS_REDIS_URL'] || (ENV['COSMOS_DEVEL'] ? 'redis://127.0.0.1:6379/0' : 'redis://cosmos-redis:6379/0')
      @redis_pool = ConnectionPool.new(size: pool_size) { build_redis() }
      @topic_offsets = {}
    end

    unless $enterprise_cosmos
      def build_redis
        return Redis.new(url: @redis_url)
      end
    end

    unless $enterprise_cosmos
      def get_tlm_values(items, scope: $cosmos_scope)
        values = []
        return values if items.empty?

        @redis_pool.with do |redis|
          promises = []
          redis.pipelined do
            items.each_with_index do |item, index|
              target_name, packet_name, item_name, value_type = item.split('__')
              raise ArgumentError, "items must be formatted as TGT__PKT__ITEM__TYPE" if target_name.nil? || packet_name.nil? || item_name.nil? || value_type.nil?
              promises[index] = tlm_variable_with_limits_state_gather(redis, target_name, packet_name, item_name, value_type.intern, scope: scope)
            end
          end
          promises.each_with_index do |promise, index|
            value_type = items[index].split('__')[-1]
            result = promise.value
            if result[0]
              if value_type == :FORMATTED or value_type == :WITH_UNITS
                values << [JSON.parse(result[0]).to_s]
              else
                values << [JSON.parse(result[0])]
              end
            elsif result[1]
              if value_type == :FORMATTED or value_type == :WITH_UNITS
                values << [JSON.parse(result[1]).to_s]
              else
                values << [JSON.parse(result[1])]
              end
            elsif result[2]
              values << [JSON.parse(result[2]).to_s]
            elsif result[3]
              values << [JSON.parse(result[3]).to_s]
            else
              raise "Item '#{items[index].split('__')[0..2].join(' ')}' does not exist"
            end
            if result[-1]
              values[-1] << JSON.parse(result[-1]).intern
            else
              values[-1] << nil
            end
          end
        end

        return values
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

    def tlm_variable_with_limits_state_gather(redis, target_name, packet_name, item_name, value_type, scope: $cosmos_scope)
      case value_type
      when :RAW
        secondary_keys = [item_name, "#{item_name}__L"]
      when :CONVERTED
        secondary_keys = ["#{item_name}__C", item_name, "#{item_name}__L"]
      when :FORMATTED
        secondary_keys = ["#{item_name}__F", "#{item_name}__C", item_name, "#{item_name}__L"]
      when :WITH_UNITS
        secondary_keys = ["#{item_name}__U", "#{item_name}__F", "#{item_name}__C", item_name, "#{item_name}__L"]
      else
        raise "Unknown value type #{value_type}"
      end
      redis.hmget("#{scope}__tlm__{#{target_name}__#{packet_name}}", *secondary_keys)
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
      def read_topics(topics, offsets = nil, timeout_ms = 1000, &block)
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

    def self.write_topic(topic, msg_hash, id = nil, maxlen = 1000, approximate = true)
      self.instance.write_topic(topic, msg_hash, id, maxlen, approximate)
    end
    def write_topic(topic, msg_hash, id = nil, maxlen = 1000, approximate = true)
      # Logger.debug "write_topic topic:#{topic} id:#{id} hash:#{msg_hash}"
      @redis_pool.with do |redis|
        if id
          return redis.xadd(topic, msg_hash, id: id, approximate: approximate)
        else
          return redis.xadd(topic, msg_hash, approximate: approximate)
        end
      end
    end

    def self.trim_topic(topic, minid, approximate = true, limit: 0)
      self.instance.trim_topic(topic, minid, approximate, limit: limit)
    end
    def trim_topic(topic, minid, approximate = true, limit: 0)
      @redis_pool.with do |redis|
        return redis.xtrim_minid(topic, minid, approximate: approximate, limit: limit)
      end
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
