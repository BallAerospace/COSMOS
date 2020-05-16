# encoding: ascii-8bit

module Cosmos
  autoload(:Conversion, 'cosmos/conversions/conversion.rb')
  autoload(:GenericConversion, 'cosmos/conversions/generic_conversion.rb')
  autoload(:NewPacketLogConversion, 'cosmos/conversions/new_packet_log_conversion.rb')
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
