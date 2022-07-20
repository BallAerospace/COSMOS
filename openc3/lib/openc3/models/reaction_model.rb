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

require 'openc3/models/model'
require 'openc3/models/trigger_model'
require 'openc3/models/microservice_model'
require 'openc3/topics/autonomic_topic'

module OpenC3
  class ReactionError < StandardError; end

  class ReactionInputError < ReactionError; end

  #  {
  #    "description": "POSX greater than 200",
  #    "snooze": 300,
  #    "review": true,
  #    "triggers": [
  #      {
  #        "name": "TV0-1234",
  #        "group": "foo",
  #      }
  #    ],
  #    "actions": [
  #      {
  #        "type": "command",
  #        "value": "INST CLEAR",
  #      }
  #    ]
  #  }
  class ReactionModel < Model
    PRIMARY_KEY = '__openc3__reaction'.freeze
    COMMAND_REACTION = 'command'.freeze
    SCRIPT_REACTION = 'script'.freeze

    def self.create_mini_id
      time = (Time.now.to_f * 10_000_000).to_i
      jitter = rand(10_000_000) 
      key = "#{jitter}#{time}".to_i.to_s(36)
      return "RV0-#{key}"
    end

    # @return [Array<ReactionModel>]
    def self.reactions(scope:)
      reactions = Array.new
      Store.hgetall("#{scope}#{PRIMARY_KEY}").each do |key, value|
        data = JSON.parse(value, :allow_nan => true, :create_additions => true)
        reaction = self.from_json(data, name: data['name'], scope: data['scope'])
        reactions << reaction if reaction.active
      end
      return reactions
    end

    # @return [ReactionModel] Return the object with the name at
    def self.get(name:, scope:)
      json = super("#{scope}#{PRIMARY_KEY}", name: name)
      unless json.nil?
        self.from_json(json, name: name, scope: scope)
      end
    end

    # @return [Array<Hash>] All the Key, Values stored under the name key
    def self.all(scope:)
      super("#{scope}#{PRIMARY_KEY}")
    end

    # @return [Array<String>] All the uuids stored under the name key
    def self.names(scope:)
      super("#{scope}#{PRIMARY_KEY}")
    end

    # Check dependents before delete.
    def self.delete(name:, scope:, force: false)
      model = self.get(name: name, scope: scope)
      if model.nil?
        raise ReactionInputError.new "failed to find reaction: #{name}"
      end
      model.triggers.each do | trigger |
        trigger_model = TriggerModel.get(name: trigger['name'], group: trigger['group'], scope: scope)
        trigger_model.update_dependents(dependent: name, remove: true)
        trigger_model.update()
      end
      Store.hdel("#{scope}#{PRIMARY_KEY}", name)
      model.notify(kind: 'deleted')
    end

    #
    def validate_snooze(snooze:)
      unless snooze.is_a?(Integer)
        raise ReactionInputError.new "invalid snooze value: #{snooze}"
      end
      if snooze < 30
        raise ReactionInputError.new "invalid snooze: '#{snooze}' must be greater than 30"
      end
      return snooze
    end

    #
    def validate_triggers(triggers:)
      unless triggers.is_a?(Array)
        raise ReactionInputError.new "invalid operator: #{operator}"
      end
      trigger_hash = Hash.new()
      triggers.each do | trigger |
        unless trigger.is_a?(Hash)
          raise ReactionInputError.new "invalid trigger object: #{trigger}"
        end
        if trigger['name'].nil? || trigger['group'].nil?
          raise ReactionInputError.new "allowed: #{triggers}"
        end
        trigger_name = trigger['name']
        unless trigger_hash[trigger_name].nil?
          raise ReactionInputError.new "no duplicate triggers allowed: #{triggers}"
        else
          trigger_hash[trigger_name] = 1
        end
      end
      return triggers
    end

    #
    def validate_actions(actions:)
      unless actions.is_a?(Array)
        raise ReactionInputError.new "invalid actions object: #{actions}"
      end
      actions.each do | action |
        unless action.is_a?(Hash)
          raise ReactionInputError.new "invalid action object: #{action}"
        end
        action_type = action['type']
        if action_type.nil?
          raise ReactionInputError.new "reaction action must contain type: #{action_type}"
        elsif action['value'].nil?
          raise ReactionInputError.new "reaction action: #{action} does not contain 'value'"
        end
        unless [COMMAND_REACTION, SCRIPT_REACTION].include?(action_type)
          raise ReactionInputError.new "reaction action contains invalid type: #{action_type}"
        end
      end
      return actions
    end

    attr_reader :name, :scope, :description, :snooze, :triggers, :actions, :active, :review, :snoozed_until

    def initialize(
      name:,
      scope:,
      description:,
      snooze:,
      actions:,
      triggers:,
      active: true,
      review: true,
      snoozed_until: nil,
      updated_at: nil
    )
      if name.nil? || scope.nil? || description.nil? || snooze.nil? || triggers.nil? || actions.nil?
        raise ReactionInputError.new "#{name}, #{scope}, #{description}, #{snooze}, #{triggers}, or #{actions} must not be nil"
      end
      super("#{scope}#{PRIMARY_KEY}", name: name, scope: scope)
      @microservice_name = "#{scope}__OPENC3__REACTION"
      @active = active
      @review = review
      @description = description
      @snoozed_until = snoozed_until
      @snooze = validate_snooze(snooze: snooze)
      @actions = validate_actions(actions: actions)
      @triggers = validate_triggers(triggers: triggers)
      @updated_at = updated_at
    end

    def verify_triggers
      trigger_models = []
      @triggers.each do | trigger |
        model = TriggerModel.get(name: trigger['name'], group: trigger['group'], scope: @scope)
        if model.nil?
          raise ReactionInputError.new "failed to find trigger: #{trigger}"
        end
        trigger_models << model
      end
      if trigger_models.empty?
        raise ReactionInputError.new "reaction must contain at least one valid trigger: #{@triggers}"
      end
      trigger_models.each do | trigger_model |
        trigger_model.update_dependents(dependent: @name)
        trigger_model.update()
      end
    end

    def create
      unless Store.hget(@primary_key, @name).nil?
        raise ReactionInputError.new "exsisting Reaction found: #{@name}"
      end
      verify_triggers()
      @updated_at = Time.now.to_nsec_from_epoch
      Store.hset(@primary_key, @name, JSON.generate(as_json(:allow_nan => true)))
      notify(kind: 'created')
    end

    def update
      verify_triggers()
      @updated_at = Time.now.to_nsec_from_epoch
      Store.hset(@primary_key, @name, JSON.generate(as_json(:allow_nan => true)))
      notify(kind: 'updated')
    end

    def activate
      @active = true
      @snoozed_until = nil if @snoozed_until && @snoozed_until < Time.now.to_i
      @updated_at = Time.now.to_nsec_from_epoch
      Store.hset(@primary_key, @name, JSON.generate(as_json(:allow_nan => true)))
      notify(kind: 'activated')
    end

    def deactivate
      @active = false
      @updated_at = Time.now.to_nsec_from_epoch
      Store.hset(@primary_key, @name, JSON.generate(as_json(:allow_nan => true)))
      notify(kind: 'deactivated')
    end

    def sleep
      @snoozed_until = Time.now.to_i + @snooze
      @updated_at = Time.now.to_nsec_from_epoch
      Store.hset(@primary_key, @name, JSON.generate(as_json(:allow_nan => true)))
      notify(kind: 'sleep')
    end

    def awaken
      @snoozed_until = nil
      @updated_at = Time.now.to_nsec_from_epoch
      Store.hset(@primary_key, @name, JSON.generate(as_json(:allow_nan => true)))
      notify(kind: 'awaken')
    end

    # @return [String] generated from the TriggerModel
    def to_s
      return "(ReactionModel :: #{@name} :: #{@active} :: #{@review} :: #{@description} :: #{@snooze} :: #{@snoozed_until})"
    end

    # @return [Hash] generated from the ReactionModel
    def as_json(*a)
      return {
        'name' => @name,
        'scope' => @scope,
        'active' => @active,
        'review' => @review,
        'description' => @description,
        'snooze' => @snooze,
        'snoozed_until' => @snoozed_until,
        'triggers' => @triggers,
        'actions' => @actions,
        'updated_at' => @updated_at
      }
    end

    # @return [ReactionModel] Model generated from the passed JSON
    def self.from_json(json, name:, scope:)
      json = JSON.parse(json, :allow_nan => true, :create_additions => true) if String === json
      raise "json data is nil" if json.nil?

      json.transform_keys!(&:to_sym)
      self.new(**json, name: name, scope: scope)
    end

    # @return [] update the redis stream / reaction topic that something has changed
    def notify(kind:)
      notification = {
        'kind' => kind,
        'type' => 'reaction',
        'data' => JSON.generate(as_json(:allow_nan => true)),
      }
      AutonomicTopic.write_notification(notification, scope: @scope)
    end

    def create_microservice(topics:)
      # reaction Microservice
      microservice = MicroserviceModel.new(
        name: @microservice_name,
        folder_name: nil,
        cmd: ['ruby', 'reaction_microservice.rb', @microservice_name],
        work_dir: '/openc3/lib/openc3/microservices',
        options: [],
        topics: topics,
        target_names: [],
        plugin: nil,
        scope: @scope
      )
      microservice.create
    end

    def deploy
      topics = ["#{@scope}__openc3_autonomic"]
      if MicroserviceModel.get_model(name: @microservice_name, scope: @scope).nil?
        create_microservice(topics: topics)
      end
    end

    def undeploy
      if ReactionModel.names(scope: @scope).empty?
        model = MicroserviceModel.get_model(name: @microservice_name, scope: @scope)
        model.destroy if model
      end
    end
  end
end
