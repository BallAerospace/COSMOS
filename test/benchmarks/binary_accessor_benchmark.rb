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

require 'benchmark/ips'
require 'cosmos'
require 'cosmos/packets/binary_accessor'

Benchmark.ips do |x|
  @data = "\x80\x81\x82\x83\x84\x85\x86\x87\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F"
  @baseline_data = "\x80\x81\x82\x83\x84\x85\x86\x87\x00\x09\x0A\x0B\x0C\x0D\x0E\x0F"
  x.report('read') do
    Cosmos::BinaryAccessor.read(-16, 16, :BLOCK, @data, :BIG_ENDIAN)
  end
  x.report('write') do
    Cosmos::BinaryAccessor.write(@baseline_data[14..15], -16, 16, :STRING, @data, :BIG_ENDIAN, :ERROR)
  end
end
