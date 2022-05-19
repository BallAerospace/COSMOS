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

require 'cosmos/models/sorted_model'

module Cosmos
  class NoteModel < SortedModel
    NOTE_TYPE = 'note'.freeze
    PRIMARY_KEY = '__NOTE'.freeze

    def self.pk(scope)
      "#{scope}#{PRIMARY_KEY}"
    end

    attr_reader :stop, :color, :description, :type

    # @param [String] scope - Cosmos scope to track event to
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
      @type = type # For the as_json, from_json round trip
      # Start is validated by super so don't bother again
      validate(stop: stop, color: color, description: description)
    end

    # Set the values of the instance, @start, @stop, @color, @description
    def validate(start: nil, stop:, color:, description:, update: false)
      @start = validate_start(start, update: update) if start
      @stop = validate_stop(stop)
      @color = validate_color(color)
      # Not much to validate here since it's just a string
      @description = description
    end

    def validate_stop(stop)
      unless stop.is_a?(Integer)
        raise SortedInputError.new "stop must be integer: #{stop}"
      end
      if stop.to_i < @start
        raise SortedInputError.new "stop: #{stop} must be >= start: #{start}"
      end
      stop.to_i
    end

    def validate_color(color)
      if color.nil?
        color = '#%06x' % (rand * 0xffffff)
      end
      valid_color = color =~ /(#*)([0-9,a-f,A-f]{6})/
      if valid_color.nil?
        raise SortedInputError.new "invalid color, must be in hex format, e.g. #FF0000"
      end
      color = "##{color}" unless color.start_with?('#')
      color
    end

    # Update the Redis hash at primary_key and remove the current activity at the current score
    # and update the score to the new score equal to the start Epoch time this uses a multi
    # to execute both the remove and create. The member via the JSON generated via calling as_json
    def update(start:, stop:, color:, description:)
      old_start = @start
      @updated_at = Time.now.to_nsec_from_epoch
      validate(start: start, stop: stop, color: color, description: description, update: true)
      self.class.destroy(scope: @scope, start: old_start)
      create()
      notify(kind: 'updated', extra: old_start)
    end

    # @return [Hash] generated from the NoteModel
    def as_json
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

    # @return [String] string view of NoteModel
    def to_s
      return "<NoteModel s: #{@start}, x: #{@stop}, c: #{@color}, d: #{@description}>"
    end
  end
end
