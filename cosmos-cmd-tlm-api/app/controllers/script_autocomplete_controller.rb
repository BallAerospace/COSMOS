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
  CMD_KEYWORDS = %w(cmd cmd_no_range_check cmd_no_hazardous_check cmd_no_checks
                    cmd_raw cmd_raw_no_range_check cmd_raw_no_hazardous_check cmd_raw_no_checks)

  TLM_KEYWORDS = %w(set_tlm set_tlm_raw override_tlm override_tlm_raw normalize_tlm
                    tlm tlm_raw tlm_formatted tlm_with_units
                    limits_enabled? enable_limits disable_limits
                    check check_raw check_tolerance check_tolerance_raw
                    wait wait_raw wait_tolerance wait_tolerance_raw wait_check wait_check_raw
                    wait_check_tolerance wait_check_tolerance_raw)

  # TODO: Where do these come from? I found them hard-coded in CommandSender.vue
  RESERVED_PARAMS = %w(PACKET_TIMESECONDS PACKET_TIMEFORMATTED
                       RECEIVED_TIMESECONDS RECEIVED_TIMEFORMATTED RECEIVED_COUNT)

  def get_keywords
    keywords = params[:type].upcase == 'TLM' ? TLM_KEYWORDS : CMD_KEYWORDS
    render :json => keywords, :status => 200
  end

  def get_ace_autocomplete_data
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 403) and return
    end

    autocomplete_data = build_autocomplete_data(params[:type], params[:scope])

    response.headers['Cache-Control'] = 'must-revalidate' # TODO: Browser is ignoring this and not caching anything for some reason. Future enhancement
    render :json => autocomplete_data, :status => 200
  end

  # private
  def build_autocomplete_data(type, scope)
    meta = type.upcase == 'TLM' ? 'telemetry' : 'command'
    autocomplete_data = Cosmos::TargetModel.all(scope: scope).flat_map do |target_name, target_info|
      Cosmos::TargetModel.packets(target_name, type: type.upcase.intern, scope: scope).map do |packet|
        {
          :caption => build_caption(packet),
          :snippet => build_snippet(packet, target_info),
          :meta => meta,
        }
      end
    end
    autocomplete_data.sort_by { |packet| packet[:caption] }
  end

  def build_caption(packet)
    "#{packet['target_name']} #{packet['packet_name']}"
  end

  def build_snippet(packet, target_info)
    caption = build_caption(packet)
    filtered_items = packet['items'].select do |item|
      !RESERVED_PARAMS.include?(item['name']) and !target_info['ignored_parameters'].include?(item['name'])
    end
    if filtered_items.any?
      params = filtered_items.each_with_index.map do |item, index|
        "#{item['name']} ${#{index + 1}:#{item['default'] || 0}}"
      end
      return "#{caption} with #{params.join(', ')}"
    end
    caption
  end
end
