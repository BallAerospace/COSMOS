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
require 'cosmos/core_ext/math'
include Math

describe Math do

  describe "sin_squared" do
    it "calculates sin squared" do
      expect(sin_squared(10)).to be_within(0.00000001).of(sin(10)**2)
    end
  end

  describe "cos_squared" do
    it "calculates cos squared" do
      expect(cos_squared(10)).to be_within(0.00000001).of(cos(10)**2)
    end
  end

  describe "variance_population" do
    it "returns 0 if the same value" do
      mean, var = variance_population([1,1,1,1])
      expect(mean).to eql 1.0
      expect(var).to eql 0.0
    end

    it "returns population variance" do
      mean, var = variance_population([1,2,3])
      expect(mean).to eql 2.0
      expect(var).to eql 2.0/3.0
    end

    it "handles an empty data set" do
      mean, var = variance_population([])
      expect(mean).to eql 0.0
      expect(var).to eql 0.0
    end
  end

  describe "variance_sample" do
    it "returns 0 if the same value" do
      mean, var = variance_sample([1,1,1,1])
      expect(mean).to eql 1.0
      expect(var).to eql 0.0
    end

    it "returns sample variance" do
      mean, var = variance_sample([1,2,3])
      expect(mean).to eql 2.0
      expect(var).to eql 1.0
    end

    it "handles an empty data set" do
      mean, var = variance_sample([])
      expect(mean).to eql 0.0
      expect(var).to eql 0.0
    end

    it "handles a single item data set" do
      mean, var = variance_sample([1])
      expect(mean).to eql 1.0
      expect(var).to eql 0.0
    end
  end

  describe "stddev_population" do
    it "returns 0 if the same value" do
      mean, var = stddev_population([1,1,1,1])
      expect(mean).to eql 1.0
      expect(var).to eql 0.0
    end

    it "returns population stddev" do
      mean, var = stddev_population([1,2,3])
      expect(mean).to eql 2.0
      expect(var).to eql sqrt(2.0/3.0)
    end
  end

  describe "stddev_sample" do
    it "returns 0 if the same value" do
      mean, var = stddev_sample([1,1,1,1])
      expect(mean).to eql 1.0
      expect(var).to eql 0.0
    end

    it "returns sample stddev" do
      mean, var = stddev_sample([1,2,3])
      expect(mean).to eql 2.0
      expect(var).to eql 1.0
    end
  end

  describe "luma_from_rgb_max_255" do
    it "returns 0 with 0 RGB" do
      expect(luma_from_rgb_max_255(0,0,0)).to eql 0.0
    end

    it "returns 1.0 with 255 RGB" do
      expect(luma_from_rgb_max_255(255,255,255)).to eql 1.0
    end

    it "returns about 0.5 with 127 RGB" do
      expect(luma_from_rgb_max_255(127,127,127)).to be_within(0.01).of(0.5)
    end
  end
end
