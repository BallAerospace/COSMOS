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
  class MetadataModel < SortedModel
    METADATA_TYPE = 'metadata'.freeze
    PRIMARY_KEY = '__METADATA'.freeze

    def self.pk(scope)
      "#{scope}#{PRIMARY_KEY}"
    end

    attr_reader :color, :metadata, :type

    # @param [Integer] start - time metadata is active in seconds from Epoch
    # @param [String] color - The event color
    # @param [String] metadata - Key value pair object to link to name
    # @param [String] scope - Cosmos scope to track event to
    def initialize(
      scope:,
      start:,
      color: nil,
      metadata:,
      type: METADATA_TYPE,
      updated_at: 0
    )
      super(start: start, scope: scope, updated_at: updated_at)
      @start = start
      @color = color
      @metadata = metadata
      @type = type # For the as_json, from_json round trip
    end

    # Validates the instance variables: @start, @color, @metadata
    def validate(update: false)
      validate_start(update: update)
      validate_color()
      validate_metadata()
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
    end

    # Update the Redis hash at primary_key based on the initial passed start
    # The member is set to the JSON generated via calling as_json
    def create(update: false)
      validate(update: update)
      @updated_at = Time.now.to_nsec_from_epoch
      Store.zadd(@primary_key, @start, JSON.generate(as_json()))
      if update
        notify(kind: 'updated')
      else
        notify(kind: 'created')
      end
    end

    # Update the Redis hash at primary_key
    def update(start:, color:, metadata:)
      @start = start
      @color = color
      @metadata = metadata
      create(update: true)
    end

    # @return [Hash] generated from the MetadataModel
    def as_json
      return {
        'scope' => @scope,
        'start' => @start,
        'color' => @color,
        'metadata' => @metadata,
        'type' => METADATA_TYPE,
        'updated_at' => @updated_at,
      }
    end

    # @return [String] string view of metadata
    def to_s
      return "<MetadataModel s: #{@start}, c: #{@color}, m: #{@metadata}>"
    end
  end
end
