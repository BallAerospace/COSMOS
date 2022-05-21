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

RSpec.describe NotesController, :type => :controller do
  before(:each) do
    mock_redis()
  end

  describe "POST create" do
    it "successfully creates note object with status code 201" do
      start = Time.now - 20
      stop = Time.now - 10
      post :create, params: { scope: 'DEFAULT', start: start.iso8601, stop: stop.iso8601, description: "note" }
      expect(response).to have_http_status(:created)
      ret = JSON.parse(response.body)
      expect(ret['updated_at'].to_i / Time::NSEC_PER_SECOND).to be_within(1).of(Time.now.to_i)
      expect(ret['start']).to be_within(1).of(start.to_i)
      expect(ret['stop']).to be_within(1).of(stop.to_i)
    end
  end
end
