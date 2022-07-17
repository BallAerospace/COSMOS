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
require 'openc3/core_ext/exception'

describe Exception do
  describe "formatted" do
    it "formats an Exception" do
      raise "My message"
    rescue => err
      expect(err.formatted).to match(/RuntimeError : My message/)
      expect(err.formatted).to match(/#{File.expand_path(__FILE__)}/)
    end

    it "formats an Exception without RuntimeError class" do
      begin
        raise "My message"
      rescue => err
        expect(err.formatted(true)).not_to match(/RuntimeError/)
        expect(err.formatted(true)).to match(/My message/)
        expect(err.formatted(true)).to match(/#{File.expand_path(__FILE__)}/)
      end

      # If it's not a RuntimeError then we should still see the class
      begin
        raise ArgumentError.new("My message")
      rescue => err
        expect(err.formatted(true)).to match(/ArgumentError/)
        expect(err.formatted(true)).to match(/My message/)
        expect(err.formatted(true)).to match(/#{File.expand_path(__FILE__)}/)
      end
    end

    it "formats an Exception without stack trace" do
      begin
        raise "My message"
      rescue => err
        expect(err.formatted(false, false)).to match(/RuntimeError : My message/)
        expect(err.formatted(false, false)).not_to match(/#{File.expand_path(__FILE__)}/)
      end

      begin
        raise "My message"
      rescue => err
        expect(err.formatted(true, false)).to match(/My message/)
        expect(err.formatted(true, false)).not_to match(/#{File.expand_path(__FILE__)}/)
      end
    end
  end

  describe "source" do
    it "returns the file and line number of the exception" do
      line = __LINE__; raise "My message"
    rescue => err
      file, line = err.source
      expect(file).to eql __FILE__
      expect(line).to eql line
    end

    it "returns the file and line number of the exception" do
      line = __LINE__; raise "My message"
    rescue => err
      # Check to simulate being on UNIX or Windows
      if err.backtrace[0].include?(':') # windows
        err.backtrace[0].gsub!(/[A-Z]:/, '')
        file_name = __FILE__.gsub(/[A-Z]:/, '')
      else
        err.backtrace[0] = "C:" + err.backtrace[0]
        file_name = "C:#{__FILE__}"
      end
      file, line = err.source
      expect(file).to eql file_name
      expect(line).to eql line
    end
  end
end
