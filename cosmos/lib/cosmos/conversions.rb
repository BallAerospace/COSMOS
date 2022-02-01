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

module Cosmos
  autoload(:Conversion, 'cosmos/conversions/conversion.rb')
  autoload(:GenericConversion, 'cosmos/conversions/generic_conversion.rb')
  autoload(:PacketTimeFormattedConversion, 'cosmos/conversions/packet_time_formatted_conversion.rb')
  autoload(:PacketTimeSecondsConversion, 'cosmos/conversions/packet_time_seconds_conversion.rb')
  autoload(:PolynomialConversion, 'cosmos/conversions/polynomial_conversion.rb')
  autoload(:ProcessorConversion, 'cosmos/conversions/processor_conversion.rb')
  autoload(:ReceivedCountConversion, 'cosmos/conversions/received_count_conversion.rb')
  autoload(:ReceivedTimeFormattedConversion, 'cosmos/conversions/received_time_formatted_conversion.rb')
  autoload(:ReceivedTimeSecondsConversion, 'cosmos/conversions/received_time_seconds_conversion.rb')
  autoload(:SegmentedPolynomialConversion, 'cosmos/conversions/segmented_polynomial_conversion.rb')
  autoload(:UnixTimeConversion, 'cosmos/conversions/unix_time_conversion.rb')
  autoload(:UnixTimeFormattedConversion, 'cosmos/conversions/unix_time_formatted_conversion.rb')
  autoload(:UnixTimeSecondsConversion, 'cosmos/conversions/unix_time_seconds_conversion.rb')
end
