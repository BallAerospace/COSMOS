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
require 'cosmos/config/config_parser'
require 'cosmos/io/json_rpc'

module Cosmos
  class Store
    def initialize(redis = nil)
      @redis = redis
      @redis ||= Redis.new(url: "redis://localhost:6379/0")
    end

    def update_interface(interface)
      @redis.hset("cosmos_interfaces", interface.name, JSON.generate(interface.to_info_hash))
    end

    def cmd_interface(interface_name, target_name, cmd_name, cmd_params, range_check, hazardous_check, raw)
      @redis.xadd("CMDINTERFACE__#{interface_name}", { 'target_name' => target_name, 'cmd_name' => cmd_name, 'cmd_params' => JSON.generate(cmd_params.as_json), 'range_check' => range_check, 'hazardous_check' => hazardous_check, 'raw' => raw })
    end

    def cmd_target(target_name, cmd_name, cmd_params, range_check, hazardous_check, raw)
      topic = "CMDTARGET__#{target_name}"
      ack_topic = "ACKCMDTARGET__#{target_name}"
      result = @redis.xrevrange(ack_topic, count: 1)
      last_id = "0-0"
      last_id = result[0][0] if result and result[0] and result[0][0]
      cmd_id = @redis.xadd(topic, { 'target_name' => target_name, 'cmd_name' => cmd_name, 'cmd_params' => JSON.generate(cmd_params.as_json), 'range_check' => range_check, 'hazardous_check' => hazardous_check, 'raw' => raw })
      50.times do
        result = @redis.xread([ack_topic], [last_id], block: 100)
        if result and result.length > 0
          result.each do |topic, messages|
            messages.each do |msg_id, msg_hash|
              last_id = msg_id
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
        end
      end
    end

    def receive_commands(interface)
      topics = []
      topics << "CMDINTERFACE__#{interface.name}"
      interface.target_names.each do |target_name|
        topics << "CMDTARGET__#{target_name}"
      end
      offsets = []
      topic_index = {}
      index = 0
      topics.each do |topic|
        result = @redis.xrevrange(topic, count: 1)
        last_id = "0-0"
        last_id = result[0][0] if result and result[0] and result[0][0]
        offsets << last_id
        topic_index[topic] = index
        index += 1
      end
      while true
        result = @redis.xread(topics, offsets, block: 1000)
        if result and result.length > 0
          result.each do |topic, messages|
            messages.each do |msg_id, msg_hash|
              offsets[topic_index[topic]] = msg_id
              Logger.info "Received: #{msg_id}: #{msg_hash.inspect}"
              yield msg_hash['target_name'], msg_hash['cmd_name'], JSON.parse(msg_hash['cmd_params']), ConfigParser.handle_true_false(msg_hash['range_check']), ConfigParser.handle_true_false(msg_hash['hazardous_check']), ConfigParser.handle_true_false(msg_hash['raw'])
              @redis.xadd("ACK" + topic, { 'result' => 'SUCCESS' }, id: msg_id)
            end
          end
        end
      end
    end

    def tlm_variable_with_limits_state_gather(target_name, packet_name, item_name, value_type)
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
      result = @redis.hmget(key, *secondary_keys)
    end
  end
end
