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
      %w(INST SYSTEM).each do |target|
        model = TargetModel.new(folder_name: target, name: target, scope: "DEFAULT")
        model.create
        model.update_store(File.join(SPEC_DIR, 'install', 'config', 'targets'))
      end
      @api = ApiTest.new
    end

    describe "get_target_list" do
      it "gets the list of targets" do
        puts @api.get_target_list(scope: "UNKNOWN")
      end

      it "gets the list of targets" do
        expect(@api.get_target_list(scope: "DEFAULT")).to contain_exactly("SYSTEM", "INST")
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

    describe "get_target_info" do
      it "complains about non-existant targets" do
        expect { @api.get_target_info("BLAH", scope: "DEFAULT") }.to raise_error(RuntimeError, "Target 'BLAH' does not exist")
      end

      xit "gets target cmd tlm count" do
        allow(Store.instance).to receive(:write_topic).and_wrap_original do |m, *args|
          if args[0] =~ /COMMAND__/
            m.call(*args)
          else
            '1577836800000-0'
          end
        end
        allow(Store.instance).to receive(:read_topics).and_yield('topic', '1577836800000-0', {"result" => "SUCCESS"}, nil)

        cmd1, tlm1 = @api.get_target_info("INST")
        @api.cmd("INST ABORT")
        # @api.inject_tlm("INST","HEALTH_STATUS")
        cmd2, tlm2 = @api.get_target_info("INST")
        expect(cmd2 - cmd1).to eq 1
        # expect(tlm2 - tlm1).to eq 1
      end
    end

    xdescribe "get_all_target_info" do
      it "gets target name, interface name, cmd & tlm count" do
        # @api.cmd("INST ABORT")
        # @api.inject_tlm("INST","HEALTH_STATUS")
        info = @api.get_all_target_info().sort
        expect(info[0][0]).to eq "INST"
        # TODO: How does this get set
        # expect(info[0][1]).to eq "INST_INT"
        expect(info[0][2]).to eq 0
        expect(info[0][3]).to eq 0
        expect(info[1][0]).to eq "SYSTEM"
        # expect(info[1][1]).to eq "" # No interface
      end
    end
  end
end
