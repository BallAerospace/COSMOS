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

RSpec.describe InternalHealthController, :type => :controller do
  before(:each) do
    mock_redis()
  end

  describe "GET health" do
    it "returns a Hash<> and status code 200" do
      get :health, params: { 'scope'=>'DEFAULT' }
      json = JSON.parse(response.body, :allow_nan => true, :create_additions => true)
      expect(json['redis']).to be_a(Array)
      expect(response).to have_http_status(:ok)
    end
  end
end
