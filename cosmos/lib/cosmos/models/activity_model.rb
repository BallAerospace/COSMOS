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
require 'cosmos/topics/timeline_topic'


module Cosmos

  class ActivityError < StandardError; end

  class ActivityInputError < ActivityError; end

  class ActivityOverlapError < ActivityError; end

  class ActivityModel < Model
    MAX_DURATION = 86400
    PRIMARY_KEY = "__cosmos_timelines"

    attr_reader :score, :duration, :start_time, :end_time, :kind, :data, :events, :fulfillment

    # @return [Array|nil] Array of the next hour in the sorted set
    def self.activities(name:, scope:)
      now = DateTime.now.new_offset(0)
      start_score = now.strftime("%s").to_i
      stop_score = (now + (1.2/24.0)).strftime("%s").to_i
      array = Store.zrangebyscore("#{scope}#{PRIMARY_KEY}__#{name}", start_score, stop_score)
      ret_array = Array.new
      array.each do |value|
        ret_array << ActivityModel.from_json(value, name: name, scope: scope)
      end
      return ret_array
    end

    # @return [Array|nil] Array up to 100 of this model or empty array if name not found under primary_key
    def self.get(name:, start_time:, end_time:, scope:, limit: 100)
      start_score = DateTime.parse(start_time).strftime("%s").to_i
      end_score = DateTime.parse(end_time).strftime("%s").to_i
      if start_score > end_score
        raise ActivityInputError.new "start_time: #{start_time} must be before end_time: #{end_time}"
      end
      array = Store.zrangebyscore("#{scope}#{PRIMARY_KEY}__#{name}", start_score, end_score, :limit => [0, limit])
      ret_array = Array.new
      array.each do |value|
        ret_array << JSON.parse(value)
      end
      return ret_array
    end

    # @return [Array<Hash>] Array up to the limit of the models (as Hash objects) stored under the primary key
    def self.all(name:, scope:, limit: 100)
      array = Store.zrange("#{scope}#{PRIMARY_KEY}__#{name}", 0, -1, :limit => [0, limit])
      ret_array = Array.new
      array.each do |value|
        ret_array << JSON.parse(value)
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

    # validate the input to the rules we have created for timelines.
    # - A task's start_time MUST NOT be in the past.
    # - A task's start_time MUST be before the end_time.
    # - A task CAN NOT be longer than MAX_DURATION in seconds.
    # - A task MUST have a kind.
    # - A task MUST have a data object/hash.
    def validate_input(start_time:, end_time:, kind:, data:)
      now = DateTime.now.new_offset(0)
      begin
        start_time = DateTime.parse(start_time).new_offset(0)
        end_time = DateTime.parse(end_time).new_offset(0)
      rescue ArgumentError
        raise ActivityInputError.new "invalid input must be datetime: #{start_time}, #{end_time}"
      end
      now_i = now.new_offset(0).strftime("%s").to_i
      start_i = start_time.strftime("%s").to_i
      duration = end_time.strftime("%s").to_i - start_i
      if now_i > start_i
        raise ActivityInputError.new "activity must be in the future, current_time: #{now} vs #{start_time}"
      elsif duration > MAX_DURATION
        raise ActivityInputError.new "activity can not be longer than #{MAX_DURATION} seconds"
      elsif duration <= 0
        raise ActivityInputError.new "start_time: #{start_time} must be before end_time: #{end_time}"
      elsif kind.nil?
        raise ActivityInputError.new "kind must not be nil: #{kind}"
      elsif data.nil?
        raise ActivityInputError.new "data must not be nil: #{data}"
      elsif data.is_a?(Hash) == false
        raise ActivityInputError.new "data must not be a json object/hash: #{data}"
      end
    end

    # Set the values of the instance, @score, @kind, @data, @events...
    def set_input(start_time:, end_time:, updated_at:, kind: nil, data: nil, events: nil, fulfillment: nil)
      @updated_at = updated_at
      begin
        start_time = DateTime.parse(start_time).new_offset(0)
        end_time = DateTime.parse(end_time).new_offset(0)
      rescue ArgumentError
        raise ActivityInputError.new "invalid input must be datetime: #{start_time}, #{end_time}"
      end
      @start_time = start_time.to_s
      @end_time = end_time.to_s
      @score = start_time.strftime("%s").to_i
      @duration = end_time.strftime("%s").to_i - @score
      @fulfillment = fulfillment.nil? ? false : fulfillment
      @kind = kind.nil? ? @kind : kind
      @data = data.nil? ? @data : data
      @events = events.nil? ? Array.new : events
    end

    def initialize(
      name:,
      start_time:,
      end_time:,
      kind:,
      data:,
      updated_at: 0,
      score: 0,
      duration: 0,
      fulfillment: nil,
      events: nil,
      plugin: nil,
      scope:)
      super("#{scope}#{PRIMARY_KEY}__#{name}", name: name, scope: scope)
      set_input(
        fulfillment: fulfillment,
        start_time: start_time,
        end_time: end_time,
        kind: kind,
        data: data,
        events: events,
        updated_at: updated_at)
    end

    # validate_time will be called on create this will pull the time up to MAX_DURATION of an activity
    # this will make sure that the activity is the only activity on the timeline for the duration of the
    # activity. Score is the Seconds since the Unix Epoch: (%s) Number of seconds since 1970-01-01 00:00:00 UTC.
    # We then search back from the end_time of the activity and check to see if any activities are in the
    # last x seconds (MAX_DURATION), if the zrange rev byscore finds activites from in reverse order so the
    # first task is the closest task to the current score. In this a parameter ignore_score allows the request
    # to ignore that time and skip to the next time but if nothing is found in the time range we can return nil.
    #
    # @param [Integer] ignore_score - should be nil unless you want to ignore a time when doing an update
    def validate_time(ignore_score = nil)
      start_score = @score + @duration
      stop_score = @score - MAX_DURATION
      array = Store.zrevrangebyscore(@primary_key, start_score, stop_score)
      array.each do |value|
        activity = JSON.parse(value)
        activity_start = DateTime.parse(activity["start_time"]).strftime("%s").to_i
        activity_stop = DateTime.parse(activity["end_time"]).strftime("%s").to_i
        if ignore_score == activity_start
          next
        elsif activity_stop > @score
          return activity["score"]
        else
          return nil
        end
      end
      return nil
    end

    # Update the Redis hash at primary_key and set the score equal to the start_time Epoch time
    # the member is set to the JSON generated via calling as_json
    def create
      validate_input(start_time: @start_time, end_time: @end_time, kind: @kind, data: @data)
      collision = validate_time()
      unless collision.nil?
        raise ActivityOverlapError.new "no activities can overlap, collision: #{collision}"
      end
      @updated_at = Process.clock_gettime(Process::CLOCK_REALTIME).to_i
      add_event("create")
      Store.zadd(@primary_key, @score, JSON.generate(self.as_json))
      notify(kind: "create")
    end

    # Update the Redis hash at primary_key and remove the current activity at the current score
    # and update the score to the new score equal to the start_time Epoch time this uses a multi
    # to execute both the remove and create. The member via the JSON generated via calling as_json
    def update(start_time:, end_time:, kind:, data:)
      array = Store.zrangebyscore("#{scope}#{PRIMARY_KEY}__#{name}", @score, @score)
      if array.length == 0
        raise ActivityError.new "failed to find activity at: #{@score}"
      end
      validate_input(start_time: start_time, end_time: end_time, kind: kind, data: data)
      score = @score
      updated_at = Process.clock_gettime(Process::CLOCK_REALTIME).to_i
      set_input(start_time: start_time, end_time: end_time, kind: kind, data: data, events: @events, updated_at: updated_at)
      # copy of create
      collision = validate_time(score)
      unless collision.nil?
        raise ActivityOverlapError.new "failed to update #{score}, no activities can overlap, collision: #{collision}"
      end
      add_event("update")
      Store.multi do |multi|
        multi.zremrangebyscore(@primary_key, score, score)
        multi.zadd(@primary_key, @score, JSON.generate(self.as_json))
      end
      notify(kind: "update")
      return @score
    end

    # commit will make an event and save the object to the redis database
    # @param [String] status - the event status such as "complete" or "failed"
    # @param [String] message - an optional message to include in the event
    def commit(status:, message: nil, fulfillment: nil)
      event = {
        "time"=>Process.clock_gettime(Process::CLOCK_REALTIME).to_i,
        "event"=>status,
        "commit"=>true}
      unless message.nil?
        event["message"] = message
      end
      @fulfillment = fulfillment.nil? ? @fulfillment : fulfillment
      @events << event
      Store.multi do |multi|
        multi.zremrangebyscore(@primary_key, @score, @score)
        multi.zadd(@primary_key, @score, JSON.generate(self.as_json))
      end
    end

    # add_event will make an event. This will NOT save the object to the redis database
    # @param [String] status - the event status such as "queued" or "updated" or "created"
    def add_event(status)
      event = {
        "time"=>Process.clock_gettime(Process::CLOCK_REALTIME).to_i,
        "event"=>status}
      @events << event
    end

    # destroy the activity from the redis database
    def destroy
      Store.zremrangebyscore(@primary_key, @score, @score)
      notify(kind: "delete")
    end

    # @return [] update the redis stream / timeline topic that something has changed
    def notify(kind:)
      notification = {
        "data" => as_json(),
        "kind" => kind,
        "type" => "activity",
        "timeline" => @name}
      TimelineTopic.write_activity(notification, scope: @scope)
    end

    # @return [Hash] generated from the ActivityModel
    def as_json
      { "updated_at" => @updated_at,
        "fulfillment" => @fulfillment,
        "score" => @score,
        "duration" => @duration,
        "start_time" => @start_time,
        "end_time" => @end_time,
        "kind" => @kind,
        "events" => @events,
        "data" => @data}
    end

    # @return [ActivityModel] Model generated from the passed JSON
    def self.from_json(json, name:, scope:)
      json = JSON.parse(json) if String === json
      raise "json data is nil" if json.nil?
      json.transform_keys!(&:to_sym)
      self.new(**json, name: name, scope: scope)
    end

  end
end
