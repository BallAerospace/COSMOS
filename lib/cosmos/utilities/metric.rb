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

require 'redis'

module Cosmos

  class Metric
    # TYPE http_server_requests_total counter
    # HELP http_server_requests_total The total number of HTTP requests handled by the Rack application.
    # examples:
    #    http_server_requests_total{code="200",method="get",path="/metrics"} 5.0
    #    http_server_requests_total{code="404",method="get",path="/favicon.ico"} 1.0

    # items = {"http_server_requests_total|code=200,method=get,path=/metrics" => [1,2,3,4,5], ...}

    def initialize(microservice, scope)
      @items = {}
      @scope = scope
      @microservice = microservice
      @size = 5000
    end

    def add_sample(name, value, labels)
      labels = labels.merge({"scope" => @scope, "microservice" => @microservice})
      key = name + "|" + labels.map{|k,v| "#{k}=#{v}"}.join(",")
      if not @items.has_key?(key)
        Logger.info("new data for #{@scope}, #{key}")
        @items[key] = {"values" => Array.new(@size), "count" => 0}
      end
      count = @items[key]["count"]
      # Logger.info("adding data for #{@scope}, #{count} #{key}, #{value}")
      @items[key]["values"][count] = value
      @items[key]["count"] = count > @size ? 0 : count + 1
    end

    def percentile(sorted_values, percentile)
      len = sorted_values.length
      return sorted_values.first if len == 1
      k = ((percentile / 100.0) * (len - 1) + 1).floor - 1
      f = ((percentile / 100.0) * (len - 1) + 1).modulo(1)
      return sorted_values[k] + (f * (sorted_values[k+1] - sorted_values[k]))
    end

    def output()
      Logger.info("#{@microservice} #{@scope} sending metrics to redis, #{@items.length}") if @items.length > 0
      redis_key = "#{@scope}__cosmos__metric"
      @items.each do |key, values|
        label_list = []
        sorted_values = values["values"].compact.sort
        for percentile_value in [10, 50, 90, 95, 99]
          percentile_result = percentile(sorted_values, percentile_value)
          Logger.info("percentiles for #{percentile_result}, #{percentile_value}")
          name, labels = key.split("|")
          labels = labels.split(',').map{|x| x.split('=')}.map{|k, v| {k=>v}}.reduce({}, :merge)
          labels["percentile"] = percentile_value
          labels["metric__value"] = percentile_result
          label_list.append(labels)
        end
        name = name + "|" + @microservice + "|" + @scope
        begin
          Logger.info("sending metrics summary to redis key: #{redis_key}, #{name}")
          Store.instance.hset(redis_key, name, JSON.generate(label_list))
        rescue RuntimeError
          Logger.error("failed attempt to update metric, #{key}, #{name} #{@scope}")
        end

      end
    end

  end

end