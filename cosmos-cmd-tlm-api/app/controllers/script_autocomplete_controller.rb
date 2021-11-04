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

class ScriptAutocompleteController < ApplicationController
  def get_command_ace_autocomplete_data
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 403) and return
    end

    autocomplete_data = Cosmos::TargetModel.all(scope: params[:scope]).flat_map do |target_name, target_info|
      Cosmos::TargetModel.packets(target_name, type: :CMD, scope: params[:scope]).map { |packet|
        {
          :caption => build_command_caption(packet),
          :snippet => build_command_snippet(packet, target_info),
          :meta => 'command',
        }
      }
    end

    render :json => autocomplete_data, :status => 200
  end

  # private
  def build_command_caption(command)
    "#{command['target_name']} #{command['packet_name']}"
  end

  def build_command_snippet(command, target_info)
    # TODO: Where do these come from? I found them hard-coded in CommandSender.vue
    reserved_params = [
      'PACKET_TIMESECONDS',
      'PACKET_TIMEFORMATTED',
      'RECEIVED_TIMESECONDS',
      'RECEIVED_TIMEFORMATTED',
      'RECEIVED_COUNT',
    ]

    caption = build_command_caption(command)
    filtered_items = command['items'].select { |item| !reserved_params.include?(item['name']) and !target_info['ignored_parameters'].include?(item['name']) }
    if filtered_items.any?
      params = filtered_items.each_with_index.map { |item, index| "#{item['name']} ${#{index + 1}:#{item['default'] || 0}}" }
      return "#{caption} with #{params.join(', ')}"
    end
    caption
  end
end
