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

  describe "GET index" do
    it "returns an empty array and status code 200" do
      get :index, params: { scope: 'DEFAULT' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eql([])
    end

    it "returns all the targets" do
      post :create, params: { scope: 'DEFAULT', target: 'TEST1', metadata: {'key'=> 'value'} }
      post :create, params: { scope: 'DEFAULT', target: 'TEST2', metadata: {'key'=> 'value'} }
      post :create, params: { scope: 'OTHER', target: 'TEST3', metadata: {'key'=> 'value'} }
      get :index, params: { scope: 'DEFAULT' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      targets = json.map { |item| item['target'] }
      expect(targets).to eql(['TEST1','TEST2'])
      get :index, params: { scope: 'OTHER' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      targets = json.map { |item| item['target'] }
      expect(targets).to eql(['TEST3'])
    end
  end

  describe "POST create" do
    it "returns a hash and status code 201" do
      post :create, params: { scope: 'DEFAULT', target: 'TEST', metadata: {'key'=> 'value'} }
      ret = JSON.parse(response.body)
      expect(ret['updated_at']).not_to be_nil
      expect(ret['start']).not_to be_nil
      expect(response).to have_http_status(:created)
    end
  end
end
