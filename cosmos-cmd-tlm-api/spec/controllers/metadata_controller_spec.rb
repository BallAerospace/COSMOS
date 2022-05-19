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

require 'rails_helper'

RSpec.describe MetadataController, :type => :controller do
  before(:each) do
    mock_redis()
  end

  describe "POST create" do
    it "successfully creates metadata object with status code 201" do
      post :create, params: { scope: 'DEFAULT', metadata: {'key'=> 'value'} }
      expect(response).to have_http_status(:created)
      ret = JSON.parse(response.body)
      expect(ret['updated_at']).not_to be_nil
      expect(ret['start']).not_to be_nil
    end

    it "successfully creates metadata object with a start time with status code 201" do
      start = "2022-01-1T01:02:00.001+00:00"
      post :create, params: { scope: 'DEFAULT', start: start, metadata: {'key'=> 'value'} }
      expect(response).to have_http_status(:created)
      ret = JSON.parse(response.body)
      expect(ret['updated_at']).not_to be_nil
      expect(ret['start']).not_to be_nil
    end

    it "returns an error and status code 400 with bad start" do
      post :create, params: { scope: 'DEFAULT', start: 'foo', metadata: {'key'=> 'value'} }
      expect(response).to have_http_status(:bad_request)
      ret = JSON.parse(response.body)
      expect(ret['status']).not_to be_nil
      expect(ret['message']).not_to be_nil
    end

    it "returns an error and status code 400 with no metadata" do
      start = "2022-01-1T01:02:00.001+00:00"
      post :create, params: { scope: 'DEFAULT', start: start }
      expect(response).to have_http_status(:bad_request)
      ret = JSON.parse(response.body)
      expect(ret['status']).not_to be_nil
      expect(ret['message']).not_to be_nil
    end
  end

  describe "GET latest" do
    it "successfully returns a metadata object and status code 200" do
      post :create, params: { scope: 'DEFAULT', metadata: {'key'=> 'value'} }
      expect(response).to have_http_status(:created)
      get :latest
      expect(response).to have_http_status(:ok)
      ret = JSON.parse(response.body)
      expect(ret['updated_at']).not_to be_nil
    end
  end

  describe "GET index" do
    it "successfully returns an empty array and status code 200" do
      get :index, params: { scope: 'DEFAULT' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eql([])
    end

    it "successfully returns all the metadata" do
      post :create, params: { scope: 'DEFAULT', metadata: {'key'=> 'value1'} }
      expect(response).to have_http_status(:created)
      post :create, params: { scope: 'DEFAULT', metadata: {'key'=> 'value2'} }
      expect(response).to have_http_status(:created)
      post :create, params: { scope: 'OTHER', metadata: {'key'=> 'value3'} }
      expect(response).to have_http_status(:created)
      get :index, params: { scope: 'DEFAULT' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      metadata = json.map { |item| item['metadata'] }
      expect(metadata).to eql([{'key'=> 'value1'}, {'key'=> 'value2'}])
      get :index, params: { scope: 'OTHER' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      metadata = json.map { |item| item['metadata'] }
      expect(metadata).to eql([{'key'=> 'value3'}])
    end
  end

  describe "GET search" do
    it "successfully returns a single value in an array and status code 200" do
      post :create, params: { scope: 'DEFAULT', metadata: {'version'=> '1'} }
      expect(response).to have_http_status(:created)
      post :create, params: { scope: 'DEFAULT', metadata: {'version'=> '2'} }
      expect(response).to have_http_status(:created)
      get :search, params: { scope: 'DEFAULT', key: 'version', value: '1' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.length).to eql(1)
    end

    it "successfully returns an array and status code 200" do
      post :create, params: { scope: 'DEFAULT', metadata: {'version'=> '1'} }
      expect(response).to have_http_status(:created)
      post :create, params: { scope: 'DEFAULT', metadata: {'version'=> '2'} }
      expect(response).to have_http_status(:created)
      get :search, params: { scope: 'DEFAULT', key: 'version', value: '0' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.length).to eql(0)
    end
  end

  describe "GET show" do
    it "returns an error object with status code 404" do
      get :show, params: { scope: 'DEFAULT', id: '42' }
      expect(response).to have_http_status(:not_found)
      ret = JSON.parse(response.body)
      expect(ret['status']).not_to be_nil
      expect(ret['message']).not_to be_nil
    end

    it "returns an instance and status code 200" do
      post :create, params: { scope: 'DEFAULT', metadata: {'version'=> '1'} }
      expect(response).to have_http_status(:created)
      new_json = JSON.parse(response.body)
      get :show, params: { scope: 'DEFAULT', id: new_json['start'] }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['start']).to eql(new_json['start'])
    end
  end

  describe "PUT update" do
    it "attempts to update a bad metadata object returns an error with status code 404" do
      put :update, params: { scope: 'DEFAULT', id: '42' }
      expect(response).to have_http_status(:not_found)
      ret = JSON.parse(response.body)
      expect(ret['status']).not_to be_nil
      expect(ret['message']).not_to be_nil
    end

    it "successfully updates a metadata object and status code 200" do
      start = "2022-01-1T01:02:00.001+00:00"
      post :create, params: { scope: 'DEFAULT', start: start, metadata: {'version'=> '1'} }
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['metadata']['version']).to eql('1')
      start_id = DateTime.parse(start).strftime('%s%3N')
      put :update, params: { scope: 'DEFAULT', id: start_id, start: start, metadata: {'version'=> '2'} }
      expect(response).to have_http_status(:ok)
      new_json = JSON.parse(response.body)
      expect(json['start']).to eql(new_json['start'])
      expect(new_json['metadata']['version']).to eql('2')
    end

    it "successfully updates a metadata object with a different start time and status code 200" do
      start = "2022-01-1T01:02:00.001+00:00"
      post :create, params: { scope: 'DEFAULT', start: start, metadata: {'version'=> '1'} }
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['metadata']['version']).to eql('1')
      start_id = DateTime.parse(start).strftime('%s%3N')
      start = "2022-02-02T02:02:00.001+00:00"
      put :update, params: { scope: 'DEFAULT', id: start_id, start: start, metadata: {'version'=> '2'} }
      expect(response).to have_http_status(:ok)
      new_json = JSON.parse(response.body)
      expect(json['start']).not_to eql(new_json['start'])
      expect(new_json['metadata']['version']).to eql('2')
    end

    it "attempts to update a bad metadata object and status code 400" do
      start = "2022-01-1T01:02:00.001+00:00"
      post :create, params: { scope: 'DEFAULT', start: start, metadata: {'version'=> '1'} }
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['metadata']['version']).to eql('1')
      start_id = DateTime.parse(start).strftime('%s%3N')
      put :update, params: { scope: 'DEFAULT', id: start_id, start: start, metadata: 'foo' }
      expect(response).to have_http_status(:bad_request)
      ret = JSON.parse(response.body)
      expect(ret['status']).not_to be_nil
      expect(ret['message']).not_to be_nil
    end
  end

  describe "DELETE delete" do
    it "attempts to delete a bad metadata object with status code 404" do
      delete :delete, params: { scope: 'DEFAULT', id: '42' }
      expect(response).to have_http_status(:not_found)
      ret = JSON.parse(response.body)
      expect(ret['status']).not_to be_nil
      expect(ret['message']).not_to be_nil
    end

    it "attempts to delete a bad id with status code 400" do
      delete :delete, params: { scope: 'DEFAULT', id: 'foo' }
      expect(response).to have_http_status(:bad_request)
      ret = JSON.parse(response.body)
      expect(ret['status']).not_to be_nil
      expect(ret['message']).not_to be_nil
    end

    it "successfully updates a metadata object with status code 204" do
      start = "2022-01-1T01:02:00.001+00:00"
      post :create, params: { scope: 'DEFAULT', start: start, metadata: {'version'=> '1'} }
      expect(response).to have_http_status(:created)
      start_id = DateTime.parse(start).strftime('%s%3N')
      delete :delete, params: { scope: 'DEFAULT', id: start_id }
      expect(response).to have_http_status(:no_content)
    end
  end
end
