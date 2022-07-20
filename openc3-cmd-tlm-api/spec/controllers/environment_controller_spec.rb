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

RSpec.describe EnvironmentController, :type => :controller do
  before(:each) do
    mock_redis()
  end

  describe "GET index" do
    it "returns an empty array and status code 200" do
      get :index, params: { "scope" => "DEFAULT" }
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json).to eql([])
      expect(response).to have_http_status(:ok)
    end
  end

  xdescribe "POST then GET index with Environments" do
    it "returns an array and status code 200" do
      post :create, params: { 'scope' => 'DEFAULT', 'key' => 'NAME', 'value' => 'BOB' }
      expect(response).to have_http_status(:created)
      get :index, params: { "scope" => "DEFAULT" }
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(response).to have_http_status(:ok)
      expect(json.empty?).to eql(false)
      expect(json.length).to eql(1)
      expect(json[0]["name"]).to eql('BOB')
    end
  end

  xdescribe "POST two Environments with the same name on different scopes then GET index with Environments" do
    it "returns an array of one and status code 200" do
      post :create, params: { 'scope' => 'DEFAULT', 'key' => 'NAME', 'value' => 'OBO' }
      expect(response).to have_http_status(:created)
      post :create, params: { 'scope' => 'TEST', 'key' => 'NAME', 'value' => 'BOB' }
      expect(response).to have_http_status(:created)
      get :index, params: { 'scope' => 'DEFAULT' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json.empty?).to eql(false)
      expect(json.length).to eql(1)
      expect(json[0]["name"]).to eql('OBO')
    end
  end

  xdescribe "POST create" do
    it "returns a json hash of name and status code 201" do
      post :create, params: { 'scope' => 'DEFAULT', 'key' => 'NAME', 'value' => 'BOB' }
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json["name"]).to eql('BOB')
    end
  end

  describe "POST error" do
    it "returns a hash and status code 400" do
      post :create, params: { 'scope' => 'DEFAULT' }
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['status']).to eql('error')
      expect(json['message']).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe "POST error missing key and value" do
    it "returns a hash and status code 400" do
      post :create, params: { 'scope' => 'DEFAULT', 'test' => 'name' }
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['status']).to eql('error')
      expect(json['message']).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe "POST error invalid json" do
    it "returns a hash and status code 400" do
      post :create, params: { 'scope' => 'DEFAULT', 'key' => 'ERROR' }
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['status']).to eql('error')
      expect(json['message']).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  xdescribe "DELETE" do
    it "returns a json hash of name and status code 204" do
      delete :destroy, params: { 'scope' => 'DEFAULT', "name" => "foobar" }
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['status']).to eql('error')
      expect(json['message']).not_to be_nil
      expect(response).to have_http_status(:not_found)
      post :create, params: { 'scope' => 'DEFAULT', 'key' => 'FOO', 'value' => 'BAR' }
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      delete :destroy, params: { 'scope' => 'DEFAULT', 'name' => json['name'] }
      expect(response).to have_http_status(:no_content)
      get :index, params: { 'scope' => 'DEFAULT', 'name' => json['name'] }
      expect(response).to have_http_status(:not_found)
    end
  end
end
