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

require 'benchmark'

iterations = 10_000_000

value = "hi"

Benchmark.bm(30) do |x|
  x.report("value.is_a?") { iterations.times { if value.is_a?(Integer); end } }
  x.report("value.respond_to?") { iterations.times { if value.respond_to?(:abs); end } }
  x.report("type === value") { iterations.times { if Integer === value; end } }
  x.report("case when") do
    iterations.times do
      case value
      when Integer
      end
    end
  end
  x.report("if x2") do
    iterations.times do
      if value.is_a?(Integer)
      elsif value.is_a?(String)
      end
    end
  end
  x.report("case when x2") do
    iterations.times do
      case value
      when Integer
      when String
      end
    end
  end
end
