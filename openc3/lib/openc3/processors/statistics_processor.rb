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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'openc3/processors/processor'

module OpenC3
  class StatisticsProcessor < Processor
    # @return [Array] The set of samples stored by the processor
    attr_accessor :samples

    # @param item_name [String] The name of the item to gather statistics on
    # @param samples_to_average [Integer] The number of samples to store for calculations
    # @param value_type #See Processor::initialize
    def initialize(item_name, samples_to_average, value_type = :CONVERTED)
      super(value_type)
      @item_name = item_name.to_s.upcase
      @samples_to_average = Integer(samples_to_average)
      reset()
    end

    # Run statistics on the item
    #
    # See Processor#call
    def call(packet, buffer)
      value = packet.read(@item_name, @value_type, buffer)
      # Don't process NaN or Infinite values
      return if value.to_f.nan? || value.to_f.infinite?

      @samples << value
      @samples = @samples[-@samples_to_average..-1] if @samples.length > @samples_to_average
      mean, stddev = Math.stddev_sample(@samples)
      @results[:MAX] = @samples.max
      @results[:MIN] = @samples.min
      @results[:MEAN] = mean
      @results[:STDDEV] = stddev
    end

    # Reset any state
    def reset
      @samples = []
      @results[:MAX] = nil
      @results[:MIN] = nil
      @results[:MEAN] = nil
      @results[:STDDEV] = nil
    end

    # Make a light weight clone of this processor. This only creates a new hash of results
    #
    # @return [Processor] A copy of the processor with a new hash of results
    def clone
      processor = super()
      processor.samples = processor.samples.clone
      processor
    end
    alias dup clone

    # Convert to configuration file string
    def to_config
      "  PROCESSOR #{@name} #{self.class.name.to_s.class_name_to_filename} #{@item_name} #{@samples_to_average} #{@value_type}\n"
    end

    def as_json(*a)
      { 'name' => @name, 'class' => self.class.name, 'params' => [@item_name, @samples_to_average, @value_type.to_s] }
    end
  end # class StatisticsProcessor
end
