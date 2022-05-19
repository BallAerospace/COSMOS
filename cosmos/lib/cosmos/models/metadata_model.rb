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
    class MetadataError < StandardError; end
    class MetadataInputError < MetadataError; end
    class MetadataOverlapError < MetadataError; end

    METADATA_TYPE = 'metadata'.freeze
    PRIMARY_KEY = '__METADATA'.freeze

    def self.pk(scope)
      puts "metadata pk:#{scope}#{PRIMARY_KEY}"
      return "#{scope}#{PRIMARY_KEY}"
    end

    # @return [String|nil] String of the saved json or nil if value not found under primary_key
    def self.get(start:, scope:)
      super(value: start, scope: scope)
    end

    # Remove metadata value
    # @return [Integer] 1 if found and removed, 0 if not found
    def self.destroy(start:, scope:)
      super(value: start, scope: scope)
    end

    # @return [String|nil] json or nil if metadata empty
    def self.get_current_value(scope:)
      start = Time.now.to_i
      array = Store.zrevrangebyscore(self.pk(scope), start, '-inf', :limit => [0, 1])
      return nil if array.empty?
      return array[0]
    end

    attr_reader :start, :color, :metadata, :type

    # @param [Integer] start - time metadata is active in seconds from Epoch
    # @param [String] color - The event color
    # @param [String] metadata - Key value pair object to link to name
    # @param [String] scope - Cosmos scope to track event to
    def initialize(
      start:,
      color: nil,
      metadata:,
      scope:,
      type: METADATA_TYPE,
      updated_at: 0
    )
      super(value: start, scope: scope, updated_at: updated_at)
      @type = type # For the as_json, from_json round trip
      validate(start: start, color: color, metadata: metadata)
    end

    # Set the values of the instance, @start, @stop, @metadata
    def validate(start:, color:, metadata:, update: false)
      @start = validate_start(start, update)
      @color = validate_color(color)
      @metadata = validate_metadata(metadata)
    end

    # start MUST be a positive integer
    def validate_start(start, update)
      unless start.is_a?(Integer)
        raise MetadataInputError.new "start must be integer: #{start}"
      end
      if start.to_i < 0
        raise MetadataInputError.new "start must be positive: #{start}"
      end
      if !update and MetadataModel.get(start: start, scope: @scope)
        raise MetadataOverlapError.new "no metadata can overlap, existing data at #{start}"
      end
      start
    end

    # validate color
    def validate_color(color)
      if color.nil?
        color = '#%06x' % (rand * 0xffffff)
      end
      valid_color = color =~ /(#*)([0-9,a-f,A-f]{6})/
      if valid_color.nil?
        raise MetadataInputError.new "invalid color, must be in hex format, e.g. #FF0000"
      end
      color = "##{color}" unless color.start_with?('#')
      color
    end

    def validate_metadata(metadata)
      unless metadata.is_a?(Hash)
        raise MetadataInputError.new "Metadata must be a hash/object: #{metadata}"
      end
      metadata
    end

    # Update the Redis hash at primary_key based on the initial passed value
    # The member is set to the JSON generated via calling as_json
    def create()
      @updated_at = Time.now.to_nsec_from_epoch
      Store.zadd(@primary_key, @start, JSON.generate(as_json()))
      notify(kind: 'created')
    end

    # Update the Redis hash at primary_key and remove the current activity at the current score
    # and update the score to the new score equal to the start Epoch time this uses a multi
    # to execute both the remove and create. The member via the JSON generated via calling as_json
    def update(start:, color:, metadata:)
      old_start = @start
      @updated_at = Time.now.to_nsec_from_epoch
      validate(start: start, color: color, metadata: metadata, update: true)
      MetadataModel.destroy(scope: @scope, start: old_start)
      create()
      notify(kind: 'updated', extra: old_start)
      return @start
    end

    # destroy the activity from the redis database
    def destroy
      MetadataModel.destroy(scope: @scope, start: @start)
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
        raise MetadataError.new "Failed to write to stream: #{notification}, #{e}"
      end
    end

    # @return [Hash] generated from the MetadataModel
    def as_json
      return {
        'scope' => @scope,
        'updated_at' => @updated_at,
        'start' => @start,
        'color' => @color,
        'metadata' => @metadata,
        'type' => METADATA_TYPE
      }
    end

    # @return [String] string view of metadata
    def to_s
      return "<MetadataModel s: #{@start}, c: #{@color}, m: #{@metadata}>"
    end
  end
end
