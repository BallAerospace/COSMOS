# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/processors/processor'

module Cosmos

  describe Processor do

    describe "initialize" do
      it "should store an optional value_type" do
        a = Processor.new(:RAW)
        a.value_type.should eql :RAW
        b = Processor.new
        b.value_type.should eql :CONVERTED
      end
    end

    describe "call" do
      it "should raise an exception" do
        expect { Processor.new.call(0, 0) }.to raise_error("call method must be defined by subclass")
      end
    end

    describe "to_s" do
      it "should return a String" do
        Processor.new.to_s.should eql "Processor"
      end
    end

    describe "name" do
      it "should have an assignable name" do
        a = Processor.new
        a.name = "Test"
        a.name.should eql "TEST"
      end
    end

    describe "reset" do
      it "should have a reset method" do
        a = Processor.new
        expect { a.reset }.not_to raise_error
      end
    end
  end
end

