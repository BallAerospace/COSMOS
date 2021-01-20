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
require 'cosmos/models/interface_status_model'

module Cosmos
  describe InterfaceStatusModel do
    before(:each) do
      mock_redis()
    end

    describe "self.get" do
      it "returns the specified interface" do
        model = InterfaceStatusModel.new(name: "TEST_INT", state: "CONNECTED", scope: "DEFAULT",
          txsize: 10, rxsize: 20) # Set a few things to check
        model.create
        model = InterfaceStatusModel.new(name: "SPEC_INT", state: "CONNECTED", scope: "DEFAULT",
          txsize: 100, rxsize: 200) # Set different of TEST_INT
        model.create
        test = InterfaceStatusModel.get(name: "TEST_INT", scope: "DEFAULT")
        expect(test["name"]).to eql "TEST_INT"
        expect(test["txsize"]).to eql 10
        expect(test["rxsize"]).to eql 20
      end

      it "works with same named routers" do
        model = InterfaceStatusModel.new(name: "TEST_INT", state: "CONNECTED", scope: "DEFAULT",
          txsize: 10, rxsize: 20) # Set a few things to check
        model.create
        model = RouterStatusModel.new(name: "TEST_INT", state: "CONNECTED", scope: "DEFAULT",
          txsize: 100, rxsize: 200) # Set different
        model.create
        test = InterfaceStatusModel.get(name: "TEST_INT", scope: "DEFAULT")
        expect(test["name"]).to eql "TEST_INT"
        expect(test["txsize"]).to eql 10
        expect(test["rxsize"]).to eql 20
        test = RouterStatusModel.get(name: "TEST_INT", scope: "DEFAULT")
        expect(test["name"]).to eql "TEST_INT"
        expect(test["txsize"]).to eql 100
        expect(test["rxsize"]).to eql 200
      end
    end

    describe "self.names" do
      it "returns all interface names" do
        model = InterfaceStatusModel.new(name: "TEST_INT", state: "CONNECTED", scope: "DEFAULT")
        model.create
        model = InterfaceStatusModel.new(name: "SPEC_INT", state: "CONNECTED", scope: "DEFAULT")
        model.create
        model = InterfaceStatusModel.new(name: "OTHER_INT", state: "CONNECTED", scope: "OTHER")
        model.create
        names = InterfaceStatusModel.names(scope: "DEFAULT")
        # contain_exactly doesn't care about ordering and neither do we
        expect(names).to contain_exactly("TEST_INT", "SPEC_INT")
        names = InterfaceStatusModel.names(scope: "OTHER")
        expect(names).to contain_exactly("OTHER_INT")
      end
    end

    describe "self.all" do
      it "returns all the parsed interfaces" do
        model = InterfaceStatusModel.new(name: "TEST_INT", state: "CONNECTED", scope: "DEFAULT",
          txsize: 10, rxsize: 20) # Set a few things to check
        model.create
        model = InterfaceStatusModel.new(name: "SPEC_INT", state: "CONNECTED", scope: "DEFAULT",
          txsize: 100, rxsize: 200) # Set different of TEST_INT
        model.create
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all.keys).to contain_exactly("TEST_INT", "SPEC_INT")
        expect(all["TEST_INT"]["txsize"]).to eql 10
        expect(all["TEST_INT"]["rxsize"]).to eql 20
        expect(all["SPEC_INT"]["txsize"]).to eql 100
        expect(all["SPEC_INT"]["rxsize"]).to eql 200
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        model = InterfaceStatusModel.new(name: "TEST_INT", state: "CONNECTED", scope: "DEFAULT")
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
  end
end
