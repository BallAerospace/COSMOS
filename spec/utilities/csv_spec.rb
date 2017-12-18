# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

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

      @test_file = File.open('cosmos_csv_spec.csv','w')
      @test_file.write(@lines.join(''))
      @test_file.close

      @csv = CSV.new(@test_file.path)
    end

    after(:each) do
      Dir["*cosmos_csv_spec*"].each do |filename|
        File.delete(filename)
      end
    end

    after(:all) do
      clean_config()
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

    describe "create_archive" do
      it "creates a default archive file" do
        @csv.create_archive
        expect(File.exist?(@csv.archive_file)).to be true
        @csv.close_archive
      end

      it "automatically closes an existing open archive file" do
        @csv.create_archive
        first = @csv.archive_file
        expect(File.basename(first)).to match(/.*#{File.basename(@test_file,'.csv')}.*/)
        @csv.create_archive
        second = @csv.archive_file
        expect(File.basename(second)).to match(/.*#{File.basename(@test_file,'.csv')}.*/)
        expect(first).to_not eql(second)
      end

      it "creates an archive file at an arbitrary path" do
        if Kernel.is_windows?
          Dir.mkdir("C:/temp") unless File.directory?("C:/temp")
          @csv.create_archive("C:/temp")
          expect(File.exist?(@csv.archive_file)).to be true
          @csv.close_archive
        end
      end
    end

    describe "write_archive" do
      it "writes to the archive file" do
        @csv.create_archive
        @csv.write_archive(%w(HI a b c))
        @csv.close_archive
        data = File.read @csv.archive_file
        expect(data.include?("HI,a,b,c")).to be true
      end

      it "automatically opens an archive for writing" do
        expect(@csv.archive_file).to eq('')
        @csv.write_archive([])
        expect(File.basename(@csv.archive_file)).to match(/.*#{File.basename(@test_file,'.csv')}.*/)
      end
    end
  end
end
