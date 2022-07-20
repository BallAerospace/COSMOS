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

RSpec.describe TimelineController, :type => :controller do
  before(:each) do
    mock_redis()
  end

  describe "GET index" do
    it "returns an empty array and status code 200" do
      get :index, params: {"scope"=>"DEFAULT"}
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json).to eql([])
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST then GET index with Timelines" do
    it "returns an array and status code 200" do
      post :create, params: {"scope"=>"DEFAULT", "name" => "test"}
      expect(response).to have_http_status(:created)
      get :index, params: {"scope"=>"DEFAULT"}
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json.empty?).to eql(false)
      expect(json.length).to eql(1)
      expect(json[0]["name"]).to eql("test")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST two timelines with the same name on different scopes then GET index with Timelines" do
    it "returns an array of one and status code 200" do
      post :create, params: {"scope"=>"DEFAULT", "name" => "test"}
      expect(response).to have_http_status(:created)
      post :create, params: {"scope"=>"TEST", "name" => "test"}
      expect(response).to have_http_status(:created)
      get :index, params: {"scope"=>"DEFAULT"}
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json.empty?).to eql(false)
      expect(json.length).to eql(1)
      expect(json[0]["name"]).to eql("test")
    end
  end

  describe "POST create" do
    it "returns a json hash of name and status code 201" do
      post :create, params: {"scope"=>"DEFAULT", "name" => "test"}
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json["name"]).to eql("test")
    end
  end

  describe "POST color" do
    it "returns a json hash of name and status code 200" do
      post :create, params: {"scope"=>"DEFAULT", "name" => "test"}
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json["name"]).to eql("test")
      expect(json["color"]).not_to be_nil
      post :color, params: {"scope"=>"DEFAULT", "name"=>"test", "color" => "#FF0000"}
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json["name"]).to eql("test")
      expect(json["color"]).to eql("#FF0000")
    end
  end

  describe "POST error" do
    it "returns a hash and status code 400" do
      post :create, params: {"scope"=>"DEFAULT"}
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json["status"]).to eql("error")
      expect(json["message"]).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe "POST error missing name" do
    it "returns a hash and status code 400" do
      post :create, params: {"scope"=>"DEFAULT", "test" => "name"}
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json["status"]).to eql("error")
      expect(json["message"]).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe "POST error invalid json" do
    it "returns a hash and status code 400" do
      post :create, params: {"scope"=>"DEFAULT"}
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json["status"]).to eql("error")
      expect(json["message"]).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe "DELETE" do
    it "returns a json hash of name and status code 204" do
      allow_any_instance_of(OpenC3::MicroserviceModel).to receive(:undeploy).and_return(nil)
      delete :destroy, params: {"scope"=>"DEFAULT", "name"=>"test"}
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json["status"]).to eql("error")
      expect(json["message"]).not_to be_nil
      expect(response).to have_http_status(:not_found)
      post :create, params: {"scope"=>"DEFAULT", "name" => "test"}
      expect(response).to have_http_status(:created)
      delete :destroy, params: {"scope"=>"DEFAULT", "name"=>"test"}
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json["name"]).to eql("test")
      expect(response).to have_http_status(:no_content)
    end
  end
end
