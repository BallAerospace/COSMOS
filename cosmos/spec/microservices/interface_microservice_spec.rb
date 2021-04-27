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
require 'cosmos/interfaces/interface'
require 'cosmos/utilities/authorization'
require 'cosmos/microservices/interface_microservice'

module Cosmos
  describe InterfaceMicroservice do
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
      allow(System).to receive(:targets).and_return({"TEST" => interface})

      # TODO: Adding target_names: ["TEST"] as a parameter duplicates the target_names in the interface
      model = InterfaceModel.new(name: "TEST_INT", scope: "DEFAULT", config_params: ["TestInterface"])
      model.create
      model = MicroserviceModel.new(folder_name: "TEST", name: "DEFAULT__INTERFACE__TEST_INT", scope: "DEFAULT", target_names: ["TEST"])
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
        im = InterfaceMicroservice.new("DEFAULT__INTERFACE__TEST_INT")
        config = im.instance_variable_get(:@config)
        expect(config['name']).to eql "DEFAULT__INTERFACE__TEST_INT"
        interface = im.instance_variable_get(:@interface)
        expect(interface.name).to eql "TEST_INT"
        expect(interface.state).to eql "ATTEMPTING"
        expect(interface.target_names).to eql ["TEST"]
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["name"]).to eql "TEST_INT"
        expect(all["TEST_INT"]["state"]).to eql "ATTEMPTING"
        # Each interface microservice starts 2 threads: microservice_status_thread in microservice.rb
        # and the InterfaceCmdHandlerThread in interface_microservice.rb
        expect(Thread.list.count - init_threads).to eql 2

        im.shutdown
        sleep 0.1 # Allow threads to exit
        expect(Thread.list.count).to eql init_threads
      end
    end

    describe "run" do
      it "handles exceptions in connect" do
        $connect_raise = true
        capture_io do |stdout|
          im = InterfaceMicroservice.new("DEFAULT__INTERFACE__TEST_INT")
          all = InterfaceStatusModel.all(scope: "DEFAULT")
          expect(all["TEST_INT"]["state"]).to eql "ATTEMPTING"
          interface = im.instance_variable_get(:@interface)
          interface.reconnect_delay = 0.1 # Override the reconnect delay to be quick

          im_thread = Thread.new { im.run }
          sleep 0.1
          expect(stdout.string).to include("Connecting ...")
          expect(stdout.string).to_not include("Connection Success")
          expect(stdout.string).to include("Connection Failed: RuntimeError : test-error")
          all = InterfaceStatusModel.all(scope: "DEFAULT")
          expect(all["TEST_INT"]["state"]).to eql "ATTEMPTING"

          $connect_raise = false
          sleep 0.5 # Allow it to reconnect successfully
          expect(stdout.string).to include("Connection Success")
          all = InterfaceStatusModel.all(scope: "DEFAULT")
          expect(all["TEST_INT"]["state"]).to eql "CONNECTED"

          im.shutdown
          im_thread.kill
        end
        sleep 0.1 # Allow threads to exit
      end

      it "handles exceptions while reading" do
        i = 0
        allow(System).to receive_message_chain("telemetry.identify!") do
          i += 1
          raise 'test-error' if i == 1
          nil
        end
        allow(System).to receive_message_chain("telemetry.update!") { Packet.new("TGT", "PKT") }

        $read_interface_raise = true
        capture_io do |stdout|
          im = InterfaceMicroservice.new("DEFAULT__INTERFACE__TEST_INT")
          all = InterfaceStatusModel.all(scope: "DEFAULT")
          expect(all["TEST_INT"]["state"]).to eql "ATTEMPTING"
          interface = im.instance_variable_get(:@interface)
          interface.reconnect_delay = 0.3 # Override the reconnect delay to be quick

          im_thread = Thread.new { im.run }
          sleep 0.25
          expect(stdout.string).to include("Connecting ...")
          expect(stdout.string).to include("Connection Success")
          expect(stdout.string).to include("Connection Lost: RuntimeError : test-error")
          all = InterfaceStatusModel.all(scope: "DEFAULT")
          expect(all["TEST_INT"]["state"]).to eql "ATTEMPTING"
          expect($disconnect_count).to eql 1
          stdout.truncate(0) # Erase the previous connection strings so we can verify the reconnect

          $read_interface_raise = false
          sleep 0.3 # Allow to reconnect
          expect(stdout.string).to include("Connecting ...")
          expect(stdout.string).to include("Connection Success")
          all = InterfaceStatusModel.all(scope: "DEFAULT")
          expect(all["TEST_INT"]["state"]).to eql "CONNECTED"

          im.shutdown
          im_thread.kill
        end
        sleep 0.1 # Allow threads to exit
      end
    end

    it "handles exceptions in monitor thread" do
      $read_allowed_raise = true
      capture_io do |stdout|
        im = InterfaceMicroservice.new("DEFAULT__INTERFACE__TEST_INT")
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "ATTEMPTING"
        interface = im.instance_variable_get(:@interface)
        interface.reconnect_delay = 0.1 # Override the reconnect delay to be quick

        im_thread = Thread.new { im.run }
        sleep 0.01 # Allow to start and immediately crash
        expect(stdout.string).to include("Fatal Exception!")
        copy = stdout.string.dup

        sleep 0.3 # Give it time but it shouldn't connect
        expect(stdout.string).to eql copy
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "DISCONNECTED"
        expect(im_thread.alive?).to be false

        im.shutdown
      end
      sleep 0.1 # Allow threads to exit
    end

    it "handles a clean disconnect" do
      capture_io do |stdout|
        im = InterfaceMicroservice.new("DEFAULT__INTERFACE__TEST_INT")
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "ATTEMPTING"
        interface = im.instance_variable_get(:@interface)
        interface.reconnect_delay = 0.1 # Override the reconnect delay to be quick

        im_thread = Thread.new { im.run }
        sleep 0.1 # Allow to start
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "CONNECTED"
        expect(stdout.string).to include("Connecting ...")
        expect(stdout.string).to include("Connection Success")

        @api.disconnect_interface("TEST_INT")
        sleep 0.2 # Allow disconnect
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "DISCONNECTED"
        expect(stdout.string).to include("Disconnect requested")
        expect(stdout.string).to include("Clean disconnect")
        expect(stdout.string).to include("Connection Lost")

        # Wait and verify still DISCONNECTED and not ATTEMPTING
        sleep 0.2
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "DISCONNECTED"
        expect($disconnect_count).to eql 1

        im.shutdown
        im_thread.kill
      end
      sleep 0.1 # Allow threads to exit
    end

    it "handles long disconnect delays" do
      capture_io do |stdout|
        im = InterfaceMicroservice.new("DEFAULT__INTERFACE__TEST_INT")
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "ATTEMPTING"
        interface = im.instance_variable_get(:@interface)
        interface.reconnect_delay = 0.1 # Override the reconnect delay to be quick

        im_thread = Thread.new { im.run }
        sleep 0.01 # Allow to start
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "CONNECTED"
        expect(stdout.string).to include("Connecting ...")
        expect(stdout.string).to include("Connection Success")

        $disconnect_delay = 0.5
        @api.disconnect_interface("TEST_INT")
        sleep 0.7 # Allow disconnect
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "DISCONNECTED"
        expect(stdout.string).to include("Disconnect requested")
        expect(stdout.string).to include("Clean disconnect")
        expect(stdout.string).to include("Connection Lost")

        # Wait and verify still DISCONNECTED and not ATTEMPTING
        sleep 0.5
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "DISCONNECTED"
        expect($disconnect_count).to eql 1

        im.shutdown
        im_thread.kill
      end
      sleep 0.1 # Allow threads to exit
    end

    it "handles a interface that doesn't allow reads" do
      capture_io do |stdout|
        im = InterfaceMicroservice.new("DEFAULT__INTERFACE__TEST_INT")
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "ATTEMPTING"
        interface = im.instance_variable_get(:@interface)
        interface.instance_variable_set(:@read_allowed, false)

        # Shouldn't cause error because read_interface shouldn't be called
        $read_interface_raise = true
        im_thread = Thread.new { im.run }
        sleep 0.1 # Allow to start
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "CONNECTED"
        expect(stdout.string).to include("Connecting ...")
        expect(stdout.string).to include("Connection Success")
        expect(stdout.string).to include("Starting connection maintenance")

        @api.disconnect_interface("TEST_INT")
        sleep 1.1 # Allow disconnect and wait for @interface_thread_sleeper.sleep(1)
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "DISCONNECTED"
        expect(stdout.string).to include("Disconnect requested")
        expect(stdout.string).to include("Connection Lost")

        # Wait and verify still DISCONNECTED and not ATTEMPTING
        sleep 0.2
        all = InterfaceStatusModel.all(scope: "DEFAULT")
        expect(all["TEST_INT"]["state"]).to eql "DISCONNECTED"
        expect($disconnect_count).to eql 1

        im.shutdown
        im_thread.kill
      end
      sleep 0.1 # Allow threads to exit
    end
  end
end
