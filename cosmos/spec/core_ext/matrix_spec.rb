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
require 'cosmos/core_ext/matrix'
require 'ostruct'

describe Matrix do
  describe "[]" do
    it "returns an entire row" do
      matrix = Matrix[[1,2,3],[4,5,6],[7,8,9]]
      expect(matrix[0]).to eql [1,2,3]
      expect(matrix[1]).to eql [4,5,6]
      expect(matrix[2]).to eql [7,8,9]
    end

    it "returns an element" do
      matrix = Matrix[[1,2,3],[4,5,6],[7,8,9]]
      expect(matrix[0,0]).to eql 1
      expect(matrix[1,1]).to eql 5
      expect(matrix[2,2]).to eql 9
    end
  end

  describe "[]=" do
    it "sets an element" do
      matrix = Matrix[[1,2,3],[4,5,6],[7,8,9]]
      matrix[0,0] = -1
      expect(matrix[0,0]).to eql(-1)
    end
  end

  describe "rot" do
    it "creates a rotation about x" do
      expect(Matrix.rot(:X, Math::PI / 2)).to eql Matrix[[1,0,0],[0,cos(Math::PI / 2),sin(Math::PI / 2)],[0,-sin(Math::PI / 2),cos(Math::PI / 2)]]
      expect(Matrix.rot(:X, 90)).to eql Matrix.rot(:x, 90)
      expect(Matrix.rot(:x, 90)).to eql Matrix.rot(1, 90)
    end

    it "creates a rotation about y" do
      expect(Matrix.rot(:Y, Math::PI / 2)).to eql Matrix[[cos(Math::PI / 2),0,-sin(Math::PI / 2)],[0,1,0],[sin(Math::PI / 2),0, cos(Math::PI / 2)]]
    end

    it "creates a rotation about z" do
      expect(Matrix.rot(:Z, Math::PI / 2)).to eql Matrix[[cos(Math::PI / 2),sin(Math::PI / 2),0],[-sin(Math::PI / 2),cos(Math::PI / 2),0],[0,0,1]]
    end
  end

  describe "trace" do
    it "sums the diagonal" do
      expect(Matrix[[1,2,3],[4,5,6],[7,8,9]].trace).to eql 15.0
    end

    it "handles rectangular matrices" do
      expect(Matrix[[1,2],[4,5],[7,8]].trace).to eql 6.0
    end
  end

  describe "cfromq" do
    it "calculates the rotational matrix from the quaternion" do
      quaternion = OpenStruct.new
      quaternion.w = 1
      quaternion.x = 0
      quaternion.y = 0
      quaternion.z = 0
      expect(Matrix.cfromq(quaternion)).to eql Matrix[[1.0,0.0,0.0],[0.0,1.0,0.0],[0.0,0.0,1.0]]

      quaternion.w = Math.sqrt(0.5)
      quaternion.x = Math.sqrt(0.5)
      quaternion.y = 0
      quaternion.z = 0
      matrix = Matrix.cfromq(quaternion)
      expect(matrix[0]).to eql [1.0, 0.0, 0.0]
      expect(matrix[1][0]).to eql 0.0
      expect(matrix[1][1]).to be_within(1e-10).of(0.0)
      expect(matrix[1][2]).to be_within(1e-10).of(1.0)
      expect(matrix[2][0]).to eql 0.0
      expect(matrix[2][1]).to be_within(1e-10).of(-1.0)
      expect(matrix[2][2]).to be_within(1e-10).of(0.0)
    end
  end

  describe "trans4" do
    it "translates the matrix by x,y,z" do
      matrix = Matrix[[4,4,4,4],[3,3,3,3],[2,2,2,2],[1,1,1,1]]
      expect(matrix.trans4(1,1,1)).to eql Matrix[[4,4,4,4],[3,3,3,3],[2,2,2,2],[10,10,10,10]]
    end
  end

  describe "scale4" do
    it "scales the matrix by x,y,z" do
      matrix = Matrix[[5,5,5,5],[4,4,4,4],[3,3,3,3],[2,2,2,2]]
      expect(matrix.scale4(2,4,6)).to eql Matrix[[10,10,10,10],[16,16,16,16],[18,18,18,18],[2,2,2,2]]
    end
  end

  describe "rot4" do
    it "rotates the matrix about the quaternion" do
      matrix = Matrix[[4,4,4,4],[3,3,3,3],[2,2,2,2],[1,1,1,1]]
      quaternion = OpenStruct.new
      quaternion.w = Math.sqrt(0.5)
      quaternion.x = Math.sqrt(0.5)
      quaternion.y = 0
      quaternion.z = 0
      matrix = matrix.rot4(quaternion)
      expect(matrix[0]).to eql [4.0, 4.0, 4.0, 4.0]
      expect(matrix[1][0]).to be_within(1e-10).of(2.0)
      expect(matrix[1][1]).to be_within(1e-10).of(2.0)
      expect(matrix[1][2]).to be_within(1e-10).of(2.0)
      expect(matrix[1][3]).to be_within(1e-10).of(2.0)
      expect(matrix[2][0]).to be_within(1e-10).of(-3.0)
      expect(matrix[2][1]).to be_within(1e-10).of(-3.0)
      expect(matrix[2][2]).to be_within(1e-10).of(-3.0)
      expect(matrix[2][3]).to be_within(1e-10).of(-3.0)
      expect(matrix[3]).to eql [1.0, 1.0, 1.0, 1.0]
    end
  end
end
