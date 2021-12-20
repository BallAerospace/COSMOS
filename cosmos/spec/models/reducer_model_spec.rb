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
require 'cosmos/models/reducer_model'

module Cosmos
  describe ReducerModel do
    before(:each) do
      mock_redis()
    end

    describe "singleton_methods" do
      it "returns methods for decom, minute, and hour" do
        methods = ReducerModel.singleton_methods
        expect(methods).to include(:add_decom)
        expect(methods).to include(:add_minute)
        expect(methods).to include(:add_hour)
        expect(methods).to include(:all_decom)
        expect(methods).to include(:all_minute)
        expect(methods).to include(:all_hour)
        expect(methods).to include(:rm_decom)
        expect(methods).to include(:rm_minute)
        expect(methods).to include(:rm_hour)
      end
    end

    # Since this methods all share a common implementation (due to define_singleton_method)
    # we only need to test one of the sets (decom) rather than all (minute, hour)
    describe "add_decom, all_decom, rm_decom" do
      it "adds, lists and removes a file to the decom set" do
        ReducerModel.add_decom(filename: "DEFAULT/spec/file.bin", scope: "DEFAULT")
        expect(ReducerModel.all_decom(scope: "DEFAULT")).to include("DEFAULT/spec/file.bin")
        expect(ReducerModel.all_minute(scope: "DEFAULT")).to be_empty
        expect(ReducerModel.all_hour(scope: "DEFAULT")).to be_empty
        expect(ReducerModel.rm_decom(filename: "DEFAULT/spec/file.bin", scope: "DEFAULT"))
        expect(ReducerModel.all_decom(scope: "DEFAULT")).to be_empty
      end
    end
  end
end
