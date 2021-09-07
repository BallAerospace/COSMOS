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
require 'cosmos/models/auth_model'
require 'cosmos/models/ping_model'

RSpec.describe InternalStatusController, :type => :controller do

  AUTH = 'foobar'

  before(:each) do
    mock_redis()
    Cosmos::AuthModel.set(AUTH)
  end

  # TODO

  describe "GET status" do
    it "returns a Hash<string, string> and status code 200" do
      request.headers["Authorization"] = AUTH
      get :status
      json = JSON.parse(response.body)
      expect(json).to eql([])
      expect(response).to have_http_status(:ok)
    end
  end

end