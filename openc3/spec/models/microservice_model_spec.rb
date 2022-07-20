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
require 'openc3/models/microservice_model'

module OpenC3
  describe MicroserviceModel do
    before(:each) do
      mock_redis()
    end

    describe "self.get" do
      it "returns the specified model with or without scope" do
        model = MicroserviceModel.new(folder_name: "TEST", name: "DEFAULT__TYPE__TEST", scope: "DEFAULT")
        model.create
        model = MicroserviceModel.new(folder_name: "SPEC", name: "DEFAULT__TYPE__SPEC", scope: "DEFAULT")
        model.create
        target = MicroserviceModel.get(name: "DEFAULT__TYPE__TEST", scope: "DEFAULT")
        expect(target["name"]).to eql "DEFAULT__TYPE__TEST"
        expect(target["folder_name"]).to eql "TEST"
        target = MicroserviceModel.get(name: "DEFAULT__TYPE__SPEC") # No scope
        expect(target["name"]).to eql "DEFAULT__TYPE__SPEC"
        expect(target["folder_name"]).to eql "SPEC"
      end
    end

    describe "self.names" do
      it "returns all model names" do
        model = MicroserviceModel.new(folder_name: "TEST", name: "DEFAULT__TYPE__TEST", scope: "DEFAULT")
        model.create
        model = MicroserviceModel.new(folder_name: "SPEC", name: "DEFAULT__TYPE__SPEC", scope: "DEFAULT")
        model.create
        model = MicroserviceModel.new(folder_name: "OTHER", name: "OTHER__TYPE__TEST", scope: "OTHER")
        model.create
        names = MicroserviceModel.names()
        # contain_exactly doesn't care about ordering and neither do we
        expect(names).to contain_exactly("DEFAULT__TYPE__TEST", "DEFAULT__TYPE__SPEC", "OTHER__TYPE__TEST")
      end

      it "returns scoped model names" do
        model = MicroserviceModel.new(folder_name: "TEST", name: "DEFAULT__TYPE__TEST", scope: "DEFAULT")
        model.create
        model = MicroserviceModel.new(folder_name: "SPEC", name: "DEFAULT__TYPE__SPEC", scope: "DEFAULT")
        model.create
        model = MicroserviceModel.new(folder_name: "OTHER", name: "OTHER__TYPE__TEST", scope: "OTHER")
        model.create
        names = MicroserviceModel.names(scope: "DEFAULT")
        # contain_exactly doesn't care about ordering and neither do we
        expect(names).to contain_exactly("DEFAULT__TYPE__TEST", "DEFAULT__TYPE__SPEC")
        names = MicroserviceModel.names(scope: "OTHER")
        expect(names).to contain_exactly("OTHER__TYPE__TEST")
      end
    end

    describe "self.all" do
      it "returns all the parsed models" do
        model = MicroserviceModel.new(folder_name: "TEST", name: "DEFAULT__TYPE__TEST", scope: "DEFAULT")
        model.create
        model = MicroserviceModel.new(folder_name: "SPEC", name: "DEFAULT__TYPE__SPEC", scope: "DEFAULT")
        model.create
        model = MicroserviceModel.new(folder_name: "OTHER", name: "OTHER__TYPE__TEST", scope: "OTHER")
        model.create
        all = MicroserviceModel.all()
        # contain_exactly doesn't care about ordering and neither do we
        expect(all.keys).to contain_exactly("DEFAULT__TYPE__TEST", "DEFAULT__TYPE__SPEC", "OTHER__TYPE__TEST")
      end

      it "returns scoped parsed models" do
        model = MicroserviceModel.new(folder_name: "TEST", name: "DEFAULT__TYPE__TEST", scope: "DEFAULT")
        model.create
        model = MicroserviceModel.new(folder_name: "SPEC", name: "DEFAULT__TYPE__SPEC", scope: "DEFAULT")
        model.create
        model = MicroserviceModel.new(folder_name: "OTHER", name: "OTHER__TYPE__TEST", scope: "OTHER")
        model.create
        all = MicroserviceModel.all(scope: "DEFAULT")
        # contain_exactly doesn't care about ordering and neither do we
        expect(all.keys).to contain_exactly("DEFAULT__TYPE__TEST", "DEFAULT__TYPE__SPEC")
        all = MicroserviceModel.all(scope: "OTHER")
        expect(all.keys).to contain_exactly("OTHER__TYPE__TEST")
      end
    end

    describe "self.handle_config" do
      it "only recognizes MICROSERVICE" do
        parser = double("ConfigParser").as_null_object
        expect(parser).to receive(:verify_num_parameters)
        expect { MicroserviceModel.handle_config(parser, "OTHER", ["folder", "micro-name"], scope: "DEFAULT") }.to raise_error(ConfigParser::Error)
        # This is a bad name because it has double underscores which are reserved as a delimiter
        expect { MicroserviceModel.handle_config(parser, "MICROSERVICE", ["folder", "bad__name"], scope: "DEFAULT") }.to raise_error("name 'DEFAULT__USER__BAD__NAME' must be formatted as SCOPE__TYPE__NAME")
        model = MicroserviceModel.handle_config(parser, "MICROSERVICE", ["folder", "micro-name"], scope: "DEFAULT")
        expect(model.name).to eql "DEFAULT__USER__MICRO-NAME"
      end
    end

    describe "initialize" do
      it "requires name to be formatted SCOPE__TYPE__NAME" do
        expect { MicroserviceModel.new(name: "SCOPE", folder_name: "FOLDER", scope: "DEFAULT") }.to raise_error("name 'SCOPE' must be formatted as SCOPE__TYPE__NAME")
        expect { MicroserviceModel.new(name: "SCOPE__TYPE", folder_name: "FOLDER", scope: "DEFAULT") }.to raise_error("name 'SCOPE__TYPE' must be formatted as SCOPE__TYPE__NAME")
        expect { MicroserviceModel.new(name: "SCOPE__TYPE__NAME", folder_name: "FOLDER", scope: "DEFAULT") }.to raise_error("name 'SCOPE__TYPE__NAME' scope 'SCOPE' doesn't match scope parameter 'DEFAULT'")
        model = MicroserviceModel.new(folder_name: "TEST", name: "DEFAULT__TYPE__NAME", scope: "DEFAULT")
        expect(model.name).to eql "DEFAULT__TYPE__NAME"
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        model = MicroserviceModel.new(folder_name: "TEST", name: "DEFAULT__TYPE__NAME", scope: "DEFAULT")
        json = model.as_json(:allow_nan => true)
        expect(json['name']).to eq "DEFAULT__TYPE__NAME"
        params = model.method(:initialize).parameters
        params.each do |type, name|
          # Scope isn't included in as_json as it is part of the key used to get the model
          next if name == :scope

          expect(json.key?(name.to_s)).to be true
        end
      end
    end

    describe "as_config" do
      it "exports model as OpenC3 configuration" do
        model = MicroserviceModel.new(folder_name: "TEST", name: "DEFAULT__TYPE__NAME", scope: "DEFAULT")
        expect(model.as_config).to match(/MICROSERVICE TEST NAME/)
      end
    end

    describe "handle_config" do
      it "parses microservice specific keywords" do
        model = MicroserviceModel.new(folder_name: "TEST", name: "DEFAULT__TYPE__NAME", scope: "DEFAULT")

        parser = ConfigParser.new
        tf = Tempfile.new
        tf.puts "ENV KEY1 'VALUE 1'"
        tf.puts "ENV KEY2 'VALUE 2'"
        tf.puts "WORK_DIR #{Dir.pwd}"
        tf.puts "TOPIC TOPIC1"
        tf.puts "TOPIC TOPIC2"
        tf.puts "TARGET_NAME TARGET1"
        tf.puts "TARGET_NAME TARGET2"
        tf.puts "CMD ruby run.rb --switch"
        tf.puts "OPTION NAME1 VALUE1"
        tf.puts "OPTION NAME2 VALUE2"
        tf.close
        parser.parse_file(tf.path) do |keyword, params|
          model.handle_config(parser, keyword, params)
        end
        json = model.as_json(:allow_nan => true)
        expect(json['env']).to include("KEY1" => "VALUE 1", "KEY2" => "VALUE 2")
        expect(json['work_dir']).to eql Dir.pwd
        expect(json['topics']).to include("TOPIC1", "TOPIC2")
        expect(json['target_names']).to include("TARGET1", "TARGET2")
        expect(json['cmd']).to eql ["ruby", "run.rb", "--switch"]
        expect(json['options']).to include(["NAME1", "VALUE1"], ["NAME2", "VALUE2"])
        tf.unlink
      end
    end

    describe "deploy" do
      it "does nothing if folder_name is undefined" do
        model = MicroserviceModel.new(name: "DEFAULT__TYPE__NAME", scope: "DEFAULT")
        model.create
        expect(Aws::S3::Client).not_to receive(:new)
        model.deploy(Dir.pwd, {})
      end

      it "creates and deploys a MicroserviceModel" do
        s3 = instance_double("Aws::S3::Client")
        allow(Aws::S3::Client).to receive(:new).and_return(s3)

        scope = "DEFAULT"
        folder = "EXAMPLE"
        name = "#{scope}__USER__#{folder}"
        dir = File.join(SPEC_DIR, "install")
        expect(s3).to receive(:put_object).with(bucket: 'config', key: "#{scope}/microservices/#{name}/example_target.rb", body: anything)

        model = MicroserviceModel.new(folder_name: folder, name: name, scope: scope, plugin: 'PLUGIN')
        model.create
        model.deploy(dir, {})

        config = ConfigTopic.read(scope: 'DEFAULT')
        expect(config[0][1]['kind']).to eql 'created'
        expect(config[0][1]['type']).to eql 'microservice'
        expect(config[0][1]['name']).to eql name
        expect(config[0][1]['plugin']).to eql 'PLUGIN'
      end
    end

    describe "undeploy" do
      it "calls destroy on a deployed MicroserviceModel" do
        s3 = instance_double("Aws::S3::Client")
        allow(Aws::S3::Client).to receive(:new).and_return(s3)
        options = OpenStruct.new
        options.key = "blah"
        objs = double("Object", :contents => [options])

        scope = "DEFAULT"
        folder = "EXAMPLE"
        name = "#{scope}__USER__#{folder}"
        expect(s3).to receive(:list_objects).with(bucket: 'config', prefix: "#{scope}/microservices/#{name}/").and_return(objs)
        expect(s3).to receive(:delete_object).with(bucket: 'config', key: "blah")

        model = MicroserviceModel.new(folder_name: folder, name: name, scope: scope, plugin: 'PLUGIN')
        model.undeploy

        config = ConfigTopic.read(scope: 'DEFAULT')
        expect(config[0][1]['kind']).to eql 'deleted'
        expect(config[0][1]['type']).to eql 'microservice'
        expect(config[0][1]['name']).to eql name
        expect(config[0][1]['plugin']).to eql 'PLUGIN'
      end
    end
  end
end
