# encoding: ascii-8bit

module Cosmos
  autoload(:Processor, 'cosmos/processors/processor.rb')
  autoload(:StatisticsProcessor, 'cosmos/processors/statistics_processor.rb')
  autoload(:WatermarkProcessor, 'cosmos/processors/watermark_processor.rb')
  autoload(:NewPacketLogProcessor, 'cosmos/processors/new_packet_log_processor.rb')
end
