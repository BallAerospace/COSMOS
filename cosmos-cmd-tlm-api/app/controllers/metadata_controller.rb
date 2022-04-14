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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos/models/metadata_model'

class MetadataController < ApplicationController
  def initialize
    @model_class = Cosmos::MetadataModel
  end

  def parse_time_input(x_start:, x_stop:)
    now = DateTime.now.new_offset(0)
    start = x_start.nil? ? (now - 7) : DateTime.parse(x_start) # minus 7 days
    stop = x_stop.nil? ? (now + 7) : DateTime.parse(x_stop) # plus 7 days
    return start.strftime('%s%3N').to_i, stop.strftime('%s%3N').to_i
  end

  # Returns a single metadata in json
  #
  # name [String] the target or name of metadata, `INST`
  # scope [String] the scope of the chronicle, `DEFAULT`
  # target [String] (required) The key in the metadata
  # @return [String] the current metadata converted into json format.
  def get
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    begin
      model = @model_class.get_current_value(target: params[:name], scope: params[:scope])
      if model.nil?
        render :json => { :status => 'error', :message => 'not found' }, :status => 204
        return
      end
      render :json => model.as_json(), :status => 200
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :backtrace => e.backtrace }, :status => 400
    end
  end

  # Returns an array/list of metadata in json. With optional start_time and end_time parameters
  #
  # scope [String] the scope of the chronicle, `DEFAULT`
  # start [String] (optional) The start time of the search window for chronicle to return. Recommend in ISO format, `2031-04-16T01:02:00+00:00`. If not provided start_time is equal to 12 hours before the request is made.
  # stop [String] (optional) The stop time of the search window for chronicle to return. Recommend in ISO format, `2031-04-16T01:02:00+00:00`. If not provided end_time is equal to 2 days after the request is made.
  # @return [String] the array of entries converted into json format.
  def index
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    begin
      start, stop = parse_time_input(x_start: params[:start], x_stop: params[:stop])
      json_array = @model_class.get(scope: params[:scope], start: start, stop: stop)
      render :json => json_array, :status => 200
    rescue ArgumentError
      render :json => { :status => 'error', :message => 'Invalid input provided' }, :status => 400
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :backtrace => e.backtrace }, :status => 400
    end
  end

  # Returns an array/list of metadata in json. With optional start_time and end_time parameters
  #
  # scope [String] the scope of the chronicle, `DEFAULT`
  # start [String] (optional) The start time of the search window for chronicle to return. Recommend in ISO format, `2031-04-16T01:02:00+00:00`. If not provided start_time is equal to 12 hours before the request is made.
  # stop [String] (optional) The stop time of the search window for chronicle to return. Recommend in ISO format, `2031-04-16T01:02:00+00:00`. If not provided end_time is equal to 2 days after the request is made.
  # key [String] (required) The key in the metadata
  # value [String] (required) The value equal to the value of the key in the metadata
  # @return [String] the array of entries converted into json format.
  def search
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    begin
      start, stop = parse_time_input(x_start: params[:start], x_stop: params[:stop])
      json_array = @model_class.get(scope: params[:scope], start: start, stop: stop)
      key, value = [params[:key], params[:value]]
      raise MetadataInputError "Must include key, value in metadata search" if key.nil? || value.nil?
      selected_array = json_array.select { | json_model | json_model['metadata'][key] == value }
      render :json => selected_array, :status => 200
    rescue ArgumentError => e
      render :json => { :status => 'error', :message => 'Invalid input provided' }, :status => 400
    rescue Cosmos::MetadataError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class }, :status => 400
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :backtrace => e.backtrace }, :status => 400
    end
  end

  # Returns an object/hash the contains `count` as a key in json.
  #
  # scope [String] the scope of the chronicle, `DEFAULT`
  # @return [String] the object/hash converted into json format
  # Request Headers
  # ```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  # ```
  def count
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    begin
      count = @model_class.count(scope: params[:scope])
      render :json => { 'name' => params[:name], 'count' => count }, :status => 200
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :backtrace => e.backtrace }, :status => 400
    end
  end

  # Returns an object/hash of a single metadata in json.
  #
  # scope [String] the scope of the chronicle, `DEFAULT`
  # id [String] the id of the entry, `1620248449`
  # @return [String] the metadata as a object/hash converted into json format
  # Request Headers
  # ```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  # ```
  def show
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    begin
      model_hash = @model_class.score(score: params[:id], scope: params[:scope])
      if model_hash.nil?
        render :json => { :status => 'error', :message => 'not found' }, :status => 404
        return
      end
      render :json => model_hash, :status => 200
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :backtrace => e.backtrace }, :status => 400
    end
  end

  # Record metadata and returns an object/hash of in json.
  #
  # scope [String] the scope of the chronicle, `DEFAULT`
  # json [String] The json of the activity (see below)
  # @return [String] the metadata converted into json format
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
  #    "target": "INST",
  #    "start": "2031-04-16T01:02:00.001+00:00",
  #    "color": "#FF0000",
  #    "metadata": {"version"=>"v1234567"}
  #  }
  # ```
  def create
    begin
      authorize(permission: 'scripts', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    begin
      hash = params.to_unsafe_h.slice(:target, :start, :color, :metadata).to_h
      if hash['start'].nil?
        hash['start'] = DateTime.now.strftime('%s%3N').to_i
      else
        hash['start'] = DateTime.parse(hash['start']).strftime('%s%3N').to_i
      end
      model = @model_class.from_json(hash.symbolize_keys, scope: params[:scope])
      model.create()
      Cosmos::Logger.info(
        "Metadata created: #{model}",
        scope: params[:scope],
        user: user_info(request.headers['HTTP_AUTHORIZATION'])
      )
      render :json => model.as_json, :status => 201
    rescue ArgumentError, TypeError => e
      message = "Invalid input: #{JSON.generate(hash)}"
      render :json => { :status => 'error', :message => message, :type => e.class }, :status => 400
    rescue Cosmos::MetadataInputError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class }, :status => 400
    rescue Cosmos::MetadataError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class }, :status => 418
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :backtrace => e.backtrace }, :status => 400
    end
  end

  # Update metadata and returns an object/hash of in json.
  #
  # id [String] the id or start value, `12345667`
  # scope [String] the scope of the chronicle, `TEST`
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
  #    "target": "target",
  #    "start": "2031-04-16T01:02:00.001+00:00",
  #    "metadata": {"version"=>"v1234567"}
  #    "color": "#FF0000",
  #  }
  # ```
  def update
    begin
      authorize(permission: 'scripts', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    begin
      hash = @model_class.score(score: params[:id], scope: params[:scope])
      if hash.nil?
        render :json => { :status => 'error', :message => 'not found' }, :status => 404
        return
      end
      model = @model_class.from_json(hash.symbolize_keys, scope: params[:scope])

      hash = params.to_unsafe_h.slice(:target, :start, :color, :metadata).to_h
      hash['start'] = DateTime.parse(hash['start']).strftime('%s%3N').to_i
      model.update(start: hash['start'], color: hash['color'], metadata: hash['metadata'])
      Cosmos::Logger.info(
        "Metadata updated: #{model}",
        scope: params[:scope],
        user: user_info(request.headers['HTTP_AUTHORIZATION'])
      )
      render :json => model.as_json, :status => 200
    rescue ArgumentError, TypeError => e
      message = "Invalid input: #{JSON.generate(hash)}"
      render :json => { :status => 'error', :message => message, :type => e.class }, :status => 400
    rescue Cosmos::MetadataInputError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class }, :status => 400
    rescue Cosmos::MetadataError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class }, :status => 418
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :backtrace => e.backtrace }, :status => 400
    end
  end

  # Removes metadata by score/id.
  #
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
  def delete
    begin
      authorize(permission: 'scripts', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end
    begin
      hash = @model_class.score(score: params[:id], scope: params[:scope])
      if hash.nil?
        render :json => { :status => 'error', :message => 'not found' }, :status => 404
        return
      end
      model = @model_class.from_json(hash.symbolize_keys, scope: params[:scope])
      model.destroy()
      Cosmos::Logger.info(
        "Metadata destroyed: #{params[:id]}",
        scope: params[:scope],
        user: user_info(request.headers['HTTP_AUTHORIZATION'])
      )
      render :json => { "status" => 1 }, :status => 204
    rescue Cosmos::MetadataError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class }, :status => 400
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, :type => e.class, :backtrace => e.backtrace }, :status => 400
    end
  end

end
