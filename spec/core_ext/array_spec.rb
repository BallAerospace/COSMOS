# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/core_ext/array'

describe Array do

  describe "inspect" do
    it "should limit the number of items to 10" do
      Array.new([1,2,3,4,5,6,7,8,9,10]).inspect.should eql "[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
      Array.new([1,2,3,4,5,6,7,8,9,10,11]).inspect.should match /#<Array:\d+>/
    end
  end

  describe "clone_to_f" do
    it "should clone the array and convert all the values to floats" do
      Array.new([1,2,3,4,5]).clone_to_f.should eql [1.0,2.0,3.0,4.0,5.0]
    end
  end

  describe "nearest_index" do
    it "should raise error if empty" do
      expect { Array.new.nearest_index(nil) }.to raise_error
    end

    def find_sorted_value(array, sorted)
      array.nearest_index(-1, sorted).should eql 0
      (0..10).each do |val|
        array.nearest_index(val,sorted).should eql val
        # Ensure we always round up
        if val < 10
          array.nearest_index(val+0.1,sorted).should eql val
          array.nearest_index(val+0.5,sorted).should eql val + 1
          array.nearest_index(val+0.9,sorted).should eql val + 1
        end
      end
      array.nearest_index(5.5,sorted).should eql 6
      array.nearest_index(11, sorted).should eql 10
    end

    context "with sorted data" do
      context "with sorted = true" do
        it "should find the nearest index" do
          array = Array.new([0,1,2,3,4,5,6,7,8,9,10])
          find_sorted_value(array, true)
        end
      end

      context "with sorted = false" do
        it "should find the nearest index" do
          array = Array.new([0,1,2,3,4,5,6,7,8,9,10])
          find_sorted_value(array, false)
        end

        it "should find the nearest index with duplicates" do
          index1 = Array.new([0,1,1,1,1,2,2,3]).nearest_index(1,false)
          index2 = Array.new([0,1,1,1,1,2,2]).nearest_index(1,false)
          index1.should eql index2
        end
      end
    end

    context "with unsorted data" do
      it "should find the nearest index to a value" do
        array = Array.new([10,1,9,2,8,3,7,4,6,5,0])
        array.nearest_index(-1, false).should eql 10
        array.nearest_index(11, false).should eql 0
        # Ensure we round up
        array.nearest_index(0.5, false).should eql 1
        array.nearest_index(1.5, false).should eql 3
        array.nearest_index(2.5, false).should eql 5
        array.nearest_index(3.5, false).should eql 7
        array.nearest_index(4.5, false).should eql 9
        array.nearest_index(5.5, false).should eql 8
        array.nearest_index(6.5, false).should eql 6
        array.nearest_index(7.5, false).should eql 4
        array.nearest_index(8.5, false).should eql 2
        array.nearest_index(9.5, false).should eql 0
      end
    end
  end

  describe "index_lt_eq" do
    it "should find the nearest index less than or equal to" do
      Array.new([0,1,1,1,1,2,2,3]).index_lt_eq(1).should eql 1
      Array.new([0,1,1,2,3]).index_lt_eq(1).should eql 1
      Array.new([0,1,1,2,3]).index_lt_eq(0.5).should eql 0
    end

    it "should return the first index if can't find one" do
      Array.new([1,2,3,4]).index_lt_eq(0).should eql 0
    end
  end

  describe "index_gt_eq" do
    it "should find the nearest index greater than or equal to" do
      Array.new([0,1,1,1,1,2,2,3]).index_gt_eq(1).should eql 4
      Array.new([0,0.1,1,1,1,2,2]).index_gt_eq(1).should eql 4
      Array.new([0,0.1,0.5,1,1]).index_gt_eq(0.7).should eql 3
    end

    it "should return the last index if can't find one" do
      Array.new([1,2,3,4]).index_gt_eq(5).should eql 3
    end
  end

  describe "range_containing" do
    it "should complain if start < end" do
      expect { Array.new().range_containing(2,1) }.to raise_error(RuntimeError, "end_value: 1 must be greater than start_value: 2")
    end

    it "should find the range of values containing both" do
      Array.new([0,1,1,2,2,3]).range_containing(1,2).should eql (1..4)
      Array.new([0,1,1,2,2,3]).range_containing(1,1).should eql (1..2)
    end
  end

  describe "sum" do
    it "should sum up the array elements" do
      Array.new([0,1,2,3,4]).sum.should eql 10
      # The float causes the entire result to be a Float
      Array.new([0,1,2,3,4.0]).sum.should eql 10.0
    end
  end

  describe "mean" do
    it "should calculate the mean" do
      Array.new([0,1,2,3,4]).mean.should eql 2.0
    end
  end

  describe "squared" do
    it "should square each element in the array" do
      array = Array.new([0,1,2,3,4])
      array.squared.should eql [0,1,4,9,16]
      # It should not affect the original
      array.should eql [0,1,2,3,4]
    end
  end

  describe "max_with_index" do
    it "should find the first maximum value and its index" do
      Array.new([0,1,8,3,4]).max_with_index.should eql [8,2]
      Array.new([-1,-8,-3,-4]).max_with_index.should eql [-1,0]
      Array.new([0,1,2,2,0]).max_with_index.should eql [2,2]
    end
  end

  describe "min_with_index" do
    it "should find the first maximum value and its index" do
      Array.new([8,9,2,5,6]).min_with_index.should eql [2,2]
      Array.new([-1,-8,-3,-4]).min_with_index.should eql [-8,1]
      Array.new([0,1,2,2,0]).min_with_index.should eql [0,0]
    end
  end

  describe "histogram" do
    it "should group elements" do
      myData1 = [1, 7, 4, 3, 4, 2, 7, 0, 8, 3, 4]
      myData2 = [1, 2, 3]
      myData3 = [2, 4, 8]
      myData1.histogram(9, true).length.should eql 9
      myData1.histogram(1, true).length.should eql 1
      myData1.histogram(9, true)[0][2].should eql 1
      myData1.histogram(9, true)[4][2].should eql 3
      myData1.histogram(3, true)[0][2].should eql 3
      myData2.histogram(5, true).length.should eql 5
      myData2.histogram(50, true).length.should eql 50
      myData2.histogram(5, true)[4][2].should eql 0
      myData2.histogram(5, true)[1][2].should eql 1
      myData3.histogram(7, true).length.should eql 7
      myData3.histogram(25, true).length.should eql 25
      myData3.histogram(7, true)[2][2].should eql 1
      myData3.histogram(25, true)[20][2].should eql 0
    end
  end
end

