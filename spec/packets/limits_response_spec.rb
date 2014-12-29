# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/packets/limits_response'

module Cosmos

  describe LimitsResponse do

    describe "call" do
      it "should raise an exception" do
        expect { LimitsResponse.new.call(nil,nil,nil) }.to raise_error(/defined by subclass/)
      end
    end
  end
end
