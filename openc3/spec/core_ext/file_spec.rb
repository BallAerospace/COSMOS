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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'spec_helper'
require 'openc3/core_ext/file'
require 'tempfile'

describe File do
  describe "is_ascii?" do
    it "returns true if a file only contains printable ASCII characters" do
      tf = Tempfile.new('unittest')
      (32..126).each do |val|
        tf.puts(val.chr)
      end
      tf.close
      expect(File.is_ascii?(tf.path)).to be true
      tf.unlink
    end

    it "returns false if a file contains non-ASCII characters" do
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
    it "formats the time" do
      time = Time.now
      timestamp = sprintf("%04u_%02u_%02u_%02u_%02u_%02u", time.year, time.month, time.mday, time.hour, time.min, time.sec)
      expect(File.build_timestamped_filename(nil, ".txt", time)).to match(timestamp)
    end

    it "allows empty tags" do
      expect(File.build_timestamped_filename([])).to match(/\d\d\.txt/)
    end

    it "allows nil tags" do
      expect(File.build_timestamped_filename(nil)).to match(/\d\d\.txt/)
    end

    it "includes the tags" do
      expect(File.build_timestamped_filename(['this', 'is', 'a', 'test'])).to match('this_is_a_test')
    end

    it "changes the extension" do
      expect(File.build_timestamped_filename(nil, ".bin")).to match(".bin")
    end
  end

  describe "find_in_search_path" do
    it "returns the path to the file" do
      expect(File.find_in_search_path("openc3.rb")).to match("lib/openc3.rb")
    end

    it "returns nil if the file can't be found" do
      expect(File.find_in_search_path("blah_blah_blah.rb")).to be_nil
    end
  end
end
