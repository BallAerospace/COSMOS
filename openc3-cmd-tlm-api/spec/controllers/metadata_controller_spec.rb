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

RSpec.describe MetadataController, :type => :controller do
  before(:each) do
    mock_redis()
  end

  def create_metadata(start: Time.now, color: '#FFFFFF', metadata: {'key'=> 'value'})
    post :create, params: { scope: 'DEFAULT', start: start.iso8601, color: color, metadata: metadata }
    start
  end

  describe "POST create" do
    it "successfully creates metadata object with a start time" do
      start = create_metadata()
      expect(response).to have_http_status(:created)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['start']).to eql(start.to_i)
    end

    it "successfully creates metadata object without specific start time" do
      now = Time.now.to_i
      post :create, params: { scope: 'DEFAULT', metadata: {'key'=> 'value'} }
      expect(response).to have_http_status(:created)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['updated_at'].to_i / Time::NSEC_PER_SECOND).to be_within(1).of(now)
      expect(ret['start']).to be_within(1).of(now)
    end

    it "returns an error and status code 400 with bad start" do
      post :create, params: { scope: 'DEFAULT', start: 'foo', metadata: {'key'=> 'value'} }
      expect(response).to have_http_status(:bad_request)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql("error")
      expect(ret['message']).to match("no time information")
    end

    it "returns an error and status code 400 with duplicate start" do
      now = Time.now
      create_metadata(start: now)
      create_metadata(start: now)
      expect(response).to have_http_status(:bad_request)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql("error")
      expect(ret['message']).to match("duplicate")
    end

    it "returns an error and status code 400 with bad color" do
      create_metadata(color: 'mycolor')
      expect(response).to have_http_status(:bad_request)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql("error")
      expect(ret['message']).to match("invalid color")
    end

    it "returns an error and status code 400 with no metadata" do
      post :create, params: { scope: 'DEFAULT', start: Time.now.iso8601 }
      expect(response).to have_http_status(:bad_request)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql("error")
      expect(ret['message']).to match("missing keyword: :metadata")
    end

    it "returns an error and status code 401 with bad authorization" do
      post :create # Simply don't pass in the scope
      expect(response).to have_http_status(:unauthorized)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql("error")
      expect(ret['message']).to match("Scope is required")
    end
  end

  describe "GET latest" do
    it "successfully returns a metadata object and status code 200" do
      post :create, params: { scope: 'DEFAULT', start: (Time.now - 100).iso8601, metadata: {'key'=> 'past'} }
      post :create, params: { scope: 'DEFAULT', start: Time.now.iso8601, metadata: {'key'=> 'latest'} }
      post :create, params: { scope: 'DEFAULT', start: (Time.now + 100).iso8601, metadata: {'key'=> 'future'} }
      get :latest,  params: { scope: 'DEFAULT' }
      expect(response).to have_http_status(:ok)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['metadata']).to eql({'key'=> 'latest'})
    end

    it "returns error and status 204 if no metadata" do
      get :latest,  params: { scope: 'DEFAULT' }
      expect(response).to have_http_status(:no_content)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql("error")
      expect(ret['message']).to match("no metadata entries")
    end

    it "returns an error and status code 401 with bad authorization" do
      get :latest # Simply don't pass in the scope
      expect(response).to have_http_status(:unauthorized)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql("error")
      expect(ret['message']).to match("Scope is required")
    end
  end

  describe "GET index" do
    it "successfully returns an empty array and status code 200" do
      get :index, params: { scope: 'DEFAULT' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json).to eql([])
    end

    it "successfully returns all the metadata" do
      post :create, params: { scope: 'DEFAULT', start: Time.now.iso8601, metadata: {'key'=> 'value1'} }
      post :create, params: { scope: 'DEFAULT', start: (Time.now + 1).iso8601, metadata: {'key'=> 'value2'} }
      post :create, params: { scope: 'DEFAULT', start: (Time.now + 2).iso8601, metadata: {'key'=> 'value3'} }
      post :create, params: { scope: 'OTHER', start: Time.now.iso8601, metadata: {'key'=> 'value4'} }
      get :index, params: { scope: 'DEFAULT' }
      expect(response).to have_http_status(:ok)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      metadata = ret.map { |item| item['metadata'] }
      expect(metadata).to eql([{'key'=> 'value3'}, {'key'=> 'value2'}, {'key'=> 'value1'}])
      get :index, params: { scope: 'OTHER' }
      expect(response).to have_http_status(:ok)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      metadata = ret.map { |item| item['metadata'] }
      expect(metadata).to eql([{'key'=> 'value4'}])
    end

    # TODO: mock_redis doesn't currently implement limit
    # it "limits the metadata returned" do
    #   post :create, params: { scope: 'DEFAULT', metadata: {'key'=> 'value1'} }
    #   post :create, params: { scope: 'DEFAULT', metadata: {'key'=> 'value2'} }
    #   post :create, params: { scope: 'DEFAULT', metadata: {'key'=> 'value3'} }
    #   get :index, params: { scope: 'DEFAULT', limit: 2 }
    #   expect(response).to have_http_status(:ok)
    #   json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
    #   metadata = json.map { |item| item['metadata'] }
    #   expect(metadata).to eql([{'key'=> 'value1'}, {'key'=> 'value2'}])
    # end

    it "gets a range of metadata given start and end (inclusive)" do
      now = Time.now
      (0..10).each do |i|
        post :create, params: { scope: 'DEFAULT', start: (now - i).iso8601, metadata: {'key'=> i} }
      end
      get :index, params: { scope: 'DEFAULT', start: (now - 5).iso8601, stop: (now - 3).iso8601 }
      expect(response).to have_http_status(:ok)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      metadata = ret.map { |item| item['metadata'] }
      expect(metadata).to eql([{'key'=> '5'}, {'key'=> '4'}, {'key'=> '3'}])
    end

    it "returns an error and status code 400 with stop before start" do
      get :index, params: { scope: 'DEFAULT', start: Time.now.iso8601, stop: (Time.now - 1).iso8601 }
      expect(response).to have_http_status(:bad_request)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql("error")
      expect(ret['message']).to match(/start: \d+ must be before stop/)
    end

    it "returns an error and status code 400 with bad start" do
      get :index, params: { scope: 'DEFAULT', start: 'start', stop: (Time.now - 1).iso8601 }
      expect(response).to have_http_status(:bad_request)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql("error")
      expect(ret['message']).to match("no time information")
    end

    it "returns an error and status code 401 with bad authorization" do
      get :index # Simply don't pass in the scope
      expect(response).to have_http_status(:unauthorized)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql("error")
      expect(ret['message']).to match("Scope is required")
    end
  end

  # describe "GET search" do
  #   it "successfully returns a single value in an array and status code 200" do
  #     post :create, params: { scope: 'DEFAULT', start: Time.now.iso8601, metadata: {'version'=> '1'} }
  #     post :create, params: { scope: 'DEFAULT', start: (Time.now + 1).iso8601, metadata: {'version'=> '2'} }
  #     get :search, params: { scope: 'DEFAULT', key: 'version', value: '1' }
  #     expect(response).to have_http_status(:ok)
  #     json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
  #     expect(json.metadata).to eql({'version'=> '1'})
  #   end

  #   it "successfully returns an empty array and status code 200 if no match" do
  #     post :create, params: { scope: 'DEFAULT', start: Time.now.iso8601, metadata: {'version'=> '1'} }
  #     post :create, params: { scope: 'DEFAULT', start: (Time.now + 1).iso8601, metadata: {'version'=> '2'} }
  #     get :search, params: { scope: 'DEFAULT', key: 'version', value: '0' }
  #     expect(response).to have_http_status(:ok)
  #     json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
  #     expect(json.length).to eql(0)
  #   end
  # end

  describe "GET show" do
    it "returns an error object with status code 404" do
      get :show, params: { scope: 'DEFAULT', id: '42' }
      expect(response).to have_http_status(:not_found)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql("error")
      expect(ret['message']).to match("not found")
    end

    it "returns an instance and status code 200" do
      start = create_metadata()
      get :show, params: { scope: 'DEFAULT', id: start.to_i }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['start']).to eql(start.to_i)
    end
  end

  describe "PUT update" do
    it "attempts to update a bad metadata object returns an error with status code 404" do
      put :update, params: { scope: 'DEFAULT', id: '42' }
      expect(response).to have_http_status(:not_found)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql("error")
      expect(ret['message']).not_to be_nil
    end

    it "successfully updates a metadata object and status code 200" do
      start = create_metadata()
      put :update, params: { scope: 'DEFAULT', id: start.to_i, start: start.iso8601, metadata: {'version'=> '2'} }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['start']).to eql(start.to_i)
      expect(json['metadata']).to eql({'version' => '2'})

      get :show, params: { scope: 'DEFAULT', id: start.to_i }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['start']).to eql(start.to_i)
      expect(json['metadata']).to eql({'version' => '2'})

      get :latest,  params: { scope: 'DEFAULT' }
      expect(response).to have_http_status(:ok)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['start']).to eql(start.to_i)
      expect(json['metadata']).to eql({'version' => '2'})
    end

    it "successfully updates a metadata object with a different start time and status code 200" do
      start = create_metadata()
      put :update, params: { scope: 'DEFAULT', id: start.to_i, start: (start - 100).iso8601, metadata: {'version'=> '2'} }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['start']).to eql(start.to_i - 100)
      expect(json['metadata']).to eql({'version' => '2'})
    end

    it "attempts to update a bad metadata object and status code 400" do
      start = create_metadata()
      put :update, params: { scope: 'DEFAULT', id: start.to_i, start: start.iso8601, metadata: 'foo' }
      expect(response).to have_http_status(:bad_request)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
    end
  end

  describe "DELETE delete" do
    it "attempts to delete a bad metadata object with status code 404" do
      delete :destroy, params: { scope: 'DEFAULT', id: '42' }
      expect(response).to have_http_status(:not_found)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
    end

    it "attempts to delete a bad id with status code 400" do
      delete :destroy, params: { scope: 'DEFAULT', id: 'foo' }
      expect(response).to have_http_status(:bad_request)
      ret = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(ret['status']).to eql('error')
      expect(ret['message']).not_to be_nil
    end

    it "successfully updates a metadata object with status code 204" do
      start = create_metadata()
      delete :destroy, params: { scope: 'DEFAULT', id: start.to_i }
      expect(response).to have_http_status(:no_content)
    end
  end
end
