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

module OpenC3
  autoload(:Conversion, 'openc3/conversions/conversion.rb')
  autoload(:GenericConversion, 'openc3/conversions/generic_conversion.rb')
  autoload(:PacketTimeFormattedConversion, 'openc3/conversions/packet_time_formatted_conversion.rb')
  autoload(:PacketTimeSecondsConversion, 'openc3/conversions/packet_time_seconds_conversion.rb')
  autoload(:PolynomialConversion, 'openc3/conversions/polynomial_conversion.rb')
  autoload(:ProcessorConversion, 'openc3/conversions/processor_conversion.rb')
  autoload(:ReceivedCountConversion, 'openc3/conversions/received_count_conversion.rb')
  autoload(:ReceivedTimeFormattedConversion, 'openc3/conversions/received_time_formatted_conversion.rb')
  autoload(:ReceivedTimeSecondsConversion, 'openc3/conversions/received_time_seconds_conversion.rb')
  autoload(:SegmentedPolynomialConversion, 'openc3/conversions/segmented_polynomial_conversion.rb')
  autoload(:UnixTimeConversion, 'openc3/conversions/unix_time_conversion.rb')
  autoload(:UnixTimeFormattedConversion, 'openc3/conversions/unix_time_formatted_conversion.rb')
  autoload(:UnixTimeSecondsConversion, 'openc3/conversions/unix_time_seconds_conversion.rb')
end
