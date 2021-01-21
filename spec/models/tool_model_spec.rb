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
require 'cosmos/models/tool_model'

module Cosmos
  describe ToolModel do
    DEFAULT_APPS = ["CmdTlmServer", "Command Sender", "Data Extractor", "Limits Monitor",
      "Packet Viewer", "Script Runner", "Telemetry Grapher", "Telemetry Viewer"]

    before(:each) do
      mock_redis()
    end

    describe "self.get" do
      it "returns the specified tool" do
        model = ToolModel.new(folder_name: "TEST", name: "TEST2", scope: "DEFAULT")
        model.create
        model = ToolModel.new(folder_name: "SPEC", name: "SPEC", scope: "DEFAULT")
        model.create
        target = ToolModel.get(name: "TEST2", scope: "DEFAULT")
        expect(target["name"]).to eql "TEST2"
        expect(target["folder_name"]).to eql "TEST"
      end
    end

    describe "self.names" do
      it "returns default tool names" do
        # Try two different scopes
        names = ToolModel.names(scope: "DEFAULT")
        expect(names).to contain_exactly(*DEFAULT_APPS)
        names = ToolModel.names(scope: "OTHER")
        expect(names).to contain_exactly(*DEFAULT_APPS)
      end

      it "returns all tool names" do
        model = ToolModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        model.create
        model = ToolModel.new(folder_name: "SPEC", name: "SPEC", scope: "DEFAULT")
        model.create
        model = ToolModel.new(folder_name: "OTHER", name: "OTHER", scope: "OTHER")
        model.create
        names = ToolModel.names(scope: "DEFAULT")
        expect(names).to contain_exactly(*DEFAULT_APPS, "TEST", "SPEC")
        names = ToolModel.names(scope: "OTHER")
        expect(names).to contain_exactly(*DEFAULT_APPS, "OTHER")
      end
    end

    describe "self.all" do
      it "returns all the parsed tools" do
        model = ToolModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        model.create
        model = ToolModel.new(folder_name: "SPEC", name: "SPEC", scope: "DEFAULT")
        model.create
        all = ToolModel.all(scope: "DEFAULT")
        expect(all.keys).to contain_exactly(*DEFAULT_APPS, "TEST", "SPEC")
      end
    end

    describe "self.handle_config" do
      it "only recognizes TOOL" do
        parser = double("ConfigParser").as_null_object
        expect(parser).to receive(:verify_num_parameters)
        tool = ToolModel.handle_config(parser, "TOOL", ["FOLDER", "NAME"], scope: "DEFAULT")
        expect(tool.name).to eql("NAME")
        expect(tool.folder_name).to eql("FOLDER")
        expect { ToolModel.handle_config(parser, "TOOLS", ["FOLDER", "NAME"], scope: "DEFAULT") }.to raise_error(ConfigParser::Error)
      end
    end

    describe "self.set_order" do
      it "reorders the tools" do
        # Create a few new tool models
        model = ToolModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        model.create
        expect(model.position).to eql DEFAULT_APPS.length + 1
        model = ToolModel.new(folder_name: "TEST", name: "TEST2", scope: "DEFAULT")
        model.create
        expect(model.position).to eql DEFAULT_APPS.length + 2

        ToolModel.set_order(name: "TEST", order: 0, scope: "DEFAULT")
        model = ToolModel.get(name: "TEST", scope: "DEFAULT")
        expect(model['position']).to eql 0.5

        ToolModel.set_order(name: "TEST", order: 1, scope: "DEFAULT")
        model = ToolModel.get(name: "TEST", scope: "DEFAULT")
        expect(model['position']).to eql 1.5

        ToolModel.set_order(name: "TEST2", order: 1, scope: "DEFAULT")
        model = ToolModel.get(name: "TEST2", scope: "DEFAULT")
        expect(model['position']).to eql 1.25
      end
    end

    # describe "create" do
    #   it "stores model based on scope and class name" do
    #     model = ToolModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
    #     model.create
    #     keys = Store.scan(0)
    #     # This is an implementation detail but Redis keys are pretty critical so test it
    #     expect(keys[1]).to contain_exactly("DEFAULT__cosmos_targets")
    #   end
    # end

    # describe "as_json" do
    #   it "encodes all the input parameters" do
    #     model = ToolModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
    #     json = model.as_json
    #     expect(json['name']).to eq "TEST"
    #     params = model.method(:initialize).parameters
    #     params.each do |type, name|
    #       # Scope isn't included in as_json as it is part of the key used to get the model
    #       next if name == :scope
    #       expect(json.key?(name.to_s)).to be true
    #     end
    #   end
    # end

    # describe "as_config" do
    #   it "exports model as COSMOS configuration" do
    #     model = ToolModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
    #     expect(model.as_config).to match(/TARGET TEST/)
    #     model = ToolModel.new(folder_name: "TEST", name: "TEST2", scope: "DEFAULT")
    #     expect(model.as_config).to match(/TARGET TEST TEST2/)
    #   end
    # end

    # describe "handle_config" do
    #   it "raises as there are no keywords below TARGET" do
    #     model = ToolModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
    #     expect { model.handle_config(nil, "TARGET", nil) }.to raise_error("Unsupported keyword for TARGET: TARGET")
    #   end
    # end

    # describe "deploy" do
    #   before(:each) do
    #     @scope = "DEFAULT"
    #     @target = "INST"
    #     @s3 = instance_double("Aws::S3::Client")#.as_null_object
    #     allow(@s3).to receive(:put_object)
    #     allow(Aws::S3::Client).to receive(:new).and_return(@s3)
    #     @target_dir = File.join(SPEC_DIR, "install", "config")
    #   end

    #   it "raises if the target can't be found" do
    #     @target_dir = Dir.pwd
    #     variables = {"test"=>"example"}
    #     model = ToolModel.new(folder_name: @target, name: @target, scope: @scope, plugin: @target)
    #     model.create
    #     expect { model.deploy(@target_dir, variables) }.to raise_error(/No target files found/)
    #   end

    #   it "copies the target files to S3" do
    #     Dir.glob("#{@target_dir}/targets/#{@target}/**/*") do |filename|
    #       next unless File.file?(filename)
    #       # Files are stored in S3 with <SCOPE>/<TARGET NAME>/<file path>
    #       # Splitting on 'config' gives us the target and path so just prepend the scope
    #       filename = "#{@scope}#{filename.split("config")[-1]}"
    #       expect(@s3).to receive(:put_object).with(bucket: 'config', key: filename, body: anything)
    #     end
    #     model = ToolModel.new(folder_name: @target, name: @target, scope: @scope, plugin: @target)
    #     model.create
    #     model.deploy(@target_dir, {})
    #   end

    #   it "creates target_id.txt as a hash" do
    #     key = "DEFAULT/targets/INST/target_id.txt"
    #     expect(@s3).to receive(:put_object).with(bucket: 'config', key: key, body: anything)
    #     model = ToolModel.new(folder_name: @target, name: @target, scope: @scope, plugin: @target)
    #     model.create
    #     model.deploy(@target_dir, {})
    #   end

    #   it "archives the target to S3" do
    #     key = "DEFAULT/target_archives/INST/INST_current.zip"
    #     expect(@s3).to receive(:put_object).with(bucket: 'config', key: key, body: anything)
    #     model = ToolModel.new(folder_name: @target, name: @target, scope: @scope, plugin: @target)
    #     model.create
    #     model.deploy(@target_dir, {})
    #   end

    #   it "puts the packets in Redis" do
    #     model = ToolModel.new(folder_name: @target, name: @target, scope: @scope, plugin: "PLUGIN")
    #     model.create
    #     model.deploy(@target_dir, {})
    #     expect(Store.hkeys("DEFAULT__cosmostlm__INST")).to include("HEALTH_STATUS", "ADCS", "PARAMS", "IMAGE", "MECH")
    #     expect(Store.hkeys("DEFAULT__cosmoscmd__INST")).to include("ABORT", "COLLECT", "CLEAR") #... etc

    #     # Spot check a telemetry packet and a command
    #     telemetry = Store.instance.get_packet(@target, "HEALTH_STATUS", scope: @scope)
    #     expect(telemetry['target_name']).to eql @target
    #     expect(telemetry['packet_name']).to eql "HEALTH_STATUS"
    #     expect(telemetry['items'].length).to be > 10
    #     command = Store.instance.get_packet(@target, "ABORT", scope: @scope, type: 'cmd')
    #     expect(command['target_name']).to eql @target
    #     expect(command['packet_name']).to eql "ABORT"
    #     expect(command['items'].length).to be > 10
    #   end

    #   it "creates and deploys Target microservices" do
    #     variables = { "test" => "example" }
    #     umodel = double(MicroserviceModel)
    #     expect(umodel).to receive(:create).exactly(4).times
    #     expect(umodel).to receive(:deploy).with(@target_dir, variables).exactly(4).times
    #     # Verify the microservices that are started
    #     expect(MicroserviceModel).to receive(:new).with(hash_including(
    #       name: "#{@scope}__DECOM__#{@target}")
    #     ).and_return(umodel)
    #     expect(MicroserviceModel).to receive(:new).with(hash_including(
    #       name: "#{@scope}__CVT__#{@target}")
    #     ).and_return(umodel)
    #     expect(MicroserviceModel).to receive(:new).with(hash_including(
    #       name: "#{@scope}__PACKETLOG__#{@target}")
    #     ).and_return(umodel)
    #     expect(MicroserviceModel).to receive(:new).with(hash_including(
    #       name: "#{@scope}__DECOMLOG__#{@target}")
    #     ).and_return(umodel)
    #     model = ToolModel.new(folder_name: @target, name: @target, scope: @scope, plugin: @target)
    #     model.create
    #     model.deploy(@target_dir, variables)
    #   end

    #   it "doesn't deploy microservices with no packets" do
    #     @target = "EMPTY"
    #     umodel = double(MicroserviceModel)
    #     expect(umodel).to_not receive(:create)
    #     expect(umodel).to_not receive(:deploy)
    #     model = ToolModel.new(folder_name: @target, name: @target, scope: @scope, plugin: @target)
    #     model.create
    #     model.deploy(@target_dir, {})
    #   end
    # end

    # describe "undeploy" do
    #   before(:each) do
    #     @s3 = instance_double("Aws::S3::Client")
    #     allow(@s3).to receive(:put_object)
    #     objs = double("Object", :contents => [])
    #     allow(@s3).to receive(:list_objects).and_return(objs)
    #     allow(Aws::S3::Client).to receive(:new).and_return(@s3)
    #   end

    #   it "destroys any deployed Target microservices" do
    #     umodel = double(MicroserviceModel)
    #     expect(umodel).to receive(:destroy).exactly(4).times
    #     expect(MicroserviceModel).to receive(:get_model).and_return(umodel).exactly(4).times
    #     model = ToolModel.new(folder_name: "INST", name: "INST", scope: "DEFAULT", plugin: "INST")
    #     model.undeploy
    #   end
    # end
  end
end
