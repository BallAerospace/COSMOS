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
  class MetadataModel < SortedModel
    METADATA_TYPE = 'metadata'.freeze
    PRIMARY_KEY = '__METADATA'.freeze

    def self.pk(scope)
      "#{scope}#{PRIMARY_KEY}"
    end

    attr_reader :color, :metadata, :constraints, :type

    # @param [Integer] start - Time metadata is active in seconds from Epoch
    # @param [String] color - The event color
    # @param [Hash] metadata - Hash of metadata values
    # @param [Hash] constraints - Constraints to apply to the metadata
    # @param [String] scope - OpenC3 scope to track event to
    def initialize(
      scope:,
      start:,
      color: nil,
      metadata:,
      constraints: nil,
      type: METADATA_TYPE,
      updated_at: 0
    )
      super(start: start, scope: scope, updated_at: updated_at)
      @start = start
      @color = color
      @metadata = metadata
      @constraints = constraints if constraints
      @type = type # For the as_json, from_json round trip
    end

    # Validates the instance variables: @start, @color, @metadata
    def validate(update: false)
      validate_start(update: update)
      validate_color()
      validate_metadata()
      validate_constraints() if @constraints
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

    def validate_metadata()
      unless @metadata.is_a?(Hash)
        raise SortedInputError.new "Metadata must be a hash/object: #{@metadata}"
      end
      # Convert keys to strings. This isn't quite as efficient as symbols
      # but we store as JSON which is all strings and it makes comparisons easier.
      @metadata = @metadata.transform_keys(&:to_s)
    end

    def validate_constraints()
      unless @constraints.is_a?(Hash)
        raise SortedInputError.new "Constraints must be a hash/object: #{@constraints}"
      end
      # Convert keys to strings. This isn't quite as efficient as symbols
      # but we store as JSON which is all strings and it makes comparisons easier.
      @constraints = @constraints.transform_keys(&:to_s)
      unless (@constraints.keys - @metadata.keys).empty?
        raise SortedInputError.new "Constraints keys must be subset of metadata: #{@constraints.keys} subset #{@metadata.keys}"
      end
      @constraints.each do |key, constraint|
        unless constraint.include?(@metadata[key])
          raise SortedInputError.new "Constraint violation! key:#{key} value:#{@metadata[key]} constraint:#{constraint}"
        end
      end
    end

    # Update the Redis hash at primary_key based on the initial passed start
    # The member is set to the JSON generated via calling as_json
    def create(update: false)
      validate(update: update)
      @updated_at = Time.now.to_nsec_from_epoch
      MetadataModel.destroy(scope: @scope, start: update) if update
      Store.zadd(@primary_key, @start, JSON.generate(as_json(:allow_nan => true)))
      if update
        notify(kind: 'updated')
      else
        notify(kind: 'created')
      end
    end

    # Update the model. All arguments are optional, only those set will be updated.
    def update(start: nil, color: nil, metadata: nil, constraints: nil)
      orig_start = @start
      @start = start if start
      @color = color if color
      @metadata = metadata if metadata
      @constraints = constraints if constraints
      create(update: orig_start)
    end

    # @return [Hash] generated from the MetadataModel
    def as_json(*a)
      {
        'scope' => @scope,
        'start' => @start,
        'color' => @color,
        'metadata' => @metadata.as_json(*a),
        'constraints' => @constraints,
        'type' => METADATA_TYPE,
        'updated_at' => @updated_at,
      }
    end
    alias to_s as_json
  end
end
