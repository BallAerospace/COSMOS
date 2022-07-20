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

require 'rails_helper'

RSpec.describe ReactionController, :type => :controller do
  # TARGET = 'INST'.freeze

  before(:each) do
    mock_redis()
    # OpenC3::TargetModel.new(TARGET)
    # allow_any_instance_of(OpenC3::MicroserviceModel).to receive(:create).and_return(nil)
  end

  def generate_trigger(
    name: 'foobar',
    left: {'type' => 'value', 'value' => '9000'},
    operator: '>',
    right: {'type' => 'value', 'value' => '42'}
  )
    TriggerModel.new(
      name: name,
      scope: SCOPE,
      target: 'INST',
      packet: 'ADCS',
      left: left,
      operator: operator,
      right: right,
      dependents: []
    ).create()
  end

  def generate_reaction_hash(
    description: 'another test',
    triggers: ['foobar'],
    reactions: [{'type' => 'command', 'data' => 'TEST'}]
  )
    return {
      'description' => description,
      'snooze' => 300,
      'triggers' => triggers,
      'reactions' => reactions
    }
  end

  describe 'GET index' do
    it 'returns an empty array and status code 200' do
      get :index, params: {'scope'=>'DEFAULT'}
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json).to eql([])
      expect(response).to have_http_status(:ok)
    end
  end

  xdescribe 'POST then GET index with Triggers' do
    it 'returns an array and status code 200' do
      hash = generate_reaction_hash()
      post :create, params: hash.merge({'scope'=>'DEFAULT'})
      expect(response).to have_http_status(:created)
      trigger = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(trigger['name']).not_to be_nil
      get :get, params: {'scope'=>'DEFAULT', 'name'=>trigger['name']}
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      get :index, params: {'scope'=>'DEFAULT'}
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json.empty?).to eql(false)
      expect(json.length).to eql(1)
      expect(json[0]['name']).to eql(trigger['name'])
    end
  end

  xdescribe 'POST create' do
    it 'returns a json hash of name and status code 201' do
      hash = generate_reaction_hash()
      post :create, params: hash.merge({'scope'=>'DEFAULT'})
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['name']).not_to be_nil
    end
  end

  xdescribe 'POST two reactions on different scopes then GET index' do
    it 'returns an array of one and status code 200' do
      hash = generate_reaction_hash()
      post :create, params: hash.merge({'scope'=>'DEFAULT'})
      expect(response).to have_http_status(:created)
      default_json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      post :create, params: hash.merge({'scope'=>'TEST'})
      expect(response).to have_http_status(:created)
      test_json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      # name should not match
      expect(default_json['name']).not_to eql(test_json['name'])
      # check the value on the index
      get :index, params: {'scope'=>'DEFAULT'}
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json.empty?).to eql(false)
      expect(json.length).to eql(1)
      expect(json[0]['name']).to eql(default_json['name'])
    end
  end

  # describe 'PUT update' do
  #   it 'returns a json hash of name and status code 200' do
  #     hash = generate_reaction_hash()
  #     post :create, params: hash.merge({'scope'=>'DEFAULT'})
  #     expect(response).to have_http_status(:created)
  #     json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
  #     expect(json['name']).not_to be_nil
  #     expect(json['dependents']).not_to be_nil
  #     json['description'] = 'something...'
  #     put :update, params: json.merge({'scope'=>'DEFAULT'})
  #     expect(response).to have_http_status(:ok)
  #     json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
  #     expect(json['name']).not_to be_nil
  #     expect(json['description']).to eql('something...')
  #   end
  # end

  xdescribe 'POST error' do
    it 'returns a hash and status code 400' do
      post :create, params: {'scope'=>'DEFAULT'}
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['status']).to eql('error')
      expect(json['message']).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  xdescribe 'POST error bad trigger' do
    it 'returns a hash and status code 400' do
      hash = generate_reaction_hash()
      hash['triggers'] = ['problem']
      post :create, params: hash.merge({'scope'=>'DEFAULT'})
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['status']).to eql('error')
      expect(json['message']).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe 'DELETE' do
    it 'returns a json hash of name and status code 404 if not found' do
      delete :destroy, params: {'scope'=>'DEFAULT', 'name'=>'test'}
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['status']).to eql('error')
      expect(json['message']).not_to be_nil
    end

    xit 'returns a json hash of name and status code 204 if found' do
      allow_any_instance_of(OpenC3::MicroserviceModel).to receive(:undeploy).and_return(nil)
      hash = generate_reaction_hash()
      post :create, params: hash.merge({'scope'=>'DEFAULT'})
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      delete :destroy, params: {'scope'=>'DEFAULT', 'name'=>json['name']}
      expect(response).to have_http_status(:no_content)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['name']).to eql('test')
    end
  end
end
