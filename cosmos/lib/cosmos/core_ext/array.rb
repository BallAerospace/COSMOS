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

require 'cosmos/ext/array' if RUBY_ENGINE == 'ruby' and !ENV['COSMOS_NO_EXT']

# COSMOS specific additions to the Ruby Array class
class Array
  # Redefine inspect to only print for small numbers of
  # items. Prevents exceptions taking forever to be raise with
  # large objects. See http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/105145
  alias old_inspect inspect

  # @param max_elements [Integer] The maximum number of elements in the array to
  #   print out before simply displaying the array class and object id
  # @return [String] String representation of the array
  def inspect(max_elements = 10)
    if self.length <= max_elements
      old_inspect()
    else
      '#<' + self.class.to_s + ':' + self.object_id.to_s + '>'
    end
  end

  # @return [Array] Cloned array after all elements called to_f
  def clone_to_f
    new_array = self.class.new(0)
    self.each do |value|
      new_array << value.to_f
    end
    new_array
  end

  # Returns the array index nearest to the passed in value. This only makes sense
  # for numerical arrays containing integers or floats. It has an optimized
  # algorithm if the array is sorted but will fail if passed unsorted data with
  # the sorted option.
  #
  # @param value [Numeric] A value to search for in the array
  # @param ordered_data [Boolean] Whether or not the data is sorted
  # @return [Integer] The index of the element closest to value
  def nearest_index(value, ordered_data = true)
    raise "Cannot search on empty array" if self.empty?

    if ordered_data
      last_index  = self.length - 1
      first_value = self[0].to_f
      last_value = self[-1].to_f
      return 0 if first_value == last_value

      slope = last_index.to_f / (last_value - first_value)
      offset = -(slope * first_value)
      guess_index = ((slope * value.to_f) + offset).to_i

      # Return immediately for boundary conditions
      return 0 if guess_index < 0
      return last_index if guess_index > last_index

      # Verify guess index
      previous_guess_index = nil
      previous_guess_value = nil

      # While in the valid range of indexes
      while guess_index >= 0 and guess_index <= last_index

        # Retrieve the value at our current guess index
        guess_value = self[guess_index]

        # We're done if we found the exact value
        return guess_index if guess_value == value

        if previous_guess_value # Determine if we did better or worse
          # Was previous guess better or worse?
          if (guess_value - value).abs <= (previous_guess_value - value).abs
            # Previous Guess Worse or the same
            if guess_value > value # Moving with decreasing indexes
              if previous_guess_value > value # Still moving in right direction
                previous_guess_index = guess_index
                guess_index -= 1
              else # We passed the value
                return guess_index
              end
            else # guess_value < value and moving with increasing indexes
              if previous_guess_value < value # Still moving in right direction
                previous_guess_index = guess_index
                guess_index += 1
              else # We passed the value
                return guess_index
              end
            end
          else
            # Previous Guess Better
            return previous_guess_index
          end
        else # Move to the next point
          previous_guess_index = guess_index
          if guess_value > value
            guess_index -= 1
          else # guess_value < value
            guess_index += 1
          end
        end
        previous_guess_value = guess_value
      end

      # Return our best guess
      return 0 if guess_index < 0

      return last_index
    else # Brute force search
      # Calculate the initial delta
      min_delta     = (self[0] - value).abs
      closest_index = 0
      self.each_with_index do |self_value, index|
        # Calculate the delta between the current value and value we are
        # searching for
        delta = (value - self_value).abs
        # If the newly calculate delta is less than or equal to are previous
        # minimum delta then we proceed
        if delta <= min_delta
          # There is a special case if the delta is equal to the previously
          # calculated delta. We want to round up in this case so we check if
          # the value we are searching for is greater than the current value.
          # If so we skip this value since we don't want to round down.
          next if (delta == min_delta) and (value > self_value)

          min_delta = delta
          closest_index = index
        end
      end
      return closest_index
    end
  end

  # Returns the index of the first element which is less than or equal to the
  # passed in value.
  #
  # NOTE: This routine only works on sorted data!
  #
  # @param value [Numeric] The value to search for in the array
  # @return [Fixnum] The index of the element which is less than or equal to
  #   the value
  def index_lt_eq(value)
    index = nearest_index(value)

    # Keep backing up if self[index - 1] == value to move past duplicates
    while index > 0 and self[index - 1] == value
      index -= 1
    end

    return index if self[index] <= value

    index -= 1 if index > 0
    return index
  end

  # Returns the index of the last element which is greater than or equal to the
  # passed in value.
  #
  # NOTE: This routine only works on sorted data!
  #
  # @param value [Numeric] The value to search for in the array
  # @return [Fixnum] The index of the element which is greater than or equal to
  #   the value
  def index_gt_eq(value)
    index = nearest_index(value)
    last_index = self.length - 1

    # Keep moving forward if self[index - 1] == value to move past duplicates
    while index < last_index and self[index + 1] == value
      index += 1
    end

    return index if self[index] >= value

    index += 1 if (self.length - 1) > index
    return index
  end

  # Returns the range of array elements which contain both the start value and
  # end value.
  #
  # NOTE: This routine only works on sorted data!
  #
  # @param start_value [Numeric] The start value to search for (must be less
  #   than end_value)
  # @param end_value [Numeric] The end value to search for
  # @return [Range] The range of array elements which contain both the
  #   start_value and end_value
  def range_containing(start_value, end_value)
    raise "end_value: #{end_value} must be greater than start_value: #{start_value}" if end_value < start_value

    Range.new(index_lt_eq(start_value), index_gt_eq(end_value))
  end

  # Returns the range of array elements which within both the start value and
  # end value.
  #
  # NOTE: This routine only works on sorted data!
  #
  # @param start_value [Numeric] The start value to search for (must be less
  #   than end_value)
  # @param end_value [Numeric] The end value to search for
  # @return [Range] The range of array elements which contain both the
  #   start_value and end_value
  def range_within(start_value, end_value)
    raise "end_value: #{end_value} must be greater than start_value: #{start_value}" if end_value < start_value

    range = Range.new(index_gt_eq(start_value), index_lt_eq(end_value))
    # Sometimes we get a backwards range so check for that and reverse it
    range = Range.new(range.last, range.first) if range.last < range.first
    range
  end

  if !(self.method_defined?(:sum))
    # @return [Numeric] The sum of all the elements in the array
    def sum
      self.inject(0, :+)
    end
  end

  # return [Float] The mean of all the elements in the array
  def mean
    return 0.0 if self.empty?

    return self.sum / self.length.to_f
  end

  # return [Array] A new array with each value of the original squared
  def squared
    self.map { |value| value * value }
  end

  if RUBY_ENGINE != 'ruby' or ENV['COSMOS_NO_EXT']
    # return [Numeric, Fixnum] The first maximum value and its index
    def max_with_index
      maximum = nil
      maximum_index = nil

      if self.length > 0
        maximum = self[0]
        maximum_index = 0

        (1..(self.length - 1)).each do |index|
          value = self[index]

          if value > maximum
            maximum = value
            maximum_index = index
          end
        end
      end

      return [maximum, maximum_index]
    end

    # return [Numeric, Fixnum] The first minimum value and its index
    def min_with_index
      minimum = nil
      minimum_index = nil

      if self.length > 0
        minimum = self[0]
        minimum_index = 0

        (1..(self.length - 1)).each do |index|
          value = self[index]

          if value < minimum
            minimum = value
            minimum_index = index
          end
        end
      end

      return [minimum, minimum_index]
    end
  end

  # @param num_buckets [Integer] The number of buckets (groups of numbers) that
  #   will be used when histogramming. nil indicates to use as many buckets as
  #   necessary to cause each bucket to have a unique element.
  # @param numeric [Boolean] Whether the array data is numeric
  # @param block [Proc] If a block is given it will be called to sort buckets
  #   with the same object. This might be necessary if your data is not numeric
  #   and you want to override the way your objects compare.
  # @return [Array<Array(first_value, last_value, num_values)>] Array of buckets
  #   which are arrays containing the first value that is found in the bucket,
  #   the last value found in the bucket, and the total number of values in the
  #   bucket.
  def histogram(num_buckets = nil, numeric = false, &block)
    buckets = {}

    # Count the occurance of each value
    self.each do |value|
      buckets[value] ||= 0
      buckets[value] += 1
    end

    # Sort buckets by value, use block for sorting if given
    if block_given?
      sorted_buckets = buckets.sort { |x, y| yield(x, y) }
    else
      sorted_buckets = buckets.sort
    end

    reduced_buckets = []
    if num_buckets
      # Validate num_buckets
      raise "Invalid num_buckets #{num_buckets}" if num_buckets.to_i <= 0

      # Handle histogram types
      if numeric
        # Numeric histograms use the same sized range for each bucket
        first_value   = sorted_buckets[0][0]
        last_value    = sorted_buckets[-1][0]
        delta         = last_value - first_value
        bucket_size   = delta.to_f / num_buckets.to_f
        integers      = false
        integers      = true if first_value.kind_of?(Integer) and last_value.kind_of?(Integer)
        if integers
          bucket_size = bucket_size.ceil
          last_value = first_value + bucket_size * num_buckets - 1
          delta = last_value - first_value
          (delta + 1).times do |index|
            buckets[first_value + index] ||= 0
          end
          if block_given?
            sorted_buckets = buckets.sort { |val1, val2| yield(val1, val2) }
          else
            sorted_buckets = buckets.sort
          end
        end
        bucket_ranges = []
        current_value = first_value
        num_buckets.times do |bucket_index|
          if bucket_index == (num_buckets - 1)
            bucket_ranges[bucket_index] = (current_value)..(last_value)
          else
            if integers
              bucket_ranges[bucket_index] = (current_value)..(current_value + bucket_size - 1)
            else
              bucket_ranges[bucket_index] = (current_value)..(current_value + bucket_size)
            end
          end
          current_value += bucket_size
        end

        # Build the final buckets
        first_index  = 0
        sorted_index = 0
        num_buckets.times do |bucket_index|
          break if sorted_index > (sorted_buckets.length - 1)

          sum = 0
          bucket_range = bucket_ranges[bucket_index]
          while bucket_range.include?(sorted_buckets[sorted_index][0])
            sum += sorted_buckets[sorted_index][1]
            sorted_index += 1
            break if sorted_index > (sorted_buckets.length - 1)
          end
          reduced_buckets[bucket_index] = [bucket_range.first, bucket_range.last, sum]
        end
      else
        # Non-numeric histograms use the same number of items per bucket
        items_per_bucket = sorted_buckets.length / num_buckets.to_i
        items_per_bucket = 1 if items_per_bucket < 1
        bucket_sizes     = [items_per_bucket] * num_buckets
        excess_items     = sorted_buckets.length - (items_per_bucket * num_buckets)
        if excess_items > 0
          bucket_sizes.length.times do |bucket_size_index|
            break if excess_items <= 0

            bucket_sizes[bucket_size_index] += 1
            excess_items -= 1
          end
        end

        # Build the final buckets
        first_index = 0
        num_buckets.times do |bucket_index|
          break if first_index > (sorted_buckets.length - 1)

          if bucket_index == (num_buckets - 1)
            last_index = sorted_buckets.length - 1
          else
            last_index = first_index + bucket_sizes[bucket_index] - 1
            last_index = sorted_buckets.length - 1 if last_index > (sorted_buckets.length - 1)
          end
          sum = 0
          sorted_buckets[first_index..last_index].each { |key, value| sum += value }
          reduced_buckets[bucket_index] = [sorted_buckets[first_index][0], sorted_buckets[last_index][0], sum]
          first_index = first_index + bucket_sizes[bucket_index]
        end
      end
    else
      sorted_buckets.each { |key, value| reduced_buckets << [key, key, value] }
    end
    reduced_buckets
  end
end # class Array
