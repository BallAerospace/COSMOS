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

# https://www.rubydoc.info/gems/redis/Redis/Commands/SortedSets

require 'openc3/models/model'
require 'openc3/topics/timeline_topic'

module OpenC3
  class ActivityError < StandardError; end

  class ActivityInputError < ActivityError; end

  class ActivityOverlapError < ActivityError; end

  class ActivityModel < Model
    MAX_DURATION = Time::SEC_PER_DAY
    PRIMARY_KEY = '__openc3_timelines'.freeze # MUST be equal to `TimelineModel::PRIMARY_KEY` minus the leading __

    # Called via the microservice this gets the previous 00:00:15 to 01:01:00. This should allow
    # for a small buffer around the timeline to make sure the schedule doesn't get stale.
    # 00:00:15 was selected as the schedule queue used in the microservice has round robin array
    # with 15 slots to make sure we don't miss a planned task.
    # @return [Array|nil] Array of the next hour in the sorted set
    def self.activities(name:, scope:)
      now = Time.now.to_i
      start_score = now - 15
      stop_score = (now + 3660)
      array = Store.zrangebyscore("#{scope}#{PRIMARY_KEY}__#{name}", start_score, stop_score)
      ret_array = Array.new
      array.each do |value|
        ret_array << ActivityModel.from_json(value, name: name, scope: scope)
      end
      return ret_array
    end

    # @return [Array|nil] Array up to 100 of this model or empty array if name not found under primary_key
    def self.get(name:, start:, stop:, scope:, limit: 100)
      if start > stop
        raise ActivityInputError.new "start: #{start} must be before stop: #{stop}"
      end

      array = Store.zrangebyscore("#{scope}#{PRIMARY_KEY}__#{name}", start, stop, :limit => [0, limit])
      ret_array = Array.new
      array.each do |value|
        ret_array << JSON.parse(value, :allow_nan => true, :create_additions => true)
      end
      return ret_array
    end

    # @return [Array<Hash>] Array up to the limit of the models (as Hash objects) stored under the primary key
    def self.all(name:, scope:, limit: 100)
      array = Store.zrange("#{scope}#{PRIMARY_KEY}__#{name}", 0, -1, :limit => [0, limit])
      ret_array = Array.new
      array.each do |value|
        ret_array << JSON.parse(value, :allow_nan => true, :create_additions => true)
      end
      return ret_array
    end

    # @return [String|nil] String of the saved json or nil if score not found under primary_key
    def self.score(name:, score:, scope:)
      array = Store.zrangebyscore("#{scope}#{PRIMARY_KEY}__#{name}", score, score, :limit => [0, 1])
      array.each do |value|
        return ActivityModel.from_json(value, name: name, scope: scope)
      end
      return nil
    end

    # @return [Integer] count of the members stored under the primary key
    def self.count(name:, scope:)
      return Store.zcard("#{scope}#{PRIMARY_KEY}__#{name}")
    end

    # Remove one member from a sorted set.
    # @return [Integer] count of the members removed
    def self.destroy(name:, scope:, score:)
      Store.zremrangebyscore("#{scope}#{PRIMARY_KEY}__#{name}", score, score)
    end

    # Remove members from min to max of the sorted set.
    # @return [Integer] count of the members removed
    def self.range_destroy(name:, scope:, min:, max:)
      Store.zremrangebyscore("#{scope}#{PRIMARY_KEY}__#{name}", min, max)
    end

    # @return [ActivityModel] Model generated from the passed JSON
    def self.from_json(json, name:, scope:)
      json = JSON.parse(json, :allow_nan => true, :create_additions => true) if String === json
      raise "json data is nil" if json.nil?

      json.transform_keys!(&:to_sym)
      self.new(**json, name: name, scope: scope)
    end

    attr_reader :duration, :start, :stop, :kind, :data, :events, :fulfillment

    def initialize(
      name:,
      start:,
      stop:,
      kind:,
      data:,
      scope:,
      updated_at: 0,
      duration: 0,
      fulfillment: nil,
      events: nil
    )
      super("#{scope}#{PRIMARY_KEY}__#{name}", name: name, scope: scope)
      set_input(
        fulfillment: fulfillment,
        start: start,
        stop: stop,
        kind: kind,
        data: data,
        events: events,
      )
      @updated_at = updated_at
    end

    # validate_time will be called on create this will pull the time up to MAX_DURATION of an activity
    # this will make sure that the activity is the only activity on the timeline for the duration of the
    # activity. Score is the Seconds since the Unix Epoch: (%s) Number of seconds since 1970-01-01 00:00:00 UTC.
    # We then search back from the stop of the activity and check to see if any activities are in the
    # last x seconds (MAX_DURATION), if the zrange rev byscore finds activites from in reverse order so the
    # first task is the closest task to the current score. In this a parameter ignore_score allows the request
    # to ignore that time and skip to the next time but if nothing is found in the time range we can return nil.
    #
    # @param [Integer] ignore_score - should be nil unless you want to ignore a time when doing an update
    def validate_time(ignore_score = nil)
      max_score = @start - MAX_DURATION
      array = Store.zrevrangebyscore(@primary_key, @stop, max_score)
      array.each do |value|
        activity = JSON.parse(value, :allow_nan => true, :create_additions => true)
        if ignore_score == activity['start']
          next
        elsif activity['stop'] > @start
          return activity['start']
        else
          return nil
        end
      end
      return nil
    end

    # validate the input to the rules we have created for timelines.
    # - A task's start MUST NOT be in the past.
    # - A task's start MUST be before the stop.
    # - A task CAN NOT be longer than MAX_DURATION (86400) in seconds.
    # - A task MUST have a kind.
    # - A task MUST have a data object/hash.
    def validate_input(start:, stop:, kind:, data:)
      begin
        DateTime.strptime(start.to_s, '%s')
        DateTime.strptime(stop.to_s, '%s')
      rescue Date::Error
        raise ActivityInputError.new "failed validation input must be seconds: #{start}, #{stop}"
      end
      now_i = Time.now.to_i + 10
      duration = stop - start
      if now_i >= start
        raise ActivityInputError.new "activity must be in the future, current_time: #{now_i} vs #{start}"
      elsif duration >= MAX_DURATION
        raise ActivityInputError.new "activity can not be longer than #{MAX_DURATION} seconds"
      elsif duration <= 0
        raise ActivityInputError.new "start: #{start} must be before stop: #{stop}"
      elsif kind.nil?
        raise ActivityInputError.new "kind must not be nil: #{kind}"
      elsif data.nil?
        raise ActivityInputError.new "data must not be nil: #{data}"
      elsif data.is_a?(Hash) == false
        raise ActivityInputError.new "data must be a json object/hash: #{data}"
      end
    end

    # Set the values of the instance, @start, @kind, @data, @events...
    def set_input(start:, stop:, kind: nil, data: nil, events: nil, fulfillment: nil)
      begin
        DateTime.strptime(start.to_s, '%s')
        DateTime.strptime(stop.to_s, '%s')
      rescue ArgumentError
        raise ActivityInputError.new "invalid input must be seconds: #{start}, #{stop}"
      end
      @start = start
      @stop = stop
      @duration = @stop - @start
      @fulfillment = fulfillment.nil? ? false : fulfillment
      @kind = kind.nil? ? @kind : kind
      @data = data.nil? ? @data : data
      @events = events.nil? ? Array.new : events
    end

    # Update the Redis hash at primary_key and set the score equal to the start Epoch time
    # the member is set to the JSON generated via calling as_json
    def create
      validate_input(start: @start, stop: @stop, kind: @kind, data: @data)
      collision = validate_time()
      unless collision.nil?
        raise ActivityOverlapError.new "no activities can overlap, collision: #{collision}"
      end

      @updated_at = Time.now.to_nsec_from_epoch
      add_event(status: 'created')
      Store.zadd(@primary_key, @start, JSON.generate(self.as_json(:allow_nan => true)))
      notify(kind: 'created')
    end

    # Update the Redis hash at primary_key and remove the current activity at the current score
    # and update the score to the new score equal to the start Epoch time this uses a multi
    # to execute both the remove and create. The member via the JSON generated via calling as_json
    def update(start:, stop:, kind:, data:)
      array = Store.zrangebyscore(@primary_key, @start, @start)
      if array.length == 0
        raise ActivityError.new "failed to find activity at: #{@start}"
      end

      validate_input(start: start, stop: stop, kind: kind, data: data)
      old_start = @start
      set_input(start: start, stop: stop, kind: kind, data: data, events: @events)
      @updated_at = Time.now.to_nsec_from_epoch
      # copy of create
      collision = validate_time(old_start)
      unless collision.nil?
        raise ActivityOverlapError.new "failed to update #{old_start}, no activities can overlap, collision: #{collision}"
      end

      add_event(status: 'updated')
      Store.multi do |multi|
        multi.zremrangebyscore(@primary_key, old_start, old_start)
        multi.zadd(@primary_key, @start, JSON.generate(self.as_json(:allow_nan => true)))
      end
      notify(kind: 'updated', extra: old_start)
      return @start
    end

    # commit will make an event and save the object to the redis database
    # @param [String] status - the event status such as "complete" or "failed"
    # @param [String] message - an optional message to include in the event
    def commit(status:, message: nil, fulfillment: nil)
      event = {
        'time' => Time.now.to_i,
        'event' => status,
        'commit' => true
      }
      event['message'] = message unless message.nil?
      @fulfillment = fulfillment.nil? ? @fulfillment : fulfillment
      @events << event
      Store.multi do |multi|
        multi.zremrangebyscore(@primary_key, @start, @start)
        multi.zadd(@primary_key, @start, JSON.generate(self.as_json(:allow_nan => true)))
      end
      notify(kind: 'event')
    end

    # add_event will make an event. This will NOT save the object to the redis database
    # @param [String] status - the event status such as "queued" or "updated" or "created"
    def add_event(status:)
      event = {
        'time' => Time.now.to_i,
        'event' => status
      }
      @events << event
    end

    # destroy the activity from the redis database
    def destroy
      Store.zremrangebyscore(@primary_key, @start, @start)
      notify(kind: 'deleted')
    end

    # @return [] update the redis stream / timeline topic that something has changed
    def notify(kind:, extra: nil)
      notification = {
        'data' => JSON.generate(as_json(:allow_nan => true)),
        'kind' => kind,
        'type' => 'activity',
        'timeline' => @name
      }
      notification['extra'] = extra unless extra.nil?
      begin
        TimelineTopic.write_activity(notification, scope: @scope)
      rescue StandardError => e
        raise ActivityError.new "Failed to write to stream: #{notification}, #{e}"
      end
    end

    # @return [Hash] generated from the ActivityModel
    def as_json(*a)
      {
        'name' => @name,
        'updated_at' => @updated_at,
        'fulfillment' => @fulfillment,
        'duration' => @duration,
        'start' => @start,
        'stop' => @stop,
        'kind' => @kind,
        'events' => @events,
        'data' => @data.as_json(*a)
      }
    end
  end
end
