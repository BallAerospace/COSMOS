# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/core_ext/matrix'

describe Matrix do

  describe "[]" do
    it "returns an entire row" do
      matrix = Matrix[[1,2,3],[4,5,6],[7,8,9]]
      matrix[0].should eql [1,2,3]
      matrix[1].should eql [4,5,6]
      matrix[2].should eql [7,8,9]
    end

    it "returns an element" do
      matrix = Matrix[[1,2,3],[4,5,6],[7,8,9]]
      matrix[0,0].should eql 1
      matrix[1,1].should eql 5
      matrix[2,2].should eql 9
    end
  end

  describe "[]=" do
    it "sets an element" do
      matrix = Matrix[[1,2,3],[4,5,6],[7,8,9]]
      matrix[0,0] = -1
      matrix[0,0].should eql -1
    end
  end

  describe "rot" do
    it "creates a rotation about x" do
      Matrix.rot(:X, Math::PI / 2).should eql Matrix[[1,0,0],[0,cos(Math::PI / 2),sin(Math::PI / 2)],[0,-sin(Math::PI / 2),cos(Math::PI / 2)]]
      Matrix.rot(:X, 90).should eql Matrix.rot(:x, 90)
      Matrix.rot(:x, 90).should eql Matrix.rot(1, 90)
    end

    it "creates a rotation about y" do
      Matrix.rot(:Y, Math::PI / 2).should eql Matrix[[cos(Math::PI / 2),0,-sin(Math::PI / 2)],[0,1,0],[sin(Math::PI / 2),0, cos(Math::PI / 2)]]
    end

    it "creates a rotation about z" do
      Matrix.rot(:Z, Math::PI / 2).should eql Matrix[[cos(Math::PI / 2),sin(Math::PI / 2),0],[-sin(Math::PI / 2),cos(Math::PI / 2),0],[0,0,1]]
    end
  end

  describe "trace" do
    it "sums the diagonal" do
      Matrix[[1,2,3],[4,5,6],[7,8,9]].trace.should eql 15.0
    end

    it "handles rectangular matrices" do
      Matrix[[1,2],[4,5],[7,8]].trace.should eql 6.0
    end
  end
end

