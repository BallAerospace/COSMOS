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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos/api/interface_api'
require 'cosmos/script/extract'
require 'cosmos/interfaces/interface'
require 'cosmos/utilities/authorization'
require 'cosmos/microservices/router_microservice'

module Cosmos
  describe RouterMicroservice do
    class ApiTest
      include Extract
      include Api
      include Authorization
    end

    class TestInterface < Interface
      def initialize
        super
        @connected = false
      end

      def read_allowed?
        raise 'test-error' if $read_allowed_raise

        super
      end

      def connect
        super
        @data = "\x00"
        @connected = true
        raise 'test-error' if $connect_raise
      end

      def connected?
        @connected
      end

      def disconnect
        $disconnect_count += 1
        @data = nil # Upon disconnect the read_interface should return nil
        sleep $disconnect_delay
        @connected = false
        super
      end

      def read_interface
        raise 'test-error' if $read_interface_raise

        sleep 0.1
        @data
      end
    end

    before(:each) do
      mock_redis()
      setup_system()

      allow(System).to receive(:setup_targets).and_return(nil)
      interface = double("Interface").as_null_object
      allow(interface).to receive(:connected?).and_return(true)
      allow(System).to receive(:targets).and_return({ "TEST" => interface })
      allow(System).to receive_message_chain("telemetry.packets") { [["PKT", Packet.new("TEST", "PKT")]] }
      model = RouterModel.new(name: "TEST_INT", scope: "DEFAULT", target_names: ["TEST"], config_params: ["TestInterface"])
      model.create
      model = MicroserviceModel.new(folder_name: "TEST", name: "DEFAULT__ROUTER__TEST_INT", scope: "DEFAULT", target_names: ["TEST"])
      model.create

      @api = ApiTest.new

      $connect_raise = false
      $read_allowed_raise = false
      $read_interface_raise = false
      $disconnect_delay = 0
      $disconnect_count = 0
    end

    describe "initialize" do
      it "creates an interface, updates status, and starts cmd thread" do
        init_threads = Thread.list.count
        uservice = RouterMicroservice.new("DEFAULT__ROUTER__TEST_INT")
        config = uservice.instance_variable_get(:@config)
        expect(config['name']).to eql "DEFAULT__ROUTER__TEST_INT"
        interface = uservice.instance_variable_get(:@interface)
        expect(interface.name).to eql "TEST_INT"
        expect(interface.state).to eql "ATTEMPTING"
        expect(interface.target_names).to eql ["TEST"]
        all = RouterStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["name"]).to eql "TEST_INT"
        expect(all["TEST_INT"]["state"]).to eql "ATTEMPTING"
        # Each router microservice starts 2 threads: microservice_status_thread in microservice.rb
        # and the RouterCmdHandlerThread in interface_microservice.rb
        expect(Thread.list.count - init_threads).to eql 2

        uservice.shutdown
        sleep 0.1 # Allow threads to exit
        expect(Thread.list.count).to eql init_threads
      end
    end

    describe "run" do
      xit "connects and disconnects" do
        capture_io do |stdout|
          uservice = RouterMicroservice.new("DEFAULT__ROUTER__TEST_INT")
          all = RouterStatusModel.all(scope: "DEFAULT")
          expect(all["TEST_INT"]["state"]).to eql "ATTEMPTING"
          interface = uservice.instance_variable_get(:@interface)
          interface.reconnect_delay = 0.1 # Override the reconnect delay to be quick

          uservice_thread = Thread.new { uservice.run }
          sleep 0.1
          expect(stdout.string).to include("Connecting ...")
          expect(stdout.string).to include("Connection Success")
          all = RouterStatusModel.all(scope: "DEFAULT")
          expect(all["TEST_INT"]["state"]).to eql "CONNECTED"

          @api.disconnect_router("TEST_INT")
          sleep 0.3 # Allow disconnect
          all = RouterStatusModel.all(scope: "DEFAULT")
          expect(all["TEST_INT"]["state"]).to eql "DISCONNECTED"
          expect(stdout.string).to include("Disconnect requested")
          expect(stdout.string).to include("Clean disconnect")
          expect(stdout.string).to include("Connection Lost")

          uservice.shutdown
        end
        sleep 0.1 # Allow threads to exit
      end
    end
  end
end
