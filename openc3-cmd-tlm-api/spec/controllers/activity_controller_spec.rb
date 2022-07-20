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

RSpec.describe ActivityController, :type => :controller do
  before(:each) do
    mock_redis()
  end

  def generate_activity_hash(start)
      dt = DateTime.now.new_offset(0)
      start_time = dt + (start/24.0)
      stop_time = dt + ((start+1.0)/24.0)
      return {
        'start' => start_time.to_s,
        'stop' => stop_time.to_s,
        'kind' => 'cmd',
        'data' => {'cmd'=>'Test'}
      }
  end

  describe "GET index" do
    it "returns an empty array and status code 200" do
      hash = generate_activity_hash(200.0)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      expect(response).to have_http_status(:created)
      get :index, params: { 'scope'=>'DEFAULT', 'name'=>'test' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json).to eql([])
    end

    it "returns an array and status code 200" do
      hash = generate_activity_hash(50.0)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      expect(response).to have_http_status(:created)
      start = DateTime.now.new_offset(0) + 2.0 # add two days
      stop = start + (4.0/24.0) # add four hours to the start time
      get :index, params: { 'scope'=>'DEFAULT', 'name'=>'test', 'start'=>start.to_s, 'stop'=>stop.to_s }
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(response).to have_http_status(:ok)
      expect(json.empty?).to eql(false)
      expect(json.length).to eql(1)
    end
  end

  describe "GET count" do
    it "returns a json hash of name and count and status code 200" do
      get :count, params: { 'scope'=>'DEFAULT', 'name'=>'test' }
      json = JSON.parse(response.body)
      expect(json["name"]).to eql("test")
      expect(json["count"]).to eql(0)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST create" do
    it "returns a hash and status code 201" do
      hash = generate_activity_hash(1.0)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['updated_at']).not_to be_nil
      expect(ret['duration']).to eql(3600)
      expect(ret['start']).not_to be_nil
      expect(ret['stop']).not_to be_nil
      expect(response).to have_http_status(:created)
    end

    xit "returns a hash and status code 400 with missing values" do
      post :create, params: { 'scope'=>'DEFAULT', 'name'=>'test' }
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
      expect(response).to have_http_status(400)
    end

    it "returns a hash and status code 400 with negative values" do
      hash = generate_activity_hash(-1.0)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
      expect(response).to have_http_status(400)
    end

    it "returns a hash and status code 400 with longer than 1 day" do
      dt = DateTime.now.new_offset(0)
      dt_start = dt + (1.0/24.0)
      dt_stop = dt + 2.0
      hash = {
        "start" => dt_start.to_s,
        'stop' => dt_stop.to_s,
        "kind" => "cmd",
        "data" => {"test"=>"test"}
      }
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
      expect(response).to have_http_status(400)
    end

    it "returns a hash and status code 409 with overwrite" do
      hash = generate_activity_hash(1.0)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      expect(response).to have_http_status(:created)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
      expect(response).to have_http_status(409)
    end
  end

  describe "POST event" do
    it "returns a hash and status code 200" do
      hash = generate_activity_hash(1.0)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      expect(response).to have_http_status(:created)
      created = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(created['start']).not_to be_nil
      event_hash = { 'status'=>'valid', 'message'=>'external event update' }
      post :event, params: event_hash.merge({'scope'=>'DEFAULT', 'name'=>'test', 'id'=>created['start'] })
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret["events"].empty?).to eql(false)
      expect(ret["events"].length).to eql(2)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET show" do
    it "returns a hash and status code 200" do
      hash = generate_activity_hash(1.0)
      post :create, params: hash.merge({'scope'=>'DEFAULT', 'name'=>'test' })
      expect(response).to have_http_status(:created)
      created = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(created['start']).not_to be_nil
      get :show, params: {'scope'=>'DEFAULT', 'name'=>'test', 'id'=>created['start']}
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['start']).to eql(created['start'])
      expect(ret['stop']).to eql(created['stop'])
      expect(ret['updated_at']).not_to be_nil
      expect(ret['duration']).to eql(3600)
      expect(response).to have_http_status(:ok)
    end

    it "returns a hash and status code 404 with invalid start" do
      get :show, params: {'scope'=>'DEFAULT', 'name'=>'test', 'id'=>'200'}
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT update" do
    it "returns a hash and status code 200" do
      hash = generate_activity_hash(1.0)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      created = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(created['start']).not_to be_nil
      hash = generate_activity_hash(2.0)
      put :update, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test', 'id'=>created['start'] })
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['start']).not_to eql(created['start'])
      expect(response).to have_http_status(:ok)
    end

    it "returns a hash and status code 409" do
      hash = generate_activity_hash(1.0)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      expect(response).to have_http_status(:created)
      created = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(created['start']).not_to be_nil
      hash = generate_activity_hash(2.0)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      expect(response).to have_http_status(:created)
      hash = generate_activity_hash(2.0)
      put :update, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test', 'id'=>created['start'] })
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
      expect(response).to have_http_status(409)
    end

    it "returns a hash and status code 404 with invalid start" do
      put :update, params: {'scope'=>'DEFAULT', 'name'=>'test', 'id'=>'200'}
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
      expect(response).to have_http_status(:not_found)
    end

    xit "returns a hash and status code 400 with valid params" do
      hash = generate_activity_hash(1.0)
      post :create, params: hash.merge({'scope'=>'DEFAULT', 'name'=>'test' })
      created = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(created['start']).not_to be_nil
      put :update, params: {'scope'=>'DEFAULT', 'name'=>'test', 'id'=>created['start']}
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
      expect(response).to have_http_status(400)
    end

    xit "returns a hash and status code 400 with negative time" do
      hash = generate_activity_hash(1.0)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      expect(response).to have_http_status(:created)
      created = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(created['start']).not_to be_nil
      json = generate_activity_hash(-2.0)
      put :update, params: {'scope'=>'DEFAULT', 'name'=>'test', 'id'=>created['start'], "json"=>json}
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
      expect(response).to have_http_status(400)
    end

    xit "returns a hash and status code 400 with invalid json" do
      hash = generate_activity_hash(1.0)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      expect(response).to have_http_status(:created)
      created = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(created['start']).not_to be_nil
      put :update, params: {'scope'=>'DEFAULT', 'name'=>'test', 'id'=>created['start'], 'start'=>'Test'}
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe "DELETE destroy" do
    it "returns a status code 204" do
      hash = generate_activity_hash(1.0)
      post :create, params: hash.merge({ 'scope'=>'DEFAULT', 'name'=>'test' })
      expect(response).to have_http_status(:created)
      created = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(created['start']).not_to be_nil
      delete :destroy, params: {'scope'=>'DEFAULT', 'name'=>'test', 'id'=>created['start']}
      expect(response).to have_http_status(:no_content)
    end

    it "returns a status code 404" do
      delete :destroy, params: {'scope'=>'DEFAULT', 'name'=>'test', "id"=>"200"}
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST multi_create" do
    it "returns an array and status code 200" do
      post_array = []
      for i in (1..10) do
        dt = DateTime.now.new_offset(0)
        start_time = dt + (i/24.0)
        stop_time = dt + ((i+0.5)/24.0)
        post_array << {
          "name" => "test",
          "start" => start_time.to_s,
          'stop' => stop_time.to_s,
          "kind" => "cmd",
          "data" => {"test"=>"test #{i}"}
        }
      end
      post :multi_create, params: {'scope'=>'DEFAULT', 'multi'=>post_array}
      expect(response).to have_http_status(:ok)
      get :index, params: {'scope'=>'DEFAULT', 'name'=>'test'}
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json.empty?).to eql(false)
      expect(json.length).to eql(10)
    end

    it "returns an array and status code 200 with errors" do
      dt = DateTime.now.new_offset(0)
      start_time = dt + (1/24.0)
      stop_time = dt + ((1.5)/24.0)
      post_array = [
        {'name' => 'foo', 'start' => start_time.to_s, 'stop' => stop_time.to_s},
        {'start' => start_time.to_s, 'stop' => stop_time.to_s},
        'Test',
        1,
      ]
      post :multi_create, params: {'scope'=>'DEFAULT', 'multi'=>post_array}
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json.empty?).to eql(false)
      expect(json.length).to eql(1)
    end
  end

  describe "POST multi_destory" do
    it "returns a hash and status code 400" do
      post :multi_create, params: {'scope'=>'DEFAULT', 'multi'=>'TEST'}
      expect(response).to have_http_status(400)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['status']).to eql('error')
      expect(json['message']).not_to be_nil
      post :multi_destroy, params: {'scope'=>'DEFAULT', 'multi'=>'TEST'}
      expect(response).to have_http_status(400)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['status']).to eql('error')
      expect(json['message']).not_to be_nil
    end

    it "returns an array and status code 200" do
      create_post_array = []
      for i in (1..10) do
        dt = DateTime.now.new_offset(0)
        start_time = dt + (i/24.0)
        stop_time = dt + ((i+0.5)/24.0)
        create_post_array << {
          'name' => 'test',
          'start' => start_time.to_s,
          'stop' => stop_time.to_s,
          'kind' => 'cmd',
          'data' => {'cmd'=>"test #{i}"}
        }
      end
      post :multi_create, params: {'scope'=>'DEFAULT', 'multi'=>create_post_array}
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      destroy_post_array = []
      json.each do |hash|
        destroy_post_array << {"name" => hash["name"], "id" => hash['start']}
      end
      post :multi_destroy, params: {'scope'=>'DEFAULT', 'multi'=>destroy_post_array}
      expect(response).to have_http_status(:ok)
      get :index, params: {"scope"=>"DEFAULT", "name"=>"test"}
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json.empty?).to eql(true)
    end

    it "returns an array and status code 200 with errors" do
      dt = DateTime.now.new_offset(0)
      destroy_post_array = [
        {'id'=>'123456'},
        'Test',
        1,
      ]
      post :multi_destroy, params: {'scope'=>'DEFAULT', 'multi'=>destroy_post_array}
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json.empty?).to eql(true)
    end
  end
end
