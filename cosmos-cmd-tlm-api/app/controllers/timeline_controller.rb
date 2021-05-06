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

require 'cosmos/models/timeline_model'

class TimelineController < ApplicationController
  def initialize
    @model_class = Cosmos::TimelineModel
  end

  # Returns an array/list of timeline names in json.
  #
  # @param name [String] the timeline name, `system42`
  # @param scope [String] the scope of the timeline, `TEST`
  # @return [String] the array of timeline names converted into json format
  def index
    authorize(permission: 'system', scope: params[:scope], token: headers[:Authorization])
    timelines = @model_class.names
    ret = Array.new
    timelines.each do |timeline|
      timeline_array = timeline.split("__")
      if params[:scope] == timeline_array[0]
        ret << timeline_array[2]
      end
    end
    render :json => ret, :status => 200
  end

  # Create a new timeline returns object/hash of the timeline in json.
  #
  # @param scope [String] the scope of the timeline, `TEST`
  # @param json [String] The json of the timeline name (see below)
  # @return [String] the timeline converted into json format
  #```json
  #  {
  #    "name": "system42"
  #  }
  #```
  def create
    authorize(permission: 'system', scope: params[:scope], token: params[:token])
    begin
      hash = JSON.parse(params[:json])
      model = @model_class.new(name: hash["name"], scope: params[:scope])
      model.create()
      model.deploy()
      render :json => {"name" => hash["name"]}, :status => 201
    rescue RuntimeError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    rescue JSON::ParserError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    rescue TypeError
      render :json => {"status" => "error", "message" => "Invalid json object"}, :status => 400
    rescue Cosmos::TimelineInputError => e
      render :json => {"status" => "error", "message" => e.message}, :status => 400
    end
  end

  # Returns hash/object of timeline name in json with a 204 no-content status code.
  #
  # @param name [String] the timeline name, `system42`
  # @param scope [String] the scope of the timeline, `TEST`
  # @return [String] hash/object of timeline name in json with a 204 no-content status code
  def destroy
    authorize(permission: 'system', scope: params[:scope], token: params[:token])
    model = @model_class.get(name: params[:name], scope: params[:scope])
    if model.nil?
      render :json => {
        "status" => "error",
        "message" => "failed to find timeline: #{params[:name]}",
      }, :status => 404
    else
      model.undeploy()
      model.notify(kind: "delete")
      ret = @model_class.delete(name: params[:name], scope: params[:scope])
      render :json => {
        "name" => params[:name],
      }, :status => 204
    end
  end

end
