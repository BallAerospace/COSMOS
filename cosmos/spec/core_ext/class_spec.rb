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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos/core_ext/class'

describe Class do
  describe "instance_attr_reader" do
    it "adds instance attribute readers for class variables" do
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
      expect(MyClass.test).to eql "Test"
      expect(my.test).to eql "Test"
      # No accessor methods are created
      expect { my.test = "Blah" }.to raise_error(NoMethodError)
    end

    it "does not allow arbitrary code" do
      expect {
        class MyClass
          instance_attr_reader "test;puts 'HI'"
        end
      }.to raise_error(ArgumentError)

      expect {
        class MyClass
          instance_attr_reader "test\nputs 'HI'"
        end
      }.to raise_error(ArgumentError)
    end
  end

  describe "instance_attr_accessor" do
    it "adds instance attribute readers for class variables" do
      class MyClass
        instance_attr_accessor :test
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
      expect(MyClass.test).to eql "Test"
      expect(my.test).to eql "Test"
      my.test = "Blah"
      expect(MyClass.test).to eql "Blah"
      expect(my.test).to eql "Blah"
    end

    it "does not allow arbitrary code" do
      expect {
        class MyClass
          instance_attr_accessor "test;puts 'HI'"
        end
      }.to raise_error(ArgumentError)

      expect {
        class MyClass
          instance_attr_accessor "test\nputs 'HI'"
        end
      }.to raise_error(ArgumentError)
    end
  end
end
