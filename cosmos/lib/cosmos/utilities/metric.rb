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

require 'cosmos/models/metric_model'

module Cosmos

  class Metric
    # This class is designed to output metrics to the cosmos-cmd-tlm-api
    # InternalMetricsController. Output format can be read about here
    # https://prometheus.io/docs/concepts/data_model/
    #
    # Warning contains some sorcery.
    #
    # examples:
    #    TYPE foobar histogram
    #    HELP foobar internal metric generated from cosmos/utilities/metric.rb
    #    foobar{code="200",method="get",path="/metrics"} 5.0
    #
    # items = {"name|labels" => [value_array], ...}

    attr_reader :items
    attr_accessor :size
    attr_reader :scope
    attr_reader :microservice

    def initialize(microservice:, scope:)
      if microservice.include? "|" or scope.include? "|"
        raise ArgumentError.new("invalid input must not contain '|'")
      end
      @items = {}
      @scope = scope
      @microservice = microservice
      @size = 5000
    end

    def add_sample(name:, value:, labels:)
      # add a value to the metric to report out later or a seperate thread
      # name is a string often function_name_duration_seconds
      #    name: debug_duration_seconds
      # value is a numerical value to add to a round robin array.
      #    value: 0.1211
      # labels is a hash of values that could have an effect on the value.
      #    labels: {"code"=>200,"method"=>"get","path"=>"/metrics"}
      # internal:
      # the internal items hash is used as a lookup table to store unique
      # varients of a similar metric. these varients are values that could
      # cause a difference in run time to add context to the metric. the
      # microservice and scope are added to the labels the labels are
      # converted to a string and joined with the name to create a unique
      # metric item. this is looked up in the items hash and if not found
      # the key is created and an array of size @size is allocated. then
      # the value is added to @items and the count of the value is increased
      # if the count of the values exceed the size of the array it sets the
      # count back to zero and the array will over write older data.
      key = "#{name}|" + labels.map {|k,v| "#{k}=#{v}"}.join(",")
      if not @items.has_key?(key)
        Logger.debug("new data for #{@scope}, #{key}")
        @items[key] = { "values" => Array.new(@size), "count" => 0 }
      end
      count = @items[key]["count"]
      # Logger.info("adding data for #{@scope}, #{count} #{key}, #{value}")
      @items[key]["values"][count] = value
      @items[key]["count"] = count + 1 >= @size ? 0 : count + 1
    end

    def percentile(sorted_values, percentile)
      # get the percentile out of an ordered array
      len = sorted_values.length
      return sorted_values.first if len == 1
      k = ((percentile / 100.0) * (len - 1) + 1).floor - 1
      f = ((percentile / 100.0) * (len - 1) + 1).modulo(1)
      return sorted_values[k] + (f * (sorted_values[k + 1] - sorted_values[k]))
    end

    def output
      # Output percentile based metrics to Redis under the key of the
      # #{@scope}__cosmos__metric we will use hset with a subkey.
      # internal:
      # loop over the key value pairs within the @items hash, remove nil
      # and sort the values added via the add_sample method. calculate the
      # different percentiles. the labels are still only contained in the
      # key of the @items hash to extract these you split the key on | the
      # name|labels then to make the labels back into a hash we split the ,
      # into an array ["foo=bar", ...] and split again this time on the =
      # into [["foo","bar"], ...] to map the internal array into a hash
      # [{"foo"=>"bar"}, ...] finally reducing the array into a single hash
      # to add the percentile and percentile value. this hash is added to an
      # array. to store the array as the value with the metric name again joined
      # with the @microservice and @scope.
      Logger.debug("#{@microservice} #{@scope} sending metrics to redis, #{@items.length}") if @items.length > 0
      @items.each do |key, values|
        label_list = []
        name, labels = key.split("|")
        metric_labels = labels.nil? ? {} : labels.split(',').map {|x| x.split('=')}.map {|k, v| { k => v }}.reduce({}, :merge)
        sorted_values = values["values"].compact.sort
        for percentile_value in [10, 50, 90, 95, 99]
          percentile_result = percentile(sorted_values, percentile_value)
          labels = metric_labels.clone.merge({ "scope" => @scope, "microservice" => @microservice })
          labels["percentile"] = percentile_value
          labels["metric__value"] = percentile_result
          label_list.append(labels)
        end
        begin
          Logger.debug("sending metrics summary to redis key: #{@microservice}")
          metric = MetricModel.new(name: @microservice, scope: @scope, metric_name: name, label_list: label_list)
          metric.create(force: true)
        rescue RuntimeError
          Logger.error("failed attempt to update metric, #{key}, #{name} #{@scope}")
        end
      end
    end

    def destroy
      MetricModel.destroy(scope: @scope, name: @microservice)
    end

  end

end
