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
      "Packet Viewer", "Script Runner", "Telemetry Grapher", "Telemetry Viewer", "Data Viewer"]

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

    describe "self.set_position" do
      it "reorders the tools" do
        # Create a few new tool models
        model = ToolModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        model.create
        # Verify the new position is at the end
        expect(model.position).to eql DEFAULT_APPS.length
        model = ToolModel.new(folder_name: "TEST", name: "TEST2", scope: "DEFAULT")
        model.create
        # Verify the new position is at the end
        expect(model.position).to eql DEFAULT_APPS.length + 1

        # Verify CmdTlmServer is currently 0 (first)
        server = ToolModel.get(name: "CmdTlmServer", scope: "DEFAULT")
        expect(server['position']).to eq 0

        # Move TEST to the beginning
        ToolModel.set_position(name: "TEST", position: 0, scope: "DEFAULT")
        model = ToolModel.get(name: "TEST", scope: "DEFAULT")
        # The tool gets moved to the 0 position
        expect(model['position']).to eql 0
        # CmdTlmServer is moved to 1
        server = ToolModel.get(name: "CmdTlmServer", scope: "DEFAULT")
        expect(server['position']).to eql 1
        # TEST2 doesn't change
        model = ToolModel.get(name: "TEST2", scope: "DEFAULT")
        expect(model['position']).to eql DEFAULT_APPS.length + 1

        # Move TEST to the end
        ToolModel.set_position(name: "TEST", position: DEFAULT_APPS.length + 1, scope: "DEFAULT")
        model = ToolModel.get(name: "TEST", scope: "DEFAULT")
        expect(model['position']).to eql DEFAULT_APPS.length + 1
        # CmdTlmServer is now 0
        server = ToolModel.get(name: "CmdTlmServer", scope: "DEFAULT")
        expect(server['position']).to eql 0
        # TEST2 moves down
        model = ToolModel.get(name: "TEST2", scope: "DEFAULT")
        expect(model['position']).to eql DEFAULT_APPS.length
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        model = ToolModel.new(name: "TEST", scope: "DEFAULT")
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
      it "exports tool as COSMOS configuration" do
        model = ToolModel.new(folder_name: "FOLDER", name: "TEST", scope: "DEFAULT")
        expect(model.as_config).to match(/TOOL FOLDER "TEST"/)
        model = ToolModel.new(name: "TEST2", scope: "DEFAULT")
        expect(model.as_config).to match(/TOOL nil "TEST2"/)
      end
    end

    describe "handle_config" do
      it "parses tool specific keywords" do
        model = ToolModel.new(name: "TEST", scope: "DEFAULT")

        parser = ConfigParser.new
        tf = Tempfile.new
        tf.puts "URL myurl"
        tf.puts "ICON mdi-icon"
        tf.close
        parser.parse_file(tf.path) do |keyword, params|
          model.handle_config(parser, keyword, params)
        end
        json = model.as_json
        expect(json['url']).to eql 'myurl'
        expect(json['icon']).to eql 'mdi-icon'
        tf.unlink
      end
    end

    describe "deploy" do
      it "does nothing if folder_name is undefined" do
        model = ToolModel.new(name: "TEST", scope: "DEFAULT")
        model.create
        expect(Aws::S3::Client).not_to receive(:new)
        model.deploy(Dir.pwd, {})
      end

      it "creates and deploys a ToolModel" do
        s3 = instance_double("Aws::S3::Client")
        allow(Aws::S3::Client).to receive(:new).and_return(s3)

        scope = "DEFAULT"
        folder = "DEMO"
        name = "DEMO"
        dir = File.join(SPEC_DIR, "install")
        expect(s3).to receive(:put_object).with(bucket: 'config', key: "#{scope}/tools/#{name}/index.html", body: anything)

        model = ToolModel.new(folder_name: folder, name: name, scope: scope)
        model.create
        model.deploy(dir, {})
      end
    end

    describe "undeploy" do
      it "calls destroy on a deployed ToolModel" do
        s3 = instance_double("Aws::S3::Client")
        allow(Aws::S3::Client).to receive(:new).and_return(s3)
        options = OpenStruct.new
        options.key = "blah"
        objs = double("Object", :contents => [options])

        scope = "DEFAULT"
        folder = "DEMO"
        name = "DEMO"
        expect(s3).to receive(:list_objects).with(bucket: 'config', prefix: "#{scope}/tools/#{name}/").and_return(objs)
        expect(s3).to receive(:delete_object).with(bucket: 'config', key: "blah")

        model = ToolModel.new(folder_name: folder, name: name, scope: scope)
        model.undeploy
      end
    end
  end
end
