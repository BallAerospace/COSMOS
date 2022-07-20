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
require 'fileutils'
require 'openc3/models/target_model'
require 'openc3/models/microservice_model'

module OpenC3
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

    describe "self.packet_names" do
      before(:each) do
        setup_system()
        model = TargetModel.new(folder_name: "INST", name: "INST", scope: "DEFAULT")
        model.create
        model.update_store(System.new(['INST'], File.join(SPEC_DIR, 'install', 'config', 'targets')))
        model = TargetModel.new(folder_name: "EMPTY", name: "EMPTY", scope: "DEFAULT")
        model.create
        model.update_store(System.new(['EMPTY'], File.join(SPEC_DIR, 'install', 'config', 'targets')))
      end

      it "raises for an unknown type" do
        expect { TargetModel.packet_names("INST", type: :OTHER, scope: "DEFAULT") }.to raise_error(/Unknown type OTHER/)
      end

      it "returns empty array for a non-existant target" do
        names = TargetModel.packet_names("BLAH", scope: "DEFAULT")
        expect(names).to be_a Array
        expect(names).to be_empty
      end

      it "returns all telemetry packet names" do
        names = TargetModel.packet_names("INST", type: :TLM, scope: "DEFAULT")
        # Verify result is Array of strings
        expect(names).to be_a Array
        expect(names).to include("ADCS", "HEALTH_STATUS", "PARAMS", "IMAGE", "MECH")
      end

      it "returns empty array for no telemetry packets" do
        names = TargetModel.packet_names("EMPTY", type: :TLM, scope: "DEFAULT")
        # Verify result is Array of strings
        expect(names).to be_a Array
        expect(names).to be_empty
      end

      it "returns all command packet names" do
        names = TargetModel.packet_names("INST", type: :CMD, scope: "DEFAULT")
        expect(names).to be_a Array
        expect(names).to include("ABORT", "COLLECT", "CLEAR") # Spot check
      end

      it "returns empty array for no command packets" do
        names = TargetModel.packet_names("EMPTY", type: :CMD, scope: "DEFAULT")
        # Verify result is Array of strings
        expect(names).to be_a Array
        expect(names).to be_empty
      end
    end

    describe "self.packets" do
      before(:each) do
        setup_system()
        model = TargetModel.new(folder_name: "INST", name: "INST", scope: "DEFAULT")
        model.create
        model.update_store(System.new(['INST'], File.join(SPEC_DIR, 'install', 'config', 'targets')))
        model = TargetModel.new(folder_name: "EMPTY", name: "EMPTY", scope: "DEFAULT")
        model.create
        model.update_store(System.new(['EMPTY'], File.join(SPEC_DIR, 'install', 'config', 'targets')))
      end

      it "raises for an unknown type" do
        expect { TargetModel.packets("INST", type: :OTHER, scope: "DEFAULT") }.to raise_error(/Unknown type OTHER/)
      end

      it "raises for a non-existant target" do
        expect { TargetModel.packets("BLAH", scope: "DEFAULT") }.to raise_error("Target 'BLAH' does not exist")
      end

      it "returns all telemetry packets" do
        pkts = TargetModel.packets("INST", type: :TLM, scope: "DEFAULT")
        # Verify result is Array of packet Hashes
        expect(pkts).to be_a Array
        names = []
        pkts.each do |pkt|
          expect(pkt).to be_a Hash
          expect(pkt['target_name']).to eql "INST"
          names << pkt['packet_name']
        end
        expect(names).to include("ADCS", "HEALTH_STATUS", "PARAMS", "IMAGE", "MECH")
      end

      it "returns empty array for no telemetry packets" do
        pkts = TargetModel.packets("EMPTY", type: :TLM, scope: "DEFAULT")
        # Verify result is Array of packet Hashes
        expect(pkts).to be_a Array
        expect(pkts).to be_empty
      end

      it "returns packet hash if the command exists" do
        pkts = TargetModel.packets("INST", type: :CMD, scope: "DEFAULT")
        expect(pkts).to be_a Array
        names = []
        pkts.each do |pkt|
          expect(pkt).to be_a Hash
          expect(pkt['target_name']).to eql "INST"
          expect(pkt['items']).to be_a Array
          names << pkt['packet_name']
        end
        expect(names).to include("ABORT", "COLLECT", "CLEAR") # Spot check
      end

      it "returns empty array for no command packets" do
        pkts = TargetModel.packets("EMPTY", type: :CMD, scope: "DEFAULT")
        # Verify result is Array of packet Hashes
        expect(pkts).to be_a Array
        expect(pkts).to be_empty
      end
    end

    describe "self.all_packet_name_descriptions" do
      before(:each) do
        setup_system()
        model = TargetModel.new(folder_name: "INST", name: "INST", scope: "DEFAULT")
        model.create
        model.update_store(System.new(['INST'], File.join(SPEC_DIR, 'install', 'config', 'targets')))
        model = TargetModel.new(folder_name: "EMPTY", name: "EMPTY", scope: "DEFAULT")
        model.create
        model.update_store(System.new(['EMPTY'], File.join(SPEC_DIR, 'install', 'config', 'targets')))
      end

      it "returns only the packet_name and description" do
        pkts = TargetModel.all_packet_name_descriptions("INST", type: :TLM, scope: "DEFAULT")
        # Verify result is Array of packet Hashes
        expect(pkts).to be_a Array
        names = []
        pkts.each do |pkt|
          expect(pkt).to be_a Hash
          expect(pkt.keys).to eql(%w(packet_name description))
        end
      end
    end

    describe "self.packet" do
      before(:each) do
        setup_system()
        model = TargetModel.new(folder_name: "INST", name: "INST", scope: "DEFAULT")
        model.create
        model.update_store(System.new(['INST'], File.join(SPEC_DIR, 'install', 'config', 'targets')))
      end

      it "raises for an unknown type" do
        expect { TargetModel.packet("INST", "HEALTH_STATUS", type: :OTHER, scope: "DEFAULT") }.to raise_error(/Unknown type OTHER/)
      end

      it "raises for a non-existant target" do
        expect { TargetModel.packet("BLAH", "HEALTH_STATUS", type: :TLM, scope: "DEFAULT") }.to raise_error("Packet 'BLAH HEALTH_STATUS' does not exist")
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

    describe "self.packet_item" do
      before(:each) do
        setup_system()
        model = TargetModel.new(folder_name: "INST", name: "INST", scope: "DEFAULT")
        model.create
        model.update_store(System.new(['INST'], File.join(SPEC_DIR, 'install', 'config', 'targets')))
      end

      it "raises for an unknown type" do
        expect { TargetModel.packet_item("INST", "HEALTH_STATUS", "CCSDSVER", type: :OTHER, scope: "DEFAULT") }.to raise_error(/Unknown type OTHER/)
      end

      it "raises for a non-existant target" do
        expect { TargetModel.packet_item("BLAH", "HEALTH_STATUS", "CCSDSVER", scope: "DEFAULT") }.to raise_error("Packet 'BLAH HEALTH_STATUS' does not exist")
      end

      it "raises for a non-existant packet" do
        expect { TargetModel.packet_item("INST", "BLAH", "CCSDSVER", scope: "DEFAULT") }.to raise_error("Packet 'INST BLAH' does not exist")
      end

      it "raises for a non-existant item" do
        expect { TargetModel.packet_item("INST", "HEALTH_STATUS", "BLAH", scope: "DEFAULT") }.to raise_error("Item 'INST HEALTH_STATUS BLAH' does not exist")
      end

      it "returns item hash if the telemetry item exists" do
        item = TargetModel.packet_item("INST", "HEALTH_STATUS", "CCSDSVER", scope: "DEFAULT")
        expect(item['name']).to eql "CCSDSVER"
        expect(item['bit_offset']).to eql 0
      end

      it "returns item hash if the command item exists" do
        item = TargetModel.packet_item("INST", "ABORT", "CCSDSVER", type: :CMD, scope: "DEFAULT")
        expect(item['name']).to eql "CCSDSVER"
        expect(item['bit_offset']).to eql 0
      end
    end

    describe "self.packet_items" do
      before(:each) do
        setup_system()
        model = TargetModel.new(folder_name: "INST", name: "INST", scope: "DEFAULT")
        model.create
        model.update_store(System.new(['INST'], File.join(SPEC_DIR, 'install', 'config', 'targets')))
      end

      it "raises for an unknown type" do
        expect { TargetModel.packet_items("INST", "HEALTH_STATUS", ["CCSDSVER"], type: :OTHER, scope: "DEFAULT") }.to raise_error(/Unknown type OTHER/)
      end

      it "raises for a non-existant target" do
        expect { TargetModel.packet_items("BLAH", "HEALTH_STATUS", ["CCSDSVER"], scope: "DEFAULT") }.to raise_error("Packet 'BLAH HEALTH_STATUS' does not exist")
      end

      it "raises for a non-existant packet" do
        expect { TargetModel.packet_items("INST", "BLAH", ["CCSDSVER"], scope: "DEFAULT") }.to raise_error("Packet 'INST BLAH' does not exist")
      end

      it "raises for non-existant items" do
        expect { TargetModel.packet_items("INST", "HEALTH_STATUS", ["BLAH"], scope: "DEFAULT") }.to \
          raise_error("Item(s) 'INST HEALTH_STATUS BLAH' does not exist")
        expect { TargetModel.packet_items("INST", "HEALTH_STATUS", ["CCSDSVER", "BLAH"], scope: "DEFAULT") }.to \
          raise_error("Item(s) 'INST HEALTH_STATUS BLAH' does not exist")
        expect { TargetModel.packet_items("INST", "HEALTH_STATUS", [:BLAH, :NOPE], scope: "DEFAULT") }.to \
          raise_error("Item(s) 'INST HEALTH_STATUS BLAH', 'INST HEALTH_STATUS NOPE' does not exist")
      end

      it "returns item hash array if the telemetry items exists" do
        items = TargetModel.packet_items("INST", "HEALTH_STATUS", ["CCSDSVER", "CCSDSTYPE"], scope: "DEFAULT")
        expect(items.length).to eql 2
        expect(items[0]['name']).to eql "CCSDSVER"
        expect(items[0]['bit_offset']).to eql 0
        expect(items[1]['name']).to eql "CCSDSTYPE"

        # Verify it also works with symbols
        items = TargetModel.packet_items("INST", "HEALTH_STATUS", [:CCSDSVER, :CCSDSTYPE], scope: "DEFAULT")
        expect(items.length).to eql 2
        expect(items[0]['name']).to eql "CCSDSVER"
        expect(items[0]['bit_offset']).to eql 0
        expect(items[1]['name']).to eql "CCSDSTYPE"
      end

      it "returns item hash array if the command items exists" do
        items = TargetModel.packet_items("INST", "ABORT", ["CCSDSVER", "CCSDSTYPE"], type: :CMD, scope: "DEFAULT")
        expect(items.length).to eql 2
        expect(items[0]['name']).to eql "CCSDSVER"
        expect(items[0]['bit_offset']).to eql 0
        expect(items[1]['name']).to eql "CCSDSTYPE"
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
      it "requires name and scope" do
        expect { TargetModel.new(folder_name: "TEST", name: "TEST") }.to raise_error(ArgumentError)
        expect { TargetModel.new(folder_name: "TEST", scope: "DEFAULT") }.to raise_error(ArgumentError)
        model = TargetModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        expect(model).to_not be_nil
      end
    end

    describe "create" do
      it "stores model based on scope and class name" do
        model = TargetModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        model.create
        keys = Store.scan(0)
        # This is an implementation detail but Redis keys are pretty critical so test it
        expect(keys[1]).to include("DEFAULT__openc3_targets").at_most(1).times
        # 21/07/2021 - G this needed to be changed to contain OPENC3__TOKEN
      end
    end

    describe "as_json" do
      it "encodes all the input parameters" do
        model = TargetModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        json = model.as_json(:allow_nan => true)
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
      it "exports model as OpenC3 configuration" do
        model = TargetModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        expect(model.as_config).to match(/TARGET TEST/)
        model = TargetModel.new(folder_name: "TEST", name: "TEST2", scope: "DEFAULT")
        expect(model.as_config).to match(/TARGET TEST TEST2/)
      end
    end

    describe "handle_config" do
      it "parses tool specific keywords" do
        model = TargetModel.new(folder_name: "TEST", name: "TEST", scope: "DEFAULT")
        model.create
        parser = ConfigParser.new
        tf = Tempfile.new
        tf.puts "CMD_LOG_CYCLE_TIME 1"
        tf.puts "CMD_LOG_CYCLE_SIZE 2"
        tf.puts "CMD_DECOM_LOG_CYCLE_TIME 3"
        tf.puts "CMD_DECOM_LOG_CYCLE_SIZE 4"
        tf.puts "TLM_LOG_CYCLE_TIME 5"
        tf.puts "TLM_LOG_CYCLE_SIZE 6"
        tf.puts "TLM_DECOM_LOG_CYCLE_TIME 7"
        tf.puts "TLM_DECOM_LOG_CYCLE_SIZE 8"
        tf.close
        parser.parse_file(tf.path) do |keyword, params|
          model.handle_config(parser, keyword, params)
        end
        json = model.as_json(:allow_nan => true)
        expect(json['cmd_log_cycle_time']).to eql 1
        expect(json['cmd_log_cycle_size']).to eql 2
        expect(json['cmd_decom_log_cycle_time']).to eql 3
        expect(json['cmd_decom_log_cycle_size']).to eql 4
        expect(json['tlm_log_cycle_time']).to eql 5
        expect(json['tlm_log_cycle_size']).to eql 6
        expect(json['tlm_decom_log_cycle_time']).to eql 7
        expect(json['tlm_decom_log_cycle_size']).to eql 8
        tf.unlink
      end
    end

    describe "deploy" do
      before(:each) do
        @scope = "DEFAULT"
        @target = "INST"
        @s3 = instance_double("Aws::S3::Client") # .as_null_object
        allow(@s3).to receive(:put_object)
        allow(Aws::S3::Client).to receive(:new).and_return(@s3)
        @target_dir = File.join(SPEC_DIR, "install", "config")
      end

      it "raises if the target can't be found" do
        @target_dir = Dir.pwd
        variables = { "test" => "example" }
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: 'PLUGIN')
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
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: 'PLUGIN')
        model.create
        model.deploy(@target_dir, {})
      end

      it "creates target_id.txt as a hash" do
        file = "DEFAULT/targets/INST/target_id.txt"
        expect(@s3).to receive(:put_object).with(bucket: 'config', key: file, body: anything)
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: 'PLUGIN')
        model.create
        model.deploy(@target_dir, {})
      end

      it "archives the target to S3" do
        file = "DEFAULT/target_archives/INST/INST_current.zip"
        expect(@s3).to receive(:put_object).with(bucket: 'config', key: file, body: anything)
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: 'PLUGIN')
        model.create
        model.deploy(@target_dir, {})
      end

      it "puts the packets in Redis" do
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: 'PLUGIN')
        model.create
        model.deploy(@target_dir, {})
        expect(Store.hkeys("DEFAULT__openc3tlm__INST")).to include("HEALTH_STATUS", "ADCS", "PARAMS", "IMAGE", "MECH")
        expect(Store.hkeys("DEFAULT__openc3cmd__INST")).to include("ABORT", "COLLECT", "CLEAR") # ... etc

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
        expect(umodel).to receive(:create).exactly(6).times
        expect(umodel).to receive(:deploy).with(@target_dir, variables).exactly(6).times
        # Verify the microservices that are started
        expect(MicroserviceModel).to receive(:new).with(hash_including(
          name: "#{@scope}__COMMANDLOG__#{@target}",
          plugin: 'PLUGIN'
          )).and_return(umodel)
        expect(MicroserviceModel).to receive(:new).with(hash_including(
                                                          name: "#{@scope}__DECOMCMDLOG__#{@target}",
                                                          plugin: 'PLUGIN',
                                                          scope: @scope
                                                        )).and_return(umodel)
        expect(MicroserviceModel).to receive(:new).with(hash_including(
                                                          name: "#{@scope}__PACKETLOG__#{@target}",
                                                          plugin: 'PLUGIN',
                                                          scope: @scope
                                                        )).and_return(umodel)
        expect(MicroserviceModel).to receive(:new).with(hash_including(
                                                          name: "#{@scope}__DECOMLOG__#{@target}",
                                                          plugin: 'PLUGIN',
                                                          scope: @scope
                                                        )).and_return(umodel)
        expect(MicroserviceModel).to receive(:new).with(hash_including(
                                                          name: "#{@scope}__DECOM__#{@target}",
                                                          plugin: 'PLUGIN',
                                                          scope: @scope
                                                        )).and_return(umodel)
        expect(MicroserviceModel).to receive(:new).with(hash_including(
                                                          name: "#{@scope}__REDUCER__#{@target}",
                                                          plugin: 'PLUGIN',
                                                          scope: @scope
                                                        )).and_return(umodel)
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: 'PLUGIN')
        model.create
        output = ''
        capture_io do |stdout|
          model.deploy(@target_dir, variables)
          expect(stdout.string).to include("#{@scope}__COMMANDLOG__#{@target}")
          expect(stdout.string).to include("#{@scope}__DECOMCMDLOG__#{@target}")
          expect(stdout.string).to include("#{@scope}__PACKETLOG__#{@target}")
          expect(stdout.string).to include("#{@scope}__DECOMLOG__#{@target}")
          expect(stdout.string).to include("#{@scope}__DECOM__#{@target}")
          expect(stdout.string).to include("#{@scope}__REDUCER__#{@target}")
        end
      end

      it "deploys no microservices if no commands or telemetry" do
        @target = "EMPTY"
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: 'PLUGIN')
        model.create
        capture_io do |stdout|
          model.deploy(@target_dir, {})
          expect(stdout.string).to_not include("#{@scope}__COMMANDLOG__#{@target}")
          expect(stdout.string).to_not include("#{@scope}__DECOMCMDLOG__#{@target}")
          expect(stdout.string).to_not include("#{@scope}__PACKETLOG__#{@target}")
          expect(stdout.string).to_not include("#{@scope}__DECOMLOG__#{@target}")
          expect(stdout.string).to_not include("#{@scope}__DECOM__#{@target}")
          expect(stdout.string).to_not include("#{@scope}__REDUCER__#{@target}")
        end
        expect(MicroserviceModel.names()).to be_empty
      end

      it "deploys only command microservices if no telemetry" do
        @target = "EMPTY"
        FileUtils.mkdir_p("#{@target_dir}/targets/#{@target}/cmd_tlm")
        File.open("#{@target_dir}/targets/#{@target}/cmd_tlm/cmd.txt", 'w') do |file|
          file.puts 'COMMAND INST CMD LITTLE_ENDIAN "Command"'
          file.puts '  APPEND_ID_PARAMETER ID 8 UINT 1 1 1 "ID"'
        end
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: 'PLUGIN')
        model.create
        capture_io do |stdout|
          model.deploy(@target_dir, {})
          expect(stdout.string).to include("#{@scope}__COMMANDLOG__#{@target}")
          expect(stdout.string).to include("#{@scope}__DECOMCMDLOG__#{@target}")
          expect(stdout.string).to_not include("#{@scope}__PACKETLOG__#{@target}")
          expect(stdout.string).to_not include("#{@scope}__DECOMLOG__#{@target}")
          expect(stdout.string).to_not include("#{@scope}__DECOM__#{@target}")
          expect(stdout.string).to_not include("#{@scope}__REDUCER__#{@target}")
        end
        expect(MicroserviceModel.names()).to include(
          "#{@scope}__COMMANDLOG__#{@target}",
          "#{@scope}__DECOMCMDLOG__#{@target}")
        FileUtils.rm_rf("#{@target_dir}/targets/#{@target}/cmd_tlm")
      end

      it "deploys only telemetry microservices if no commands" do
        @target = "EMPTY"
        FileUtils.mkdir_p("#{@target_dir}/targets/#{@target}/cmd_tlm")
        File.open("#{@target_dir}/targets/#{@target}/cmd_tlm/tlm.txt", 'w') do |file|
          file.puts 'TELEMETRY INST TLM LITTLE_ENDIAN "Telemetry"'
          file.puts '  APPEND_ID_ITEM ID 8 UINT 1 "ID"'
        end
        model = TargetModel.new(folder_name: @target, name: @target, scope: @scope, plugin: 'PLUGIN')
        model.create
        capture_io do |stdout|
          model.deploy(@target_dir, {})
          expect(stdout.string).to_not include("#{@scope}__COMMANDLOG__#{@target}")
          expect(stdout.string).to_not include("#{@scope}__DECOMCMDLOG__#{@target}")
          expect(stdout.string).to include("#{@scope}__PACKETLOG__#{@target}")
          expect(stdout.string).to include("#{@scope}__DECOMLOG__#{@target}")
          expect(stdout.string).to include("#{@scope}__DECOM__#{@target}")
          expect(stdout.string).to include("#{@scope}__REDUCER__#{@target}")
        end
        expect(MicroserviceModel.names()).to include(
          "#{@scope}__PACKETLOG__#{@target}",
          "#{@scope}__DECOMLOG__#{@target}",
          "#{@scope}__DECOM__#{@target}",
          "#{@scope}__REDUCER__#{@target}")
        FileUtils.rm_rf("#{@target_dir}/targets/#{@target}/cmd_tlm")
      end
    end

    describe "destroy" do
      before(:each) do
        @s3 = instance_double("Aws::S3::Client")
        allow(@s3).to receive(:put_object)
        objs = double("Object", :contents => [])
        allow(@s3).to receive(:list_objects).and_return(objs)
        allow(Aws::S3::Client).to receive(:new).and_return(@s3)
        @target_dir = File.join(SPEC_DIR, "install", "config")
        ConfigTopic.initialize_stream("DEFAULT")
      end

      it "destroys any deployed Target microservices" do
        orig_keys = get_all_redis_keys()
        # Add in the keys that remain when a target is destroyed
        orig_keys << "DEFAULT__openc3cmd__UNKNOWN"
        orig_keys << "DEFAULT__openc3tlm__UNKNOWN"
        orig_keys << "DEFAULT__limits_sets"
        orig_keys << "DEFAULT__tlm__UNKNOWN"
        orig_keys << "openc3_microservices"

        umodel = double(MicroserviceModel)
        expect(umodel).to receive(:destroy).exactly(14).times
        expect(MicroserviceModel).to receive(:get_model).and_return(umodel).exactly(14).times
        inst_model = TargetModel.new(folder_name: "INST", name: "INST", scope: "DEFAULT", plugin: "INST_PLUGIN")
        inst_model.create
        inst_model.deploy(@target_dir, {})

        config = ConfigTopic.read(scope: 'DEFAULT')
        expect(config[0][1]['kind']).to eql 'created'
        expect(config[0][1]['type']).to eql 'target'
        expect(config[0][1]['name']).to eql 'INST'
        expect(config[0][1]['plugin']).to eql 'INST_PLUGIN'

        sys_model = TargetModel.new(folder_name: "SYSTEM", name: "SYSTEM", scope: "DEFAULT", plugin: "SYSTEM_PLUGIN")
        sys_model.create
        sys_model.deploy(@target_dir, {})

        config = ConfigTopic.read(scope: 'DEFAULT')
        expect(config[0][1]['kind']).to eql 'created'
        expect(config[0][1]['type']).to eql 'target'
        expect(config[0][1]['name']).to eql 'SYSTEM'
        expect(config[0][1]['plugin']).to eql 'SYSTEM_PLUGIN'

        keys = get_all_redis_keys()
        # Spot check some keys
        expect(keys).to include("DEFAULT__COMMAND__{INST}__ABORT")
        expect(keys).to include("DEFAULT__COMMAND__{INST}__COLLECT")
        expect(keys).to include("DEFAULT__TELEMETRY__{INST}__ADCS")
        expect(keys).to include("DEFAULT__TELEMETRY__{INST}__HEALTH_STATUS")
        expect(keys).to include("DEFAULT__openc3cmd__INST")
        expect(keys).to include("DEFAULT__openc3tlm__INST")
        targets = Store.hgetall("DEFAULT__openc3_targets")
        expect(targets.keys).to include("INST")

        inst_model.destroy
        config = ConfigTopic.read(scope: 'DEFAULT')
        expect(config[0][1]['kind']).to eql 'deleted'
        expect(config[0][1]['type']).to eql 'target'
        expect(config[0][1]['name']).to eql 'INST'
        expect(config[0][1]['plugin']).to eql 'INST_PLUGIN'

        sys_model.destroy
        config = ConfigTopic.read(scope: 'DEFAULT')
        expect(config[0][1]['kind']).to eql 'deleted'
        expect(config[0][1]['type']).to eql 'target'
        expect(config[0][1]['name']).to eql 'SYSTEM'
        expect(config[0][1]['plugin']).to eql 'SYSTEM_PLUGIN'

        targets = Store.hgetall("DEFAULT__openc3_targets")
        expect(targets.keys).to_not include("INST")
        keys = get_all_redis_keys()
        expect(orig_keys.sort).to eql keys.sort
      end
    end
  end
end
