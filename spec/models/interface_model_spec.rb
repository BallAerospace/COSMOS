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
require 'cosmos/models/interface_model'

module Cosmos
  describe InterfaceModel do
    before(:each) do
      mock_redis()
    end

    describe "self.get" do
      it "returns the specified interface" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT",
          connect_on_startup: false, auto_reconnect: false) # Set a few things to check
        model.create
        model = InterfaceModel.new(name: "SPEC_INT", scope: "DEFAULT",
          connect_on_startup: true, auto_reconnect: true) # Set to opposite of TEST_INT
        model.create
        test = InterfaceModel.get(name: "TEST_INT", scope: "DEFAULT")
        expect(test["name"]).to eq "TEST_INT"
        expect(test["connect_on_startup"]).to be false
        expect(test["auto_reconnect"]).to be false
      end

      it "works with same named routers" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT",
          connect_on_startup: false, auto_reconnect: false) # Set a few things to check
        model.create
        model = RouterModel.new(name: "TEST_INT", scope: "DEFAULT",
          connect_on_startup: true, auto_reconnect: true) # Set to opposite
        model.create
        test = InterfaceModel.get(name: "TEST_INT", scope: "DEFAULT")
        expect(test["name"]).to eq "TEST_INT"
        expect(test["connect_on_startup"]).to be false
        expect(test["auto_reconnect"]).to be false
        test = RouterModel.get(name: "TEST_INT", scope: "DEFAULT")
        expect(test["name"]).to eq "TEST_INT"
        expect(test["connect_on_startup"]).to be true
        expect(test["auto_reconnect"]).to be true
      end
    end

    describe "self.names" do
      it "returns all interface names" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")
        model.create
        model = InterfaceModel.new(name: "SPEC_INT", scope: "DEFAULT")
        model.create
        model = InterfaceModel.new(name: "OTHER_INT", scope: "OTHER")
        model.create
        names = InterfaceModel.names(scope: "DEFAULT")
        # contain_exactly doesn't care about ordering and neither do we
        expect(names).to contain_exactly("TEST_INT", "SPEC_INT")
        names = InterfaceModel.names(scope: "OTHER")
        expect(names).to contain_exactly("OTHER_INT")
      end
    end

    describe "self.all" do
      it "returns all the parsed interfaces" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT",
          connect_on_startup: false, auto_reconnect: false) # Set a few things to check
        model.create
        model = InterfaceModel.new(name: "SPEC_INT", scope: "DEFAULT",
          connect_on_startup: true, auto_reconnect: true) # Set to opposite of TEST_INT
        model.create
        all = InterfaceModel.all(scope: "DEFAULT")
        expect(all.keys).to contain_exactly("TEST_INT", "SPEC_INT")
        expect(all["TEST_INT"]["connect_on_startup"]).to be false
        expect(all["TEST_INT"]["auto_reconnect"]).to be false
        expect(all["SPEC_INT"]["connect_on_startup"]).to be true
        expect(all["SPEC_INT"]["auto_reconnect"]).to be true
      end
    end

    describe "self.handle_config" do
      it "only recognizes INTERFACE" do
        parser = double("ConfigParser").as_null_object
        expect(parser).to receive(:verify_num_parameters)
        InterfaceModel.handle_config(parser, "INTERFACE", ["TEST_INT"], scope: "DEFAULT")
        expect { InterfaceModel.handle_config(parser, "ROUTER", ["TEST_INT"], scope: "DEFAULT") }.to raise_error(ConfigParser::Error)
      end
    end

    describe "initialize" do
      it "requires name and scope" do
        expect { InterfaceModel.new(name: "TEST_INT") }.to raise_error(ArgumentError)
        expect { InterfaceModel.new(scope: "TEST_INT") }.to raise_error(ArgumentError)
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")
      end
    end

    describe "create" do
      it "stores model based on scope and class name" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")
        model.create
        keys = Store.scan(0)
        # This is an implementation detail but Redis keys are pretty critical so test it
        expect(keys[1]).to contain_exactly("DEFAULT__cosmos_interfaces")
      end
    end

    describe "build" do
      it "instantiates the interface" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT", config_params: ["interface.rb"])
        interface = model.build
        expect(interface.class).to eq Interface
        # Now instantiate a more complex option
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT",
          config_params: %w(tcpip_client_interface.rb 127.0.0.1 8080 8081 10.0 nil BURST 4 0xDEADBEEF))
        interface = model.build
        expect(interface.class).to eq TcpipClientInterface
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")
        json = model.as_json
        expect(json['name']).to eq "TEST_INT"
        params = model.method(:initialize).parameters
        params.each do |type, name|
          # Scope isn't included in as_json as it is part of the key used to get the model
          next if name == :scope
          expect(json.key?(name.to_s)).to be true
        end
      end
    end

    describe "as_config" do
      it "exports model as COSMOS configuration" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")
        expect(model.as_config).to match(/INTERFACE TEST_INT/)
      end
    end

    describe "deploy" do
      it "creates and deploys a MicroserviceModel" do
        dir = Dir.pwd
        variables = {"test"=>"example"}
        # double MicroserviceModel because we're not testing that here
        umodel = double(MicroserviceModel)
        expect(umodel).to receive(:create)
        expect(umodel).to receive(:deploy).with(dir, variables)
        expect(MicroserviceModel).to receive(:new).and_return(umodel)
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT", plugin: "PLUG")
        model.create
        model.deploy(dir, variables)
      end
    end

    describe "undeploy" do
      it "calls destroy on a deployed MicroserviceModel" do
        umodel = double(MicroserviceModel)
        expect(umodel).to receive(:destroy)
        expect(MicroserviceModel).to receive(:get_model).and_return(umodel)
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT", plugin: "PLUG")
        model.undeploy
      end
    end
  end
end
