# encoding: ascii-8bit

module Cosmos
  autoload(:PacketLogWriter, 'cosmos/packet_logs/packet_log_writer.rb')
  autoload(:PacketLogWriterPair, 'cosmos/packet_logs/packet_log_writer_pair.rb')
  autoload(:PacketLogReader, 'cosmos/packet_logs/packet_log_reader.rb')
  autoload(:CcsdsLogReader, 'cosmos/packet_logs/ccsds_log_reader.rb')
end
