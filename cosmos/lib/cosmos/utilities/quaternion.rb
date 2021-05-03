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

require 'cosmos/core_ext/matrix'

include Math

module Cosmos
  # A quaternion where q[3] is the scalar component
  class Quaternion
    # Create a Quaternion given the initial components
    #
    # @param array [Array<Float, Float, Float, Float>] Initial values where
    # the forth value is the scalar
    # or [Array<Float, Float, Float>] which as an axis of rotation
    # @param angle [Float] if axis given for array parameter
    def initialize(array = [0.0, 0.0, 0.0, 0.0], angle = nil)
      if array.length == 4
        @data = array.clone
      elsif array.length == 3 and angle
        a = 0.5 * angle
        s = sin(a) / sqrt(array[0] * array[0] + array[1] * array[1] + array[2] * array[2])
        @data = []
        @data[0] = array[0] * s
        @data[1] = array[1] * s
        @data[2] = array[2] * s
        @data[3] = cos(a)
      else
        raise "Invalid arguments given to Quaternion.new"
      end
    end

    # @return [String] The name of the class and the object_id followed by the
    #   data
    def to_s
      "#<Cosmos::Quaternion:0x#{self.object_id.to_s(16)}> #{@data}"
    end

    # @param index [Integer] Which component to access
    # @return [Float] The quaternion component
    def [](index)
      return data[index]
    end

    # @param index [Integer] The component to set
    # @param value [Float] The quaternion component
    def []=(index, value)
      @data[index] = value
    end

    # @return [Array<Float, Float, Float, Float>] The entire quaternion where the
    # the last element is the scalar
    attr_accessor :data

    # @return [Float] The first element
    def q0
      return @data[0]
    end
    alias x q0

    # @return [Float] The second element
    def q1
      return @data[1]
    end
    alias y q1

    # @return [Float] The third element
    def q2
      return @data[2]
    end
    alias z q2

    # @return [Float] The scalar element
    def q3
      return @data[3]
    end
    alias w q3

    # @param value [Float] Set the first element
    def q0=(value)
      @data[0] = value
    end

    # @param value [Float] Set the second element
    def q1=(value)
      @data[1] = value
    end

    # @param value [Float] Set the third element
    def q2=(value)
      @data[2] = value
    end

    # @param value [Float] Set the scalar element
    def q3=(value)
      @data[3] = value
    end

    # @param other [Quaternion] Quaternion to multiply with
    # @return [Quaternion] New quaternion resulting from the muliplication
    def *(other)
      q = Quaternion.new()

      q[0] =  (@data[3] * other[0]) - (@data[2] * other[1]) +
        (@data[1] * other[2]) + (@data[0] * other[3])
      q[1] =  (@data[2] * other[0]) + (@data[3] * other[1]) -
        (@data[0] * other[2]) + (@data[1] * other[3])
      q[2] = -(@data[1] * other[0]) + (@data[0] * other[1]) +
        (@data[3] * other[2]) + (@data[2] * other[3])
      q[3] = -(@data[0] * other[0]) - (@data[1] * other[1]) -
        (@data[2] * other[2]) + (@data[3] * other[3])

      return q
    end
    alias qmult *

    # @return [Quaternion] The inverse of the current quaternion
    def inverse
      Quaternion.new([-@data[0], -@data[1], -@data[2], @data[3]])
    end
    alias inv inverse

    # @return [Quaternion] The normalized version of the current quaternion
    def normalize
      t = @data[0] * @data[0] + @data[1] * @data[1] + @data[2] * @data[2] + @data[3] * @data[3]
      if t > 0.0
        f = 1.0 / sqrt(t)
        @data[0] *= f
        @data[1] *= f
        @data[2] *= f
        @data[3] *= f
      end
      return self
    end

    # Rotate a vector using this quaternion
    #
    # @param vector [Array<Float, Float Float>] Vector to rotate
    # @return [Array<Float, Float, Float>] New rotated vector
    def vecrot(vector)
      temp_q = self.inverse * (Quaternion.new([vector[0], vector[1], vector[2], 0]) * self)
      return [temp_q[0], temp_q[1], temp_q[2]]
    end

    def self.arc(f, t)
      dot = f[0] * t[0] + f[1] * t[1] + f[2] * t[2]
      if dot > 0.999999
        x = 0.0
        y = 0.0
        z = 0.0
        w = 1.0
      elsif dot < -0.999999
        if (f.z.abs < f.x.abs) && (f.z.abs < f.y.abs)
          x = f[0] * f[2] - f[2] * f[1]
          y = f[2] * f[0] + f[1] * f[2]
          z = -f[1] * f[1] - f[0] * f[0]
        elsif f.y.abs < f.x.abs
          x = f[1] * f[2] - f[0] * f[1]
          y = f[0] * f[0] + f[2] * f[2]
          z = -f[2] * f[1] - f[1] * f[0]
        else
          x = -f[2] * f[2] - f[1] * f[1]
          y = f[1] * f[0] - f[0] * f[2]
          z = f[0] * f[1] + f[2] * f[0]
        end

        dot = x * x + y * y + z * z
        div = sqrt(dot)
        x /= div
        y /= div
        z /= div
        w = 0.0
      else
        div = sqrt((dot + 1.0) * 2.0)
        x = (f[1] * t[2] - f[2] * t[1]) / div
        y = (f[2] * t[0] - f[0] * t[2]) / div
        z = (f[0] * t[1] - f[1] * t[0]) / div
        w = div * 0.5
      end
      return Quaternion.new([x,y,z,w])
    end

    # @param value [Numeric]
    # @return [Float] The sign of a number as 1.0 = positive, -1.0 = negative
    def self.signnz(value)
      if value >= 0.0
        return 1.0
      else
        return -1.0
      end
    end

    # Create a quaternion from a direction-cosine matrix (rotation matrix).
    # Reference Article: J. Spacecraft Vol.13, No.12 Dec.1976 p754
    #
    # @param rotation_matrix [Matrix] The rotation matrix
    # @return [Quaternion] New quaternion resulting from the matrix
    def self.qfromc(rotation_matrix)
      tracec = rotation_matrix.trace()
      p = 1.0 + tracec
      if p < 0.0
        p = 0.0
      end
      q = Quaternion.new([0.0, 0.0, 0.0, sqrt(p) / 2.0])
      if q[3] >= 0.1
        factor = 1.0 / (4.0 * q[3])
        q[0] = (rotation_matrix[1][2] - rotation_matrix[2][1]) * factor
        q[1] = (rotation_matrix[2][0] - rotation_matrix[0][2]) * factor
        q[2] = (rotation_matrix[0][1] - rotation_matrix[1][0]) * factor
      else # For rotations near 180 degrees
        q[0] = sqrt(((2.0 * rotation_matrix[0][0]) + 1.0 - tracec) / 4.0)
        q[1] = sqrt(((2.0 * rotation_matrix[1][1]) + 1.0 - tracec) / 4.0)
        q[2] = sqrt(((2.0 * rotation_matrix[2][2]) + 1.0 - tracec) / 4.0)

        i = 0
        if q[1] >= q[i]
          i = 1
        end
        if q[2] >= q[i]
          i = 2
        end
        case i
        when 0
          q[0] = q[0].abs * Quaternion.signnz(rotation_matrix[1][2] - rotation_matrix[2][1])
          q[1] = q[1].abs * Quaternion.signnz((rotation_matrix[1][0] + rotation_matrix[0][1]) * q[0])
          q[2] = q[2].abs * Quaternion.signnz((rotation_matrix[2][0] + rotation_matrix[0][2]) * q[0])
        when 1
          q[1] = q[1].abs * Quaternion.signnz(rotation_matrix[2][0] - rotation_matrix[0][2])
          q[0] = q[0].abs * Quaternion.signnz((rotation_matrix[1][0] + rotation_matrix[0][1]) * q[1])
          q[2] = q[2].abs * Quaternion.signnz((rotation_matrix[2][1] + rotation_matrix[1][2]) * q[1])
        else
          q[2] = q[2].abs * Quaternion.signnz(rotation_matrix[0][1] - rotation_matrix[1][0])
          q[0] = q[0].abs * Quaternion.signnz((rotation_matrix[0][2] + rotation_matrix[2][0]) * q[2])
          q[1] = q[1].abs * Quaternion.signnz((rotation_matrix[1][2] + rotation_matrix[2][1]) * q[2])
        end
      end

      return q
    end
  end
end
