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
require 'cosmos/api/target_api'
require 'cosmos/script/extract'
require 'cosmos/utilities/authorization'
require 'cosmos/topics/command_topic'
require 'cosmos/topics/telemetry_topic'

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
      %w(INST EMPTY SYSTEM).each do |target|
        model = TargetModel.new(folder_name: target, name: target, scope: "DEFAULT")
        model.create
        model.update_store(File.join(SPEC_DIR, 'install', 'config', 'targets'))
      end

      @api = ApiTest.new
    end

    describe "get_target_list" do
      it "gets an empty array for an unknown scope" do
        expect(@api.get_target_list(scope: "UNKNOWN")).to be_empty
      end

      it "gets the list of targets" do
        expect(@api.get_target_list(scope: "DEFAULT")).to contain_exactly("EMPTY", "INST", "SYSTEM")
      end
    end

    describe "get_target" do
      it "returns nil if the target doesn't exist" do
        expect(@api.get_target("BLAH", scope: "DEFAULT")).to be_nil
      end

      it "gets a target hash" do
        tgt = @api.get_target("INST", scope: "DEFAULT")
        expect(tgt).to be_a Hash
        expect(tgt['name']).to eql "INST"
      end
    end

    describe "get_all_target_info" do
      it "gets target name, interface name, cmd & tlm count" do
        info = @api.get_all_target_info(scope: "DEFAULT")
        expect(info[0][0]).to eq "EMPTY"
        expect(info[0][1]).to eq ""
        expect(info[0][2]).to eq 0
        expect(info[0][3]).to eq 0
        expect(info[1][0]).to eq "INST"
        expect(info[1][1]).to eq "INST_INT"
        expect(info[1][2]).to eq 0
        expect(info[1][3]).to eq 0
        expect(info[2][0]).to eq "SYSTEM"
        expect(info[2][1]).to eq ""
        expect(info[2][2]).to eq 0
        expect(info[2][3]).to eq 0

        # Act like the InterfaceMicroservice and write to the CommandTopic & TelemetryTopic
        packet = System.commands.packet("INST", "ABORT").clone
        packet.received_time = Time.now.sys
        packet.received_count += 1
        CommandTopic.write_packet(packet, scope: "DEFAULT")
        packet = System.commands.packet("INST", "CLEAR").clone
        packet.received_time = Time.now.sys
        packet.received_count += 1
        CommandTopic.write_packet(packet, scope: "DEFAULT")
        packet = System.telemetry.packet("INST", "HEALTH_STATUS").clone
        packet.received_time = Time.now.sys
        packet.received_count += 1
        TelemetryTopic.write_packet(packet, scope: "DEFAULT")
        packet = System.telemetry.packet("INST", "ADCS").clone
        packet.received_time = Time.now.sys
        packet.received_count += 1
        TelemetryTopic.write_packet(packet, scope: "DEFAULT")

        info = @api.get_all_target_info(scope: "DEFAULT")
        expect(info[1][2]).to eql 2 # cmd count
        expect(info[1][3]).to eql 2 # tlm count
      end
    end
  end
end
