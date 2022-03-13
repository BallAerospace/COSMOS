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

RSpec.describe CompletedScriptController, :type => :controller do
  describe "GET index" do
    before(:each) do
      # Simply stub out CompletedScript to return an empty JSON structure
      allow(CompletedScript).to receive(:all).and_return('{}')
    end

    context "without scope" do
      it "renders status error" do
        get :index
        expect(response.content_type).to include('application/json')
        expect(JSON.parse(response.body, symbolize_names: true)).to include(status: 'error')
        expect(JSON.parse(response.body, symbolize_names: true)).to include(message: 'Scope is required')
      end
    end

    context "with scope" do
      before(:each) do
        get :index, params: { "scope" => "DEFAULT" }
      end

      it "renders error with missing token" do
        $cosmos_authorize = true
        get :index, params: { "scope" => "DEFAULT" }
        expect(response.content_type).to include('application/json')
        expect(response.status).to eq(401)
        expect(JSON.parse(response.body, symbolize_names: true)).to include(status: 'error')
        expect(JSON.parse(response.body, symbolize_names: true)).to include(message: 'Token is required')
        $cosmos_authorize = false
      end

      it "handles forbidden errors (enterprise only)" do
        $cosmos_authorize = true
        # CompletedScriptController includes the Authorize module so we need to stub it
        allow_any_instance_of(CompletedScriptController).to receive(:authorize).and_raise(Cosmos::ForbiddenError)
        get :index, params: { "scope" => "DEFAULT" }
        expect(response.status).to eq(403)
        expect(response.content_type).to include('application/json')
        expect(JSON.parse(response.body, symbolize_names: true)).to include(status: 'error')
        $cosmos_authorize = false
      end

      it 'responds with valid content type' do
        expect(response.status).to eq(200)
        expect(response.content_type).to include('application/json')
      end
    end
  end
end
