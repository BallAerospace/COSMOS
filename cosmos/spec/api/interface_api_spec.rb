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
require 'cosmos/api/interface_api'
require 'cosmos/script/extract'
require 'cosmos/utilities/authorization'
require 'cosmos/microservices/interface_microservice'

module Cosmos
  describe Api do
    class ApiTest
      include Extract
      include Api
      include Authorization
    end

    before(:each) do
      mock_redis()
      setup_system()

      model = InterfaceModel.new(name: "INST_INT", scope: "DEFAULT", target_names: ["INST"], config_params: ["interface.rb"])
      model.create

      # Mock out some stuff in Microservice initialize()
      dbl = double("AwsS3Client").as_null_object
      allow(Aws::S3::Client).to receive(:new).and_return(dbl)
      allow(Zip::File).to receive(:open).and_return(true)
      allow_any_instance_of(Cosmos::Interface).to receive(:connected?).and_return(true)
      @im_shutdown = false
      allow_any_instance_of(Cosmos::Interface).to receive(:read_interface) { sleep(0.01) until @im_shutdown }

      model = MicroserviceModel.new(name: "DEFAULT__INTERFACE__INST_INT", scope: "DEFAULT", target_names: ["INST"])
      model.create
      @im = InterfaceMicroservice.new("DEFAULT__INTERFACE__INST_INT")
      @im_thread = Thread.new { @im.run }
      sleep(1) # Allow the thread to run

      @api = ApiTest.new
    end

    after(:each) do
      @im_shutdown = true
      @im.shutdown
      sleep(0.1)
    end

    describe "get_interface" do
      it "returns interface hash" do
        interface = @api.get_interface("INST_INT")
        expect(interface).to be_a Hash
        expect(interface['name']).to eql "INST_INT"
        expect(interface['log']).to be true
        # Verify it also includes the status
        expect(interface['state']).to eql "CONNECTED"
        expect(interface['clients']).to eql 0
      end
    end

    describe "get_interface_names" do
      it "returns all interface names" do
        model = InterfaceModel.new(name: "INT1", scope: "DEFAULT")
        model.create
        model = InterfaceModel.new(name: "INT2", scope: "DEFAULT")
        model.create
        expect(@api.get_interface_names).to eql ["INST_INT", "INT1", "INT2"]
      end
    end

    describe "connect_interface, disconnect_interface" do
      it "connects the interface" do
        expect(@api.get_interface("INST_INT")['state']).to eql "CONNECTED"
        @api.disconnect_interface("INST_INT")
        sleep(0.1)
        expect(@api.get_interface("INST_INT")['state']).to eql "DISCONNECTED"
        @api.connect_interface("INST_INT")
        sleep(0.1)
        expect(@api.get_interface("INST_INT")['state']).to eql "ATTEMPTING"
      end
    end

    describe "start_raw_logging_interface" do
      it "should start raw logging on the interface" do
        expect_any_instance_of(Cosmos::Interface).to receive(:start_raw_logging)
        @api.start_raw_logging_interface("INST_INT")
        sleep(0.1)
      end

      it "should start raw logging on all interfaces" do
        expect_any_instance_of(Cosmos::Interface).to receive(:start_raw_logging)
        @api.start_raw_logging_interface("ALL")
        sleep(0.1)
      end
    end

    describe "stop_raw_logging_interface" do
      it "should stop raw logging on the interface" do
        expect_any_instance_of(Cosmos::Interface).to receive(:stop_raw_logging)
        @api.stop_raw_logging_interface("INST_INT")
        sleep(0.1)
      end

      it "should stop raw logging on all interfaces" do
        expect_any_instance_of(Cosmos::Interface).to receive(:stop_raw_logging)
        @api.stop_raw_logging_interface("ALL")
        sleep(0.1)
      end
    end

    describe "get_all_interface_info" do
      it "gets interface name and all info" do
        info = @api.get_all_interface_info.sort
        expect(info[0][0]).to eq "INST_INT"
      end
    end
  end
end
