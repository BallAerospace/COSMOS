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
      # Logger.stdout = true
      return @@instance if @@instance
      @@instance_mutex.synchronize do
        @@instance ||= self.new(pool_size)
        return @@instance
      end
    end

    def build_redis
      return Redis.new(url: @redis_url)
    end

    def initialize(pool_size = 10)
      Redis.exists_returns_integer = true
      @redis_url = ENV['COSMOS_REDIS_URL'] || (ENV['COSMOS_DEVEL'] ? 'redis://127.0.0.1:6379/0' : 'redis://cosmos-redis:6379/0')
      @redis_pool = ConnectionPool.new(size: pool_size) { build_redis() }
      @topic_offsets = {}
      @overrides = {}
    end

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

    def cmd_packet_exist?(target_name, packet_name, scope: $cosmos_scope)
      _packet_exist?(target_name, packet_name, type: 'cmd', scope: scope)
    end
    def tlm_packet_exist?(target_name, packet_name, scope: $cosmos_scope)
      _packet_exist?(target_name, packet_name, type: 'tlm', scope: scope)
    end
    def _packet_exist?(target_name, packet_name, type:, scope: $cosmos_scope)
      @redis_pool.with do |redis|
        # TODO: pipeline
        if redis.exists("#{scope}__cosmos#{type}__#{target_name}") != 0
          if redis.hexists("#{scope}__cosmos#{type}__#{target_name}", packet_name)
            true
          else
            raise "Packet '#{target_name} #{packet_name}' does not exist"
          end
        else
          raise "Target '#{target_name}' does not exist"
        end
      end
    end

    def get_packet(target_name, packet_name, type: 'tlm', scope: $cosmos_scope)
      @redis_pool.with do |redis|
        # TODO: pipeline
        if redis.exists("#{scope}__cosmos#{type}__#{target_name}") != 0
          if redis.hexists("#{scope}__cosmos#{type}__#{target_name}", packet_name)
            return JSON.parse(redis.hget("#{scope}__cosmos#{type}__#{target_name}", packet_name))
          else
            raise "Packet '#{target_name} #{packet_name}' does not exist"
          end
        else
          raise "Target '#{target_name}' does not exist"
        end
      end
    end

    # TODO: Is this needed?
    # def set_packet(packet, type: 'tlm')
    #   @redis_pool.with do |redis|
    #     if redis.exists("cosmos#{type}__#{packet.target_name}") != 0
    #       if redis.hexists("cosmos#{type}__#{packet.target_name}", packet.packet_name)
    #         return redis.hset("cosmos#{type}__#{packet.target_name}", packet.packet_name, JSON.generate(packet.as_json))
    #       else
    #         raise "Packet '#{packet.target_name} #{packet.packet_name}' does not exist"
    #       end
    #     else
    #       raise "Target '#{packet.target_name}' does not exist"
    #     end
    #   end
    # end

    def get_item_from_packet_hash(packet, item_name)
      item = packet['items'].find {|item| item['name'] == item_name.to_s }
      raise "Item '#{packet['target_name']} #{packet['packet_name']} #{item_name}' does not exist" unless item
      item
    end

    def get_item(target_name, packet_name, item_name, type: 'tlm', scope: $cosmos_scope)
      packet = get_packet(target_name, packet_name, type: type, scope: scope)
      get_item_from_packet_hash(packet, item_name)
    end

    def get_commands(target_name, scope: $cosmos_scope)
      _get_cmd_tlm(target_name, type: 'cmd', scope: scope)
    end

    def get_telemetry(target_name, scope: $cosmos_scope)
      _get_cmd_tlm(target_name, type: 'tlm', scope: scope)
    end

    # Helper method for get_commands and get_telemetry
    def _get_cmd_tlm(target_name, type:, scope: $cosmos_scope)
      result = []
      @redis_pool.with do |redis|
        if redis.exists("#{scope}__cosmos#{type}__#{target_name}") != 0
          packets = redis.hgetall("#{scope}__cosmos#{type}__#{target_name}")
          packets.sort.each do |packet_name, packet_json|
            result << JSON.parse(packet_json)
          end
        else
          raise "Target '#{target_name}' does not exist"
        end
      end
      result
    end

    # TODO: This can't take a Packet but this is how the interface_microservice works
    # def inject_packet(packet)
    #   # Test to make sure this is a valid packet
    #   get_packet(packet.target_name, packet.packet_name)

    #   # Write new packet to stream
    #   msg_hash = { time: packet.received_time.to_nsec_from_epoch,
    #                stored: packet.stored,
    #                target_name: packet.target_name,
    #                packet_name: packet.packet_name,
    #                received_count: packet.received_count, # TODO: Plus one?
    #                buffer: packet.buffer(false) }
    #   write_topic("TELEMETRY__#{packet.target_name}__#{packet.packet_name}", msg_hash)
    # end

    def get_cmd_item(target_name, packet_name, param_name, type: :WITH_UNITS, scope: $cosmos_scope)
      msg_id, msg_hash = read_topic_last("#{scope}__DECOMCMD__#{target_name}__#{packet_name}")
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
      result = redis.hmget("#{scope}__tlm__#{target_name}__#{packet_name}", *secondary_keys)
    end

    def get_tlm_item(target_name, packet_name, item_name, type: :WITH_UNITS, scope: $cosmos_scope)
      if @overrides["#{target_name}__#{packet_name}__#{item_name}__#{type}"]
        return @overrides["#{target_name}__#{packet_name}__#{item_name}__#{type}"]
      end

      types = []
      case type
      when :WITH_UNITS
        types = ["#{item_name}__U", "#{item_name}__F", "#{item_name}__C", item_name]
      when :FORMATTED
        types = ["#{item_name}__F", "#{item_name}__C", item_name]
      when :CONVERTED
        types = ["#{item_name}__C", item_name]
      when :RAW
        types = [item_name]
      end

      @redis_pool.with do |redis|
        results = redis.hmget("#{scope}__tlm__#{target_name}__#{packet_name}", *types)
        results.each do |result|
          return JSON.parse(result) if result
        end
        return nil
      end
    end

    def set_tlm_item(target_name, packet_name, item_name, value, type: :CONVERTED, scope: $cosmos_scope)
      case type
      when :WITH_UNITS
        field = "#{item_name}__U"
      when :FORMATTED
        field = "#{item_name}__F"
      when :CONVERTED
        field = "#{item_name}__C"
      when :RAW
        field = item_name
      end

      @redis_pool.with do |redis|
        redis.hset("#{scope}__tlm__#{target_name}__#{packet_name}", field, value)
      end
    end

    def override(target_name, packet_name, item_name, value, type:, scope: $cosmos_scope)
      @overrides["#{target_name}__#{packet_name}__#{item_name}__#{type}"] = value
    end

    def normalize(target_name, packet_name, item_name, scope: $cosmos_scope)
      %w(RAW CONVERTED FORMATTED WITH_UNITS).each do |type|
        @overrides.delete("#{target_name}__#{packet_name}__#{item_name}__#{type}")
      end
    end

    def get_oldest_message(topic)
      @redis_pool.with do |redis|
        result = redis.xrange(topic, count: 1)
        return result[0]
      end
    end

    def get_newest_message(topic)
      @redis_pool.with do |redis|
        result = redis.xrevrange(topic, count: 1)
        return result[0]
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

    def read_topic_last(topic)
      @redis_pool.with do |redis|
        result = redis.xrevrange(topic, '+', '-', count: 1)
        if result and result.length > 0
          return result[0]
        else
          return nil
        end
      end
    end

    def initialize_streams(topics)
      @redis_pool.with do |redis|
        topics.each do |topic|
          # Create empty stream with maxlen 0
          redis.xadd(topic, { a: 'b' }, maxlen: 0)
        end
      end
    end

    def decrement_id(id)
      time, sequence = id.split('-')
      if sequence == '0'
        "#{time.to_i - 1}-18446744073709551615"
      else
        "#{time}-#{sequence.to_i - 1}"
      end
    end

    def self.get(*args)
      self.instance.get(*args)
    end
    def self.set(*args)
      self.instance.set(*args)
    end
    def self.incr(key)
      self.instance.incr(key)
    end
    def self.hget(key, field)
      self.instance.hget(key, field)
    end
    def self.hset(key, field, value)
      self.instance.hset(key, field, value)
    end
    def self.hkeys(key)
      self.instance.hkeys(key)
    end
    def self.hdel(key, field)
      self.instance.hdel(key, field)
    end
    def self.hgetall(key)
      self.instance.hgetall(key)
    end
    def self.del(key)
      self.instance.del(key)
    end
    def self.exists?(*keys)
      self.instance.exists?(*keys)
    end
    def self.scan(count, **options)
      self.instance.scan(count, **options)
    end
    def self.sadd(key, value)
      self.instance.sadd(key, value)
    end
    def self.srem(key, member)
      self.instance.srem(key, member)
    end
    def self.xrevrange(*args, **kw_args)
      self.instance.xrevrange(*args, **kw_args)
    end
    def self.publish(*args)
      self.instance.publish(*args)
    end
    def self.smembers(key)
      self.instance.smembers(key)
    end
    def self.update_topic_offsets(topics)
      self.instance.update_topic_offsets(topics)
    end
    def self.read_topics(topics, offsets = nil, timeout_ms = 1000, &block)
      self.instance.read_topics(topics, offsets = nil, timeout_ms = 1000, &block)
    end
    def self.write_topic(topic, msg_hash, id = nil, maxlen = 1000, approximate = true)
      self.instance.write_topic(topic, msg_hash, id = nil, maxlen = 1000, approximate = true)
    end
    def self.mapped_hmset(key, hash)
      self.instance.mapped_hmset(key, hash)
    end

    def get(*args)
      @redis_pool.with { |redis| return redis.get(*args) }
    end
    def set(*args)
      @redis_pool.with { |redis| return redis.set(*args) }
    end
    def incr(key)
      @redis_pool.with { |redis| return redis.incr(key) }
    end
    def hget(key, field)
      @redis_pool.with { |redis| return redis.hget(key, field) }
    end
    def hset(key, field, value)
      @redis_pool.with { |redis| redis.hset(key, field, value) }
    end
    def hkeys(key)
      @redis_pool.with { |redis| redis.hkeys(key) }
    end
    def hdel(key, field)
      @redis_pool.with { |redis| redis.hdel(key, field) }
    end
    def hgetall(key)
      @redis_pool.with { |redis| redis.hgetall(key) }
    end
    def del(key)
      @redis_pool.with { |redis| redis.del(key) }
    end
    def exists?(*keys)
      @redis_pool.with { |redis| redis.exists?(*keys) }
    end
    def scan(count, **options)
      @redis_pool.with { |redis| redis.scan(count, **options) }
    end
    def sadd(key, value)
      @redis_pool.with { |redis| redis.sadd(key, value) }
    end
    def srem(key, member)
      @redis_pool.with { |redis| redis.srem(key, member) }
    end
    def xrevrange(*args, **kw_args)
      @redis_pool.with { |redis| redis.xrevrange(*args, **kw_args) }
    end
    def publish(*args)
      @redis_pool.with { |redis| redis.publish(*args) }
    end
    def smembers(key)
      @redis_pool.with { |redis| return redis.smembers(key) }
    end
    def mapped_hmset(key, hash)
      @redis_pool.with { |redis| return redis.mapped_hmset(key, hash) }
    end

    def update_topic_offsets(topics)
      @redis_pool.with do |redis|
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
    end

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

    def write_topic(topic, msg_hash, id = nil, maxlen = 1000, approximate = true)
      # Logger.debug "write_topic topic:#{topic} id:#{id} hash:#{msg_hash}"
      @redis_pool.with do |redis|
        if id
          return redis.xadd(topic, msg_hash, id: id, maxlen: maxlen, approximate: approximate)
        else
          return redis.xadd(topic, msg_hash, maxlen: maxlen, approximate: approximate)
        end
      end
    end

  end
end
