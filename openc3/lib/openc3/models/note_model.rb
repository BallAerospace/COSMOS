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

require 'openc3/models/sorted_model'

module OpenC3
  class NoteModel < SortedModel
    NOTE_TYPE = 'note'.freeze
    PRIMARY_KEY = '__NOTE'.freeze

    def self.pk(scope)
      "#{scope}#{PRIMARY_KEY}"
    end

    attr_reader :stop, :color, :description, :type

    # @param [String] scope - OpenC3 scope to track event to
    # @param [Integer] start - start of the event in seconds from Epoch
    # @param [Integer] stop - stop of the event in seconds from Epoch
    # @param [String] color - The event color
    # @param [String] description - What the event is about
    def initialize(
      scope:,
      start:,
      stop:,
      color: nil,
      description:,
      type: NOTE_TYPE,
      updated_at: 0
    )
      super(start: start, scope: scope, updated_at: updated_at)
      @start = start
      @stop = stop
      @color = color
      @description = description
      @type = type # For the as_json, from_json round trip
    end

    # Validates the instance variables: @start, @stop, @color, @description
    def validate(update: false)
      validate_start(update: update)
      validate_stop()
      validate_color()
    end

    def validate_stop()
      unless @stop.is_a?(Integer)
        raise SortedInputError.new "stop must be integer: #{@stop}"
      end
      if @stop.to_i < @start
        raise SortedInputError.new "stop: #{@stop} must be >= start: #{@start}"
      end
      @stop = @stop.to_i
    end

    def validate_color()
      if @color.nil?
        @color = '#%06x' % (rand * 0xffffff)
      end
      unless @color =~ /(#*)([0-9,a-f,A-f]{6})/
        raise SortedInputError.new "invalid color, must be in hex format, e.g. #FF0000"
      end
      @color = "##{@color}" unless @color.start_with?('#')
    end

    # Update the Redis hash at primary_key based on the initial passed start
    # The member is set to the JSON generated via calling as_json
    def create(update: false)
      validate(update: update)
      @updated_at = Time.now.to_nsec_from_epoch
      NoteModel.destroy(scope: @scope, start: update) if update
      Store.zadd(@primary_key, @start, JSON.generate(as_json(:allow_nan => true)))
      if update
        notify(kind: 'updated')
      else
        notify(kind: 'created')
      end
    end

    # Update the Redis hash at primary_key
    def update(start:, stop:, color:, description:)
      orig_start = @start
      @start = start
      @stop = stop
      @color = color
      @description = description
      create(update: orig_start)
    end

    # @return [Hash] generated from the NoteModel
    def as_json(*a)
      return {
        'scope' => @scope,
        'start' => @start,
        'stop' => @stop,
        'color' => @color,
        'description' => @description,
        'type' => NOTE_TYPE,
        'updated_at' => @updated_at,
      }
    end
    alias to_s as_json
  end
end
