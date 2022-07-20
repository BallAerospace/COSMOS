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

require 'openc3/script/extract'
require 'time'

module OpenC3
  module Script
    include Extract

    private

    # Gets the current metadata
    #
    # @return The result of the method call.
    def get_metadata()
      response = $api_server.request('get', "/openc3-api/metadata/latest")
      return nil if response.nil? || response.code != 200
      return JSON.parse(response.body, :allow_nan => true, :create_additions => true)
    end

    # Sets the metadata
    #
    # @param metadata [Hash<Symbol, Variable>] A hash of metadata
    # @param color [String] Events color to show on Calendar tool, if nil will be blue
    # @param start [Time] Metadata time value, if nil will be current time
    # @return The result of the method call.
    def set_metadata(metadata, color: nil, start: nil)
      unless metadata.is_a?(Hash)
        raise "metadata must be a Hash: #{metadata} is a #{metadata.class}"
      end
      color = color.nil? ? '#003784' : color
      data = { color: color, metadata: metadata }
      data[:start] = start.iso8601 unless start.nil?
      response = $api_server.request('post', '/openc3-api/metadata', data: data, json: true)
      return nil if response.nil? || response.code != 201
      return JSON.parse(response.body, :allow_nan => true, :create_additions => true)
    end

    # Updates the metadata
    #
    # @param metadata [Hash<Symbol, Variable>] A hash of metadata
    # @param color [String] Events color to show on Calendar tool, if nil will be blue
    # @param start [Integer] Metadata time value as integer seconds from epoch
    # @return The result of the method call.
    def update_metadata(metadata, color: nil, start: nil)
      unless metadata.is_a?(Hash)
        raise "metadata must be a Hash: #{metadata} is a #{metadata.class}"
      end
      color = color.nil? ? '#003784' : color
      if start == nil
        existing = get_metadata()
        start = existing['start']
        metadata = existing['metadata'].merge(metadata)
      end
      data = { :color => color, :metadata => metadata }
      data[:start] = Time.at(start).iso8601
      response = $api_server.request('put', "/openc3-api/metadata/#{start}", data: data, json: true)
      return nil if response.nil? || response.code != 201
      return JSON.parse(response.body, :allow_nan => true, :create_additions => true)
    end

    # Requests the metadata from the user for a target
    def input_metadata(*args, **kwargs)
      raise StandardError "can only be used in Script Runner"
    end
  end
end
