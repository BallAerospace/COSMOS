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
      @lines << "test,1,2,3\n"
      @lines << "more,words,go,here\n"
      @lines << "foo,two words,3.4,5.6\n"

      @test_file = File.open('cosmos_csv_spec.csv','w')
      @test_file.write(@lines.join(''))
      @test_file.close

      @csv = CSV.new(@test_file.path)

      @dir_name = System.paths['LOGS']
    end

    after(:each) do
      File.delete("cosmos_csv_spec.csv")
      if @dir_created
        sleep(1)
        FileUtils.remove_dir(@dir_name, false)
      end
    end

    after(:all) do
      clean_config()
    end

    describe "access" do
      it "should allow hash style access" do
        @csv["test"].should eq(%w(1 2 3))
      end

      it "should return all valid keys" do
        @csv.keys.should eq(%w(test more foo))
      end
    end

    describe "create_archive" do
      it "should create a default archive file" do
        @csv.create_archive
        File.exist?(@csv.archive_file).should be_truthy
        @csv.close_archive
      end

      it "should create an archive file at an arbitrary path" do
        if Kernel.is_windows?
          Dir.mkdir("C:/temp") unless File.directory?("C:/temp")
          @csv.create_archive("C:/temp")
          File.exist?(@csv.archive_file).should be_truthy
          @csv.close_archive
        end
      end
    end

    describe "write_archive" do
      it "should write to the archive file" do
        @csv.create_archive
        @csv.write_archive(%w(HI a b c))
        @csv.close_archive
        data = File.read @csv.archive_file
        data.include?("HI,a,b,c").should be_truthy
      end

      it "should raise an exception if writing to an unopened archive" do
        expect {@csv.write_archive([])}.to raise_error
      end

      it "should raise an exception if trying to reopen archive" do
        @csv.create_archive
        expect {@csv.create_archive}.to raise_error
        @csv.close_archive
      end

      it "should raise an exception if trying to write closed archive" do
        @csv.create_archive
        @csv.close_archive
        expect {@csv.write_archive([])}.to raise_error
      end
    end
  end
end
