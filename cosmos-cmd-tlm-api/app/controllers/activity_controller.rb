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
  # @param name [String] the timeline name, `system42`
  # @param scope [String] the scope of the timeline, `TEST`
  # @param start_time [String] (optional) The start time of the search window for timeline to return. Recommend in ISO format, `2031-04-16T01:02:00+00:00`. If not provided start_time is equal to 12 hours before the request is made.
  # @param end_time [String] (optional) The end time of the search window for timeline to return. Recommend in ISO format, `2031-04-16T01:02:00+00:00`. If not provided end_time is equal to 2 days after the request is made.
  # @return [String] the array of activities converted into json format.
  def index
    authorize(permission: 'system', scope: params[:scope], token: params[:Authorization])
    now = DateTime.now.new_offset(0)
    start_time = params[:start_time].nil? ? (now - (12.0/24.0)).to_s : params[:start_time] # minus 12 hours
    end_time = params[:end_time].nil? ? (now + 2).to_s : params[:end_time] # plus 2 days
    begin
      model = @model_class.get(name: params[:name], scope: params[:scope], start_time: start_time, end_time: end_time)
      render :json => model.as_json(), :status => 200
    rescue Date::Error
      render :json => {"status" => "error", "message" => "Invalid date provided"}, :status => 400
    rescue Cosmos::ActivityInputError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    rescue StandardError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    end
  end

  # Returns an object/hash of activity in json.
  #
  # @param name [String] the timeline name, `system42`
  # @param scope [String] the scope of the timeline, `TEST`
  # @param json [String] The json of the activity (see below)
  # @return [String] the activity converted into json format
  #```json
  #  {
  #    "start_time": "2031-04-16T01:02:00+00:00",
  #    "end_time": "2031-04-16T01:02:00+00:00",
  #    "kind": "cmd",
  #    "data": {"cmd"=>"INST ABORT"}
  #  }
  #```
  def create
    authorize(permission: 'system', scope: params[:scope], token: params[:Authorization])
    begin
      model = @model_class.from_json(params[:json], name: params[:name], scope: params[:scope])
      model.create()
      render :json => model.as_json, :status => 201
    rescue JSON::ParserError => e
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
  # @param name [String] the timeline name, `system42`
  # @param scope [String] the scope of the timeline, `TEST`
  # @return [String] the object/hash converted into json format
  def count
    authorize(permission: 'system', scope: params[:scope], token: params[:Authorization])
    count = @model_class.count(name: params[:name], scope: params[:scope])
    render :json => {
      "name" => params[:name],
      "count" => count
    }, :status => 200
  end

  # Returns an object/hash of a single activity in json.
  #
  # @param name [String] the timeline name, `system42`
  # @param scope [String] the scope of the timeline, `TEST`
  # @param id [String] the score or id of the activity, `1620248449`
  # @return [String] the activity as a object/hash converted into json format
  def show
    authorize(permission: 'system', scope: params[:scope], token: params[:Authorization])
    model = @model_class.score(name: params[:name], score: params[:id], scope: params[:scope])
    if model.nil?
      render :json => {"status" => "error", "message" => "not found"}, :status => 404
    else
      render :json => model.as_json, :status => 200
    end
  end

  # Adds an event to the object/hash of a single activity in json.
  #
  # @param name [String] the timeline name, `system42`
  # @param scope [String] the scope of the timeline, `TEST`
  # @param id [String] the score or id of the activity, `1620248449`
  # @param json [String] The json of the event (see #event_model)
  # @return [String] the activity as a object/hash converted into json format
  #```json
  #  {
  #    "status": "system42-ready",
  #    "message": "script was completed"
  #  }
  def event
    authorize(permission: 'system', scope: params[:scope], token: params[:Authorization])
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
  # @param name [String] the timeline name, `system42`
  # @param scope [String] the scope of the timeline, `TEST`
  # @param id [String] the score or id of the activity, `1620248449`
  # @param json [String] The json of the event (see #activity_model)
  # @return [String] the activity as a object/hash converted into json format
  #```json
  #  {
  #    "start_time": "2031-04-16T01:02:00+00:00",
  #    "end_time": "2031-04-16T01:02:00+00:00",
  #    "kind": "cmd",
  #    "data": {"cmd"=>"INST ABORT"}
  #  }
  #``
  def update
    authorize(permission: 'system', scope: params[:scope], token: params[:Authorization])
    model = @model_class.score(name: params[:name], score: params[:id], scope: params[:scope])
    if model.nil?
      render :json => {"status" => "error", "message" => "not found"}, :status => 404
      return
    end
    begin
      hash = JSON.parse(params[:json])
      model.update(start_time: hash["start_time"], end_time: hash["end_time"], kind: hash["kind"], data: hash["data"])
      render :json => model.as_json, :status => 200
    rescue JSON::ParserError => e
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
  # @param name [String] the timeline name, `system42`
  # @param scope [String] the scope of the timeline, `TEST`
  # @param id [String] the score or id of the activity, `1620248449`
  # @return [String] object/hash converted into json format but with a 204 no-content status code
  def destroy
    authorize(permission: 'system', scope: params[:scope], token: params[:Authorization])
    model = @model_class.score(name: params[:name], score: params[:id], scope: params[:scope])
    if model.nil?
      render :json => {"status" => "error", "message" => "not found"}, :status => 404
      return
    end
    ret = @model_class.destroy(name: params[:name], score: params[:id], scope: params[:scope])
    render :json => {"status" => ret}, :status => 204
  end
end
