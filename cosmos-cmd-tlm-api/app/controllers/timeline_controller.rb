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

  # Returns an array/list of timeline values in json.
  #
  # scope [String] the scope of the timeline, `TEST`
  # @return [String] the array of timeline names converted into json format
  def index
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 403) and return
    end
    timelines = @model_class.all
    ret = Array.new
    timelines.each do |timeline, value|
      if params[:scope] == timeline.split('__')[0]
        ret << value
      end
    end
    render :json => ret, :status => 200
  end

  # Create a new timeline returns object/hash of the timeline in json.
  #
  # scope [String] the scope of the timeline, `TEST`
  # json [String] The json of the timeline name (see below)
  # @return [String] the timeline converted into json format
  # Request Headers
  #```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  #```
  # Request Post Body
  #```json
  #  {
  #    "name": "system42",
  #    "color": "#FFFFFF"
  #  }
  #```
  def create
    begin
      authorize(permission: 'scripts', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 403) and return
    end
    begin
      model = @model_class.new(name: params['name'], color: params['color'], scope: params[:scope])
      model.create()
      model.deploy()
      render :json => model.as_json, :status => 201
    rescue RuntimeError, JSON::ParserError => e
      render :json => { 'status' => 'error', 'message' => e.message, 'type' => e.class }, :status => 400
    rescue TypeError
      render :json => { 'status' => 'error', 'message' => 'Invalid json object', 'type' => e.class }, :status => 400
    rescue Cosmos::TimelineInputError => e
      render :json => { 'status' => 'error', 'message' => e.message, 'type' => e.class }, :status => 400
    end
  end

  # Change the color returns object/hash of the timeline in json.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # json [String] The json of the timeline name (see below)
  # @return [String] the timeline converted into json format
  # Request Headers
  #```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  #```
  # Request Post Body
  #```json
  #  {
  #    "color": "#FFFFFF"
  #  }
  #```
  def color
    begin
      authorize(permission: 'scripts', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 403) and return
    end
    model = @model_class.get(name: params[:name], scope: params[:scope])
    if model.nil?
      render :json => {
        'status' => 'error',
        'message' => "failed to find timeline: #{params[:name]}",
      }, :status => 404
      return
    end
    begin
      model.update_color(color: params['color'])
      model.update()
      model.notify(kind: 'update')
      render :json => model.as_json, :status => 200
    rescue RuntimeError, JSON::ParserError => e
      render :json => { 'status' => 'error', 'message' => e.message, 'type' => e.class }, :status => 400
    rescue TypeError
      render :json => { 'status' => 'error', 'message' => 'Invalid json object', 'type' => e.class }, :status => 400
    rescue Cosmos::TimelineInputError => e
      render :json => { 'status' => 'error', 'message' => e.message, 'type' => e.class }, :status => 400
    end
  end

  # Returns hash/object of timeline name in json with a 204 no-content status code.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # @return [String] hash/object of timeline name in json with a 204 no-content status code
  def destroy
    begin
      authorize(permission: 'scripts', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { 'status' => 'error', 'message' => e.message }, :status => 403) and return
    end
    model = @model_class.get(name: params[:name], scope: params[:scope])
    if model.nil?
      render :json => {
        'status' => 'error',
        'message' => "failed to find timeline: #{params[:name]}",
      }, :status => 404
      return
    end
    begin
      use_force = params[:force].nil? == false && params[:force] == 'true'
      ret = @model_class.delete(name: params[:name], scope: params[:scope], force: use_force)
      model.undeploy()
      model.notify(kind: 'delete')
      render :json => { 'name' => params[:name]}, :status => 204
    rescue Cosmos::TimelineError => e
      render :json => { 'status' => 'error', 'message' => e.message, 'type' => e.class }, :status => 400
    end
  end

end
