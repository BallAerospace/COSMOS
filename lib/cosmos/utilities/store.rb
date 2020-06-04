# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'redis'
require 'json'
require 'thread'
require 'connection_pool'
require 'cosmos/config/config_parser'
require 'cosmos/io/json_rpc'

module Cosmos
  class Store
    # Variable that holds the singleton instance
    @@instance = nil

    # Mutex used to ensure that only one instance is created
    @@instance_mutex = Mutex.new

    # Get the singleton instance
    def self.instance(pool_size = 10)
      return @@instance if @@instance
      @@instance_mutex.synchronize do
        @@instance ||= self.new(pool_size)
        return @@instance
      end
    end

    def initialize(pool_size = 10)
      @redis_pool = ConnectionPool.new(size: pool_size) { Redis.new(url: "redis://localhost:6379/0") }
      @topic_offsets = {}
    end

    def update_interface(interface)
      @redis_pool.with { |redis| redis.hset("cosmos_interfaces", interface.name, JSON.generate(interface.to_info_hash)) }
    end

    def cmd_interface(interface_name, target_name, cmd_name, cmd_params, range_check, hazardous_check, raw)
      write_topic("CMDINTERFACE__#{interface_name}", { 'target_name' => target_name, 'cmd_name' => cmd_name, 'cmd_params' => JSON.generate(cmd_params.as_json), 'range_check' => range_check, 'hazardous_check' => hazardous_check, 'raw' => raw })
    end

    def cmd_target(target_name, cmd_name, cmd_params, range_check, hazardous_check, raw, timeout_ms = 5000)
      topic = "CMDTARGET__#{target_name}"
      ack_topic = "ACKCMDTARGET__#{target_name}"
      cmd_id = write_topic(topic, { 'target_name' => target_name, 'cmd_name' => cmd_name, 'cmd_params' => JSON.generate(cmd_params.as_json), 'range_check' => range_check, 'hazardous_check' => hazardous_check, 'raw' => raw })
      (timeout_ms / 100).times do
        read_topics([ack_topic], 100) do |topic, msg_id, msg_hash, redis|
          if msg_id == cmd_id
            Logger.info "Ack Received: #{msg_id}: #{msg_hash.inspect}"
            # yield target_name, cmd_name, cmd_params, range_check, hazardous_check, raw
            if msg_hash["result"] == "SUCCESS"
              return
            else
              # TODO: handle hazardous response and other errors properly
              raise "Cmd Error"
            end
          end
        end
      end
      raise "Timeout waiting for cmd ack"
    end

    def receive_commands(interface)
      topics = []
      topics << "CMDINTERFACE__#{interface.name}"
      interface.target_names.each do |target_name|
        topics << "CMDTARGET__#{target_name}"
      end
      while true
        read_topics(topics) do |topic, msg_id, msg_hash, redis|
          yield msg_hash['target_name'], msg_hash['cmd_name'], JSON.parse(msg_hash['cmd_params']), ConfigParser.handle_true_false(msg_hash['range_check']), ConfigParser.handle_true_false(msg_hash['hazardous_check']), ConfigParser.handle_true_false(msg_hash['raw'])
          write_topic("ACK" + topic, { 'result' => 'SUCCESS' }, msg_id)
        end
      end
    end

    def get_tlm_values(item_array, value_types = :CONVERTED)
      items = []
      states = []
      settings = []

      # TODO: Consider removing or modifying this method to not include limits ranges or set
      if !item_array.is_a?(Array) || (!item_array[0].is_a?(Array) and !item_array.empty?)
        raise ArgumentError, "item_array must be nested array: [['TGT','PKT','ITEM'],...]"
      end
      return [[], [], [], System.limits_set] if item_array.empty?
      if value_types.is_a?(Array)
        elem = value_types[0]
      else
        elem = value_types
      end
      # Due to JSON round tripping from scripts, value_types can be a String
      # so we must check for both Symbol and String
      if !elem.is_a?(Symbol) && !elem.is_a?(String)
        raise ArgumentError, "value_types must be a single symbol or array of symbols specifying the conversion method (:RAW, :CONVERTED, :FORMATTED, :WITH_UNITS)"
      end

      raise(ArgumentError, "Passed #{item_array.length} items but only #{value_types.length} value types") if (Array === value_types) and item_array.length != value_types.length

      value_type = value_types.intern unless Array === value_types
      @redis_pool.with do |redis|
        # Get all the stuff we need
        full_result = redis.pipelined do
          item_array.length.times do |index|
            entry = item_array[index]
            target_name = entry[0]
            packet_name = entry[1]
            item_name = entry[2]
            value_type = value_types[index].intern if Array === value_types
            tlm_variable_with_limits_state_gather(redis, target_name, packet_name, item_name, value_type)
          end
        end
        item_array.length.times do |index|
          value_type = value_types[index].intern if Array === value_types
          result = full_result[index]
          if result[0]
            if value_type == :FORMATTED or value_type == :WITH_UNITS
              items << JSON.parse(result[0]).to_s
            else
              items << JSON.parse(result[0])
            end
          elsif result[1]
            if value_type == :FORMATTED or value_type == :WITH_UNITS
              items << JSON.parse(result[1]).to_s
            else
              items << JSON.parse(result[1])
            end
          elsif result[2]
            items << JSON.parse(result[2]).to_s
          elsif result[3]
            items << JSON.parse(result[3]).to_s
          else
            items << nil
          end
          if result[-1]
            states << JSON.parse(result[-1]).to_s
          else
            states << nil
          end
          settings << nil # TODO: Modify API to not include this or limits_set
        end
      end

      return items, states, settings
    end

    def get_limits(target_name, packet_name, item_name)
      limits = {}
      @redis_pool.with do |redis|
        packet = JSON.parse(redis.hget("cosmostlm__#{target_name}", packet_name))
        item = packet['items'].find {|item| item['name'] == item_name }
        item['limits'].each do |key, vals|
          limits[key] = [vals['red_low'], vals['yellow_low'], vals['yellow_high'], vals['red_high']]
          limits[key].concat([vals['green_low'], vals['green_high']]) if vals['green_low']
        end
      end
      return limits
    end

    def tlm_variable_with_limits_state_gather(redis, target_name, packet_name, item_name, value_type)
      key = "tlm__#{target_name}__#{packet_name}"
      case value_type
      when :RAW
        secondary_keys = [item_name, "#{item_name}__L"]
      when :CONVERTED
        secondary_keys = ["#{item_name}__C", item_name, "#{item_name}__L"]
      when :FORMATTED
        secondary_keys = ["#{item_name}__F", "#{item_name}__C", item_name, "#{item_name}__L"]
      else
        secondary_keys = ["#{item_name}__U", "#{item_name}__F", "#{item_name}__C", item_name, "#{item_name}__L"]
      end
      result = redis.hmget(key, *secondary_keys)
    end

    def read_topics(topics, timeout_ms = 1000)
      @redis_pool.with do |redis|
        offsets = []
        topics.each do |topic|
          last_id = @topic_offsets[topic]
          if last_id
            offsets << last_id
          else
            result = redis.xrevrange(topic, count: 1)
            last_id = "0-0"
            last_id = result[0][0] if result and result[0] and result[0][0]
            offsets << last_id
            @topic_offsets[topic] = last_id
          end
        end
        result = redis.xread(topics, offsets, block: timeout_ms)
        if result and result.length > 0
          result.each do |topic, messages|
            messages.each do |msg_id, msg_hash|
              @topic_offsets[topic] = msg_id
              yield topic, msg_id, msg_hash, redis if block_given?
            end
          end
        end
        return result
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

    def write_topic(topic, msg_hash, id = nil, maxlen = 1000, approximate = true)
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
