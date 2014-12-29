# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/core_ext/file'
require 'tempfile'

describe File do

  describe "is_ascii?" do
    it "should return true if a file only contains printable ASCII characters" do
      tf = Tempfile.new('unittest')
      (32..126).each do |val|
        tf.puts(val.chr)
      end
      tf.close
      expect(File.is_ascii?(tf.path)).to be true
      tf.unlink
    end

    it "should return false if a file contains non-ASCII characters" do
      tf = Tempfile.new('unittest')
      (0..255).each do |val|
        tf.puts(val.chr)
      end
      tf.close
      expect(File.is_ascii?(tf.path)).to be false
      tf.unlink
    end
  end

  describe "build_timestamped_filename" do
    it "should format the time" do
      time = Time.now
      timestamp = sprintf("%04u_%02u_%02u_%02u_%02u_%02u", time.year, time.month, time.mday, time.hour, time.min, time.sec)
      File.build_timestamped_filename(nil,".txt",time).should match timestamp
    end

    it "should allow empty tags" do
      File.build_timestamped_filename([]).should match /\d\d\.txt/
    end

    it "should allow nil tags" do
      File.build_timestamped_filename(nil).should match /\d\d\.txt/
    end

    it "should include the tags" do
      File.build_timestamped_filename(['this','is','a','test']).should match 'this_is_a_test'
    end

    it "should change the extension" do
      File.build_timestamped_filename(nil,".bin").should match ".bin"
    end
  end

  describe "find_in_search_path" do
    it "should return the path to the file" do
      File.find_in_search_path("cosmos.rb").should match "/lib/cosmos.rb"
    end

    it "should return nil if the file can't be found" do
      File.find_in_search_path("blah_blah_blah.rb").should be_nil
    end
  end
end
