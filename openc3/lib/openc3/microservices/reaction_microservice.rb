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
require 'openc3/models/reaction_model'
require 'openc3/models/notification_model'
require 'openc3/models/trigger_model'
require 'openc3/topics/autonomic_topic'
require 'openc3/utilities/authentication'

require 'openc3/script'

module OpenC3
  
  # This should remain a thread safe implamentation. This is the in memory 
  # cache that should mirror the database. This will update two hash 
  # variables and will track triggers to lookup what triggers link to what
  # reactions.
  class ReactionBase

    def initialize(scope:)
      @scope = scope
      @reactions_mutex = Mutex.new
      @reactions = Hash.new
      @lookup_mutex = Mutex.new
      @lookup = Hash.new
    end

    # RETURNS an Array of active and not snoozed reactions
    def get_snoozed
      data = nil
      @reactions_mutex.synchronize do
        data = Marshal.load( Marshal.dump(@reactions) )
      end
      ret = Array.new
      return ret unless data
      data.each do | _name, r_hash |
        data = Marshal.load( Marshal.dump(r_hash) )
        reaction = ReactionModel.from_json(data, name: data['name'], scope: data['scope'])
        ret << reaction if reaction.active && reaction.snoozed_until
      end
      return ret
    end

    # RETURNS an Array of active and not snoozed reactions
    def get_reactions(trigger_name:)
      array_value = nil
      @lookup_mutex.synchronize do
        array_value = Marshal.load( Marshal.dump(@lookup[trigger_name]) )
      end
      ret = Array.new
      return ret unless array_value
      array_value.each do | name |
        @reactions_mutex.synchronize do
          data = Marshal.load( Marshal.dump(@reactions[name]) )
          reaction = ReactionModel.from_json(data, name: data['name'], scope: data['scope'])
          ret << reaction if reaction.active && reaction.snoozed_until.nil?
        end
      end
      return ret
    end

    # Update the memeory database with a HASH of reactions from the external
    # database
    def setup(reactions:)
      @reactions_mutex.synchronize do
        @reactions = Marshal.load( Marshal.dump(reactions) )
      end
      @lookup_mutex.synchronize do
        @lookup = Hash.new
        reactions.each do | reaction_name, reaction |
          reaction['triggers'].each do | trigger |
            trigger_name = trigger['name']
            if @lookup[trigger_name].nil?
              @lookup[trigger_name] = [reaction_name]
            else
              @lookup[trigger_name] << reaction_name
            end
          end
        end
      end
    end

    # Pulls the latest reaction name from the in memory database to see
    # if the reaction should be put to sleep.
    def sleep(name:)
      @reactions_mutex.synchronize do
        data = Marshal.load( Marshal.dump(@reactions[name]) )
        return unless data
        reaction = ReactionModel.from_json(data, name: data['name'], scope: data['scope'])
        if reaction.snoozed_until.nil? || Time.now.to_i >= reaction.snoozed_until
          reaction.sleep()
        end
        @reactions[name] = reaction.as_json(:allow_nan => true)
      end
    end

    # Pulls the latest reaction name from the in memory database to see
    # if the reaction should be awaken.
    def wake(name:)
      @reactions_mutex.synchronize do
        data = Marshal.load( Marshal.dump(@reactions[name]) )
        return unless data
        reaction = ReactionModel.from_json(data, name: data['name'], scope: data['scope'])
        reaction.awaken()
        @reactions[name] = reaction.as_json(:allow_nan => true)
      end
    end

    # Add a reaction to the in memory database
    def add(reaction:)
      reaction_name = reaction['name']
      @reactions_mutex.synchronize do
        @reactions[reaction_name] = reaction
      end
      reaction['triggers'].each do | trigger |
        trigger_name = trigger['name']
        @lookup_mutex.synchronize do 
          if @lookup[trigger_name].nil?
            @lookup[trigger_name] = [reaction_name]
          else
            @lookup[trigger_name] << reaction_name
          end
        end
      end
    end

    # Updates a reaction to the in memory database. This current does not
    # update the lookup Hash for the triggers.
    def update(reaction:)
      reaction_name = reaction['name']
      @reactions_mutex.synchronize do
        @reactions[reaction_name] = reaction
      end
    end

    # Removes a reaction to the in memory database.
    def remove(reaction:)
      reaction_name = reaction['name']
      @reactions_mutex.synchronize do
        @reactions.delete(reaction_name)
      end
      reaction['triggers'].each do | trigger |
        trigger_name = trigger['name']
        @lookup_mutex.synchronize do 
          @lookup[trigger_name].delete(reaction_name)
        end
      end
    end
  end

  # This should remain a thread safe implamentation.
  class QueueBase

    attr_reader :queue

    def initialize(scope:)
      @queue = Queue.new
    end

    def enqueue(kind:, data:)
      @queue << [kind, data]
    end
  end

  # This should remain a thread safe implamentation.
  class SnoozeBase

    def initialize(scope:)
      # store the round robin watch
      @watch_mutex = Mutex.new
      @watch_size = 25
      @watch_queue = Array.new(@watch_size)
      @watch_index = 0
    end

    def not_queued?(reaction:)
      key = "#{reaction.name}__#{reaction.snoozed_until}"
      @watch_mutex.synchronize do
        return false if @watch_queue.index(key)
        @watch_queue[@watch_index] = key
        @watch_index = @watch_index + 1 >= @watch_size ? 0 : @watch_index + 1
        return true
      end
    end
  end

  # Shared between the monitor thread and the manager thread to
  # share the resources. 
  class ReactionShare

    attr_reader :reaction_base, :queue_base, :snooze_base

    def initialize(scope:)
      @reaction_base = ReactionBase.new(scope: scope)
      @queue_base = QueueBase.new(scope: scope)
      @snooze_base = SnoozeBase.new(scope: scope)
    end

  end

  # The Reaction worker is a very simple thread pool worker. Once the manager
  # queues a trigger to evaluate against the reactions. The worker will check
  # the reactions to see if it needs to fire any reactions.
  class ReactionWorker
    REACTION_METRIC_NAME = 'reaction_duration_seconds'.freeze

    attr_reader :name, :scope, :share

    def initialize(name:, scope:, share:, ident:)
      @name = name
      @scope = scope
      @share = share
      @ident = ident
      @metric_output_time = 0
      @metric = Metric.new(microservice: @name, scope: @scope)
      @authentication = generate_auth()
    end

    # generate the auth object
    def generate_auth
      if ENV['OPENC3_API_USER'].nil? || ENV['OPENC3_API_CLIENT'].nil?
        return OpenC3Authentication.new()
      else
        return OpenC3KeycloakAuthentication.new(ENV['OPENC3_KEYCLOAK_URL'])
      end
    end

    def reaction(data:)
      return ReactionModel.from_json(data, name: data['name'], scope: data['scope'])
    end

    def run
      Logger.info "ReactionWorker-#{@ident} running"
      loop do
        begin
          kind, data = @share.queue_base.queue.pop
          break if kind.nil? || data.nil?
          case kind
          when 'reaction'
            run_reaction(reaction: reaction(data: data))
          when 'trigger'
            process_enabled_trigger(data: data)
          end
          current_time = Time.now.to_i
          if @metric_output_time < current_time
            @metric.output
            @metric_output_time = current_time + 120
          end
        rescue StandardError => e
          Logger.error "ReactionWorker-#{@ident} failed to evaluate kind: #{kind} data: #{data}\n#{e.formatted}"
        end
      end
      Logger.info "ReactionWorker-#{@ident} exiting"
    end

    def process_enabled_trigger(data:)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @share.reaction_base.get_reactions(trigger_name: data['name']).each do | reaction |
        run_reaction(reaction: reaction)
      end
      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      metric_labels = { 'type' => 'trigger', 'thread' => "worker-#{@ident}" }
      @metric.add_sample(name: REACTION_METRIC_NAME, value: diff, labels: metric_labels)
    end

    def run_reaction(reaction:)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      reaction.actions.each do |action|
        run_action(reaction: reaction, action: action)
      end
      @share.reaction_base.sleep(name: reaction.name)
      diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
      metric_labels = { 'type' => 'reaction', 'thread' => "worker-#{@ident}" }
      @metric.add_sample(name: REACTION_METRIC_NAME, value: diff, labels: metric_labels)
    end

    def run_action(reaction:, action:)
      case action['type']
      when 'command'
        run_command(reaction: reaction, action: action)
      when 'script'
        run_script(reaction: reaction, action: action)
      end
    end

    def run_command(reaction:, action:)
      Logger.debug "ReactionWorker-#{@ident} running reaction #{reaction.name}, command: '#{action['value']}' "
      begin
        cmd_no_hazardous_check(action['value'], scope: @scope)
        Logger.info "ReactionWorker-#{@ident} #{reaction.name} command action complete, #{action['value']}"
      rescue StandardError => e
        Logger.error "ReactionWorker-#{@ident} #{reaction.name} command action failed, #{action}\n#{e.message}"
      end
    end

    def run_script(reaction:, action:)
      Logger.debug "ReactionWorker-#{@ident} running reaction #{reaction.name}, script: '#{action['value']}'"
      begin
        request = Net::HTTP::Post.new(
          "/script-api/scripts/#{action['value']}/run?scope=#{@scope}",
          'Content-Type' => 'application/json',
          'Authorization' => @authentication.token()
        )
        request.body = JSON.generate({
          'scope' => @scope,
          'environment' => action['environment'],
          'reaction' => reaction.name,
          'id' => Time.now.to_i
        })
        hostname = ENV['OPENC3_SCRIPT_HOSTNAME'] || 'openc3-script-runner-api'
        response = Net::HTTP.new(hostname, 2902).request(request)
        raise "failed to call #{hostname}, for script: #{action['value']}, response code: #{response.code}" if response.code != '200'

        Logger.info "ReactionWorker-#{@ident} #{reaction.name} script action complete, #{action['value']} => #{response.body}"
      rescue StandardError => e
        Logger.error "ReactionWorker-#{@ident} #{reaction.name} script action failed, #{action}\n#{e.message}"
      end
    end
  end

  # The reaction snooze manager starts a thread pool and keeps track of when a 
  # reaction is activated and to evalute triggers when the snooze is complete.
  class ReactionSnoozeManager
    SNOOZE_METRIC_NAME = 'snooze_manager_duration_seconds'.freeze

    attr_reader :name, :scope, :share, :thread_pool

    def initialize(name:, scope:, share:)
      @name = name
      @scope = scope
      @share = share
      @worker_count = 3
      @thread_pool = nil
      @cancel_thread = false
      @metric = Metric.new(microservice: @name, scope: @scope)
      @metric_output_time = 0
    end

    def generate_thread_pool()
      thread_pool = []
      @worker_count.times do | i |
        worker = ReactionWorker.new(name: @name, scope: @scope, share: @share, ident: i)
        thread_pool << Thread.new { worker.run }
      end
      return thread_pool
    end

    def run
      Logger.info "ReactionSnoozeManager running"
      @thread_pool = generate_thread_pool()
      loop do
        begin
          current_time = Time.now.to_i
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          manage_snoozed_reactions(current_time: current_time)
          diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
          metric_labels = { 'type' => 'snooze', 'thread' => "manager" }
          @metric.add_sample(name: SNOOZE_METRIC_NAME, value: diff, labels: metric_labels)
          if @metric_output_time < current_time
            @metric.output
            @metric_output_time = current_time + 120
          end
        rescue StandardError => e
          Logger.error "ReactionSnoozeManager failed to snooze reactions.\n#{e.formatted}"
        end
        break if @cancel_thread
        sleep(1)
        break if @cancel_thread
      end
      Logger.info "ReactionSnoozeManager exiting"
    end

    def active_triggers(reaction:)
      reaction.triggers.each do | trigger |
        t = TriggerModel.get(name: trigger['name'], group: trigger['group'], scope: @scope)
        return true if t && t.state
      end
      return false
    end

    def manage_snoozed_reactions(current_time:)
      @share.reaction_base.get_snoozed.each do | reaction |
        time_difference = reaction.snoozed_until - current_time
        if time_difference <= 0 && @share.snooze_base.not_queued?(reaction: reaction)
          Logger.info "#{reaction.name} current: #{current_time}, vs #{reaction.snoozed_until}, #{time_difference}"
          unless reaction.review
            Logger.debug "#{reaction.name} review set to false, setting snoozed_until back to nil"
            @share.reaction_base.wake(name: reaction.name)
            next
          end
          if active_triggers(reaction: reaction)
            @share.queue_base.enqueue(kind: 'reaction', data: reaction.as_json(:allow_nan => true))
          else
            @share.reaction_base.wake(name: reaction.name)
          end
        end
      end
    end

    def shutdown
      @cancel_thread = true
      @worker_count.times do | i |
        @share.queue_base.enqueue(kind: nil, data: nil)
      end
    end
  end

  # The reaction microservice starts a manager then gets the
  # reactions and triggers from redis. It then monitors the
  # AutonomicTopic for changes.
  class ReactionMicroservice < Microservice
    ACTION_METRIC_NAME = 'reactions_duration_seconds'.freeze

    attr_reader :name, :scope, :share, :manager, :manager_thread

    def initialize(*args)
      super(*args)
      @share = ReactionShare.new(scope: @scope)
      @manager = ReactionSnoozeManager.new(name: @name, scope: @scope, share: @share)
      @manager_thread = nil
      @read_topic = true
    end

    def run
      Logger.info "ReactionMicroservice running"
      @manager_thread = Thread.new { @manager.run }
      loop do
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        reactions = ReactionModel.all(scope: @scope)
        @share.reaction_base.setup(reactions: reactions)
        diff = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start # seconds as a float
        @metric.add_sample(name: ACTION_METRIC_NAME, value: diff, labels: { 'thread' => 'microservice' })
        break if @cancel_thread

        block_for_updates()
        break if @cancel_thread
      end
      Logger.info "ReactionMicroservice exiting"
    end

    def topic_lookup_functions
      return {
        'group' => {
          'created' => :no_op,
          'updated' => :no_op,
          'deleted' => :no_op,
        },
        'trigger' => {
          'created' => :no_op,
          'updated' => :no_op,
          'deleted' => :no_op,
          'enabled' => :trigger_enabled_event,
          'disabled' => :no_op,
          'activated' => :no_op,
          'deactivated' => :no_op,
        },
        'reaction' => {
          'created' => :reaction_created_event,
          'updated' => :refresh_event,
          'deleted' => :reaction_deleted_event,
          'sleep' => :no_op,
          'awaken' => :no_op,
          'activated' => :reaction_updated_event,
          'deactivated' => :reaction_updated_event,
        }
      }
    end

    def block_for_updates
      @read_topic = true
      while @read_topic
        begin
          AutonomicTopic.read_topics(@topics) do |_topic, _msg_id, msg_hash, _redis|
            Logger.debug "ReactionMicroservice block_for_updates: #{msg_hash.to_s}"
            public_send(topic_lookup_functions[msg_hash['type']][msg_hash['kind']], msg_hash)
          end
        rescue StandardError => e
          Logger.error "ReactionMicroservice failed to read topics #{@topics}\n#{e.formatted}"
        end
      end
    end

    def no_op(data)
      Logger.debug "ReactionMicroservice web socket event: #{data}"
    end

    def refresh_event(data)
      Logger.debug "ReactionMicroservice web socket schedule refresh: #{data}"
      @read_topic = false
    end

    # 
    def trigger_enabled_event(msg_hash)
      Logger.debug "ReactionMicroservice trigger event msg_hash: #{msg_hash}"
      @share.queue_base.enqueue(kind: 'trigger', data: JSON.parse(msg_hash['data'], :allow_nan => true, :create_additions => true))
    end

    # Add the reaction to the shared data. 
    def reaction_created_event(msg_hash)
      Logger.debug "ReactionMicroservice reaction created msg_hash: #{msg_hash}"
      @share.reaction_base.add(reaction: JSON.parse(msg_hash['data'], :allow_nan => true, :create_additions => true))
    end

    # Update the reaction to the shared data. 
    def reaction_updated_event(msg_hash)
      Logger.debug "ReactionMicroservice reaction updated msg_hash: #{msg_hash}"
      @share.reaction_base.update(reaction: JSON.parse(msg_hash['data'], :allow_nan => true, :create_additions => true))
    end

    # Remove the reaction from the shared data
    def reaction_deleted_event(msg_hash)
      Logger.debug "ReactionMicroservice reaction deleted msg_hash: #{msg_hash}"
      @share.reaction_base.remove(reaction: JSON.parse(msg_hash['data'], :allow_nan => true, :create_additions => true))
    end

    def shutdown
      @read_topic = false
      @manager.shutdown()
      super
    end
  end
end

OpenC3::ReactionMicroservice.run if __FILE__ == $0
