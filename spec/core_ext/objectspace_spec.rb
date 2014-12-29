# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/core_ext/objectspace'

describe ObjectSpace do

  describe "find" do
    it "should find a class in the Ruby object space" do
      ObjectSpace.find(Class).should_not be_nil
      ObjectSpace.find(Cosmos).should be_nil
    end
  end

  describe "find_all" do
    it "should find classes in the Ruby object space" do
      ObjectSpace.find_all(Class).should be_a(Array)
      ObjectSpace.find_all(Cosmos).should eql([])
    end
  end
end
