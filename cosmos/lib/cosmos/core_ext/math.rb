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

# COSMOS specific additions to the Ruby Math module. The algorithms implemented
# here are based on standard deviation algorithms based on Wikipedia Algorithms
# for calculating variance, Section 3.
module Math
  # Add all the module instance methods as module functions so we can call them
  # either as Math.sin_squared or directly if we "include Math"
  extend self

  # Power reduction formula. Calculates sin squared which is
  # (1 - cos(2 * angle)) / 2
  #
  # @param angle [Float] Angle in degrees
  # @return [Float] sin(angle) squared
  def sin_squared(angle)
    return (1.0 - Math.cos(2.0 * angle)) / 2.0
  end

  # Power reduction formula. Calculates cos squared which is
  # (1 + cos(2 * angle)) / 2
  #
  # @param angle [Float] Angle in degrees
  # @return [Float] cos(angle) squared
  def cos_squared(angle)
    return (1.0 + Math.cos(2.0 * angle)) / 2.0
  end

  # Calculates the population variance of a group of numbers. If the population
  # is finite the population variance is the variance of the underlying
  # probability distribution.
  #
  # @param array [Array<Numeric>] Array of values
  # @return [Float, Float] The first value is the mean and the second is the
  #   variance
  def variance_population(array)
    mean, m2, num_values = variance_generic(array)
    if num_values != 0.0
      return [mean, m2 / num_values]
    else
      return [mean, 0.0]
    end
  end

  # Calculates the sample variance of a group of numbers. If the population of
  # numbers is very large, it is not possible to count every value in the
  # population, so the computation must be performed on a sample of the
  # population.
  #
  # @param array [Array<Numeric>] Array of values
  # @return [Float, Float] The first value is the mean and the second is the
  #   variance
  def variance_sample(array)
    mean, m2, num_values = variance_generic(array)
    if num_values != 1.0
      return [mean, m2 / (num_values - 1.0)]
    else
      return [mean, 0.0]
    end
  end

  # Calculates the standard deviation of the population variation by taking the
  # square root of the population variance.
  #
  # @param array [Array<Numeric>] Array of values
  # @return [Float, Float] The first value is the mean and the second is the
  #   standard deviation
  def stddev_population(array)
    mean, variance = self.variance_population(array)
    return [mean, Math.sqrt(variance)]
  end

  # Calculates the standard deviation of the sample variation by taking the
  # square root of the sample variance.
  #
  # @param array [Array<Numeric>] Array of values
  # @return [Float, Float] The first value is the mean and the second is the
  #   standard deviation
  def stddev_sample(array)
    mean, variance = self.variance_sample(array)
    return [mean, Math.sqrt(variance)]
  end

  # Calculates luma, the brightness, given RGB values.
  #
  # @param red [Numeric] Red RGB value (0 - 255)
  # @param green [Numeric] Green RGB value (0 - 255)
  # @param blue [Numeric] Blue RGB value (0 - 255)
  # @return [Float] The calculated luma
  def luma_from_rgb_max_255(red, green, blue)
    (0.2126 * (red.to_f / 255.0)) + (0.7152 * (green.to_f / 255.0)) + (0.0722 * (blue.to_f / 255.0))
  end

  protected
  def variance_generic(array)
    num_values = 0.0
    mean = 0.0
    m2 = 0.0

    array.each do |value|
      value = value.to_f # so we work for arrays of floats or ints
      num_values += 1.0
      delta = value - mean
      mean = mean + (delta / num_values)
      m2 = m2 + delta * (value - mean)
    end

    return [mean, m2, num_values]
  end
end
