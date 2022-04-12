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

require 'cosmos/script/extract'

module Cosmos
  module Script
    include Extract

    private

    # Sets the metadata value for a target
    #
    # @param target [String] Target to set metadata on
    # @return The result of the method call.
    def get_metadata(target)
      endpoint = "/cosmos-api/metadata/get/#{target}"
      response = $api_server.request('get', endpoint)
      return nil if response.nil? || response.code != 200
      return JSON.parse(response.body)
    end

    # Sets the metadata value for a target
    #
    # @param target [String] Target to set metadata on
    # @param metadata [Hash<Symbol, Variable>] A hash of metadata
    # @param color [String] Events color to show on Calendar tool
    # @param start (optional) [String] Metadata time value if nil will default to current time
    # @return The result of the method call.
    def set_metadata(target, metadata, color: nil, start: nil)
      color = color.nil? ? '#003784' : color
      data = {:color => color, :metadata => metadata, :target => target}
      data[:start] = start unless start.nil?
      response = $api_server.request('post', '/cosmos-api/metadata', data: data, json: true)
      return nil if response.nil? || response.code != 201
      return JSON.parse(response.body)
    end

    # Requests the metadata from the user for a target
    #
    def input_metadata(*args, **kwargs)
      rasie StandardError "can only be used in script-runner"
    end

  end
end
