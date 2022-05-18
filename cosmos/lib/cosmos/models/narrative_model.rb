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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

# https://www.rubydoc.info/gems/redis/Redis/Commands/SortedSets

require 'cosmos/topics/calendar_topic'

module Cosmos

  class NarrativeError < StandardError; end

  class NarrativeInputError < NarrativeError; end

  class NarrativeOverlapError < NarrativeError; end

  # TODO: Refactor based on SortedModel
  class NarrativeModel < Model

    CHRONICLE_TYPE = 'narrative'.freeze
    PRIMARY_KEY = '__NARRATIVE'.freeze

    def self.pk(scope)
      return "#{scope}#{PRIMARY_KEY}"
    end

    # @return [Array|nil] Array up to 100 of this model or empty array
    def self.get(start:, stop:, scope:, limit: 100)
      if start > stop
        raise MetadataInputError.new "start: #{start} must be before stop: #{stop}"
      end
      pk = self.pk(scope)
      array = Store.zrangebyscore(pk, start, stop, :limit => [0, limit])
      ret_array = Array.new
      array.each do |value|
        ret_array << JSON.parse(value)
      end
      return ret_array
    end

    # @return [Array<Hash>] Array up to the limit of the models (as Hash objects) stored under the primary key
    def self.all(scope:, limit: 100)
      pk = self.pk(scope)
      array = Store.zrange(pk, 0, -1, :limit => [0, limit])
      ret_array = Array.new
      array.each do |value|
        ret_array << JSON.parse(value)
      end
      return ret_array
    end

    # @return [Integer] count of the members stored under the primary key
    def self.count(scope:)
      return Store.zcard(self.pk(scope))
    end

    # @return [String|nil] String of the saved json or nil if score not found under primary_key
    def self.score(score:, scope:)
      pk = self.pk(scope)
      array = Store.zrangebyscore(pk, score, score, :limit => [0, 1])
      array.each do |value|
        return JSON.parse(value)
      end
      return nil
    end

    # Remove member from a sorted set based on the score.
    # @return [Integer] count of the members removed
    def self.destroy(scope:, score:)
      pk = self.pk(scope)
      Store.zremrangebyscore(pk, score, score)
    end

    # Remove members from min to max of the sorted set.
    # @return [Integer] count of the members removed
    def self.range_destroy(scope:, min:, max:)
      pk = self.pk(scope)
      Store.zremrangebyscore(pk, min, max)
    end

    # @return [NarrativeModel] Model generated from the passed JSON
    def self.from_json(json, scope:)
      json = JSON.parse(json) if String === json
      raise "json data is nil" if json.nil?

      json.transform_keys!(&:to_sym)
      self.new(**json, scope: scope)
    end

    attr_reader :start, :stop, :duration, :color, :description, :type

    # @param [String] scope - Cosmos scope to track event to
    # @param [Integer] start - start of the event in seconds from Epoch
    # @param [Integer] stop - stop of the event in seconds from Epoch
    # @param [String] color - The event color
    # @param [String] description - What the event is about
    def initialize(
      scope:,
      start:,
      stop:,
      color:,
      description:,
      type: CHRONICLE_TYPE,
      updated_at: 0,
      duration: 0
    )
      super(NarrativeModel.pk(scope), name: start.to_s, scope: scope)
      set_input(
        start: start,
        stop: stop,
        color: color,
        description: description,
      )
      @type = type
      @updated_at = updated_at
    end

    # validate color
    def validate_color(color)
      if color.nil?
        color = '#%06x' % (rand * 0xffffff)
      end
      valid_color = color =~ /(#*)([0-9,a-f,A-f]{6})/
      if valid_color.nil?
        raise MetadataInputError.new "invalid color but in hex format. #FF0000"
      end

      color = "##{color}" unless color.start_with?('#')
      return color
    end

    # validate the input to the rules we have created for timelines.
    # - An entry's start MUST be before the stop.
    # - An entry's description MUST a String.
    def validate_input(start:, stop:, color:, description:)
      begin
        DateTime.strptime(start.to_s, '%s')
        DateTime.strptime(stop.to_s, '%s')
      rescue Date::Error
        raise NarrativeInputError.new "failed validation input must be seconds: #{start}, #{stop}"
      end
      validate_color(color)
      duration = stop - start
      if duration <= 0
        raise NarrativeInputError.new "start: #{start} must be before stop: #{stop}"
      elsif description.is_a?(String) == false
        raise NarrativeInputError.new "description must be a String: #{description}"
      end
    end

    # Set the values of the instance, @start, @stop, @description...
    def set_input(start:, stop:, color:, description:)
      begin
        DateTime.strptime(start.to_s, '%s')
        DateTime.strptime(stop.to_s, '%s')
      rescue ArgumentError
        raise NarrativeInputError.new "invalid input must be seconds: #{start}, #{stop}"
      end
      @start = start
      @stop = stop
      @duration = @stop - @start
      @color = color
      @description = description
    end

    # validate_time will be called on create and update this will validate
    # that no other chronicle event or metadata had been saved for that time.
    # One event or metadata per second to ensure data can be updated.
    #
    # @param [Integer] ignore_score - should be nil unless you want to ignore
    #   a time when doing an update
    def validate_time(ignore_score: nil)
      array = Store.zrangebyscore(@primary_key, @start, @start, :limit => [0, 1])
      array.each do |value|
        entry = JSON.parse(value)
        if ignore_score == entry['start']
          next
        else
          return entry
        end
      end
      return nil
    end

    # Update the Redis hash at primary_key and set the score equal to the start Epoch time
    # the member is set to the JSON generated via calling as_json
    def create
      validate_input(start: @start, stop: @stop, color: @color, description: @description)
      collision = validate_time()
      unless collision.nil?
        raise NarrativeOverlapError.new "no chronicles can overlap, collision: #{collision}"
      end

      @updated_at = Time.now.to_nsec_from_epoch
      Store.zadd(@primary_key, @start, JSON.generate(as_json()))
      notify(kind: 'created')
    end

    # Update the Redis hash at primary_key and remove the current activity at the current score
    # and update the score to the new score equal to the start Epoch time this uses a multi
    # to execute both the remove and create. The member via the JSON generated via calling as_json
    def update(start:, stop:, color:, description:)
      validate_input(start: start, stop: stop, color: color, description: description)
      old_start = @start

      set_input(
        start: start,
        stop: stop,
        color: color,
        description: description,
      )
      @updated_at = Time.now.to_nsec_from_epoch

      collision = validate_time(ignore_score: old_start)
      unless collision.nil?
        raise NarrativeOverlapError.new "failed to update #{old_start}, no chronicles can overlap, collision: #{collision}"
      end

      Store.multi do |multi|
        multi.zremrangebyscore(@primary_key, old_start, old_start)
        multi.zadd(@primary_key, @start, JSON.generate(as_json()))
      end
      notify(kind: 'updated', extra: old_start)
      return @start
    end

    # destroy the activity from the redis database
    def destroy
      Store.zremrangebyscore(@primary_key, @start, @start)
      notify(kind: 'deleted')
    end

    # @return [] update the redis stream / timeline topic that something has changed
    def notify(kind:, extra: nil)
      notification = {
        'data' => JSON.generate(as_json()),
        'kind' => kind,
        'type' => 'calendar',
      }
      notification['extra'] = extra unless extra.nil?
      begin
        CalendarTopic.write_entry(notification, scope: @scope)
      rescue StandardError => e
        raise NarrativeError.new "Failed to write to stream: #{notification}, #{e}"
      end
    end

    # @return [Hash] generated from the NarrativeModel
    def as_json
      return {
        'color' => @color,
        'start' => @start,
        'stop' => @stop,
        'description' => @description,
        'type' => CHRONICLE_TYPE,
        'scope' => @scope,
        'updated_at' => @updated_at,
      }
    end

    # @return [String] string view of NarrativeModel
    def to_s
      return "<NarrativeModel ->: #{@start}, x: #{@stop}, c: #{@color}, d: #{@description}>"
    end
  end
end
