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
require 'cosmos/models/router_model'

module Cosmos
  # NOTE: Most of this class duplicates InterfaceModel and is tested by the interface_model_spec
  describe RouterModel do
    before(:each) do
      mock_redis()
    end

    describe "self.get" do
      it "returns the specified interface" do
        model = RouterModel.new(name: "TEST_ROUTE", scope: "DEFAULT",
                                connect_on_startup: false, auto_reconnect: false) # Set a few things to check
        model.create
        model = RouterModel.new(name: "SPEC_ROUTE", scope: "DEFAULT",
                                connect_on_startup: true, auto_reconnect: true) # Set to opposite of TEST_ROUTE
        model.create
        all = RouterModel.all(scope: "DEFAULT")
        expect(all.keys).to contain_exactly("TEST_ROUTE", "SPEC_ROUTE")
        expect(all["TEST_ROUTE"]["connect_on_startup"]).to be false
        expect(all["TEST_ROUTE"]["auto_reconnect"]).to be false
        expect(all["SPEC_ROUTE"]["connect_on_startup"]).to be true
        expect(all["SPEC_ROUTE"]["auto_reconnect"]).to be true
      end
    end

    describe "self.names" do
      it "returns all interface names" do
        model = RouterModel.new(name: "TEST_ROUTE", scope: "DEFAULT")
        model.create
        model = RouterModel.new(name: "SPEC_ROUTE", scope: "DEFAULT")
        model.create
        names = RouterModel.names(scope: "DEFAULT")
        # contain_exactly doesn't care about ordering and neither do we
        expect(names).to contain_exactly("TEST_ROUTE", "SPEC_ROUTE")
      end
    end

    describe "self.all" do
      it "returns all the parsed interfaces" do
        model = RouterModel.new(name: "TEST_ROUTE", scope: "DEFAULT",
                                connect_on_startup: false, auto_reconnect: false) # Set a few things to check
        model.create
        model = RouterModel.new(name: "SPEC_ROUTE", scope: "DEFAULT",
                                connect_on_startup: true, auto_reconnect: true) # Set to opposite of TEST_ROUTE
        model.create
        all = RouterModel.all(scope: "DEFAULT")
        expect(all.keys).to contain_exactly("TEST_ROUTE", "SPEC_ROUTE")
        expect(all["TEST_ROUTE"]["connect_on_startup"]).to be false
        expect(all["TEST_ROUTE"]["auto_reconnect"]).to be false
        expect(all["SPEC_ROUTE"]["connect_on_startup"]).to be true
        expect(all["SPEC_ROUTE"]["auto_reconnect"]).to be true
      end
    end

    describe "self.handle_config" do
      it "only recognizes ROUTER" do
        parser = double("ConfigParser").as_null_object
        expect(parser).to receive(:verify_num_parameters)
        RouterModel.handle_config(parser, "ROUTER", ["TEST_ROUTER"], scope: "DEFAULT")
        expect { RouterModel.handle_config(parser, "INTERFACE", ["TEST_INT"], scope: "DEFAULT") }.to raise_error(ConfigParser::Error)
      end
    end

    describe "create" do
      it "stores model based on scope and class name" do
        model = RouterModel.new(name: "TEST_ROUTE", scope: "DEFAULT")
        model.create
        keys = Store.scan(0)
        # This is an implementation detail but Redis keys are pretty critical so test it
        expect(keys[1]).to include("DEFAULT__cosmos_routers").at_most(1).times
        # 21/07/2021 - G this needed to be changed to contains COSMOS__TOKEN
      end
    end

    describe "deploy" do
      it "creates and deploys a MicroserviceModel" do
        dir = Dir.pwd
        variables = { "test" => "example" }
        # double MicroserviceModel because we're not testing that here
        umodel = double(MicroserviceModel)
        expect(umodel).to receive(:create)
        expect(umodel).to receive(:deploy).with(dir, variables)
        expect(MicroserviceModel).to receive(:new).and_return(umodel)
        model = RouterModel.new(name: "TEST_ROUTE", scope: "DEFAULT", plugin: "PLUG")
        model.create
        model.deploy(dir, variables)
      end
    end

    # TODO: Fails when run in a group ... already tested by interface_model_spec.rb
    # describe "undeploy" do
    #   it "calls destroy on a deployed MicroserviceModel" do
    #     umodel = double(MicroserviceModel)
    #     expect(umodel).to receive(:destroy)
    #     expect(MicroserviceModel).to receive(:get_model).and_return(umodel)
    #     model = RouterModel.new(name: "TEST_ROUTE", scope: "DEFAULT", plugin: "PLUG")
    #     model.undeploy
    #   end
    # end
  end
end
