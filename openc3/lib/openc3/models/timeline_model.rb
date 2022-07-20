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
require 'openc3/models/activity_model'
require 'openc3/models/microservice_model'
require 'openc3/topics/timeline_topic'

module OpenC3
  class TimelineError < StandardError; end

  class TimelineInputError < TimelineError; end

  class TimelineModel < Model
    PRIMARY_KEY = 'openc3_timelines'.freeze # MUST be equal to ActivityModel::PRIMARY_KEY without leading __
    KEY = '__TIMELINE__'.freeze

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

    # @return [TimelineModel] Model generated from the passed JSON
    def self.from_json(json, name:, scope:)
      json = JSON.parse(json) if String === json
      raise "json data is nil" if json.nil?

      json.transform_keys!(&:to_sym)
      self.new(**json, name: name, scope: scope)
    end

    def initialize(name:, scope:, updated_at: nil, color: nil)
      if name.nil? || scope.nil?
        raise TimelineInputError.new "name or scope must not be nil"
      end

      super(PRIMARY_KEY, name: "#{scope}#{KEY}#{name}", scope: scope)
      @updated_at = updated_at
      @timeline_name = name
      update_color(color: color)
    end

    def update_color(color: nil)
      if color.nil?
        color = '#%06x' % (rand * 0xffffff)
      end
      valid_color = color =~ /(#*)([0-9,a-f,A-f]{6})/
      if valid_color.nil?
        raise RuntimeError.new "invalid color but in hex format. #FF0000"
      end

      unless color.start_with?('#')
        color = "##{color}"
      end
      @color = color
    end

    # @return [Hash] generated from the TimelineModel
    def as_json(*a)
      {
        'name' => @timeline_name,
        'color' => @color,
        'scope' => @scope,
        'updated_at' => @updated_at
      }
    end

    # @return [] update the redis stream / timeline topic that something has changed
    def notify(kind:)
      notification = {
        'data' => JSON.generate(as_json(:allow_nan => true)),
        'kind' => kind,
        'type' => 'timeline',
        'timeline' => @timeline_name
      }
      begin
        TimelineTopic.write_activity(notification, scope: @scope)
      rescue StandardError => e
        raise TimelineInputError.new "Failed to write to stream: #{notification}, #{e}"
      end
    end

    def deploy
      topics = ["#{@scope}__#{PRIMARY_KEY}"]
      TimelineTopic.initialize_streams(topics)
      # Timeline Microservice
      microservice = MicroserviceModel.new(
        name: @name,
        folder_name: nil,
        cmd: ['ruby', 'timeline_microservice.rb', @name],
        work_dir: '/openc3/lib/openc3/microservices',
        options: [],
        topics: topics,
        target_names: [],
        plugin: nil,
        scope: @scope
      )
      microservice.create
      notify(kind: 'created')
    end

    def undeploy
      model = MicroserviceModel.get_model(name: @name, scope: @scope)
      if model
        model.destroy
        notify(kind: 'deleted')
      end
    end
  end
end
