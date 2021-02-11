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
      allow_any_instance_of(Cosmos::Interface).to receive(:read_interface) { sleep }

      model = MicroserviceModel.new(name: "DEFAULT__INTERFACE__INST_INT", scope: "DEFAULT", target_names: ["INST"])
      model.create
      @im = InterfaceMicroservice.new("DEFAULT__INTERFACE__INST_INT")
      @im_thread = Thread.new { @im.run }
      sleep(0.01) # Allow the thread to run

      @api = ApiTest.new
    end

    after(:each) do
      @im.shutdown
      sleep(0.01)
      Thread.list.each do |t|
        if t != Thread.current
          t.kill
        end
      end
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

    describe "connect_interface, disconnect_interface, interface_state" do
      it "connects the interface" do
        interface = @api.get_interface("INST_INT")
        expect(interface['state']).to eql "CONNECTED"
        expect(@api.interface_state("INST_INT")).to eql "CONNECTED"
        @api.disconnect_interface("INST_INT")
        sleep(0.1)
        expect(@api.interface_state("INST_INT")).to eql "DISCONNECTED"
        @api.connect_interface("INST_INT")
        sleep(0.1)
        expect(@api.interface_state("INST_INT")).to eql "ATTEMPTING"
      end
    end

    describe "get_interface_targets" do
      it "raises for a non-existant interface" do
        expect { @api.get_interface_targets("BLAH") }.to raise_error("Interface 'BLAH' does not exist")
      end

      it "returns the targets associated with an interface" do
        # Preload a fake InterfaceStatusModel so the api succeeds ...
        # this automatically happens when you create a new InterfaceMicroservice
        InterfaceStatusModel.set({ 'name' => "TEST_INT", 'state' => "DISCONNECTED" }, scope: "DEFAULT")
        model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT", target_names: ["TGT1", "TGT2"])
        model.create
        expect(@api.get_interface_targets("TEST_INT")).to eql ["TGT1", "TGT2"]
      end
    end

    describe "get_interface_info" do
      it "complains about non-existant interfaces" do
        expect { @api.get_interface_info("BLAH") }.to raise_error(RuntimeError, "Interface 'BLAH' does not exist")
      end

      it "gets interface info" do
        info = @api.get_interface_info("INST_INT")
        expect(info[0]).to eq "CONNECTED"
        expect(info[1..-1]).to eq [0,0,0,0,0,0,0]
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
