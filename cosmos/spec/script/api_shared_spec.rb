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
require 'cosmos'
require 'cosmos/script'
require 'cosmos/api/api'
require 'cosmos/models/target_model'
require 'cosmos/microservices/interface_microservice'
require 'cosmos/script/extract'
require 'cosmos/utilities/authorization'

module Cosmos
  describe Script do
    class ApiTest
      include Extract
      include Api
      include Authorization
      def shutdown
      end

      def disconnect
      end

      def generate_url
        return "http://localhost:2900"
      end

      def method_missing(name, *params, **kw_params)
        self.send(name, *params, **kw_params)
      end
    end

    before(:each) do
      mock_redis()
      setup_system()

      @api = ApiTest.new
      # Mock the server proxy to directly call the api
      allow(ServerProxy).to receive(:new).and_return(@api)
      allow(CvtModel).to receive(:get_item) do |*args, **kwargs|
        if args[2] == "TEMP1"
          case kwargs[:type]
          when :RAW
            1
          when :CONVERTED
            10
          when :FORMATTED
            "10.000"
          when :WITH_UNITS
            "10.000 C"
          end
        elsif args[2] == "TEMP2"
          case kwargs[:type]
          when :RAW
            1.5
          when :CONVERTED
            10.5
          end
        end
      end

      model = TargetModel.new(folder_name: 'INST', name: 'INST', scope: "DEFAULT")
      model.create
      model.update_store(System.new(['INST'], File.join(SPEC_DIR, 'install', 'config', 'targets')))
      # model = InterfaceModel.new(name: "INST_INT", scope: "DEFAULT", target_names: ["INST"], config_params: ["interface.rb"])
      # model.create
      # model = InterfaceStatusModel.new(name: "INST_INT", scope: "DEFAULT", state: "ACTIVE")
      # model.create

      # Create an Interface we can use in the InterfaceCmdHandlerThread
      # It has to have a valid list of target_names as that is what 'receive_commands'
      # in the Store uses to determine which topics to read
      # interface = Interface.new
      # interface.name = "INST_INT"
      # interface.target_names = %w[INST]
      # # Stub to make the InterfaceCmdHandlerThread happy
      # @interface_data = ''
      # allow(interface).to receive(:connected?).and_return(true)
      # allow(interface).to receive(:write_interface) { |data| @interface_data = data }
      # @thread = InterfaceCmdHandlerThread.new(interface, nil, scope: 'DEFAULT')
      # @process = true # Allow the command to be processed or not
      # @int_thread = Thread.new { @thread.run }
      # sleep 0.01 # Allow thread to start

      # allow(redis).to receive(:xread).and_wrap_original do |m, *args|
      #   # Only use the first two arguments as the last argument is keyword block:
      #   result = m.call(*args[0..1]) if @process
      #   # Create a slight delay to simulate the blocking call
      #   sleep 0.001 if result and result.length == 0
      #   result
      # end
      initialize_script()
    end

    after(:each) do
      shutdown_script()
    end

    describe "check" do
      it "checks a telemetry item against a value" do
        capture_io do |stdout|
          check("INST", "HEALTH_STATUS", "TEMP1", "> 1")
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS TEMP1 > 1 success with value == 10/)
          check("INST HEALTH_STATUS TEMP1 == 1", type: :RAW)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS TEMP1 == 1 success with value == 1/)
        end
        expect { check("INST HEALTH_STATUS TEMP1 > 100") }.to raise_error(/CHECK: INST HEALTH_STATUS TEMP1 > 100 failed with value == 10/)
      end
    end

    describe "check_raw, check_formatted, check_with_units" do
      it "checks against the specified type" do
        capture_io do |stdout|
          check_raw("INST HEALTH_STATUS TEMP1 == 1")
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS TEMP1 == 1 success/)
          check_formatted("INST HEALTH_STATUS TEMP1 == '10.000'")
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS TEMP1 == '10.000' success/)
          check_with_units("INST HEALTH_STATUS TEMP1 == '10.000 C'")
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS TEMP1 == '10.000 C' success/)
        end
      end
    end

    describe "check_exception" do
      it "checks that the exception is raised in our apis" do
        capture_io do |stdout|
          check_exception("check", "INST HEALTH_STATUS TEMP1 == 9", type: :RAW, scope: "DEFAULT")
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS TEMP1 == 9 failed/)
          check_exception("check", "INST HEALTH_STATUS TEMP1 == 9", type: :RAW, scope: "OTHER")
          expect(stdout.string).to match(/Packet 'INST HEALTH_STATUS' does not exist/)
        end
      end

      it "raises if the exception is not raised" do
        expect { check_exception("tlm", "INST HEALTH_STATUS TEMP1") }.to raise_error(/tlm\(INST HEALTH_STATUS TEMP1\) should have raised an exception/)
      end

      # it "checks that the exception is raised in other methods" do
      #   def raise1 # no args
      #     raise "error"
      #   end
      #   def raise2(param) # regular args
      #     puts "p:#{param}"
      #     raise "error"
      #   end
      #   def raise3(param, named:) # args plus kwargs
      #     puts "p:#{param} named:#{named}"
      #     raise "error"
      #   end

      #   capture_io do |stdout|
      #     check_exception("raise1")
      #     expect(stdout.string).to match(/CHECK: raise1\(\) raised RuntimeError:error/)
      #     check_exception("raise2", 10)
      #     expect(stdout.string).to match(/CHECK: raise2\(10\) raised RuntimeError:error/)
      #     check_exception("raise3", 10, { named: 20 })
      #     expect(stdout.string).to match(/CHECK: raise3\(10, { named: 20 }\) raised RuntimeError:error/)
      #   end
      # end
    end

    describe "check_tolerance" do
      it "raises with :FORMATTED or :WITH_UNITS" do
        expect { check_tolerance("INST HEALTH_STATUS TEMP2 == 10.5", 0.1, type: :FORMATTED) }.to raise_error("Invalid type 'FORMATTED' for check_tolerance")
        expect { check_tolerance("INST HEALTH_STATUS TEMP2 == 10.5", 0.1, type: :WITH_UNITS) }.to raise_error("Invalid type 'WITH_UNITS' for check_tolerance")
      end

      it "checks that a value is within a tolerance" do
        capture_io do |stdout|
          check_tolerance("INST", "HEALTH_STATUS", "TEMP2", 1.55, 0.1, type: :RAW)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS TEMP2 was within range 1.45 to 1.65\d+ with value == 1.5/)
          check_tolerance("INST HEALTH_STATUS TEMP2", 10.5, 0.01)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS TEMP2 was within range 10.49 to 10.51 with value == 10.5/)
        end
        expect { check_tolerance("INST HEALTH_STATUS TEMP2", 11, 0.1) }.to raise_error(/CHECK: INST HEALTH_STATUS TEMP2 failed to be within range 10.9 to 11.1 with value == 10.5/)
      end
    end

    describe "check_tolerance_raw" do
      it "checks that a value is within a tolerance" do
        capture_io do |stdout|
          check_tolerance_raw("INST HEALTH_STATUS TEMP2", 1.55, 0.1)
          expect(stdout.string).to match(/CHECK: INST HEALTH_STATUS TEMP2 was within range 1.45 to 1.65\d+ with value == 1.5/)
        end
      end
    end

    describe "check_expression" do
      it "checks that an expression is true" do
        capture_io do |stdout|
          check_expression("true == true")
          expect(stdout.string).to match(/CHECK: true == true is TRUE/)
        end
        expect { check_expression("true == false") }.to raise_error(/CHECK: true == false is FALSE/)
      end
    end
  end
end
