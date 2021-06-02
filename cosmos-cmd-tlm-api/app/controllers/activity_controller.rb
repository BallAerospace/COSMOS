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

require 'cosmos/models/activity_model'
require 'cosmos/topics/timeline_topic'

class ActivityController < ApplicationController
  def initialize
    @model_class = Cosmos::ActivityModel
  end

  # Returns an array/list of activities in json. With optional start_time and end_time parameters
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # start [String] (optional) The start time of the search window for timeline to return. Recommend in ISO format, `2031-04-16T01:02:00+00:00`. If not provided start_time is equal to 12 hours before the request is made.
  # stop [String] (optional) The stop time of the search window for timeline to return. Recommend in ISO format, `2031-04-16T01:02:00+00:00`. If not provided end_time is equal to 2 days after the request is made.
  # @return [String] the array of activities converted into json format.
  def index
    authorize(permission: 'system', scope: params[:scope], token: headers[:Authorization])
    now = DateTime.now.new_offset(0)
    begin
      start = params[:start].nil? ? (now - 7) : DateTime.parse(params[:start]) # minus 7 days
      stop = params[:stop].nil? ? (now + 7) : DateTime.parse(params[:stop]) # plus 7 days
      start = start.strftime("%s").to_i
      stop = stop.strftime("%s").to_i
      model = @model_class.get(name: params[:name], scope: params[:scope], start: start, stop: stop)
      render :json => model.as_json(), :status => 200
    rescue Date::Error
      render :json => {"status" => "error", "message" => "Invalid date provided. Recommend ISO format"}, :status => 400
    rescue Cosmos::ActivityInputError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    rescue StandardError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    end
  end

  # Returns an object/hash of activity in json.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # json [String] The json of the activity (see below)
  # @return [String] the activity converted into json format
  #```json
  #  {
  #    "start": "2031-04-16T01:02:00",
  #    "stop": "2031-04-16T01:02:00",
  #    "kind": "cmd",
  #    "data": {"cmd"=>"INST ABORT"}
  #  }
  #```
  def create
    authorize(permission: 'system', scope: params[:scope], token: headers[:Authorization])
    begin
      hash = JSON.parse(params[:json])
      if hash["start"].nil? || hash["stop"].nil?
        raise ArgumentError.new "json must contain start and stop"
      end
      hash["start"] = DateTime.parse(hash["start"]).strftime("%s").to_i
      hash["stop"] = DateTime.parse(hash["stop"]).strftime("%s").to_i
      model = @model_class.from_json(hash, name: params[:name], scope: params[:scope])
      model.create()
      render :json => model.as_json, :status => 201
    rescue Date::Error, JSON::ParserError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    rescue ArgumentError
      render :json => {"status" => "error", "message" => "Invalid json object"}, :status => 400
    rescue Cosmos::ActivityInputError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    rescue Cosmos::ActivityOverlapError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 409
    rescue Cosmos::ActivityError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 418
    end
  end

  # Returns an object/hash the contains `count` as a key in json.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # @return [String] the object/hash converted into json format
  def count
    authorize(permission: 'system', scope: params[:scope], token: headers[:Authorization])
    count = @model_class.count(name: params[:name], scope: params[:scope])
    render :json => {
      "name" => params[:name],
      "count" => count
    }, :status => 200
  end

  # Returns an object/hash of a single activity in json.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # id [String] the start/id of the activity, `1620248449`
  # @return [String] the activity as a object/hash converted into json format
  def show
    authorize(permission: 'system', scope: params[:scope], token: headers[:Authorization])
    model = @model_class.score(name: params[:name], score: params[:id], scope: params[:scope])
    if model.nil?
      render :json => {"status" => "error", "message" => "not found"}, :status => 404
    else
      render :json => model.as_json, :status => 200
    end
  end

  # Adds an event to the object/hash of a single activity in json.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # id [String] the score/id of the activity, `1620248449`
  # json [String] The json of the event (see #event_model)
  # @return [String] the activity as a object/hash converted into json format
  #```json
  #  {
  #    "status": "system42-ready",
  #    "message": "script was completed"
  #  }
  #```
  def event
    authorize(permission: 'system', scope: params[:scope], token: headers[:Authorization])
    model = @model_class.score(name: params[:name], score: params[:id], scope: params[:scope])
    if model.nil?
      render :json => {"status" => "error", "message" => "not found"}, :status => 404
      return
    end
    begin
      hash = JSON.parse(params[:json])
      model.commit(status: hash["status"], message: hash["message"])
      render :json => model.as_json, :status => 200
    rescue JSON::ParserError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    rescue TypeError
      render :json => {"status" => "error", "message" => "Invalid json object"}, :status => 400
    rescue Cosmos::ActivityError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 418
    end
  end

  # Update and returns an object/hash of a single activity in json.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # id [String] the score or id of the activity, `1620248449`
  # json [String] The json of the event (see #activity_model)
  # @return [String] the activity as a object/hash converted into json format
  #```json
  #  {
  #    "start": "2031-04-16T01:02:00+00:00",
  #    "stop": "2031-04-16T01:02:00+00:00",
  #    "kind": "cmd",
  #    "data": {"cmd"=>"INST ABORT"}
  #  }
  #```
  def update
    authorize(permission: 'system', scope: params[:scope], token: headers[:Authorization])
    model = @model_class.score(name: params[:name], score: params[:id], scope: params[:scope])
    if model.nil?
      render :json => {"status" => "error", "message" => "not found"}, :status => 404
      return
    end
    begin
      hash = JSON.parse(params[:json])
      hash['start'] = DateTime.parse(hash['start']).strftime("%s").to_i
      hash['stop'] = DateTime.parse(hash['stop']).strftime("%s").to_i
      model.update(start: hash["start"], stop: hash["stop"], kind: hash["kind"], data: hash["data"])
      render :json => model.as_json, :status => 200
    rescue Date::Error, JSON::ParserError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    rescue TypeError
      render :json => {"status" => "error", "message" => "Invalid json object"}, :status => 400
    rescue Cosmos::ActivityInputError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    rescue Cosmos::ActivityOverlapError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 409
    rescue Cosmos::ActivityError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 418
    end
  end

  # Removes an activity activity by score/id.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # id [String] the score or id of the activity, `1620248449`
  # @return [String] object/hash converted into json format but with a 204 no-content status code
  def destroy
    authorize(permission: 'system', scope: params[:scope], token: headers[:Authorization])
    model = @model_class.score(name: params[:name], score: params[:id], scope: params[:scope])
    if model.nil?
      render :json => {"status" => "error", "message" => "not found"}, :status => 404
      return
    end
    begin
      ret = model.destroy()
      render :json => {"status" => ret}, :status => 204
    rescue Cosmos::ActivityError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    end
  end

  # Creates multiple activities by score/start/id.
  #
  # scope [String] the scope of the timeline, `TEST`
  # json [String] The json of the event (see #activity_model)
  # @return [String] the activity as a object/hash converted into json format
  #```json
  #  [
  #    {
  #      "start": "2031-04-16T01:02:00+00:00",
  #      "stop": "2031-04-16T01:02:00+00:00",
  #      "kind": "cmd",
  #      "data": {"cmd"=>"INST ABORT"
  #    }
  #  }
  #```
  def multi_create
    authorize(permission: 'system', scope: params[:scope], token: headers[:Authorization])
    begin
      array = JSON.parse(params[:json])
    rescue JSON::ParserError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
      return
    end
    ret = Array.new
    array.each do |hash|
      if hash.is_a?(Hash) == false
        ret << {"status" => "error", "message" => "json object must contain [id, name]"}
        next
      end
      if hash["start"].nil? || hash["stop"].nil? || hash["name"].nil?
        ret << {"status" => "error", "message" => "json object must contain [start, stop, name]", "input" => hash, status => 400}
        next
      end
      begin
        hash["start"] = DateTime.parse(hash["start"]).strftime("%s").to_i
        hash["stop"] = DateTime.parse(hash["stop"]).strftime("%s").to_i
        model = @model_class.from_json(hash, name: hash["name"], scope: params[:scope])
        model.create()
        ret << model.as_json
      rescue Date::Error, JSON::ParserError => e
        ret << {"status" => "error", "message" => e.message, "input" => hash, status => 400}
      rescue ArgumentError => e
        ret << {"status" => "error", "message" => e.message, "input" => hash, status => 400}
      rescue Cosmos::ActivityInputError => e
        ret << {"status" => "error", "message" => e.message, "input" => hash, status => 400}
      rescue Cosmos::ActivityOverlapError => e
        ret << {"status" => "error", "message" => e.message, "input" => hash, status => 409}
      rescue Cosmos::ActivityError => e
        ret << {"status" => "error", "message" => e.message, "input" => hash, status => 418}
      end
    end
    render :json => ret, :status => 200
  end

  # Removes multiple activities by score/start/id.
  #
  # scope [String] the scope of the timeline, `TEST`
  # json [String] The json below
  # @return [String] the activity as a object/hash converted into json format
  #```json
  #  [
  #    {
  #      "name": "system42", # name of the timeline
  #      "id": "12345678" # score/start/id of the timeline
  #    }
  #  }
  def multi_destroy
    authorize(permission: 'system', scope: params[:scope], token: headers[:Authorization])
    begin
      array = JSON.parse(params[:json])
    rescue JSON::ParserError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
      return
    end
    ret = Array.new
    array.each do |hash|
      if hash.is_a?(Hash) == false
        ret << {"status" => "error", "message" => "json object must contain [id, name]"}
        next
      end
      if hash["id"].nil? || hash["name"].nil?
        hash.update({"status" => "error", "message" => "json object must contain [id, name]"})
        ret << hash
        next
      end
      model = @model_class.score(name: hash["name"], score: hash["id"], scope: params[:scope])
      if model.nil?
        hash.update({"status" => "error", "message" => "not found"})
        ret << hash
        next
      end
      begin
        check = model.destroy()
        hash.update({"status" => "removed", "removed" => check})
        ret << hash
      rescue Cosmos::ActivityError => e
        hash.update({"status" => "error", "message" => e.message})
        ret << hash
      end
    end
    render :json => ret, :status => 200
  end

end
