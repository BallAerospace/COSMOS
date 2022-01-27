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

require "spec_helper"
require "cosmos/utilities/csv"
require "tempfile"

module Cosmos
  describe CSV do
    before(:each) do
      @lines = []
      # CSV data can't have extra spaces in array values
      @lines << "# This is a comment\n"
      @lines << "test,1,2,3\n"
      @lines << "bool1,true,false\n"
      @lines << "bool2,false,true\n"
      @lines << "int,10,11\n"
      @lines << "float,1.1,2.2,3.3\n"
      @lines << "string,test,text with space\n"

      @test_file = File.open('cosmos_csv_spec.csv', 'w')
      @test_file.write(@lines.join(''))
      @test_file.close

      @csv = CSV.new(@test_file.path)
    end

    after(:each) do
      Dir["*cosmos_csv_spec*"].each do |filename|
        File.delete(filename)
      end
    end

    describe "initialize" do
      it "loads the CSV data and overwrites existing key/values" do
        tf = Tempfile.new("test.csv")
        tf.puts "test,1,2,3\n"
        tf.puts "other,10\n"
        tf.puts "test,1.1,2.2,3.3\n"
        tf.close
        csv = CSV.new(tf.path)
        # Expect 1.1, 2.2, 3.3 not 1, 2, 3 because the same key was used
        expect(csv["test"]).to eql(%w(1.1 2.2 3.3))

        tf.unlink
      end
    end

    describe "access" do
      it "allows hash style access" do
        expect(@csv["test"]).to eq(%w(1 2 3))
      end

      it "returns all keys and ignores comments" do
        expect(@csv.keys).to eq(%w(test bool1 bool2 int float string))
      end

      it "returns boolean values" do
        expect(@csv.boolean("bool1")).to be true
        expect(@csv.bool("bool2")).to be false

        expect(@csv.boolean("bool1", 1)).to be false
        expect(@csv.bool("bool2", 1)).to be true

        expect(@csv.bool("bool1", (0..-1))).to eql([true, false])
        expect(@csv.bool("bool2", (0..-1))).to eql([false, true])
      end

      it "returns integer values" do
        expect(@csv.integer("int")).to be(10)
        expect(@csv.int("int", 1)).to be(11)
        expect(@csv.integer("int", (0..1))).to eql([10, 11])
      end

      it "returns float values" do
        expect(@csv.float("float")).to eq(1.1)
        expect(@csv.float("float", 1)).to eq(2.2)
        expect(@csv.float("float", 2)).to eq(3.3)
        expect(@csv.float("float", (0..1))).to eql([1.1, 2.2])
        expect(@csv.float("float", (1..2))).to eql([2.2, 3.3])
        expect(@csv.float("float", (0..-1))).to eql([1.1, 2.2, 3.3])
      end

      it "returns string values" do
        expect(@csv.string("string")).to eq("test")
        expect(@csv.str("string", 1)).to eq("text with space")
        expect(@csv.str("string", (0..-1))).to eq(["test", "text with space"])
      end

      it "returns symbol values" do
        expect(@csv.symbol("string")).to eq(:test)
        # This works but please don't do this! Symbols with spaces is ugly!
        expect(@csv.sym("string", 1)).to eq(:"text with space")
        expect(@csv.sym("string", (0..-1))).to eq([:test, :"text with space"])
      end
    end
  end
end
