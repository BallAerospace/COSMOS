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
require 'cosmos/core_ext/array'

describe Array do
  describe "inspect" do
    it "limits the number of items to 10" do
      expect(Array.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]).inspect).to eql "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
      expect(Array.new([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]).inspect).to match(/#<Array:\d+>/)
    end
  end

  describe "clone_to_f" do
    it "clones the array and convert all the values to floats" do
      expect(Array.new([1, 2, 3, 4, 5]).clone_to_f).to eql [1.0, 2.0, 3.0, 4.0, 5.0]
    end
  end

  describe "nearest_index" do
    it "raises error if empty" do
      expect { Array.new.nearest_index(nil) }.to raise_error(/empty array/)
    end

    def find_sorted_value(array, sorted)
      expect(array.nearest_index(-1, sorted)).to eql 0
      (0..10).each do |val|
        expect(array.nearest_index(val, sorted)).to eql val
        # Ensure we always round up
        if val < 10
          expect(array.nearest_index(val + 0.1, sorted)).to eql val
          expect(array.nearest_index(val + 0.5, sorted)).to eql val + 1
          expect(array.nearest_index(val + 0.9, sorted)).to eql val + 1
        end
      end
      expect(array.nearest_index(5.5, sorted)).to eql 6
      expect(array.nearest_index(11, sorted)).to eql 10
    end

    context "with sorted data" do
      context "with sorted = true" do
        it "finds the nearest index" do
          array = Array.new([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
          find_sorted_value(array, true)
        end
      end

      context "with sorted = false" do
        it "finds the nearest index" do
          array = Array.new([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
          find_sorted_value(array, false)
        end

        it "finds the nearest index with duplicates" do
          index1 = Array.new([0, 1, 1, 1, 1, 2, 2, 3]).nearest_index(1, false)
          index2 = Array.new([0, 1, 1, 1, 1, 2, 2]).nearest_index(1, false)
          expect(index1).to eql index2
        end
      end
    end

    context "with unsorted data" do
      it "finds the nearest index to a value" do
        array = Array.new([10, 1, 9, 2, 8, 3, 7, 4, 6, 5, 0])
        expect(array.nearest_index(-1, false)).to eql 10
        expect(array.nearest_index(11, false)).to eql 0
        # Ensure we round up
        expect(array.nearest_index(0.5, false)).to eql 1
        expect(array.nearest_index(1.5, false)).to eql 3
        expect(array.nearest_index(2.5, false)).to eql 5
        expect(array.nearest_index(3.5, false)).to eql 7
        expect(array.nearest_index(4.5, false)).to eql 9
        expect(array.nearest_index(5.5, false)).to eql 8
        expect(array.nearest_index(6.5, false)).to eql 6
        expect(array.nearest_index(7.5, false)).to eql 4
        expect(array.nearest_index(8.5, false)).to eql 2
        expect(array.nearest_index(9.5, false)).to eql 0
      end
    end
  end

  describe "index_lt_eq" do
    it "finds the nearest index less than or equal to" do
      expect(Array.new([0, 1, 1, 1, 1, 2, 2, 3]).index_lt_eq(1)).to eql 1
      expect(Array.new([0, 1, 1, 2, 3]).index_lt_eq(1)).to eql 1
      expect(Array.new([0, 1, 1, 2, 3]).index_lt_eq(0.5)).to eql 0
    end

    it "returns the first index if can't find one" do
      expect(Array.new([1, 2, 3, 4]).index_lt_eq(0)).to eql 0
    end
  end

  describe "index_gt_eq" do
    it "finds the nearest index greater than or equal to" do
      expect(Array.new([0, 1, 1, 1, 1, 2, 2, 3]).index_gt_eq(1)).to eql 4
      expect(Array.new([0, 0.1, 1, 1, 1, 2, 2]).index_gt_eq(1)).to eql 4
      expect(Array.new([0, 0.1, 0.5, 1, 1]).index_gt_eq(0.7)).to eql 3
    end

    it "returns the last index if can't find one" do
      expect(Array.new([1, 2, 3, 4]).index_gt_eq(5)).to eql 3
    end
  end

  describe "range_containing" do
    it "complains if start < end" do
      expect { Array.new().range_containing(2, 1) }.to raise_error(RuntimeError, "end_value: 1 must be greater than start_value: 2")
    end

    it "finds the range of values containing both" do
      expect(Array.new([0, 1, 1, 2, 2, 3]).range_containing(1, 2)).to eql (1..4)
      expect(Array.new([0, 1, 1, 2, 2, 3]).range_containing(1, 1)).to eql (1..2)
      expect(Array.new([0, 1, 2, 3, 4, 5]).range_containing(1, 4)).to eql (1..4)
    end

    it "creates an empty range at the beginning of the array if the values both too small" do
      expect(Array.new([0, 1, 1, 2, 2, 3]).range_containing(-2, -1)).to eql (0..0)
    end

    it "creates an empty range at the end of the array if the values are both too large" do
      expect(Array.new([0, 1, 1, 2, 2, 3]).range_containing(4, 5)).to eql (5..5)
    end
  end

  describe "range_within" do
    it "complains if start < end" do
      expect { Array.new().range_within(2, 1) }.to raise_error(RuntimeError, "end_value: 1 must be greater than start_value: 2")
    end

    it "finds the range of values within both" do
      expect(Array.new([0, 1, 1, 2, 2, 3]).range_within(1, 2)).to eql (2..3)
      expect(Array.new([0, 1, 1, 2, 2, 3]).range_within(1, 1)).to eql (1..2)
      expect(Array.new([0, 1, 2, 3, 4, 5]).range_within(1, 4)).to eql (1..4)
    end

    it "creates an empty range at the beginning of the array if the values both too small" do
      expect(Array.new([0, 1, 1, 2, 2, 3]).range_within(-2, -1)).to eql (0..0)
    end

    it "creates an empty range at the end of the array if the values are both too large" do
      expect(Array.new([0, 1, 1, 2, 2, 3]).range_within(4, 5)).to eql (5..5)
    end
  end

  describe "sum" do
    it "sums up the array elements" do
      expect(Array.new([0, 1, 2, 3, 4]).sum).to eql 10
      # The float causes the entire result to be a Float
      expect(Array.new([0, 1, 2, 3, 4.0]).sum).to eql 10.0
    end
  end

  describe "mean" do
    it "calculates the mean" do
      expect(Array.new([0, 1, 2, 3, 4]).mean).to eql 2.0
    end
  end

  describe "squared" do
    it "squares each element in the array" do
      array = Array.new([0, 1, 2, 3, 4])
      expect(array.squared).to eql [0, 1, 4, 9, 16]
      # It should not affect the original
      expect(array).to eql [0, 1, 2, 3, 4]
    end
  end

  describe "max_with_index", no_ext: true do
    it "finds the first maximum value and its index" do
      expect(Array.new([0, 1, 8, 3, 4]).max_with_index).to eql [8, 2]
      expect(Array.new([-1, -8, -3, -4]).max_with_index).to eql [-1, 0]
      expect(Array.new([0, 1, 2, 2, 0]).max_with_index).to eql [2, 2]
    end
  end

  describe "min_with_index", no_ext: true do
    it "finds the first maximum value and its index" do
      expect(Array.new([8, 9, 2, 5, 6]).min_with_index).to eql [2, 2]
      expect(Array.new([-1, -8, -3, -4]).min_with_index).to eql [-8, 1]
      expect(Array.new([0, 1, 2, 2, 0]).min_with_index).to eql [0, 0]
    end
  end

  describe "histogram" do
    it "groups numeric elements" do
      myData1 = [1, 7, 4, 3, 4, 2, 7, 0, 8, 3, 4]
      myData2 = [1, 2, 3]
      myData3 = [2, 4, 8]
      expect(myData1.histogram(9, true).length).to eql 9
      expect(myData1.histogram(1, true).length).to eql 1
      expect(myData1.histogram(9, true)[0][2]).to eql 1
      expect(myData1.histogram(9, true)[4][2]).to eql 3
      expect(myData1.histogram(3, true)[0][2]).to eql 3
      expect(myData2.histogram(5, true).length).to eql 5
      expect(myData2.histogram(50, true).length).to eql 50
      expect(myData2.histogram(5, true)[4][2]).to eql 0
      expect(myData2.histogram(5, true)[1][2]).to eql 1
      expect(myData3.histogram(7, true).length).to eql 7
      expect(myData3.histogram(25, true).length).to eql 25
      expect(myData3.histogram(7, true)[2][2]).to eql 1
      expect(myData3.histogram(25, true)[20][2]).to eql 0
    end

    it "sorts by a given block" do
      myData1 = [1, 7, 4, 3, 4, 2, 7, 0, 8, 3, 4]
      histogram = myData1.histogram(nil, true) do |val1, val2|
        val2[0] <=> val1[0]
      end
      expect(myData1.histogram(nil, true)).to eql histogram.reverse
    end

    it "groups non-numeric elements" do
      myData1 = ['b', 'h', 'e', 'd', 'e', 'c', 'h', 'a', 'i', 'd', 'e']
      myData2 = ['b', 'c', 'd']
      myData3 = ['c', 'e', 'i']

      expect(myData1.histogram()).to eql [['a', 'a', 1], ['b', 'b', 1], ['c', 'c', 1], ['d', 'd', 2], ['e', 'e', 3], ['h', 'h', 2], ['i', 'i', 1]]
      expect(myData2.histogram()).to eql [["b", "b", 1], ["c", "c", 1], ["d", "d", 1]]
      expect(myData3.histogram()).to eql [["c", "c", 1], ["e", "e", 1], ["i", "i", 1]]

      # Even though we request 9 we only get 7 because that's all the unique values we have
      expect(myData1.histogram(9, false).length).to eql 7
      expect(myData1.histogram(1, false).length).to eql 1
      expect(myData1.histogram(7, false)[0][2]).to eql 1
      expect(myData1.histogram(7, false)[4][2]).to eql 3
      expect(myData1.histogram(3, false)[0][2]).to eql 3
      # Even though we request 5 we only get 3 because that's all the unique values we have
      expect(myData2.histogram(5, false).length).to eql 3
      expect(myData2.histogram(3, false)[2][2]).to eql 1
      expect(myData2.histogram(3, false)[1][2]).to eql 1
      # Even though we request 7 we only get 3 because that's all the unique values we have
      expect(myData3.histogram(7, false).length).to eql 3
      expect(myData3.histogram(3, false)[2][2]).to eql 1
    end
  end
end
