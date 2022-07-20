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

require 'openc3/models/reaction_model'
require 'openc3/topics/autonomic_topic'

class ReactionController < ApplicationController
  def initialize
    @model_class = OpenC3::ReactionModel
  end

  # Returns an array/list of reactions in json.
  #
  # scope [String] the scope of the reaction, `TEST`
  # @return [String] the array of triggers converted into json format
  def index
    return unless authorization('system')
    begin
      triggers = @model_class.all(scope: params[:scope])
      ret = Array.new
      triggers.each do |_, trigger|
        ret << trigger
      end
      render :json => ret, :status => 200
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class, 'backtrace' => e.backtrace }, :status => 500
    end
  end

  # Returns an reactions in json.
  #
  # name [String] the reaction name, `RV1-12345`
  # scope [String] the scope of the reaction, `TEST`
  # @return [String] the array of reactions converted into json format.
  def show
    return unless authorization('system')
    begin
      model = @model_class.get(name: params[:name], scope: params[:scope])
      render :json => model.as_json(:allow_nan => true), :status => 200
    rescue OpenC3::ReactionInputError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 404
    rescue OpenC3::ReactionError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class, 'backtrace' => e.backtrace }, :status => 500
    end
  end

  # Create a new reaction and return the object/hash of the trigger in json.
  #
  # name [String] the reaction name, `PV1-12345`
  # scope [String] the scope of the trigger, `TEST`
  # json [String] The json of the event (see #reaction_model)
  # @return [String] the trigger converted into json format
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
  #    "description": "POSX greater than 200",
  #    "snooze": 300,
  #    "review": true,
  #    "triggers": [
  #      {
  #        "name": "TV0-1234",
  #        "group": "foo",
  #      }
  #    ],
  #    "actions": [
  #      {
  #        "type": "command",
  #        "value": "INST CLEAR",
  #      }
  #    ]
  #  }
  #```
  def create
    return unless authorization('run_script')
    begin
      hash = params.to_unsafe_h.slice(:description, :review, :snooze, :triggers, :actions).to_h
      name = @model_class.create_mini_id()
      model = @model_class.from_json(hash.symbolize_keys, name: name, scope: params[:scope])
      model.create()
      model.deploy()
      render :json => model.as_json(:allow_nan => true), :status => 201
    rescue OpenC3::ReactionInputError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
    rescue OpenC3::ReactionError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 418
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class, 'backtrace' => e.backtrace }, :status => 500
    end
  end

  # Update and returns an object/hash of a single reaction in json.
  #
  # name [String] the reaction name, `PV1-12345`
  # scope [String] the scope of the reaction, `TEST`
  # json [String] The json of the event (see #reaction_model)
  # @return [String] the reaction as a object/hash converted into json format
  # Request Headers
  #```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  #```
  # Request Post Body
  #```json
  #  {}
  #```
  def update
    return unless authorization('run_script')
    model = @model_class.get(name: params[:name], scope: params[:scope])
    if model.nil?
      render :json => { :status => 'error', :message => 'not found' }, :status => 404
      return
    end
    begin
      hash = params.to_unsafe_h.slice(:description, :review, :snooze, :triggers, :actions).to_h
      model.update()
      render :json => model.as_json(:allow_nan => true), :status => 200
    rescue OpenC3::ReactionInputError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
    rescue OpenC3::ReactionError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 418
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class, 'backtrace' => e.backtrace }, :status => 500
    end
  end

  # Set reaction active to true
  #
  # name [String] the reaction name, `PV1-12345`
  # scope [String] the scope of the reaction, `TEST`
  # @return [String] the reaction as a object/hash converted into json format
  # Request Headers
  #```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  #```
  # Request Post Body
  #```json
  #  {}
  #```
  def activate
    return unless authorization('run_script')
    begin
      model = @model_class.get(name: params[:name], scope: params[:scope])
      if model.nil?
        render :json => { :status => 'error', :message => 'not found' }, :status => 404
        return
      end
      model.activate() unless model.active
      render :json => model.as_json(:allow_nan => true), :status => 200
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class, 'backtrace' => e.backtrace }, :status => 500
    end
  end

  # Set reaction active to false
  #
  # name [String] the reaction name, `PV1-12345`
  # scope [String] the scope of the reaction, `TEST`
  # @return [String] the reaction as a object/hash converted into json format
  # Request Headers
  #```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  #```
  # Request Post Body
  #```json
  #  {}
  #```
  def deactivate
    return unless authorization('run_script')
    begin
      model = @model_class.get(name: params[:name], scope: params[:scope])
      if model.nil?
        render :json => { :status => 'error', :message => 'not found' }, :status => 404
        return
      end
      model.deactivate() if model.active
      render :json => model.as_json(:allow_nan => true), :status => 200
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class, 'backtrace' => e.backtrace }, :status => 500
    end
  end

  # Removes an reaction by name/id.
  #
  # name [String] the reaction name, `PV1-12345`
  # scope [String] the scope of the reaction, `TEST`
  # @return [String] object/hash converted into json format but with a 204 no-content status code
  # Request Headers
  #```json
  #  {
  #    "Authorization": "token/password",
  #    "Content-Type": "application/json"
  #  }
  #```
  def destroy
    return unless authorization('run_script')
    begin
      @model_class.delete(name: params[:name], scope: params[:scope])
      render :json => {"status" => true}, :status => 204
    rescue OpenC3::ReactionInputError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 404
    rescue OpenC3::ReactionError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class }, :status => 400
    rescue StandardError => e
      render :json => { :status => 'error', :message => e.message, 'type' => e.class, 'backtrace' => e.backtrace }, :status => 500
    end
  end
end
