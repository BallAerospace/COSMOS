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
      def method_missing(name, *params, **kw_params)
        self.send(name, *params, **kw_params)
      end
    end

    before(:each) do
      capture_io do |stdout|
        redis = mock_redis()
        setup_system()
        @api = ApiTest.new
        # Mock the server proxy to directly call the api
        allow(ServerProxy).to receive(:new).and_return(@api)

        model = TargetModel.new(folder_name: 'INST', name: 'INST', scope: "DEFAULT")
        model.create
        model.update_store(File.join(SPEC_DIR, 'install', 'config', 'targets'))
        model = InterfaceModel.new(name: "INST_INT", scope: "DEFAULT", target_names: ["INST"], config_params: ["interface.rb"])
        model.create
        model = InterfaceStatusModel.new(name: "INST_INT", scope: "DEFAULT", state: "ACTIVE")
        model.create

        # Create an Interface we can use in the InterfaceCmdHandlerThread
        # It has to have a valid list of target_names as that is what 'receive_commands'
        # in the Store uses to determine which topics to read
        interface = Interface.new
        interface.name = "INST_INT"
        interface.target_names = %w[INST]
        # Stub to make the InterfaceCmdHandlerThread happy
        @interface_data = ''
        allow(interface).to receive(:connected?).and_return(true)
        allow(interface).to receive(:write_interface) { |data| @interface_data = data }
        @thread = InterfaceCmdHandlerThread.new(interface, nil, scope: 'DEFAULT')
        @process = true # Allow the command to be processed or not
        @int_thread = Thread.new { @thread.run }
        sleep 0.01 # Allow thread to start

        allow(redis).to receive(:xread).and_wrap_original do |m, *args|
          # Only use the first two arguments as the last argument is keyword block:
          result = m.call(*args[0..1]) if @process
          # Create a slight delay to simulate the blocking call
          sleep 0.001 if result and result.length == 0
          result
        end
        initialize_script()
      end
    end

    after(:each) do
      shutdown_script()
      @int_thread.kill
      count = 0
      while (@int_thread.alive? or count < 100) do
        sleep 0.01
        count += 1
      end
    end

    %w(connected disconnected).each do |connect|
      context "with server #{connect}" do
        before(:each) do
          @prefix = '' # Empty if we're connected
          if connect == 'disconnected'
            disconnect_script()
            expect($api_server).to_not receive(:cmd)
            @prefix = "DISCONNECT: "
          end
        end

        describe "cmd" do
          it "sends a command" do
            capture_io do |stdout|
              cmd("INST ABORT")
              expect(stdout.string).to match(/#{@prefix}cmd\(\\\"INST ABORT\\\"\)/) #"
              stdout.rewind
              cmd("INST", "ABORT")
              expect(stdout.string).to match(/#{@prefix}cmd\(\\\"INST ABORT\\\"\)/) #"
            end
          end

          if connect == 'connected'
            it "checks parameter ranges" do
              expect { cmd("INST COLLECT with TYPE NORMAL, DURATION 20") }.to raise_error(/Command parameter 'INST COLLECT DURATION' = 20 not in valid range/)
            end
          else
            it "does not check parameter ranges" do
              cmd("INST COLLECT with TYPE NORMAL, DURATION 20")
            end
          end

          it "sends with the hash parameter syntax" do
            expect { cmd("INST", "COLLECT", "TYPE" => "NORMAL", "DURATION" => 5) }.to_not raise_error
          end

          it "#{'has no' if connect == 'disconnected'} prompts for a hazardous command" do
            capture_io do |stdout|
              expect(self).to receive(:gets) { 'y' } if connect == 'connected' # Send hazardous command
              cmd("INST COLLECT with TYPE SPECIAL")
              expect(stdout.string).to match(/#{@prefix}cmd\(\\\"INST COLLECT/) #"
              if connect == 'connected'
                expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
                expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring range checks")
                expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring hazardous warnings")
                stdout.rewind

                expect(self).to receive(:gets) { 'n' } # Don't send hazardous
                expect(self).to receive(:gets) { 'y' } # Stop running script
                cmd("INST COLLECT with TYPE SPECIAL")
                expect(stdout.string).to match(/#{@prefix}cmd\(\\\"INST COLLECT/) #"
                expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
              else
                expect(stdout.string).to_not match("Warning")
              end
            end
          end
        end

        describe "cmd_no_range_check" do
          it "sends an out of range command" do
            expect { cmd_no_range_check("INST COLLECT with TYPE NORMAL, DURATION 20") }.to_not raise_error
          end

          it "#{'has no' if connect == 'disconnected'} prompts for a hazardous command" do
            capture_io do |stdout|
              expect(self).to receive(:gets) { 'y' } if connect == 'connected' # Send hazardous command
              cmd_no_range_check("INST COLLECT with TYPE SPECIAL")

              expect(stdout.string).to match(/#{@prefix}cmd\(\\\"INST COLLECT/) #"
              if connect == 'connected'
                expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
                expect(stdout.string).to match("Command INST COLLECT being sent ignoring range checks")
                expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring hazardous warnings")
                stdout.rewind

                expect(self).to receive(:gets) { 'n' } # Don't send hazardous
                expect(self).to receive(:gets) { 'y' } # Stop running script
                cmd_no_range_check("INST COLLECT with TYPE SPECIAL")
                expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
              else
                expect(stdout.string).to_not match("Warning")
              end
            end
          end
        end

        describe "cmd_no_hazardous_check" do
          if connect == 'connected'
            it "checks parameter ranges" do
              expect { cmd_no_hazardous_check("INST COLLECT with TYPE SPECIAL, DURATION 20") }.to raise_error(/Command parameter 'INST COLLECT DURATION' = 20 not in valid range/)
            end
          else
            it "does not check parameter ranges" do
              cmd_no_hazardous_check("INST COLLECT with TYPE SPECIAL, DURATION 20")
            end
          end

          it "sends a hazardous command without prompting" do
            capture_io do |stdout|
              cmd_no_hazardous_check("INST COLLECT with TYPE SPECIAL")

              expect(stdout.string).to match(/#{@prefix}cmd\(\\\"INST COLLECT/) #"
              expect(stdout.string).to_not match("Warning: Command INST COLLECT is Hazardous")
              expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring range checks")
              expect(stdout.string).to match("Command INST COLLECT being sent ignoring hazardous warnings")
            end
          end
        end

        describe "cmd_no_checks" do
          it "sends an out of range hazardous command without prompting" do
            capture_io do |stdout|
              cmd_no_checks("INST COLLECT with TYPE SPECIAL, DURATION 20")

              expect(stdout.string).to match(/#{@prefix}cmd\(\\\"INST COLLECT/) #"
              expect(stdout.string).to_not match("Warning: Command INST COLLECT is Hazardous")
              expect(stdout.string).to match("Command INST COLLECT being sent ignoring range checks")
              expect(stdout.string).to match("Command INST COLLECT being sent ignoring hazardous warnings")
            end
          end
        end

        describe "cmd_raw" do
          it "sends a command" do
            capture_io do |stdout|
              cmd_raw("INST ABORT")
              expect(stdout.string).to match(/#{@prefix}cmd_raw\(\\\"INST ABORT\\\"\)/) #"
            end
          end

          if connect == 'connected'
            it "checks parameter ranges" do
              expect { cmd_raw("INST COLLECT with TYPE 0, DURATION 20") }.to raise_error(/Command parameter 'INST COLLECT DURATION' = 20 not in valid range/)
            end
          else
            it "does not check parameter ranges" do
              cmd_raw("INST COLLECT with TYPE 0, DURATION 20")
            end
          end

          it "#{'has no' if connect == 'disconnected'} prompts for a hazardous command" do
            capture_io do |stdout|
              expect(self).to receive(:gets) { 'y' } if connect == 'connected' # Send hazardous command
              cmd_raw("INST COLLECT with TYPE 1")

              expect(stdout.string).to match(/#{@prefix}cmd_raw\(\\\"INST COLLECT/) #"
              if connect == 'connected'
                expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
                expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring range checks")
                expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring hazardous warnings")
                stdout.rewind
                expect(self).to receive(:gets) { 'n' } # Don't send hazardous
                expect(self).to receive(:gets) { 'y' } # Stop running script
                cmd_raw("INST COLLECT with TYPE 1")
                expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
              else
                expect(stdout.string).to_not match("Warning")
              end
            end
          end
        end

        describe "cmd_raw_no_range_check" do
          it "sends an out of range command" do
            expect { cmd_raw_no_range_check("INST COLLECT with TYPE 0, DURATION 20") }.to_not raise_error
          end

          it "#{'has no' if connect == 'disconnected'} prompts for a hazardous command" do
            capture_io do |stdout|
              expect(self).to receive(:gets) { 'y' } if connect == 'connected' # Send hazardous command
              cmd_raw_no_range_check("INST COLLECT with TYPE 1")

              expect(stdout.string).to match(/#{@prefix}cmd_raw\(\\\"INST COLLECT/) #"
              if connect == 'connected'
                expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
                expect(stdout.string).to match("Command INST COLLECT being sent ignoring range checks")
                expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring hazardous warnings")
                stdout.rewind
                expect(self).to receive(:gets) { 'n' } # Don't send hazardous
                expect(self).to receive(:gets) { 'y' } # Stop running script
                cmd_raw_no_range_check("INST COLLECT with TYPE 1")
                expect(stdout.string).to match("Warning: Command INST COLLECT is Hazardous")
              else
                expect(stdout.string).to_not match("Warning")
              end
            end
          end
        end

        describe "cmd_raw_no_hazardous_check" do
          if connect == 'connected'
            it "checks parameter ranges" do
              expect { cmd_raw_no_hazardous_check("INST COLLECT with TYPE 1, DURATION 20") }.to raise_error(/Command parameter 'INST COLLECT DURATION' = 20 not in valid range/)
            end
          else
            it "does not check parameter ranges" do
              cmd_raw_no_hazardous_check("INST COLLECT with TYPE 1, DURATION 20")
            end
          end

          it "sends a hazardous command without prompting" do
            capture_io do |stdout|
              cmd_raw_no_hazardous_check("INST COLLECT with TYPE 1")
              expect(stdout.string).to match(/#{@prefix}cmd_raw\(\\\"INST COLLECT/) #"
              expect(stdout.string).to_not match("Warning: Command INST COLLECT is Hazardous")
              expect(stdout.string).to_not match("Command INST COLLECT being sent ignoring range checks")
              expect(stdout.string).to match("Command INST COLLECT being sent ignoring hazardous warnings")
            end
          end
        end

        describe "cmd_raw_no_checks" do
          it "sends an out of range hazardous command without prompting" do
            capture_io do |stdout|
              cmd_raw_no_checks("INST COLLECT with TYPE 1, DURATION 20")
              expect(stdout.string).to match(/#{@prefix}cmd_raw\(\\\"INST COLLECT/) #"
              expect(stdout.string).to_not match("Warning: Command INST COLLECT is Hazardous")
              expect(stdout.string).to match("Command INST COLLECT being sent ignoring range checks")
              expect(stdout.string).to match("Command INST COLLECT being sent ignoring hazardous warnings")
            end
          end
        end

        describe "send_raw" do
          it "sends data to the write_raw interface method" do
            send_raw('INST_INT', "\x00\x01\x02\x03")
            sleep 0.1
            expect(@interface_data).to eql "\x00\x01\x02\x03" if connect == 'connected'
          end
        end

        describe "send_raw_file" do
          before(:each) do
            file = File.open('raw_test_file.bin', 'wb')
            file.write "\x00\x01\x02\x03"
            file.close
          end

          after(:each) do
            File.delete('raw_test_file.bin')
          end

          it "raises if the interface does not exist" do
            expect { send_raw_file('BLAH_INT', 'raw_test_file.bin') }.to raise_error(/Interface 'BLAH_INT' does not exist/)
          end

          it "raises if the file does not exist" do
            expect { send_raw_file('INST_INT', 'blah.bin') }.to raise_error(/No such file/)
          end

          it "sends file data to the write_raw interface method" do
            send_raw_file('INST_INT', 'raw_test_file.bin')
            sleep 0.1
            expect(@interface_data).to eql "\x00\x01\x02\x03" if connect == 'connected'
          end
        end

        describe "get_cmd_time" do
          it "creates an actual Ruby Time value" do
            _, _, time = get_cmd_time()
            expect(time).to be_a(Time)
          end
        end
      end
    end
  end
end
