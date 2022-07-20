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

require 'digest'
require 'openc3/models/environment_model'

class EnvironmentController < ApplicationController
  def initialize
    @model_class = OpenC3::EnvironmentModel
  end

  # Returns an array/list of environment values in json.
  #
  # scope [String] the scope of the environment, `TEST`
  # @return [String] the array of environment names converted into json format
  def index
    return unless authorization('system')
    environments = @model_class.all(scope: params[:scope])
    ret = Array.new
    environments.each do |_environment, value|
      ret << value
    end
    render :json => ret, :status => 200
  end

  # Create a new environment returns object/hash of the environment in json.
  #
  # scope [String] the scope of the environment, `TEST`
  # json [String] The json of the environment name (see below)
  # @return [String] the environment converted into json format
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
  #    "key": "ENVIRONMENT_KEY",
  #    "value": "VALUE"
  #  }
  # ```
  def create
    return unless authorization('run_script')
    if params['key'].nil? || params['value'].nil?
      render :json => {
        'status' => 'error',
        'message' => "failed to get 'key' 'value' environment pair",
      }, :status => 400
      return
    end
    begin
      name = Digest::SHA1.hexdigest("#{params['key']}__#{params['value']}")
      unless @model_class.get(name: name, scope: params[:scope]).nil?
        raise OpenC3::EnvironmentError.new "key: #{params['key']} value: #{params['value']} pair already available."
      end

      model = @model_class.new(name: name, key: params['key'], value: params['value'], scope: params[:scope])
      model.create()
      OpenC3::Logger.info("Environment variable created: #{name} #{params['key']} #{params['value']}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      render :json => model.as_json(:allow_nan => true), :status => 201
    rescue RuntimeError, JSON::ParserError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
    rescue TypeError
      render :json => { :status => 'error', :message => 'Invalid json object', 'type' => e.class }, :status => 400
    rescue OpenC3::EnvironmentError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 409
    end
  end

  # Returns hash/object of environment name in json with a 204 no-content status code.
  #
  # name [String] the environment name, `bffcdb71ce38b7604db3c53000adef1ed851606d`
  # scope [String] the scope of the environment, `TEST`
  # @return [String] hash/object of environment name in json with a 204 no-content status code
  def destroy
    return unless authorization('run_script')
    model = @model_class.get(name: params[:name], scope: params[:scope])
    if model.nil?
      render :json => {
        'status' => 'error',
        'message' => "failed to find environment: #{params[:name]}",
      }, :status => 404
      return
    end
    begin
      ret = @model_class.destroy(name: params[:name], scope: params[:scope])
      OpenC3::Logger.info("Environment variable destroyed: #{params[:name]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
      render :json => { 'name' => params[:name] }, :status => 204
    rescue OpenC3::EnvironmentError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
    end
  end
end
