# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/conversions/conversion'

module Cosmos

  describe Conversion do

    describe "call" do
      it "should raise an exception" do
        expect { Conversion.new.call(0, 0, 0) }.to raise_error("call method must be defined by subclass")
      end
    end

    describe "to_s" do
      it "should return a String" do
        Conversion.new.to_s.should eql "Conversion"
      end
    end
  end
end

