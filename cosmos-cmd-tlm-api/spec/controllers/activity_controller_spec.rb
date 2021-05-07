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

require 'rails_helper'
require 'cosmos/models/timeline_model'

RSpec.describe ActivityController, :type => :controller do
  before(:each) do
    mock_redis()
  end

  def generate_activity(start)
      dt = DateTime.now.new_offset(0)
      start_time = dt + (start/24.0)
      end_time = dt + ((start+1.0)/24.0)
      post_hash = {
        "start_time" => start_time.to_s,
        "end_time" => end_time.to_s,
        "kind" => "cmd",
        "data" => {"test"=>"test"}
      }
      json = JSON.generate(post_hash)
  end

  describe "GET index" do
    it "returns an empty array and status code 200" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(50.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      expect(response).to have_http_status(:created)
      get :index, params: {"scope"=>"DEFAULT", "name"=>"test"}
      json = JSON.parse(response.body)
      expect(json).to eql([])
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET index" do
    it "returns an array and status code 200" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(50.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      expect(response).to have_http_status(:created)
      start = DateTime.now.new_offset(0) + 2.0 # add two days
      stop = start + (4.0/24.0) # add four hours to the start time
      get :index, params: {"scope"=>"DEFAULT", "name"=>"test", "start_time"=>start.to_s, "end_time"=>stop.to_s}
      json = JSON.parse(response.body)
      expect(response).to have_http_status(:ok)
      expect(json.empty?).to eql(false)
      expect(json.length).to eql(1)
    end
  end

  describe "GET count" do
    it "returns a json hash of name and count and status code 200" do
      request.headers["Authorization"] = "foobar"
      get :count, params: {"scope"=>"DEFAULT", "name"=>"test"}
      json = JSON.parse(response.body)
      expect(json["name"]).to eql("test")
      expect(json["count"]).to eql(0)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST create" do
    it "returns a hash and status code 201" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(1.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      ret = JSON.parse(response.body)
      expect(ret["score"]).not_to be_nil
      expect(ret["updated_at"]).not_to be_nil
      expect(ret["duration"]).to eql(3600)
      expect(ret["start_time"]).not_to be_nil
      expect(ret["end_time"]).not_to be_nil
      expect(response).to have_http_status(:created)
    end
  end

  describe "POST create bad json" do
    it "returns a hash and status code 400" do
      request.headers["Authorization"] = "foobar"
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>"TEST"}
      ret = JSON.parse(response.body)
      expect(ret["status"]).to eql("error")
      expect(ret["message"]).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe "POST create negative" do
    it "returns a hash and status code 400" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(-1.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      ret = JSON.parse(response.body)
      expect(ret["status"]).to eql("error")
      expect(ret["message"]).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe "POST create longer than a day" do
    it "returns a hash and status code 400" do
      request.headers["Authorization"] = "foobar"
      dt = DateTime.now.new_offset(0)
      start_time = dt + (1.0/24.0)
      end_time = dt + 2.0
      post_hash = {
        "start_time" => start_time.to_s,
        "end_time" => end_time.to_s,
        "kind" => "cmd",
        "data" => {"test"=>"test"}
      }
      json = JSON.generate(post_hash)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      ret = JSON.parse(response.body)
      expect(ret["status"]).to eql("error")
      expect(ret["message"]).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe "POST create missing values" do
    it "returns a hash and status code 400" do
      request.headers["Authorization"] = "foobar"
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>"{}"}
      ret = JSON.parse(response.body)
      expect(ret["status"]).to eql("error")
      expect(ret["message"]).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe "POST overwrite another" do
    it "returns a hash and status code 409" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(1.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      expect(response).to have_http_status(:created)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      ret = JSON.parse(response.body)
      expect(ret["status"]).to eql("error")
      expect(ret["message"]).not_to be_nil
      expect(response).to have_http_status(409)
    end
  end

  describe "POST event" do
    it "returns a hash and status code 200" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(1.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      expect(response).to have_http_status(:created)
      created = JSON.parse(response.body)
      expect(created["score"]).not_to be_nil
      json = JSON.generate({"status"=>"valid", "message"=>"external event update"})
      post :event, params: {"scope"=>"DEFAULT", "name"=>"test", "id"=>created["score"], "json"=>json}
      ret = JSON.parse(response.body)
      expect(ret["events"].empty?).to eql(false)
      expect(ret["events"].length).to eql(2)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET show" do
    it "returns a hash and status code 200" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(1.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      expect(response).to have_http_status(:created)
      created = JSON.parse(response.body)
      expect(created["score"]).not_to be_nil
      get :show, params: {"scope"=>"DEFAULT", "name"=>"test", "id"=>created["score"]}
      ret = JSON.parse(response.body)
      expect(ret["score"]).to eql(created["score"])
      expect(ret["updated_at"]).not_to be_nil
      expect(ret["duration"]).to eql(3600)
      expect(ret["start_time"]).not_to be_nil
      expect(ret["end_time"]).not_to be_nil
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET show invalid score" do
    it "returns a hash and status code 404" do
      request.headers["Authorization"] = "foobar"
      get :show, params: {"scope"=>"DEFAULT", "name"=>"test", "id"=>"200"}
      ret = JSON.parse(response.body)
      expect(ret["status"]).to eql("error")
      expect(ret["message"]).not_to be_nil
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT update invalid score" do
    it "returns a hash and status code 404" do
      request.headers["Authorization"] = "foobar"
      put :update, params: {"scope"=>"DEFAULT", "name"=>"test", "id"=>"200"}
      ret = JSON.parse(response.body)
      expect(ret["status"]).to eql("error")
      expect(ret["message"]).not_to be_nil
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT update not json" do
    it "returns a hash and status code 400" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(1.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      created = JSON.parse(response.body)
      expect(created["score"]).not_to be_nil
      put :update, params: {"scope"=>"DEFAULT", "name"=>"test", "id"=>created["score"], "json"=>"test"}
      ret = JSON.parse(response.body)
      expect(ret["status"]).to eql("error")
      expect(ret["message"]).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe "PUT update" do
    it "returns a hash and status code 200" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(1.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      created = JSON.parse(response.body)
      expect(created["score"]).not_to be_nil
      json = generate_activity(2.0)
      put :update, params: {"scope"=>"DEFAULT", "name"=>"test", "id"=>created["score"], "json"=>json}
      ret = JSON.parse(response.body)
      expect(ret["score"]).not_to eql(created["score"])
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PUT update negative time" do
    it "returns a hash and status code 400" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(1.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      expect(response).to have_http_status(:created)
      created = JSON.parse(response.body)
      expect(created["score"]).not_to be_nil
      json = generate_activity(-2.0)
      put :update, params: {"scope"=>"DEFAULT", "name"=>"test", "id"=>created["score"], "json"=>json}
      ret = JSON.parse(response.body)
      expect(ret["status"]).to eql("error")
      expect(ret["message"]).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end

  describe "PUT update invalid json" do
    it "returns a hash and status code 400" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(1.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      expect(response).to have_http_status(:created)
      created = JSON.parse(response.body)
      expect(created["score"]).not_to be_nil
      put :update, params: {"scope"=>"DEFAULT", "name"=>"test", "id"=>created["score"], "json"=>"{}"}
      ret = JSON.parse(response.body)
      expect(ret["status"]).to eql("error")
      expect(ret["message"]).not_to be_nil
      expect(response).to have_http_status(400)
    end
  end


  describe "PUT update" do
    it "returns a hash and status code 409" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(1.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      expect(response).to have_http_status(:created)
      created = JSON.parse(response.body)
      expect(created["score"]).not_to be_nil
      json = generate_activity(2.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      expect(response).to have_http_status(:created)
      json = generate_activity(2.0)
      put :update, params: {"scope"=>"DEFAULT", "name"=>"test", "id"=>created["score"], "json"=>json}
      ret = JSON.parse(response.body)
      expect(ret["status"]).to eql("error")
      expect(ret["message"]).not_to be_nil
      expect(response).to have_http_status(409)
    end
  end

  describe "DELETE destroy" do
    it "returns a status code 204" do
      request.headers["Authorization"] = "foobar"
      json = generate_activity(1.0)
      post :create, params: {"scope"=>"DEFAULT", "name"=>"test", "json"=>json}
      expect(response).to have_http_status(:created)
      created = JSON.parse(response.body)
      expect(created["score"]).not_to be_nil
      delete :destroy, params: {"scope"=>"DEFAULT", "name"=>"test", "id"=>created["score"]}
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "DELETE destroy" do
    it "returns a status code 404" do
      request.headers["Authorization"] = "foobar"
      delete :destroy, params: {"scope"=>"DEFAULT", "name"=>"test", "id"=>"200"}
      ret = JSON.parse(response.body)
      expect(ret["status"]).to eql("error")
      expect(ret["message"]).not_to be_nil
      expect(response).to have_http_status(:not_found)
    end
  end

end