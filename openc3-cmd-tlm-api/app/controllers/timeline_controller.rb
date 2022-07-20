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

require 'openc3/models/timeline_model'

class TimelineController < ApplicationController
  def initialize
    @model_class = OpenC3::TimelineModel
  end

  # Returns an array/list of timeline values in json.
  #
  # scope [String] the scope of the timeline, `TEST`
  # @return [String] the array of timeline names converted into json format
  def index
    return unless authorization('system')
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
    return unless authorization('run_script')
    begin
      model = @model_class.new(name: params['name'], color: params['color'], scope: params[:scope])
      model.create()
      model.deploy()
      OpenC3::Logger.info("Timeline created: #{params['name']}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      render :json => model.as_json(:allow_nan => true), :status => 201
    rescue RuntimeError, JSON::ParserError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
    rescue TypeError
      render :json => { :status => 'error', :message => 'Invalid json object', 'type' => e.class }, :status => 400
    rescue OpenC3::TimelineInputError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
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
    return unless authorization('run_script')
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
      model.notify(kind: 'updated')
      render :json => model.as_json(:allow_nan => true), :status => 200
    rescue RuntimeError, JSON::ParserError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
    rescue TypeError
      render :json => { :status => 'error', :message => 'Invalid json object', 'type' => e.class }, :status => 400
    rescue OpenC3::TimelineInputError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
    end
  end

  # Returns hash/object of timeline name in json with a 204 no-content status code.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # @return [String] hash/object of timeline name in json with a 204 no-content status code
  def destroy
    return unless authorization('run_script')
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
      model.notify(kind: 'deleted')
      OpenC3::Logger.info("Timeline destroyed: #{params[:name]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      render :json => { 'name' => params[:name]}, :status => 204
    rescue OpenC3::TimelineError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
    end
  end
end
