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
require 'openc3/models/microservice_model'
require 'openc3/models/target_model'
require 'openc3/topics/autonomic_topic'

module OpenC3
  class TriggerError < StandardError; end

  class TriggerInputError < TriggerError; end

  # INPUT:
  #  {
  #    "group": "someGroup",
  #    "left": {
  #      "type": "item",
  #      "target": "INST",
  #      "packet": "ADCS",
  #      "item": "POSX",
  #    },
  #    "operator": ">",
  #    "right": {
  #      "type": "value",
  #      "value": 690000,
  #    }
  #  }
  class TriggerModel < Model
    PRIMARY_KEY = '__TRIGGERS__'.freeze
    ITEM_TYPE = 'item'.freeze
    LIMIT_TYPE = 'limit'.freeze
    FLOAT_TYPE = 'float'.freeze
    STRING_TYPE = 'string'.freeze
    TRIGGER_TYPE = 'trigger'.freeze

    def self.create_mini_id
      time = (Time.now.to_f * 10_000_000).to_i
      jitter = rand(10_000_000) 
      key = "#{jitter}#{time}".to_i.to_s(36)
      return "TV0-#{key}"
    end

    # @return [TriggerModel] Return the object with the name at
    def self.get(name:, group:, scope:)
      json = super("#{scope}#{PRIMARY_KEY}#{group}", name: name)
      unless json.nil?
        self.from_json(json, name: name, scope: scope)
      end
    end

    # @return [Array<Hash>] All the Key, Values stored under the name key
    def self.all(group:, scope:)
      super("#{scope}#{PRIMARY_KEY}#{group}")
    end

    # @return [Array<String>] All the uuids stored under the name key
    def self.names(group:, scope:)
      super("#{scope}#{PRIMARY_KEY}#{group}")
    end

    # Check dependents before delete.
    def self.delete(name:, group:, scope:)
      model = self.get(name: name, group: group, scope: scope)
      if model.nil?
        raise TriggerInputError.new "invalid operation group: #{group} trigger: #{name} not found"
      end
      unless model.dependents.empty?
        raise TriggerError.new "failed to delete #{name} dependents: #{model.dependents}"
      end
      model.roots.each do | trigger |
        trigger_model = self.get(name: trigger, group: group, scope: scope)
        trigger_model.update_dependents(dependent: name, remove: true)
        trigger_model.update()
      end
      Store.hdel("#{scope}#{PRIMARY_KEY}#{group}", name)
      model.notify(kind: 'deleted')
    end

    def validate_operand(operand:)
      unless operand.is_a?(Hash)
        raise TriggerInputError.new "invalid operand: #{operand}"
      end
      operand_types = [ITEM_TYPE, LIMIT_TYPE, FLOAT_TYPE, STRING_TYPE, TRIGGER_TYPE]
      unless operand_types.include?(operand['type'])
        raise TriggerInputError.new "invalid operand type: #{operand['type']} must be of type: #{operand_types}"
      end
      if operand[operand['type']].nil?
        raise TriggerInputError.new "invalid operand must contain type: #{operand}"
      end
      case operand['type']
      when ITEM_TYPE
        if operand['target'].nil? || operand['packet'].nil? || operand['raw'].nil?
          raise TriggerInputError.new "invalid operand must contain target, packet, item, and raw: #{operand}"
        end
      when TRIGGER_TYPE
        @roots << operand[operand['type']]
      end
      return operand
    end

    def validate_operator(operator:)
      unless operator.is_a?(String)
        raise TriggerInputError.new "invalid operator: #{operator}"
      end
      operators = ['>', '<', '>=', '<=']
      match_operators = ['==', '!=']
      trigger_operators = ['AND', 'OR']
      if @roots.empty? && operators.include?(operator)
        return operator
      elsif @roots.empty? && match_operators.include?(operator)
        return operator
      elsif @roots.size() == 2 && trigger_operators.include?(operator)
        return operator
      elsif operators.include?(operator)
        raise TriggerInputError.new "invalid operator pair: '#{operator}' must be of type: #{trigger_operators}"
      else
        raise TriggerInputError.new "invalid operator: '#{operator}' must be of type: #{operators}"
      end
    end

    def validate_description(description:)
      if description.nil?
        left_type = @left['type']
        right_type = @right['type']
        return "#{@left[left_type]} #{@operator} #{@right[right_type]}"
      end
      unless description.is_a?(String)
        raise TriggerInputError.new "invalid description: #{description}"
      end
      return description
    end

    attr_reader :name, :scope, :state, :group, :active, :left, :operator, :right, :dependents, :roots

    #
    def initialize(
      name:,
      scope:,
      group:,
      left:,
      operator:,
      right:,
      state: false,
      active: true,
      description: nil,
      dependents: nil,
      updated_at: nil
    )
      if name.nil? || scope.nil? || group.nil? || left.nil? || operator.nil? || right.nil?
        raise TriggerInputError.new "#{name}, #{scope}, #{group}, #{left}, #{operator}, or #{right} must not be nil"
      end
      super("#{scope}#{PRIMARY_KEY}#{group}", name: name, scope: scope)
      @roots = []
      @group = group
      @state = state
      @active = active
      @left = validate_operand(operand: left)
      @right = validate_operand(operand: right)
      @operator = validate_operator(operator: operator)
      @description = validate_description(description: description)
      @dependents = dependents
      @updated_at = updated_at
    end

    def verify_triggers
      unless @group.is_a?(String)
        raise TriggerInputError.new "invalid group: #{@group}"
      end
      selected_group = OpenC3::TriggerGroupModel.get(name: @group, scope: @scope)
      if selected_group.nil?
        raise TriggerGroupInputError.new "failed to find group: #{@group}"
      end
      @dependents = [] if @dependents.nil?
      @roots.each do | trigger |
        model = TriggerModel.get(name: trigger, group: @group, scope: @scope)
        if model.nil?
          raise TriggerInputError.new "failed to find dependent trigger: #{trigger}"
        end
        if model.group != @group
          raise TriggerInputError.new "failed group dependent trigger: #{trigger}"
        end
        unless model.dependents.include?(@name)
          model.update_dependents(dependent: @name)
          model.update()
        end
      end
    end

    def create
      unless Store.hget(@primary_key, @name).nil?
        raise TriggerInputError.new "exsisting Trigger found: #{@name}"
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

    def enable
      @state = true
      @updated_at = Time.now.to_nsec_from_epoch
      Store.hset(@primary_key, @name, JSON.generate(as_json(:allow_nan => true)))
      notify(kind: 'enabled')
    end

    def disable
      @state = false
      @updated_at = Time.now.to_nsec_from_epoch
      Store.hset(@primary_key, @name, JSON.generate(as_json(:allow_nan => true)))
      notify(kind: 'disabled')
    end

    def activate
      @active = true
      @updated_at = Time.now.to_nsec_from_epoch
      Store.hset(@primary_key, @name, JSON.generate(as_json(:allow_nan => true)))
      notify(kind: 'activated')
    end

    def deactivate
      @active = false
      @state = false
      @updated_at = Time.now.to_nsec_from_epoch
      Store.hset(@primary_key, @name, JSON.generate(as_json(:allow_nan => true)))
      notify(kind: 'deactivated')
    end

    def modify
      raise "TODO"
    end

    # ["#{@scope}__DECOM__{#{@target}}__#{@packet}"]
    def generate_topics
      topics = Hash.new
      if @left['type'] == ITEM_TYPE
        topics["#{@scope}__DECOM__{#{left['target']}}__#{left['packet']}"] = 1
      end
      if @right['type'] == ITEM_TYPE
        topics["#{@scope}__DECOM__{#{right['target']}}__#{right['packet']}"] = 1
      end
      return topics.keys
    end

    def update_dependents(dependent:, remove: false)
      if remove
        @dependents.delete(dependent)
      elsif @dependents.index(dependent).nil?
        @dependents << dependent
      end
    end

    # @return [String] generated from the TriggerModel
    def to_s
      return "(TriggerModel :: #{@name} :: #{group} :: #{@description})"
    end

    # @return [Hash] generated from the TriggerModel
    def as_json(*a)
      return {
        'name' => @name,
        'scope' => @scope,
        'state' => @state,
        'active' => @active,
        'group' => @group,
        'description' => @description,
        'dependents' => @dependents,
        'left' => @left,
        'operator' => @operator,
        'right' => @right,
        'updated_at' => @updated_at,
      }
    end

    # @return [TriggerModel] Model generated from the passed JSON
    def self.from_json(json, name:, scope:)
      json = JSON.parse(json, :allow_nan => true, :create_additions => true) if String === json
      raise "json data is nil" if json.nil?

      json.transform_keys!(&:to_sym)
      self.new(**json, name: name, scope: scope)
    end

    # @return [] update the redis stream / trigger topic that something has changed
    def notify(kind:)
      notification = {
        'kind' => kind,
        'type' => 'trigger',
        'data' => JSON.generate(as_json(:allow_nan => true)),
      }
      AutonomicTopic.write_notification(notification, scope: @scope)
    end

    # @param [String] kind - the status such as "event" or "error"
    # @param [String] message - an optional message to include in the event
    def log(kind:, message: nil)
      notification = {
        'kind' => kind,
        'type' => 'log',
        'time' => Time.now.to_i,
        'name' => @name,
      }
      notification['message'] = message unless message.nil?
      AutonomicTopic.write_notification(notification, scope: @scope)
    end
  end
end
