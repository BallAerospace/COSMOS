# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/core_ext/class'

describe Class do

  describe "instance_attr_reader" do
    it "should add instance attribute readers for class variables" do
      class MyClass
        instance_attr_reader :test
        @@instance = nil
        def self.instance
          @@instance ||= self.new
          return @@instance
        end
        def initialize
          @test = "Test"
          @@instance = self
        end
      end

      my = MyClass.new
      MyClass.test.should eql "Test"
      my.test.should eql "Test"
    end
  end
end
