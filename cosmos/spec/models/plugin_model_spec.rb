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
require 'cosmos/models/plugin_model'

module Cosmos
  describe PluginModel do
    before(:each) do
      mock_redis()
    end

    describe "self.get" do
      it "returns the specified plugin" do
        model = PluginModel.new(name: "TEST1", scope: "DEFAULT")
        model.create
        model = PluginModel.new(name: "TEST2", scope: "OTHER")
        model.create
        names = PluginModel.names(scope: "DEFAULT")
        plugin = PluginModel.get(name: names[0], scope: "DEFAULT")
        expect(plugin["name"]).to match(/TEST1__\d{13}/)
      end
    end

    describe "self.names" do
      it "returns all plugin names" do
        model = PluginModel.new(name: "TEST", scope: "DEFAULT")
        model.create
        model = PluginModel.new(name: "SPEC", scope: "DEFAULT")
        model.create
        model = PluginModel.new(name: "OTHER", scope: "OTHER")
        model.create
        names = PluginModel.names(scope: "DEFAULT")
        # contain_exactly doesn't care about ordering and neither do we
        expect(names).to include(/TEST__\d{14}|SPEC__\d{14}/).twice
        names = PluginModel.names(scope: "OTHER")
        expect(names).to include(/OTHER__\d{14}/)
      end
    end

    describe "self.all" do
      it "returns all the parsed plugins" do
        model = PluginModel.new(name: "TEST", scope: "DEFAULT")
        model.create
        model = PluginModel.new(name: "SPEC", scope: "DEFAULT")
        model.create
        all = PluginModel.all(scope: "DEFAULT")
        expect(all.keys).to include(/TEST__\d{14}|SPEC__\d{14}/).twice
      end
    end

    describe "self.install_phase1" do
      it "parses the plugin variables" do
        expect(GemModel).to receive(:put)
        gem = double("gem")
        expect(gem).to receive(:extract_files) do |path|
          File.open("#{path}/plugin.txt", 'w') do |file|
            file.puts "VARIABLE VAR1 10"
            file.puts "VARIABLE VAR2 HI THERE"
          end
        end
        expect(Gem::Package).to receive(:new).and_return(gem)
        model = PluginModel.install_phase1(__FILE__, scope: "DEFAULT")
        expect(model['name']).to eql File.basename(__FILE__)
        expect(model['variables']).to include("VAR1" => "10", "VAR2" => "HI THERE")
      end
    end

    describe "self.install_phase2" do
      it "creates the plugin by deploying models in the plugin.txt" do
        s3 = instance_double("Aws::S3::Client").as_null_object
        allow(Aws::S3::Client).to receive(:new).and_return(s3)

        expect(GemModel).to receive(:get)
        gem = double("gem")
        expect(gem).to receive(:extract_files) do |path|
          File.open("#{path}/plugin.txt", 'w') do |file|
            file.puts "TOOL <%= folder %> <%= name %>"
            file.puts "  URL myurl"
            file.puts "TARGET <%= folder %> <%= name %>"
          end
        end
        expect(Gem::Package).to receive(:new).and_return(gem)

        variables = { "folder" => "THE_FOLDER", "name" => "THE_NAME" }
        # Just stub the instance deploy method
        expect_any_instance_of(ToolModel).to receive(:deploy).with(anything, variables).and_return(nil)
        expect_any_instance_of(TargetModel).to receive(:deploy).with(anything, variables).and_return(nil)
        PluginModel.install_phase2("name", variables, scope: "DEFAULT")
      end
    end

    describe "self.undeploy" do
      it "destroys all models associated with the plugin" do
        tool = ToolModel.new(name: "TOOL", scope: "DEFAULT", plugin: "PLUG")
        tool.create
        # Create a tool in another plugin which should not get destroyed
        tool2 = ToolModel.new(name: "ANOTHER", scope: "DEFAULT", plugin: "OTHER")
        tool2.create
        expect_any_instance_of(ToolModel).to receive(:undeploy).once # Only one gets destroyed
        target = TargetModel.new(folder_name: "TEST", name: "TARGET", scope: "DEFAULT", plugin: "PLUG")
        target.create
        expect_any_instance_of(TargetModel).to receive(:undeploy).once
        interface = InterfaceModel.new(name: "TARGET", scope: "DEFAULT", plugin: "PLUG")
        interface.create
        expect_any_instance_of(InterfaceModel).to receive(:undeploy).once
        router = RouterModel.new(name: "TARGET", scope: "DEFAULT", plugin: "PLUG")
        router.create
        expect_any_instance_of(RouterModel).to receive(:undeploy).once
        uservice = MicroserviceModel.new(name: "DEFAULT__TYPE__NAME", scope: "DEFAULT", plugin: "PLUG")
        uservice.create
        expect_any_instance_of(MicroserviceModel).to receive(:undeploy).once

        plugin = PluginModel.new(name: "PLUG", scope: "DEFAULT")
        plugin.undeploy
      end
    end
  end
end
