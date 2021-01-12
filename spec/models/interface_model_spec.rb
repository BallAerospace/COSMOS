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
      @redis = MockRedis.new
      allow(Redis).to receive(:new).and_return(@redis)
      Cosmos::Store.class_variable_set(:@@instance, nil)
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

      it "complains if it already exists" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")
        model.create
        expect { model.create }.to raise_error(/TEST_INT already exists/)
      end

      it "complains if updating non-existant" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")
        expect { model.create(update: true) }.to raise_error(/TEST_INT doesn't exist/)
      end

      it "updates existing" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT", auto_reconnect: false)
        model.create
        saved = InterfaceModel.get(name: "TEST_INT", scope: "DEFAULT")
        expect(saved['auto_reconnect']).to be false

        model.auto_reconnect = true
        model.create(update: true)
        saved = InterfaceModel.get(name: "TEST_INT", scope: "DEFAULT")
        expect(saved['auto_reconnect']).to be true
      end
    end

    describe "update" do
      it "updates existing" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT", auto_reconnect: false)
        model.create
        saved = InterfaceModel.get(name: "TEST_INT", scope: "DEFAULT")
        expect(saved['auto_reconnect']).to be false

        model.auto_reconnect = true
        model.update
        saved = InterfaceModel.get(name: "TEST_INT", scope: "DEFAULT")
        expect(saved['auto_reconnect']).to be true
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")
        json = model.as_json
        expect(json['name']).to eq "TEST_INT"
        params = model.method(:initialize).parameters
        params.each do |type, name|
          # TODO: Why isn't scope included in as_json?
          next if name == :scope
          expect(json.key?(name.to_s)).to be true
        end
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
    end
  end
end
