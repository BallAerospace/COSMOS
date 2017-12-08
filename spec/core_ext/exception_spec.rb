# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/core_ext/exception'

describe Exception do

  describe "formatted" do
    it "formats an Exception" do
      begin
        raise "My message"
      rescue => err
        expect(err.formatted).to match(/RuntimeError : My message/)
        expect(err.formatted).to match(/#{File.expand_path(__FILE__)}/)
      end
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
      begin
        line = __LINE__; raise "My message"
      rescue => err
        file, line = err.source
        expect(file).to eql __FILE__
        expect(line).to eql line
      end
    end

    it "returns the file and line number of the exception" do
      begin
        line = __LINE__; raise "My message"
      rescue => err
        # Check to simulate being on UNIX or Windows
        if err.backtrace[0].include?(':') # windows
          err.backtrace[0].gsub!(/[A-Z]:/,'')
          file_name = __FILE__.gsub(/[A-Z]:/,'')
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
end
