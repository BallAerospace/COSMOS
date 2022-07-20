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

require 'openc3/models/activity_model'
require 'openc3/topics/timeline_topic'

class ActivityController < ApplicationController
  def initialize
    @model_class = OpenC3::ActivityModel
  end

  # Returns an array/list of activities in json. With optional start_time and end_time parameters
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # start [String] (optional) The start time of the search window for timeline to return. Recommend in ISO format, `2031-04-16T01:02:00+00:00`. If not provided start_time is equal to 12 hours before the request is made.
  # stop [String] (optional) The stop time of the search window for timeline to return. Recommend in ISO format, `2031-04-16T01:02:00+00:00`. If not provided end_time is equal to 2 days after the request is made.
  # @return [String] the array of activities converted into json format.
  def index
    return unless authorization('system')
    now = DateTime.now.new_offset(0)
    begin
      start = params[:start].nil? ? (now - 7) : DateTime.parse(params[:start]) # minus 7 days
      stop = params[:stop].nil? ? (now + 7) : DateTime.parse(params[:stop]) # plus 7 days
      start = start.strftime('%s').to_i
      stop = stop.strftime('%s').to_i
      model = @model_class.get(name: params[:name], scope: params[:scope], start: start, stop: stop)
      render :json => model.as_json(:allow_nan => true), :status => 200
    rescue ArgumentError
      render :json => { :status => 'error', :message => 'Invalid date provided. Recommend ISO format' }, :status => 400
    rescue OpenC3::ActivityInputError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
    end
  end

  # Returns an object/hash of activity in json.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # json [String] The json of the activity (see below)
  # @return [String] the activity converted into json format
  # Request Headers
  # ```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  # ```
  # Request Post Body
  # ```json
  #  {
  #    "start": "2031-04-16T01:02:00",
  #    "stop": "2031-04-16T01:02:00",
  #    "kind": "cmd",
  #    "data": {"cmd"=>"INST ABORT"}
  #  }
  # ```
  def create
    return unless authorization('run_script')
    begin
      hash = params.to_unsafe_h.slice(:start, :stop, :kind, :data).to_h
      if hash['start'].nil? || hash['stop'].nil?
        raise ArgumentError.new 'post body must contain start and stop'
      end

      hash['start'] = DateTime.parse(hash['start']).strftime('%s').to_i
      hash['stop'] = DateTime.parse(hash['stop']).strftime('%s').to_i
      model = @model_class.from_json(hash.symbolize_keys, name: params[:name], scope: params[:scope])
      model.create()
      OpenC3::Logger.info(
        "Activity created: #{params[:name]} #{hash}",
        scope: params[:scope],
        user: user_info(request.headers['HTTP_AUTHORIZATION'])
      )
      render :json => model.as_json(:allow_nan => true), :status => 201
    rescue ArgumentError, TypeError => e
      message = "Invalid input: #{JSON.parse(hash, :allow_nan => true, :create_additions => true)}"
      render :json => { :status => 'error', :message => message, :type => e.class, :e => e.to_s }, :status => 400
    rescue OpenC3::ActivityInputError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 400
    rescue OpenC3::ActivityOverlapError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 409
    rescue OpenC3::ActivityError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 418
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 400
    end
  end

  # Returns an object/hash the contains `count` as a key in json.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # @return [String] the object/hash converted into json format
  # Request Headers
  # ```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  # ```
  def count
    return unless authorization('system')
    begin
      count = @model_class.count(name: params[:name], scope: params[:scope])
      render :json => { :name => params[:name], :count => count }, :status => 200
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 400
    end
  end

  # Returns an object/hash of a single activity in json.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # id [String] the start/id of the activity, `1620248449`
  # @return [String] the activity as a object/hash converted into json format
  # Request Headers
  # ```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  # ```
  def show
    return unless authorization('system')
    begin
      model = @model_class.score(name: params[:name], score: params[:id], scope: params[:scope])
      if model.nil?
        render :json => { :status => 'error', :message => 'not found' }, :status => 404
      else
        render :json => model.as_json(:allow_nan => true), :status => 200
      end
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 400
    end
  end

  # Adds an event to the object/hash of a single activity in json.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # id [String] the score/id of the activity, `1620248449`
  # json [String] The json of the event (see #event_model)
  # @return [String] the activity as a object/hash converted into json format
  # Request Headers
  # ```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  # ```
  # Request Post Body
  # ```json
  #  {
  #    "status": "system42-ready",
  #    "message": "script was completed"
  #  }
  # ```
  def event
    return unless authorization('run_script')
    model = @model_class.score(name: params[:name], score: params[:id], scope: params[:scope])
    if model.nil?
      render :json => { :status => 'error', :message => 'not found' }, :status => 404
      return
    end
    begin
      hash = params.to_unsafe_h.slice(:status, :message).to_h
      model.commit(status: hash['status'], message: hash['message'])
      OpenC3::Logger.info(
        "Event created for activity: #{params[:name]} #{hash}",
        scope: params[:scope],
        user: user_info(request.headers['HTTP_AUTHORIZATION'])
      )
      render :json => model.as_json(:allow_nan => true), :status => 200
    rescue ArgumentError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 400
    rescue OpenC3::ActivityError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 418
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 400
    end
  end

  # Update and returns an object/hash of a single activity in json.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # id [String] the score or id of the activity, `1620248449`
  # json [String] The json of the event (see #activity_model)
  # @return [String] the activity as a object/hash converted into json format
  # Request Headers
  # ```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  # ```
  # Request Post Body
  # ```json
  #  {
  #    "start": "2031-04-16T01:02:00+00:00",
  #    "stop": "2031-04-16T01:02:00+00:00",
  #    "kind": "cmd",
  #    "data": {"cmd"=>"INST ABORT"}
  #  }
  # ```
  def update
    return unless authorization('run_script')
    model = @model_class.score(name: params[:name], score: params[:id], scope: params[:scope])
    if model.nil?
      render :json => { :status => 'error', :message => 'not found' }, :status => 404
      return
    end
    begin
      hash = params.to_unsafe_h.slice(:start, :stop, :kind, :data).to_h
      hash['start'] = DateTime.parse(hash['start']).strftime('%s').to_i
      hash['stop'] = DateTime.parse(hash['stop']).strftime('%s').to_i
      model.update(start: hash['start'], stop: hash['stop'], kind: hash['kind'], data: hash['data'])
      OpenC3::Logger.info(
        "Activity updated: #{params[:name]} #{hash}",
        scope: params[:scope],
        user: user_info(request.headers['HTTP_AUTHORIZATION'])
      )
      render :json => model.as_json(:allow_nan => true), :status => 200
    rescue ArgumentError, TypeError => e
      message = "Invalid input: #{JSON.parse(hash, :allow_nan => true, :create_additions => true)}"
      render :json => { :status => 'error', :message => message, :type => e.class, :e => e.to_s }, :status => 400
    rescue OpenC3::ActivityInputError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 400
    rescue OpenC3::ActivityOverlapError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 409
    rescue OpenC3::ActivityError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 418
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 400
    end
  end

  # Removes an activity activity by score/id.
  #
  # name [String] the timeline name, `system42`
  # scope [String] the scope of the timeline, `TEST`
  # id [String] the score or id of the activity, `1620248449`
  # @return [String] object/hash converted into json format but with a 204 no-content status code
  # Request Headers
  # ```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  # ```
  def destroy
    return unless authorization('run_script')
    begin
      model = @model_class.score(name: params[:name], score: params[:id], scope: params[:scope])
      if model.nil?
        render :json => { :status => 'error', :message => 'not found' }, :status => 404
        return
      end
      ret = model.destroy()
      OpenC3::Logger.info(
        "Activity destroyed: #{params[:name]}",
        scope: params[:scope],
        user: user_info(request.headers['HTTP_AUTHORIZATION'])
      )
      render :json => { "status" => ret }, :status => 204
    rescue OpenC3::ActivityError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class }, :status => 400
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :e => e.to_s }, :status => 400
    end
  end

  # Creates multiple activities by score/start/id.
  #
  # scope [String] the scope of the timeline, `TEST`
  # json [String] The json of the event (see #activity_model)
  # @return [String] the activity as a object/hash converted into json format
  # Request Headers
  # ```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  # ```
  # Request Post Body
  # ```json
  #  {
  #    "multi": [
  #      {
  #        "name": "test",
  #        "start": "2031-04-16T01:02:00+00:00",
  #        "stop": "2031-04-16T01:02:00+00:00",
  #        "kind": "cmd",
  #        "data": {"cmd"=>"INST ABORT"
  #      }
  #    ]
  #  }
  # ```
  def multi_create
    return unless authorization('run_script')
    input_activities = params.to_unsafe_h.slice(:multi).to_h['multi']
    unless input_activities.is_a?(Array)
      render(:json => { :status => 'error', :message => 'invalid input, must be json list/array' }, :status => 400) and return
    end

    ret = Array.new
    input_activities.each do |input|
      next if input.is_a?(Hash) == false || input['start'].nil? || input['stop'].nil? || input['name'].nil?

      begin
        hash = input.dup
        name = hash.delete('name')
        hash['start'] = DateTime.parse(hash['start']).strftime('%s').to_i
        hash['stop'] = DateTime.parse(hash['stop']).strftime('%s').to_i
        model = @model_class.from_json(hash.symbolize_keys, name: name, scope: params[:scope])
        model.create()
        OpenC3::Logger.info(
          "Activity created: #{name} #{hash}",
          scope: params[:scope],
          user: user_info(request.headers['HTTP_AUTHORIZATION'])
        )
        ret << model.as_json(:allow_nan => true)
      rescue ArgumentError, TypeError => e
        ret << { :status => 'error', :message => "Invalid input, #{e.message}", 'input' => input, 'type' => e.class, status => 400 }
      rescue OpenC3::ActivityInputError => e
        ret << { :status => 'error', :message => e.message, :input => input, :type => e.class, :err => 400 }
      rescue OpenC3::ActivityOverlapError => e
        ret << { :status => 'error', :message => e.message, :input => input, :type => e.class, :err => 409 }
      rescue OpenC3::ActivityError => e
        ret << { :status => 'error', :message => e.message, :input => input, :type => e.class, :err => 418 }
      rescue StandardError => e
        ret << { :status => 'error', :message => e.message, :input => input, :type => e.class, :err => 400 }
      end
    end
    render :json => ret, :status => 200
  end

  # Removes multiple activities by score/start/id.
  #
  # scope [String] the scope of the timeline, `TEST`
  # json [String] The json below
  # @return [String] the activity as a object/hash converted into json format
  # Request Headers
  # ```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  # ```
  # Request Post Body
  # ```json
  #  {
  #    "multi": [
  #      {
  #        "name": "system42", # name of the timeline
  #        "id": "12345678" # score/start/id of the timeline
  #      }
  #    ]
  #  }
  # ```
  def multi_destroy
    return unless authorization('run_script')
    input_activities = params.to_unsafe_h.slice(:multi).to_h['multi']
    unless input_activities.is_a?(Array)
      render(:json => { :status => 'error', :message => 'invalid input' }, :status => 400) and return
    end

    ret = Array.new
    input_activities.each do |input|
      next if input.is_a?(Hash) == false || input['id'].nil? || input['name'].nil?

      model = @model_class.score(name: input['name'], score: input['id'], scope: params[:scope])
      next if model.nil?

      begin
        check = model.destroy()
        OpenC3::Logger.info("Activity destroyed: #{input['name']}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
        ret << { 'status' => 'removed', 'removed' => check, 'input' => input, 'type' => e.class }
      rescue OpenC3::ActivityError => e
        ret << { :status => 'error', :message => e.message, :input => input, :type => e.class, :err => 400 }
      rescue StandardError => e
        ret << { :status => 'error', :message => e.message, :input => input, :type => e.class, :err => 400 }
      end
    end
    render :json => ret, :status => 200
  end
end
