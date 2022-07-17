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
require 'openc3/script'
require 'tempfile'

module OpenC3
  describe Script do
    describe "disconnect" do
      before(:each) do
        # Keep track of all the methods called on the JsonDRbObject
        json = double("JsonDRbObject").as_null_object
        allow(JsonDRbObject).to receive(:new).and_return(json)
        @methods = []
        allow(json).to receive(:method_missing) do |*args, **kwargs|
          @methods << args[0]
          nil # Simulate a not yet received packet
        end
        $api_server = ServerProxy.new
        initialize_script()
        # initialize_script pushes shutdown on the @method array so remove that
        @methods.pop
      end

      it "should proxy to JsonDRbObject if not disconnected" do
        expect($disconnect).to be false
        set_tlm("INST HEALTH_STATUS TEMP1 = 0")
        # Test that the disconnect mode value doesn't matter if we're connected
        expect(tlm("INST HEALTH_STATUS TEMP1", disconnect: 10)).to be_nil
        get_command("INST ABORT")
        set_limits("INST", "HEALTH_STATUS", "TEMP1", 0.0, 10.0, 20.0, 30.0)
        inject_tlm("INST", "HEALTH_STATUS", { TEMP1: 0, TEMP2: 0, TEMP3: 0, TEMP4: 0 })

        expect(@methods).to eql %i(set_tlm tlm get_command set_limits inject_tlm)
      end

      it "disconnect_script should only allow read only methods" do
        disconnect_script()
        expect($disconnect).to be true
        set_tlm("INST HEALTH_STATUS TEMP1 = 0")
        # Test that we can override the return value in disconnect mode
        expect(tlm("INST HEALTH_STATUS TEMP1", disconnect: 10)).to eql 10
        get_command("INST ABORT")
        set_limits("INST", "HEALTH_STATUS", "TEMP1", 0.0, 10.0, 20.0, 30.0)
        inject_tlm("INST", "HEALTH_STATUS", { TEMP1: 0, TEMP2: 0, TEMP3: 0, TEMP4: 0 })

        # In disconnect we don't pass through set commands or inject_tlm
        expect(@methods).to eql %i(tlm get_command)
      end
    end
  end
end
