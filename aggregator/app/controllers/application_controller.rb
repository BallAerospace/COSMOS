require 'redis'
require 'cosmos'
require 'cosmos/models/scope_model'

class ApplicationController < ActionController::Base
    # This Controller is designed to output metrics from the cosmos/utilities/metric.rb
    # Find all scopes currently active in the cosmos system, we use the cosmos/models/scope_model
    # then seach redis for the #{scope}__cosmos__metrics key. This key uses subkeys that are the name
    # the metrics. The value of the metric is a list of prometheus labels these are hashes with key
    # value pairs. The value for the metric is contained in this hash in the metric__value key. These
    # hashes are converted into a string with key="value" and wraped in {} to make up the labels.
    # examples:
    #    TYPE foobar histogram",
    #    HELP foobar internal metric generated from cosmos/utilities/metric.rb."
    #    foobar{code="200",method="get",path="/metrics"} 5.0

    # items = {"name|labels" => [value_array], ...}
    # items = {"http_server_requests_total|code=200,method=get,path=/metrics" => [1,2,3,4,5], ...}

    def index
        Cosmos::Logger.info("request for aggregator metrics")
        begin
            scopes = Cosmos::ScopeModel.names()
        rescue RuntimeError
            Cosmos::Logger.error("failed to connect to redis to pull scopes")
            render plain: "failed to access datastore", :status => 500
        end
        Cosmos::Logger.info("ScopeModels: #{scopes}")
        data_hash = {}
        scopes.each do |scope|
            Cosmos::Logger.debug("search metrics for scope: #{scope}")
            begin
                scope_resp = Cosmos::Store.hgetall("#{scope}__cosmos__metric")
            rescue RuntimeError
                Cosmos::Logger.error("failed to connect to redis to pull metrics")
                render plain: "failed to access datastore", :status => 500
            end
            Cosmos::Logger.debug("metrics search for scope: #{scope}, returned: #{scope_resp}")
            scope_resp.each do |key, label_json|
                name = key.split("|")[0]
                if not data_hash.has_key?(name)
                    data_hash[name] = [
                        "# TYPE #{name} histogram",
                        "# HELP #{name} internal metric generated from cosmos/utilities/metric.rb."
                    ]
                end
                label_list = JSON.parse(label_json)
                label_list.each do |label_hash|
                    value = label_hash.delete("metric__value")
                    label = label_hash.map{|k,v| "#{k}=\"#{v}\""}.join(",")
                    data_hash[name].append("#{name}{#{label}} #{value}")
                end
            end
        end
        render plain: data_hash.values.join("\n")
    end

end
