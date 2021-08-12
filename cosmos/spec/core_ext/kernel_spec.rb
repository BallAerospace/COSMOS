# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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
require 'cosmos/core_ext/kernel'

describe Kernel do
  describe "is_windows?" do
    it "returns true if running on Windows" do
      # Check for a letter drive to determine Windows
      if /[a-zA-Z]:/.match?($:[0])
        expect(is_windows?).to be true
      else
        expect(is_windows?).to be false
      end
    end
  end

  describe "is_mac?" do
    it "returns true if running on Mac OS X" do
      # Check for a letter drive to determine Windows
      if /[a-zA-Z]:/.match?($:[0])
        expect(is_mac?).to be false
      else
        if RUBY_PLATFORM.match?(/darwin/)
          expect(is_mac?).to be true
        else
          expect(is_mac?).to be false
        end
      end
    end
  end

  describe "calling_method" do
    it "returns the calling method" do
      def test(start)
        test2(start)
      end

      def test2(start)
        calling_method(start)
      end
      expect(test(0)).to eql :test2
      expect(test(1)).to eql :test
    end
  end
end
