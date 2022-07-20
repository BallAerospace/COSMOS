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

require 'openc3/microservices/microservice'
require 'openc3/models/notification_model'
require 'openc3/models/trigger_model'
require 'openc3/topics/autonomic_topic'
require 'openc3/utilities/authentication'

require 'openc3/script'

module OpenC3

  class TriggerLoopError < TriggerError; end

  # Stored in the TriggerGroupShare this should be a thread safe
  # hash that triggers will be added, updated, and removed from
  class PacketBase

    def initialize(scope:)
      @scope = scope
      @mutex = Mutex.new
      @packets = Hash.new
    end

    # ["#{@scope}__DECOM__{#{@target}}__#{@packet}"]
    def packet(target:, packet:)
      topic = "#{@scope}__DECOM__{#{target}}__#{packet}"
      @mutex.synchronize do
        return Marshal.load( Marshal.dump(@packets[topic]) )
      end
    end

    def get(topic:)
      @mutex.synchronize do
        return Marshal.load( Marshal.dump(@packets[topic]) )
      end
    end

    def add(topic:, packet:)
      @mutex.synchronize do
        @packets[topic] = packet
      end
    end

    def remove(topic:)
      @mutex.synchronize do
        @packets.delete(topic)
      end
    end
  end

  # Stored in the TriggerGroupShare this should be a thread safe
  # hash that triggers will be added, updated, and removed from.
  class TriggerBase

    attr_reader :autonomic_topic

    def initialize(scope:)
      @scope = scope
      @autonomic_topic = "#{@scope}__openc3_autonomic".freeze
      @triggers_mutex = Mutex.new
      @triggers = Hash.new
      @lookup_mutex = Mutex.new
      @lookup = Hash.new
    end

    # Get triggers to evaluate based on the topic. IF the
    # topic is the equal to the autonomic topic it will
    # return only triggers with roots
    def get_triggers(topic:)
      if @autonomic_topic == topic
        return triggers_with_roots()
      else
        return triggers_from(topic: topic)
      end
    end

    # update trigger state after evaluated
    # -1 (the value is considered an error used to disable the trigger)
    #  0 (the value is considered as a false value)
    #  1 (the value is considered as a true value)
    def update_state(name:, value:)
      @triggers_mutex.synchronize do
        data = @triggers[name]
        return unless data
        trigger = TriggerModel.from_json(data, name: data['name'], scope: data['scope'])
        if value == -1 && trigger.active
          trigger.deactivate()
        elsif value == 1 && trigger.state == false
          trigger.enable()
        elsif value == 0 && trigger.state == true
          trigger.disable()
        end
        @triggers[name] = trigger.as_json(:allow_nan => true)
      end
    end

    # returns a Hash of ALL active Trigger objects
    def triggers
      val = nil
      @triggers_mutex.synchronize do
        val = Marshal.load( Marshal.dump(@triggers) )
      end
      ret = Hash.new
      val.each do | name, data |
        trigger = TriggerModel.from_json(data, name: data['name'], scope: data['scope'])
        ret[name] = trigger if trigger.active
      end
      return ret
    end

    # returns an Array of active Trigger objects that have roots to other triggers
    def triggers_with_roots
      val = nil
      @triggers_mutex.synchronize do
        val = Marshal.load( Marshal.dump(@triggers) )
      end
      ret = []
      val.each do | _name, data |
        trigger = TriggerModel.from_json(data, name: data['name'], scope: data['scope'])
        ret << trigger if trigger.active && ! trigger.roots.empty?
      end
      return ret
    end

    # returns an Array of active Trigger objects that use a topic
    def triggers_from(topic:)
      val = nil
      @lookup_mutex.synchronize do
        val = Marshal.load( Marshal.dump(@lookup[topic]) )
      end
      return [] if val.nil?
      ret = []
      @triggers_mutex.synchronize do
        val.each do | trigger_name, _v |
          data = Marshal.load( Marshal.dump(@triggers[trigger_name]) )
          trigger = TriggerModel.from_json(data, name: data['name'], scope: data['scope'])
          ret << trigger if trigger.active
        end
      end
      return ret
    end

    # get all topics group is working with
    def topics
      @lookup_mutex.synchronize do
        return Marshal.load( Marshal.dump(@lookup.keys()) )
      end
    end

    # database update of all triggers in the group
    def update(triggers:)
      @triggers_mutex.synchronize do
        @triggers = Marshal.load( Marshal.dump(triggers) )
      end
      @lookup_mutex.synchronize do
        @lookup = {@autonomic_topic => {}}
        triggers.each do | _name, data |
          trigger = TriggerModel.from_json(data, name: data['name'], scope: data['scope'])
          trigger.generate_topics.each do | topic |
            if @lookup[topic].nil?
              @lookup[topic] = { trigger.name => 1 }
            else
              @lookup[topic][trigger.name] = 1
            end
          end
        end
      end
    end

    # add a trigger from TriggerBase
    def add(trigger:)
      @triggers_mutex.synchronize do
        @triggers[trigger['name']] = Marshal.load( Marshal.dump(trigger) )
      end
      t = TriggerModel.from_json(trigger, name: trigger['name'], scope: trigger['scope'])
      @lookup_mutex.synchronize do 
        t.generate_topics.each do | topic |
          if @lookup[topic].nil?
            @lookup[topic] = { t.name => 1 }
          else
            @lookup[topic][t.name] = 1
          end
        end
      end
    end

    # remove a trigger from TriggerBase
    def remove(trigger:)
      @triggers_mutex.synchronize do
        @triggers.delete(trigger['name'])
      end
      t = TriggerModel.from_json(trigger, name: trigger['name'], scope: trigger['scope'])
      @lookup_mutex.synchronize do 
        t.generate_topics.each do | topic |
          unless @lookup[topic].nil?
            @lookup[topic].delete(t.name)
          end
        end
      end
    end
  end

  # Shared between the monitor thread and the manager thread to
  # share the triggers. This should remain a thread
  # safe implamentation.
  class TriggerGroupShare

    def self.get_group(name:)
      return name.split('__')[2]
    end

    attr_reader :trigger_base, :packet_base

    def initialize(scope:)
      @scope = scope
      @trigger_base = TriggerBase.new(scope: scope)
      @packet_base = PacketBase.new(scope: scope)
    end
  end

  # The TriggerGroupWorker is a very simple thread pool worker. Once
  # the trigger manager has pushed a packet to the queue one of
  # these workers will evaluate the triggers in the kit and
  # evaluate triggers for that packet.
  class TriggerGroupWorker
    TRIGGER_METRIC_NAME = 'trigger_eval_duration_seconds'.freeze

    TYPE = 'type'.freeze
    ITEM_RAW = 'raw'.freeze
    ITEM_TARGET = 'target'.freeze
    ITEM_PACKET = 'packet'.freeze
    ITEM_TYPE = 'item'.freeze
    FLOAT_TYPE = 'float'.freeze
    STRING_TYPE = 'string'.freeze
    LIMIT_TYPE = 'limit'.freeze
    TRIGGER_TYPE = 'trigger'.freeze

    attr_reader :name, :scope, :target, :packet, :group

    def initialize(name:, scope:, group:, queue:, share:, ident:)
      @name = name
      @scope = scope
      @group = group
      @queue = queue
      @share = share
      @ident = ident
      @metric = Metric.new(microservice: @name, scope: @scope)
      @metric_output_time = 0
    end

    def run
      Logger.info "TriggerGroupWorker-#{@ident} running"
      loop do
        topic = @queue.pop
        break if topic.nil?
        begin
          evaluate_wrapper(topic: topic)
          current_time = Time.now.to_i
          if @metric_output_time < current_time
            @metric.output
            @metric_output_time = current_time + 120
          end
        rescue StandardError => e
          Logger.error "TriggerGroupWorker-#{@ident} failed to evaluate data packet from topic: #{topic}\n#{e.formatted}"
        end
      end
      Logger.info "TriggerGroupWorker-#{@ident} exiting"
    end

    # time how long each packet takes to eval and produce a metric to public
    def evaluate_wrapper(topic:)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      evaluate_data_packet(topic: topic, triggers: @share.trigger_base.triggers)
      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      metric_labels = { 'trigger_group' => @group, 'thread' => "worker-#{@ident}" }
      @metric.add_sample(name: TRIGGER_METRIC_NAME, value: diff, labels: metric_labels) 
    end

    # Each packet will be evaluated to all triggers and use the result to send
    # the results back to the topic to be used by the reaction microservice.
    def evaluate_data_packet(topic:, triggers:)
      visited = Hash.new
      Logger.debug "TriggerGroupWorker-#{@ident} topic: #{topic}"
      triggers_to_eval = @share.trigger_base.get_triggers(topic: topic)
      Logger.debug "TriggerGroupWorker-#{@ident} triggers_to_eval: #{triggers_to_eval}"
      triggers_to_eval.each do | trigger |
        Logger.debug "TriggerGroupWorker-#{@ident} eval head: #{trigger}"
        value = evaluate_trigger(
          head: trigger,
          trigger: trigger,
          visited: visited,
          triggers: triggers
        )
        Logger.debug "TriggerGroupWorker-#{@ident} trigger: #{trigger} value: #{value}"
        # value MUST be -1, 0, or 1
        @share.trigger_base.update_state(name: trigger.name, value: value)
      end
    end

    # extract the value outlined in the operand to get the packet item limit
    # IF operand limit does not include _LOW or _HIGH this will match the
    # COLOR and return COLOR_LOW || COLOR_HIGH
    # operand item: GREEN_LOW == other operand limit: GREEN
    def get_packet_limit(operand:, other:)
      packet = @share.packet_base.packet(
        target: operand[ITEM_TARGET],
        packet: operand[ITEM_PACKET]
      )
      return nil if packet.nil?
      limit = packet["#{operand[ITEM_TYPE]}__L"]
      if limit.nil? == false && limit.include?('_')
        return other[LIMIT_TYPE] if limit.include?(other[LIMIT_TYPE])
      end
      return limit
    end

    # extract the value outlined in the operand to get the packet item value
    # IF raw in operand it will pull the raw value over the converted
    def get_packet_value(operand:)
      packet = @share.packet_base.packet(
        target: operand[ITEM_TARGET],
        packet: operand[ITEM_PACKET]
      )
      return nil if packet.nil?

      value_type = operand[ITEM_RAW] ? '' : '__C'
      return packet["#{operand[ITEM_TYPE]}#{value_type}"]
    end

    # extract the value of the operand from the packet
    def operand_value(operand:, other:, visited:)
      if operand[TYPE] == ITEM_TYPE && other[TYPE] == LIMIT_TYPE
        return get_packet_limit(operand: operand, other: other)
      elsif operand[TYPE] == ITEM_TYPE
        return get_packet_value(operand: operand)
      elsif operand[TYPE] == TRIGGER_TYPE
        return visited["#{operand[TRIGGER_TYPE]}__R"] == 1
      else
        return operand[operand[TYPE]]
      end
    end

    # the base evaluate method used by evaluate_trigger
    #   -1 (the value is considered an error used to disable the trigger)
    #    0 (the value is considered as a false value)
    #    1 (the value is considered as a true value)
    #
    def evaluate(left:, operator:, right:)
      Logger.debug "TriggerGroupWorker-#{@ident} evaluate: (#{left} #{operator} #{right})"
      begin
        case operator
        when '>'
          return left > right ? 1 : 0
        when '<'
          return left < right ? 1 : 0
        when '>='
          return left >= right ? 1 : 0
        when '<='
          return left <= right ? 1 : 0
        when '!='
          return left != right ? 1 : 0
        when '=='
          return left == right ? 1 : 0
        when 'AND'
          return left && right ? 1 : 0
        when 'OR'
          return left || right ? 1 : 0
        end
      rescue ArgumentError
        Logger.error "invalid evaluate: (#{left} #{operator} #{right})"
        return -1
      end
    end

    # This could be confusing... So this is a recursive method for the
    # TriggerGroupWorkers to call. It will use the trigger name and append a
    # __P for path or __R for result. The Path is a Hash that contains
    # a key for each node traveled to get results. When the result has
    # been found it will be stored in the result key __R in the vistied Hash
    # and eval_trigger will return a number.
    #   -1 (the value is considered an error used to disable the trigger)
    #    0 (the value is considered as a false value)
    #    1 (the value is considered as a true value)
    #
    # IF an operand is evaluated as nil it will log an error and return -1
    # IF a loop is detected it will log an error and return -1
    def evaluate_trigger(head:, trigger:, visited:, triggers:)
      if visited["#{trigger.name}__R"]
        return visited["#{trigger.name}__R"] 
      end
      if visited["#{trigger.name}__P"].nil?
        visited["#{trigger.name}__P"] = Hash.new
      end
      if visited["#{head.name}__P"][trigger.name]
        # Not sure if this is posible as on create it validates that the dependents are already created
        Logger.error "loop detected from #{head} -> #{trigger} path: #{visited["#{head.name}__P"]}"
        return visited["#{trigger.name}__R"] = -1
      end
      trigger.roots.each do | root_trigger_name |
        next if visited["#{root_trigger_name}__R"]
        root_trigger = triggers[root_trigger_name]
        if head.name == root_trigger.name
          Logger.error "loop detected from #{head} -> #{root_trigger} path: #{visited["#{head.name}__P"]}"
          return visited["#{trigger.name}__R"] = -1
        end
        result = evaluate_trigger(
          head: head,
          trigger: root_trigger,
          visited: visited,
          triggers: triggers
        )
        Logger.debug "TriggerGroupWorker-#{@ident} #{root_trigger.name} result: #{result}"
        visited["#{root_trigger.name}__R"] = visited["#{head.name}__P"][root_trigger.name] = result
      end
      left = operand_value(operand: trigger.left, other: trigger.right, visited: visited)
      right = operand_value(operand: trigger.right, other: trigger.left, visited: visited)
      if left.nil? || right.nil?
        return visited["#{trigger.name}__R"] = 0
      end
      result = evaluate(left: left, operator: trigger.operator, right: right)
      return visited["#{trigger.name}__R"] = result
    end

  end

  # The trigger manager starts a thread pool and subscribes
  # to the telemtry decom topic add the packet to a queue.
  # TriggerGroupManager adds the "packet" to the thread pool queue
  # and the thread will evaluate the "trigger".
  class TriggerGroupManager

    attr_reader :name, :scope, :share, :group, :topics, :thread_pool

    def initialize(name:, scope:, group:, share:)
      @name = name
      @scope = scope
      @group = group
      @share = share
      @worker_count = 3
      @queue = Queue.new
      @read_topic = true
      @topics = []
      @thread_pool = nil
      @cancel_thread = false
    end

    def generate_thread_pool()
      thread_pool = []
      @worker_count.times do | i |
        worker = TriggerGroupWorker.new(
          name: @name,
          scope: @scope,
          group: @group,
          queue: @queue,
          share: @share,
          ident: i,
        )
        thread_pool << Thread.new { worker.run }
      end
      return thread_pool
    end

    def run
      Logger.info "TriggerGroupManager running"
      @thread_pool = generate_thread_pool()
      loop do
        begin
          update_topics()
        rescue StandardError => e
          Logger.error "TriggerGroupManager failed to update topics.\n#{e.formatted}"
        end
        break if @cancel_thread

        block_for_updates()
        break if @cancel_thread
      end
      Logger.info "TriggerGroupManager exiting"
    end

    def update_topics
      past_topics = @topics
      @topics = @share.trigger_base.topics()
      Logger.debug "TriggerGroupManager past_topics: #{past_topics} topics: #{@topics}"
      (past_topics - @topics).each do | removed_topic |
        @share.packet_base.remove(topic: removed_topic)
      end
    end

    def block_for_updates
      @read_topic = true
      while @read_topic
        begin
          Topic.read_topics(@topics) do |topic, _msg_id, msg_hash, _redis|
            Logger.debug "TriggerGroupManager block_for_updates: #{topic} #{msg_hash.to_s}"
            if topic != @share.trigger_base.autonomic_topic
              packet = JSON.parse(msg_hash['json_data'], :allow_nan => true, :create_additions => true)
              @share.packet_base.add(topic: topic, packet: packet)
            end
            @queue << "#{topic}"
          end
        rescue StandardError => e
          Logger.error "TriggerGroupManager failed to read topics #{@topics}\n#{e.formatted}"
        end
      end
    end
    
    def refresh
      @read_topic = false
    end

    def shutdown
      @read_topic = false
      @cancel_thread = true
      @worker_count.times do | i |
        @queue << nil
      end
    end
  end

  # The trigger microservice starts a manager then gets the activities
  # from the sorted set in redis and updates the schedule for the
  # manager. Timeline will then wait for an update on the timeline
  # stream this will trigger an update again to the schedule.
  class TriggerGroupMicroservice < Microservice
    TRIGGER_METRIC_NAME = 'update_triggers_duration_seconds'.freeze

    attr_reader :name, :scope, :share, :group, :manager, :manager_thread

    def initialize(*args)
      super(*args)
      @group = TriggerGroupShare.get_group(name: @name)
      @share = TriggerGroupShare.new(scope: @scope)
      @manager = TriggerGroupManager.new(name: @name, scope: @scope, group: @group, share: @share)
      @manager_thread = nil
      @read_topic = true
    end

    def run
      Logger.info "TriggerGroupMicroservice running"
      @manager_thread = Thread.new { @manager.run }
      loop do
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        triggers = TriggerModel.all(scope: @scope, group: @group)
        @share.trigger_base.update(triggers: triggers)
        diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
        metric_labels = { 'trigger_group' => @group, 'thread' => 'microservice' }
        @metric.add_sample(name: TRIGGER_METRIC_NAME, value: diff, labels: metric_labels)
        break if @cancel_thread

        block_for_updates()
        break if @cancel_thread
      end
      Logger.info "TriggerGroupMicroservice exiting"
    end

    def topic_lookup_functions
      return {
        'created' => :created_trigger_event,
        'updated' => :created_trigger_event,
        'deleted' => :deleted_trigger_event,
        'enabled' => :created_trigger_event,
        'disabled' => :created_trigger_event,
        'activated' => :created_trigger_event,
        'deactivated' => :created_trigger_event,
      }
    end

    def block_for_updates
      @read_topic = true
      while @read_topic
        begin
          AutonomicTopic.read_topics(@topics) do |_topic, _msg_id, msg_hash, _redis|
            Logger.debug "TriggerGroupMicroservice block_for_updates: #{msg_hash.to_s}"
            if msg_hash['type'] == 'trigger'
              data = JSON.parse(msg_hash['data'], :allow_nan => true, :create_additions => true)
              public_send(topic_lookup_functions[msg_hash['kind']], data)
            end
          end
        rescue StandardError => e
          Logger.error "TriggerGroupMicroservice failed to read topics #{@topics}\n#{e.formatted}"
        end
      end
    end

    def no_op(data)
      Logger.debug "TriggerGroupMicroservice web socket event: #{data}"
    end

    def refresh_event(data)
      Logger.debug "TriggerGroupMicroservice web socket schedule refresh: #{data}"
      @read_topic = false
    end

    # Add the trigger to the share. 
    def created_trigger_event(data)
      Logger.debug "TriggerGroupMicroservice created_trigger_event #{data}"
      if data['group'] == @group
        @share.trigger_base.add(trigger: data)
        @manager.refresh()
      end
    end

    # Remove the trigger from the share.
    def deleted_trigger_event(data)
      Logger.debug "TriggerGroupMicroservice deleted_trigger_event #{data}"
      if data['group'] == @group
        @share.trigger_base.remove(trigger: data)
        @manager.refresh()
      end
    end

    def shutdown
      @read_topic = false
      @manager.shutdown()
      super
    end
  end
end

OpenC3::TriggerGroupMicroservice.run if __FILE__ == $0
