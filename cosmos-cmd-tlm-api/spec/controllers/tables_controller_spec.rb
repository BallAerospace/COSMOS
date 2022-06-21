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

RSpec.describe TablesController, :type => :controller do
  before(:each) do
    @resp = { contents: []}
    @s3 = double("AwsS3Client").as_null_object
    allow(Aws::S3::Client).to receive(:new).and_return(@s3)
    allow(@s3).to receive(:list_objects_v2).and_return(@resp)
  end

  def create_table(table_name)
    @resp[:contents] << {
      key: "INST/tables/#{table_name}"
    }
    pp @resp
  end

  describe "GET index" do
    it "successfully returns an empty array and status code 200" do
      get :index, params: { scope: 'DEFAULT' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eql([])
    end

    it "successfully returns all the tables" do
      create_table('TEST1')
      create_table('TEST2')
      get :index, params: { scope: 'DEFAULT' }
      expect(response).to have_http_status(:ok)
      puts "body:#{response.body}"
      ret = JSON.parse(response.body)
      puts "ret:#{ret}"
      expect(json).to eql([])
    end
  end
end
