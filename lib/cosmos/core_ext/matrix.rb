# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'matrix'
include Math

# COSMOS specific additions to the Ruby Matrix class
class Matrix

  old_verbose = $VERBOSE; $VERBOSE = nil
  # Allow [i] to return an entire row instead of being forced to pass both the
  # row and column (i.e [i,j]) to return an individual element.
  #
  # @param i [Integer] Row index
  # @param j [Integer] Optional column index. Pass nil to return the entire row
  #   given by i.
  # @return Either the row as an Array or the element
  def [](i, j = nil)
    if j
      @rows[i][j]
    else
      @rows[i]
    end
  end
  $VERBOSE = old_verbose

  # Allow [i,j] = x to set the element at row i, column j to value x
  #
  # @param i [Integer] Row index
  # @param j [Integer] Column index
  # @param value [Object] The value to set
  def []=(i, j, value)
    @rows[i][j] = value
  end

  # Creates a rotation matrix around one axis as defined by:
  # http://mathworld.wolfram.com/RotationMatrix.html
  #
  # @param axis [Symbol] Must be :X,:x,1, or :Y,:y,2, or :Z,:z,3
  # @param rotation_angle_in_radians [Float] The rotation angle in radians to
  #   rotate the maxtrix about the given axis
  #
  def self.rot(axis, rotation_angle_in_radians)
    rotation_matrix = Matrix.identity(3).to_a

    case axis
    when :X, :x, 1
      rotation_matrix[1][1] = cos(rotation_angle_in_radians)
      rotation_matrix[1][2] = sin(rotation_angle_in_radians)
      rotation_matrix[2][2] = rotation_matrix[1][1]
      rotation_matrix[2][1] = -(rotation_matrix[1][2])
    when :Y, :y, 2
      rotation_matrix[0][0] = cos(rotation_angle_in_radians)
      rotation_matrix[2][0] = sin(rotation_angle_in_radians)
      rotation_matrix[2][2] = rotation_matrix[0][0]
      rotation_matrix[0][2] = -(rotation_matrix[2][0])
    when :Z, :z, 3
      rotation_matrix[0][0] = cos(rotation_angle_in_radians)
      rotation_matrix[0][1] = sin(rotation_angle_in_radians)
      rotation_matrix[1][1] = rotation_matrix[0][0]
      rotation_matrix[1][0] = -(rotation_matrix[0][1])
    end

    return Matrix[*rotation_matrix]
  end

  # Sums the diagonal values of the matrix
  def trace
    sum = 0.0
    @rows.length.times do |index|
      value = @rows[index][index]
      if not value.nil?
        sum += value
      else
        break
      end
    end
    return sum
  end

  def self.cfromq(quaternion)
    result = Matrix.zero(3)

    tx = 2.0 * quaternion.x
    ty = 2.0 * quaternion.y
    tz = 2.0 * quaternion.z
    twx = tx * quaternion.w
    twy = ty * quaternion.w
    twz = tz * quaternion.w
    txx = tx * quaternion.x
    txy = ty * quaternion.x
    txz = tz * quaternion.x
    tyy = ty * quaternion.y
    tyz = tz * quaternion.y
    tzz = tz * quaternion.z

    result[0][0] = 1.0 - tyy - tzz;
    result[0][1] = txy + twz;
    result[0][2] = txz - twy;
    result[1][0] = txy - twz;
    result[1][1] = 1.0 - txx - tzz;
    result[1][2] = tyz + twx;
    result[2][0] = txz + twy;
    result[2][1] = tyz - twx;
    result[2][2] = 1.0 - txx - tyy;

    return result
  end

  def trans4(x, y, z)
    @rows[3][0] += x*@rows[0][0] + y*@rows[1][0] + z*@rows[2][0]
    @rows[3][1] += x*@rows[0][1] + y*@rows[1][1] + z*@rows[2][1]
    @rows[3][2] += x*@rows[0][2] + y*@rows[1][2] + z*@rows[2][2]
    @rows[3][3] += x*@rows[0][3] + y*@rows[1][3] + z*@rows[2][3]
    return self
  end

  def scale4(x, y, z)
    @rows[0][0] *= x; @rows[0][1] *= x; @rows[0][2] *= x; @rows[0][3] *= x;
    @rows[1][0] *= y; @rows[1][1] *= y; @rows[1][2] *= y; @rows[1][3] *= y;
    @rows[2][0] *= z; @rows[2][1] *= z; @rows[2][2] *= z; @rows[2][3] *= z;
    return self
  end

  def rot4(quaternion)
    # Get rotation matrix
    r = Matrix.cfromq(quaternion)

    4.times do |row|
      x = @rows[0][row]
      y = @rows[1][row]
      z = @rows[2][row]
      3.times do |i|
        @rows[i][row] = x*r[i][0] + y*r[i][1] + z*r[i][2]
      end
    end
  end

end
