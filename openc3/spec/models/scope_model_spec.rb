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

require 'spec_helper'
require 'openc3/models/scope_model'

module OpenC3
  describe ScopeModel do
    before(:each) do
      mock_redis()
    end

    describe "self.get" do
      it "returns the specified scope" do
        default_time = Time.now.to_nsec_from_epoch
        model = ScopeModel.new(name: "DEFAULT")
        model.create
        sleep 0.1
        other_time = Time.now.to_nsec_from_epoch
        model = ScopeModel.new(name: "OTHER")
        model.create
        target = ScopeModel.get(name: "DEFAULT")
        expect(target["name"]).to eql "DEFAULT"
        expect(target["updated_at"]).to be_within(10_000_000).of(default_time)
        target = ScopeModel.get(name: "OTHER")
        expect(target["name"]).to eql "OTHER"
        expect(target["updated_at"]).to be_within(10_000_000).of(other_time)
      end
    end

    describe "self.names" do
      it "returns all scope names" do
        model = ScopeModel.new(name: "DEFAULT")
        model.create
        model = ScopeModel.new(name: "OTHER")
        model.create
        names = ScopeModel.names()
        # contain_exactly doesn't care about ordering and neither do we
        expect(names).to contain_exactly("DEFAULT", "OTHER")
      end
    end

    describe "self.all" do
      it "returns all the parsed scopes" do
        model = ScopeModel.new(name: "DEFAULT")
        model.create
        model = ScopeModel.new(name: "OTHER")
        model.create
        all = ScopeModel.all()
        expect(all.keys).to contain_exactly("DEFAULT", "OTHER")
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        model = ScopeModel.new(name: "DEFAULT", updated_at: 12345)
        json = model.as_json(:allow_nan => true)
        expect(json['name']).to eql "DEFAULT"
        expect(json['updated_at']).to eql 12345
      end
    end

    describe "deploy" do
      it "deploys the microservices" do
        dir = File.join(SPEC_DIR, "install")
        model = ScopeModel.new(name: "DEFAULT", updated_at: 12345)
        model.create
        model.deploy(dir, {})
        expect(Store.exists("DEFAULT__COMMAND__{UNKNOWN}__UNKNOWN")).to eql 1
        expect(Store.exists("DEFAULT__TELEMETRY__{UNKNOWN}__UNKNOWN")).to eql 1
      end
    end
  end
end
