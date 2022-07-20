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
require 'openc3/models/model'

module OpenC3
  describe Model do
    class TestModel < Model
      def initialize(name:, scope:, plugin: nil, updated_at: nil)
        super("#{scope}__TEST", name: name, scope: scope, plugin: plugin, updated_at: updated_at)
      end

      def self.get(name:, scope: nil)
        super("#{scope}__TEST", name: name)
      end

      def self.names(scope: nil)
        super("#{scope}__TEST")
      end

      def self.all(scope: nil)
        super("#{scope}__TEST")
      end
    end

    before(:each) do
      mock_redis()
    end

    describe "create" do
      it "stores model based on primary_key and name" do
        start_time = Time.now.to_nsec_from_epoch
        model = Model.new("primary_key", name: "model", scope: "DEFAULT", plugin: "PLUGIN", updated_at: "blah", other: true)
        model.create # This overwrites updated_at
        vals = Model.get("primary_key", name: "model")
        expect(vals["name"]).to eq "model"
        expect(vals["scope"]).to eq "DEFAULT"
        expect(vals["plugin"]).to eq "PLUGIN"
        expect(vals["updated_at"]).to be_within(100_000_000).of(start_time)
        expect(vals["other"]).to be nil # No other keyword arguments are stored by the constructor
      end

      it "complains if it already exists" do
        model = Model.new("primary_key", name: "model")
        model.create
        expect { model.create }.to raise_error(/model already exists/)
      end

      it "complains if updating non-existant" do
        model = Model.new("primary_key", name: "model")
        expect { model.create(update: true) }.to raise_error(/model doesn't exist/)
      end

      it "updates existing" do
        model = Model.new("primary_key", name: "model", plugin: "plug-it")
        model.create
        saved = Model.get("primary_key", name: "model")
        expect(saved["plugin"]).to eq "plug-it"

        model.plugin = true
        model.create(update: true)
        saved = Model.get("primary_key", name: "model")
        expect(saved["plugin"]).to be true
      end
    end

    describe "update" do
      it "updates existing" do
        model = Model.new("primary_key", name: "model", plugin: false)
        model.create
        saved = Model.get("primary_key", name: "model")
        expect(saved["plugin"]).to be false

        model.plugin = true
        model.update
        saved = Model.get("primary_key", name: "model")
        expect(saved["plugin"]).to be true
      end
    end

    describe "deploy" do
      it "must be implemented by subclass" do
        model = Model.new("primary_key", name: "model")
        expect { model.deploy(nil, nil) }.to raise_error(/must be implemented by subclass/)
      end
    end

    describe "destroy" do
      it "removes the model" do
        model = Model.new("primary_key", name: "model")
        model.destroy
        saved = Model.get("primary_key", name: "model")
        expect(saved).to be_nil
      end
    end

    describe "self.handle_config" do
      it "must be implemented by subclass" do
        expect { Model.handle_config('parser', 'model', 'keyword', 'parameters') }.to raise_error(/must be implemented by subclass/)
      end
    end

    describe "self.set" do
      it "updates the model configuration" do
        model = TestModel.new(name: "TEST1", scope: "DEFAULT", plugin: "ONE")
        model.create
        model.plugin = "TWO"
        TestModel.set(model.as_json(:allow_nan => true), scope: "DEFAULT")
        saved = TestModel.get(name: "TEST1", scope: "DEFAULT")
        expect(saved["name"]).to eq "TEST1"
        expect(saved["plugin"]).to eq "TWO"
      end
    end

    describe "as_json, self.from_json" do
      it "round trips the model with JSON" do
        time = Time.now
        model = TestModel.new(name: "TEST1", scope: "DEFAULT", plugin: "ONE", updated_at: time)
        model.create
        hash = model.as_json(:allow_nan => true)
        json = JSON.generate(hash)
        model2 = TestModel.from_json(json, scope: "DEFAULT")
        expect(hash).to eql(model2.as_json(:allow_nan => true))
      end
    end

    describe "self.get" do
      it "returns nil if the name can't be found" do
        expect(TestModel.get(name: "BLAH", scope: "DEFAULT")).to be_nil
      end
    end

    describe "self.get_model" do
      it "returns the model object" do
        model = TestModel.new(name: "TEST1", scope: "DEFAULT")
        model.create
        model = TestModel.get_model(name: "TEST1", scope: "DEFAULT")
        expect(model.name).to eq "TEST1"
      end
    end

    describe "self.get_all_models" do
      it "returns all model object" do
        model = TestModel.new(name: "TEST_INT", scope: "DEFAULT")
        model.create
        model = TestModel.new(name: "TEST2_INT", scope: "DEFAULT")
        model.create
        model = TestModel.new(name: "TEST3_INT", scope: "OTHER") # Another scope
        model.create
        models = TestModel.get_all_models(scope: "DEFAULT")
        expect(models.keys).to contain_exactly("TEST_INT", "TEST2_INT")
        models = TestModel.get_all_models(scope: "OTHER")
        expect(models.keys).to contain_exactly("TEST3_INT")
      end
    end

    describe "self.find_all_by_plugin" do
      it "returns the model object with the specified plugin" do
        model = TestModel.new(name: "TEST_INT", scope: "DEFAULT", plugin: "ONE")
        model.create
        model = TestModel.new(name: "TEST2_INT", scope: "DEFAULT", plugin: "ONE")
        model.create
        model = TestModel.new(name: "TEST3_INT", scope: "DEFAULT", plugin: "TWO")
        model.create
        models = TestModel.find_all_by_plugin(scope: "DEFAULT", plugin: "ONE")
        expect(models.keys).to contain_exactly("TEST_INT", "TEST2_INT")
        models = TestModel.find_all_by_plugin(scope: "DEFAULT", plugin: "TWO")
        expect(models.keys).to contain_exactly("TEST3_INT")
      end
    end
  end
end
