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

require 'openc3/models/scope_model'
require 'openc3/models/metric_model'

# This Controller is designed to output metrics from the openc3/utilities/metric.rb
# Find all scopes currently active in the openc3 system, we use the openc3/models/scope_model
# then seach redis for the #{scope}__openc3__metrics key. This key uses subkeys that are the name
# the metrics. The value of the metric is a list of prometheus labels these are hashes with key
# value pairs. The value for the metric is contained in this hash in the metric__value key. These
# hashes are converted into a string with key="value" and wraped in {} to make up the labels.
# examples:
#    TYPE foobar histogram",
#    HELP foobar internal metric generated from openc3/utilities/metric.rb."
#    foobar{code="200",method="get",path="/metrics"} 5.0
# items = {"name|labels" => [value_array], ...}
# items = {"http_server_requests_total|code=200,method=get,path=/metrics" => [1,2,3,4,5], ...}
class InternalMetricsController < ActionController::Base
  def index
    OpenC3::Logger.debug("request for aggregator metrics")
    begin
      scopes = OpenC3::ScopeModel.names()
    rescue RuntimeError
      OpenC3::Logger.error("failed to connect to redis to pull scopes")
      render plain: "failed to access datastore", :status => 500
    end
    OpenC3::Logger.debug("ScopeModels: #{scopes}")
    data_hash = {}
    scopes.each do |scope|
      OpenC3::Logger.debug("search metrics for scope: #{scope}")
      begin
        scope_resp = OpenC3::MetricModel.all(scope: scope)
      rescue RuntimeError
        OpenC3::Logger.error("failed to connect to redis to pull metrics")
        render plain: "failed to access datastore", :status => 500
      end
      OpenC3::Logger.debug("metrics search for scope: #{scope}, returned: #{scope_resp}")
      scope_resp.each do |key, label_json|
        name = label_json.delete("metric_name")
        if not data_hash.has_key?(name)
          data_hash[name] = [
              "# TYPE #{name} histogram",
              "# HELP #{name} internal metric generated from openc3/utilities/metric.rb."
          ]
        end
        label_json["label_list"].each do |labels|
          value = labels.delete("metric__value")
          label_str = labels.map {|k,v| "#{k}=\"#{v}\""}.join(",")
          data_hash[name].append("#{name}{#{label_str}} #{value}")
        end
      end
    end
    render plain: data_hash.values.join("\n")
  end
end
