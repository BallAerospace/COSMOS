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
require 'cosmos/models/target_model'
require 'cosmos/models/microservice_model'

module Cosmos
  describe TargetModel do
    before(:each) do
      mock_redis()
    end

    describe "self.get" do
      it "returns the specified model" do
        model = TargetModel.new(folder_name: "TEST", name: "TEST2", scope: "DEFAULT")
        model.create
        model = TargetModel.new(folder_name: "SPEC", name: "SPEC", scope: "DEFAULT")
        model.create
        target = TargetModel.get(name: "TEST2", scope: "DEFAULT")
        expect(target["name"]).to eql "TEST2"
        expect(target["folder_name"]).to eql "TEST"
      end
    end

    describe "self.names" do
      it "returns all model names" do
        model = TargetModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        model.create
        model = TargetModel.new(folder_name: "SPEC", name: "SPEC", scope: "DEFAULT")
        model.create
        model = TargetModel.new(folder_name: "OTHER", name: "OTHER", scope: "OTHER")
        model.create
        names = TargetModel.names(scope: "DEFAULT")
        # contain_exactly doesn't care about ordering and neither do we
        expect(names).to contain_exactly("TEST", "SPEC")
        names = TargetModel.names(scope: "OTHER")
        expect(names).to contain_exactly("OTHER")
      end
    end

    describe "self.all" do
      it "returns all the parsed interfaces" do
        model = TargetModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        model.create
        model = TargetModel.new(folder_name: "SPEC", name: "SPEC", scope: "DEFAULT")
        model.create
        all = TargetModel.all(scope: "DEFAULT")
        expect(all.keys).to contain_exactly("TEST", "SPEC")
      end
    end

    describe "self.packet_exist" do
      before(:each) do
        setup_system()
        model = TargetModel.new(folder_name: "INST", name: "INST", scope: "DEFAULT")
        model.create
        model.update_store(File.join(SPEC_DIR, 'install', 'config', 'targets'))
      end

      it "raises for an unknown type" do
        expect { TargetModel.packet_exist("INST", "HEALTH_STATUS", type: :OTHER, scope: "DEFAULT") }.to raise_error(/Unknown type OTHER/)
      end

      it "raises for a non-existant target" do
        expect { TargetModel.packet_exist("BLAH", "HEALTH_STATUS", type: :TLM, scope: "DEFAULT") }.to raise_error("Target 'BLAH' does not exist")
      end

      it "raises for a non-existant packet" do
        expect { TargetModel.packet_exist("INST", "BLAH", type: :TLM, scope: "DEFAULT") }.to raise_error("Packet 'INST BLAH' does not exist")
      end

      it "returns true if the telemetry exists" do
        expect(TargetModel.packet_exist("INST", "HEALTH_STATUS", type: :TLM, scope: "DEFAULT")).to be true
      end

      it "returns true if the command exists" do
        expect(TargetModel.packet_exist("INST", "ABORT", type: :CMD, scope: "DEFAULT")).to be true
      end
    end

    describe "self.packet" do
      before(:each) do
        setup_system()
        model = TargetModel.new(folder_name: "INST", name: "INST", scope: "DEFAULT")
        model.create
        model.update_store(File.join(SPEC_DIR, 'install', 'config', 'targets'))
      end

      it "raises for an unknown type" do
        expect { TargetModel.packet("INST", "HEALTH_STATUS", type: :OTHER, scope: "DEFAULT") }.to raise_error(/Unknown type OTHER/)
      end

      it "raises for a non-existant target" do
        expect { TargetModel.packet("BLAH", "HEALTH_STATUS", type: :TLM, scope: "DEFAULT") }.to raise_error("Target 'BLAH' does not exist")
      end

      it "raises for a non-existant packet" do
        expect { TargetModel.packet("INST", "BLAH", type: :TLM, scope: "DEFAULT") }.to raise_error("Packet 'INST BLAH' does not exist")
      end

      it "returns packet hash if the telemetry exists" do
        pkt = TargetModel.packet("INST", "HEALTH_STATUS", type: :TLM, scope: "DEFAULT")
        expect(pkt['target_name']).to eql "INST"
        expect(pkt['packet_name']).to eql "HEALTH_STATUS"
      end

      it "returns packet hash if the command exists" do
        pkt = TargetModel.packet("INST", "ABORT", type: :CMD, scope: "DEFAULT")
        expect(pkt['target_name']).to eql "INST"
        expect(pkt['packet_name']).to eql "ABORT"
      end
    end

    describe "self.handle_config" do
      it "only recognizes TARGET" do
        parser = double("ConfigParser").as_null_object
        expect(parser).to receive(:verify_num_parameters)
        TargetModel.handle_config(parser, "TARGET", ["TEST", "TEST"], scope: "DEFAULT")
        expect { TargetModel.handle_config(parser, "TARGETS", ["TEST", "TEST"], scope: "DEFAULT") }.to raise_error(ConfigParser::Error)
      end
    end

    describe "initialize" do
      it "requires folder_name, name and scope" do
        expect { TargetModel.new(folder_name: "TEST", name: "TEST") }.to raise_error(ArgumentError)
        expect { TargetModel.new(name: "TEST", scope: "DEFAULT") }.to raise_error(ArgumentError)
        expect { TargetModel.new(folder_name: "TEST", scope: "DEFAULT") }.to raise_error(ArgumentError)
        model = TargetModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
      end
    end

    describe "create" do
      it "stores model based on scope and class name" do
        model = TargetModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        model.create
        keys = Store.scan(0)
        # This is an implementation detail but Redis keys are pretty critical so test it
        expect(keys[1]).to contain_exactly("DEFAULT__cosmos_targets")
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        model = TargetModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        json = model.as_json
        expect(json['name']).to eq "TEST"
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
        model = TargetModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        expect(model.as_config).to match(/TARGET TEST/)
        model = TargetModel.new(folder_name: "TEST", name: "TEST2", scope: "DEFAULT")
        expect(model.as_config).to match(/TARGET TEST TEST2/)
      end
    end

    describe "handle_config" do
      it "raises as there are no keywords below TARGET" do
        model = TargetModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        expect { model.handle_config(nil, "TARGET", nil) }.to raise_error("Unsupported keyword for TARGET: TARGET")
      end
    end

    describe "deploy" do
      before(:each) do
        @scope = "DEFAULT"
        @target = "INST"
        @s3 = instance_double("Aws::S3::Client")#.as_null_object
        allow(@s3).to receive(:put_object)
        allow(Aws::S3::Client).to receive(:new).and_return(@s3)
        @target_dir = File.join(SPEC_DIR, "install", "config")
      end

      it "raises if the target can't be found" do
        @target_dir = Dir.pwd
        variables = {"test"=>"example"}
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: @target)
        model.create
        expect { model.deploy(@target_dir, variables) }.to raise_error(/No target files found/)
      end

      it "copies the target files to S3" do
        Dir.glob("#{@target_dir}/targets/#{@target}/**/*") do |filename|
          next unless File.file?(filename)
          # Files are stored in S3 with <SCOPE>/<TARGET NAME>/<file path>
          # Splitting on 'config' gives us the target and path so just prepend the scope
          filename = "#{@scope}#{filename.split("config")[-1]}"
          expect(@s3).to receive(:put_object).with(bucket: 'config', key: filename, body: anything)
        end
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: @target)
        model.create
        model.deploy(@target_dir, {})
      end

      it "creates target_id.txt as a hash" do
        key = "DEFAULT/targets/INST/target_id.txt"
        expect(@s3).to receive(:put_object).with(bucket: 'config', key: key, body: anything)
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: @target)
        model.create
        model.deploy(@target_dir, {})
      end

      it "archives the target to S3" do
        key = "DEFAULT/target_archives/INST/INST_current.zip"
        expect(@s3).to receive(:put_object).with(bucket: 'config', key: key, body: anything)
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: @target)
        model.create
        model.deploy(@target_dir, {})
      end

      it "puts the packets in Redis" do
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: "PLUGIN")
        model.create
        model.deploy(@target_dir, {})
        expect(Store.hkeys("DEFAULT__cosmostlm__INST")).to include("HEALTH_STATUS", "ADCS", "PARAMS", "IMAGE", "MECH")
        expect(Store.hkeys("DEFAULT__cosmoscmd__INST")).to include("ABORT", "COLLECT", "CLEAR") #... etc

        # Spot check a telemetry packet and a command
        telemetry = TargetModel.packet(@target, "HEALTH_STATUS", type: :TLM, scope: @scope)
        expect(telemetry['target_name']).to eql @target
        expect(telemetry['packet_name']).to eql "HEALTH_STATUS"
        expect(telemetry['items'].length).to be > 10
        command = TargetModel.packet(@target, "ABORT", type: :CMD, scope: @scope)
        expect(command['target_name']).to eql @target
        expect(command['packet_name']).to eql "ABORT"
        expect(command['items'].length).to be > 10
      end

      it "creates and deploys Target microservices" do
        variables = { "test" => "example" }
        umodel = double(MicroserviceModel)
        expect(umodel).to receive(:create).exactly(4).times
        expect(umodel).to receive(:deploy).with(@target_dir, variables).exactly(4).times
        # Verify the microservices that are started
        expect(MicroserviceModel).to receive(:new).with(hash_including(
          name: "#{@scope}__DECOM__#{@target}")
        ).and_return(umodel)
        expect(MicroserviceModel).to receive(:new).with(hash_including(
          name: "#{@scope}__CVT__#{@target}")
        ).and_return(umodel)
        expect(MicroserviceModel).to receive(:new).with(hash_including(
          name: "#{@scope}__PACKETLOG__#{@target}")
        ).and_return(umodel)
        expect(MicroserviceModel).to receive(:new).with(hash_including(
          name: "#{@scope}__DECOMLOG__#{@target}")
        ).and_return(umodel)
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: @target)
        model.create
        model.deploy(@target_dir, variables)
      end

      it "doesn't deploy microservices with no packets" do
        @target = "EMPTY"
        umodel = double(MicroserviceModel)
        expect(umodel).to_not receive(:create)
        expect(umodel).to_not receive(:deploy)
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: @target)
        model.create
        model.deploy(@target_dir, {})
      end
    end

    describe "undeploy" do
      before(:each) do
        @s3 = instance_double("Aws::S3::Client")
        allow(@s3).to receive(:put_object)
        objs = double("Object", :contents => [])
        allow(@s3).to receive(:list_objects).and_return(objs)
        allow(Aws::S3::Client).to receive(:new).and_return(@s3)
      end

      it "destroys any deployed Target microservices" do
        umodel = double(MicroserviceModel)
        expect(umodel).to receive(:destroy).exactly(4).times
        expect(MicroserviceModel).to receive(:get_model).and_return(umodel).exactly(4).times
        model = TargetModel.new(folder_name: "INST", name: "INST", scope: "DEFAULT", plugin: "INST")
        model.undeploy
      end
    end
  end
end
