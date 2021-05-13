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

require 'cosmos/models/model'
require 'cosmos/models/activity_model'
require 'cosmos/models/microservice_model'
require 'cosmos/topics/timeline_topic'


module Cosmos

  class TimelineError < StandardError; end

  class TimelineInputError < TimelineError; end

  class TimelineModel < Model
    PRIMARY_KEY = "cosmos_timelines"
    KEY = "__TIMELINE__"

    # @return [TimelineModel] Return the object with the name at
    def self.get(name:, scope:)
      json = super(PRIMARY_KEY, name: "#{scope}#{KEY}#{name}")
      unless json.nil?
        self.from_json(json, name: name, scope: scope)
      end
    end

    # @return [Array<Hash>] All the Key, Values stored under the name key
    def self.all
      super(PRIMARY_KEY)
    end

    # @return [Array<String>] All the names stored under the name key
    def self.names
      super(PRIMARY_KEY)
    end

    # Remove the sorted set.
    def self.delete(name:, scope:, force: false)
      key = "#{scope}__#{PRIMARY_KEY}__#{name}"
      z = Store.zcard(key)
      if force == false && z > 0
        raise TimelineError.new "timeline contains activities, must force remove"
      end
      Store.multi do |multi|
        multi.del(key)
        multi.hdel(PRIMARY_KEY, "#{scope}#{KEY}#{name}")
      end
      return name
    end

    def initialize(name:, scope:, updated_at: nil)
      if name.nil? || scope.nil?
        raise TimelineInputError.new "name or scope must not be nil"
      end
      super(PRIMARY_KEY, name: "#{scope}#{KEY}#{name}", scope: scope)
      @updated_at = updated_at
    end

    # @return [Hash] generated from the TimelineModel
    def as_json
      {
        'name' => @name,
        'scope' => @scope,
        'updated_at' => @updated_at}
    end

    # @return [TimelineModel] Model generated from the passed JSON
    def self.from_json(json, name:, scope:)
      json = JSON.parse(json) if String === json
      raise "json data is nil" if json.nil?
      json.transform_keys!(&:to_sym)
      self.new(**json, name: name, scope: scope)
    end

    # @return [] update the redis stream / timeline topic that something has changed
    def notify(kind:)
      notification = Hash.new()
      notification["data"] = as_json()
      notification["kind"] = kind
      notification["type"] = "timeline"
      TimelineTopic.write_activity(notification, scope: @scope)
    end

    def deploy
      topics = generate_topic()
      notify(kind: "create")
      generate_microservice(topics)
    end

    def generate_topic
      topics = ["#{@scope}__#{PRIMARY_KEY}"]
      TimelineTopic.initialize_streams(topics)
      return topics
    end

    def generate_microservice(topics)
      # DecomLog Microservice
      microservice = MicroserviceModel.new(
        name: @name,
        folder_name: nil,
        cmd: ["ruby", "timeline_microservice.rb", @name],
        work_dir: '/cosmos/lib/cosmos/microservices',
        options: [],
        topics: topics,
        target_names: [],
        plugin: nil,
        scope: @scope)
      microservice.create
    end

    def undeploy
      model = MicroserviceModel.get_model(name: @name, scope: @scope)
      model.destroy if model
    end

  end
end
