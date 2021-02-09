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

require 'spec_helper'
require 'cosmos/api/router_api'
require 'cosmos/script/extract'
require 'cosmos/utilities/authorization'
require 'cosmos/microservices/router_microservice'

module Cosmos
  describe Api do
    class ApiTest
      include Extract
      include Api
      include Authorization
    end

    before(:each) do
      mock_redis()
      setup_system()

      model = RouterModel.new(name: "ROUTE_INT", scope: "DEFAULT", target_names: ["INST"], config_params: ["interface.rb"])
      model.create

      # Mock out some stuff in Microservice initialize()
      dbl = double("AwsS3Client").as_null_object
      allow(Aws::S3::Client).to receive(:new).and_return(dbl)
      allow(Zip::File).to receive(:open).and_return(true)
      allow_any_instance_of(Cosmos::Interface).to receive(:connected?).and_return(true)
      allow_any_instance_of(Cosmos::Interface).to receive(:read_interface) { sleep }

      model = MicroserviceModel.new(name: "DEFAULT__INTERFACE__ROUTE_INT", scope: "DEFAULT", target_names: ["INST"])
      model.create
      @im = RouterMicroservice.new("DEFAULT__INTERFACE__ROUTE_INT")
      @im_thread = Thread.new { @im.run }
      sleep(0.01) # Allow the thread to run

      @api = ApiTest.new
    end

    after(:each) do
      @im.shutdown
      sleep(0.01)
      Thread.list.each do |t|
        if t != Thread.current
          t.kill
        end
      end
      sleep(0.1)
    end

    describe "get_router" do
      it "returns router hash" do
        router = @api.get_router("ROUTE_INT")
        expect(router).to be_a Hash
        expect(router['name']).to eql "ROUTE_INT"
        expect(router['log']).to be true
        # Verify it also includes the status
        expect(router['state']).to eql "CONNECTED"
        expect(router['clients']).to eql 0
      end
    end

    describe "get_router_names" do
      it "returns all router names" do
        model = RouterModel.new(name: "INT1", scope: "DEFAULT")
        model.create
        model = RouterModel.new(name: "INT2", scope: "DEFAULT")
        model.create
        expect(@api.get_router_names).to eql ["INT1", "INT2", "ROUTE_INT"]
      end
    end

    describe "connect_router, disconnect_router, router_state" do
      it "connects the router" do
        router = @api.get_router("ROUTE_INT")
        expect(router['state']).to eql "CONNECTED"
        expect(@api.router_state("ROUTE_INT")).to eql "CONNECTED"
        @api.disconnect_router("ROUTE_INT")
        sleep(0.1)
        expect(@api.router_state("ROUTE_INT")).to eql "DISCONNECTED"
        @api.connect_router("ROUTE_INT")
        sleep(0.1)
        expect(@api.router_state("ROUTE_INT")).to eql "ATTEMPTING"
      end
    end

    describe "get_router_targets" do
      it "raises for a non-existant router" do
        expect { @api.get_router_targets("BLAH") }.to raise_error("Router 'BLAH' does not exist")
      end

      it "returns the targets associated with an router" do
        # Preload a fake RouterStatusModel so the api succeeds ...
        # this automatically happens when you create a new RouterMicroservice
        RouterStatusModel.set({'name' => "TEST_INT", 'state' => "DISCONNECTED"}, scope: "DEFAULT")
        model = RouterModel.new(name: "TEST_INT", scope: "DEFAULT", target_names: ["TGT1", "TGT2"])
        model.create
        expect(@api.get_router_targets("TEST_INT")).to eql ["TGT1", "TGT2"]
      end
    end

    describe "get_router_info" do
      it "complains about non-existant routers" do
        expect { @api.get_router_info("BLAH") }.to raise_error(RuntimeError, "Router 'BLAH' does not exist")
      end

      it "gets router info" do
        info = @api.get_router_info("ROUTE_INT")
        expect(info[0]).to eq "CONNECTED"
        expect(info[1..-1]).to eq [0,0,0,0,0,0,0]
      end
    end

    describe "get_all_router_info" do
      it "gets router name and all info" do
        info = @api.get_all_router_info.sort
        expect(info[0][0]).to eq "ROUTE_INT"
      end
    end
  end
end
