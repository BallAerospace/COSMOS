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
require 'openc3/models/interface_model'

module OpenC3
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
        expect(model.name).to eql "TEST_INT"
      end
    end

    describe "create" do
      it "stores model based on scope and class name" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")
        model.create
        keys = Store.scan(0)
        # This is an implementation detail but Redis keys are pretty critical so test it
        expect(keys[1]).to include("DEFAULT__openc3_interfaces").at_most(1).times
        # 21/07/2021 - G this needed to be changed to contain OPENC3__TOKEN
      end
    end

    describe "handle_config" do
      it "raise on unknown keywords" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")
        parser = ConfigParser.new
        tf = Tempfile.new
        tf.puts "UNKNOWN"
        tf.close
        parser.parse_file(tf.path) do |keyword, params|
          expect { model.handle_config(parser, keyword, params) }.to raise_error(/Unknown keyword/)
        end
        tf.unlink
      end

      it "raise on badly formatted keywords" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")
        parser = ConfigParser.new
        tf = Tempfile.new
        tf.puts "PROTOCOL OTHER ReadProtocol"
        tf.close
        parser.parse_file(tf.path) do |keyword, params|
          expect { model.handle_config(parser, keyword, params) }.to raise_error("Invalid protocol type: OTHER")
        end
        tf.unlink
      end

      it "parses tool specific keywords" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")

        parser = ConfigParser.new
        tf = Tempfile.new
        tf.puts "MAP_TARGET TARGET1"
        tf.puts "MAP_TARGET TARGET2"
        tf.puts "DONT_CONNECT"
        tf.puts "DONT_RECONNECT"
        tf.puts "RECONNECT_DELAY 10"
        tf.puts "DISABLE_DISCONNECT"
        tf.puts "OPTION NAME1 VALUE1"
        tf.puts "OPTION NAME2 VALUE2"
        tf.puts "PROTOCOL READ ReadProtocol 1 2 3"
        tf.puts "PROTOCOL WRITE WriteProtocol"
        tf.puts "DONT_LOG"
        tf.puts "LOG_RAW"
        tf.close
        parser.parse_file(tf.path) do |keyword, params|
          model.handle_config(parser, keyword, params)
        end
        json = model.as_json(:allow_nan => true)
        expect(json['target_names']).to include("TARGET1", "TARGET2")
        expect(json['connect_on_startup']).to be false
        expect(json['auto_reconnect']).to be false
        expect(json['reconnect_delay']).to eql 10.0
        expect(json['disable_disconnect']).to be true
        expect(json['options']).to include(["NAME1", "VALUE1"], ["NAME2", "VALUE2"])
        expect(json['protocols']).to include(["READ", "ReadProtocol", "1", "2", "3"], ["WRITE", "WriteProtocol"])
        expect(json['log']).to be false
        expect(json['log_raw']).to be true
        tf.unlink
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
        json = model.as_json(:allow_nan => true)
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
      it "exports model as OpenC3 configuration" do
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT")
        expect(model.as_config).to match(/INTERFACE TEST_INT/)
      end
    end

    describe "deploy, undeploy" do
      it "creates and deploys a MicroserviceModel" do
        dir = Dir.pwd
        variables = { "test" => "example" }

        intmodel = double(InterfaceStatusModel)
        expect(intmodel).to receive(:destroy)
        expect(InterfaceStatusModel).to receive(:get_model).and_return(intmodel)
        # double MicroserviceModel because we're not testing that here
        umodel = double(MicroserviceModel)
        expect(umodel).to receive(:create)
        expect(umodel).to receive(:deploy).with(dir, variables)
        expect(umodel).to receive(:destroy)
        expect(MicroserviceModel).to receive(:get_model).and_return(umodel)
        expect(MicroserviceModel).to receive(:new).and_return(umodel)
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT", plugin: "PLUG")
        model.create
        model.deploy(dir, variables)
        config = ConfigTopic.read(scope: 'DEFAULT')
        expect(config[0][1]['kind']).to eql 'created'
        expect(config[0][1]['type']).to eql 'interface'
        expect(config[0][1]['name']).to eql 'TEST_INT'
        expect(config[0][1]['plugin']).to eql 'PLUG'

        model.undeploy
        config = ConfigTopic.read(scope: 'DEFAULT')
        expect(config[0][1]['kind']).to eql 'deleted'
        expect(config[0][1]['type']).to eql 'interface'
        expect(config[0][1]['name']).to eql 'TEST_INT'
        expect(config[0][1]['plugin']).to eql 'PLUG'
      end
    end
  end
end
