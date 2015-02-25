# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require "spec_helper"
require "cosmos/utilities/quaternion"
include Math

module Cosmos
  describe Quaternion do

    describe "initialize" do
      it "creates 0.0 elements" do
        expect(Quaternion.new.data).to eql [0.0,0.0,0.0,0.0]
      end

      it "takes an initialization array" do
        expect(Quaternion.new([1.1,2.2,3.3,4.4]).data).to eql [1.1,2.2,3.3,4.4]
      end
    end

    describe "[] and []=" do
      it "gets and set individual elements" do
        q = Quaternion.new
        q[0] = 5.5
        expect(q[0]).to eql 5.5
      end
    end

    describe "data and data=" do
      it "gets and set all elements" do
        q = Quaternion.new
        q.data = [1.1,2.2,3.3,4.4]
        expect(q.data).to eql [1.1,2.2,3.3,4.4]
      end
    end

    describe "q0, q1, q2, q3 getter and setter" do
      it "gets and set an element" do
        q = Quaternion.new()
        q.q0 = 1.1
        q.q1 = 2.2
        q.q2 = 3.3
        q.q3 = 4.4
        expect(q.q0).to eql 1.1
        expect(q.q1).to eql 2.2
        expect(q.q2).to eql 3.3
        expect(q.q3).to eql 4.4
      end
    end

    describe "*" do
      it "multiplies quaternions" do
        q1 = Quaternion.new([1,0,0,1])
        q2 = Quaternion.new([0,1,0,1])
        expect((q1 * q2).data).to eql [1,1,1,1]
        q1 = Quaternion.new([0,1,0,1])
        q2 = Quaternion.new([0,0,1,1])
        expect((q1 * q2).data).to eql [1,1,1,1]
        q1 = Quaternion.new([1,0,0,1])
        q2 = Quaternion.new([0,0,1,1])
        expect((q1 * q2).data).to eql [1,-1,1,1]
      end
    end

    describe "inverse" do
      it "returns the inverse" do
        expect(Quaternion.new([1,2,3,4]).inverse.data).to eql [-1,-2,-3,4]
      end
    end

    describe "vecrot" do
      it "rotates the vector using the quaternion" do
        expect(Quaternion.new([1,0,0,1]).vecrot([1,1,1])).to eql [2,2,-2]
      end
    end

    describe "Quaternion.signnz" do
      it "returns 1 for zero" do
        expect(Quaternion.signnz(0)).to eql 1.0
      end

      it "returns 1 for positive" do
        expect(Quaternion.signnz(0.5)).to eql 1.0
      end

      it "returns -1 for negative" do
        expect(Quaternion.signnz(-123456789)).to eql -1.0
      end
    end

    describe "Quaternion.qfromc" do
      it "creates a quaternion from the matrix" do
        q = Quaternion.qfromc(Matrix[[1,0,0],[0,1,0],[0,0,1]])
        expect(q).to be_a Quaternion
        expect(q.data).to eql [0.0,0.0,0.0,1.0]
      end
    end
  end
end

