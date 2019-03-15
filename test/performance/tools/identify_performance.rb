require 'cosmos'
require 'tempfile'

module Cosmos
  tt = Time.now
  tf = Tempfile.new('unittest')
  tf.puts '# This is a comment'
  tf.puts '#'
  tf.puts 'TELEMETRY tgt1 pkt1 BIG_ENDIAN "TGT1 PKT1 Description"'
  tf.puts '  APPEND_ID_ITEM item1 16 UINT 1 "Item1"'
  tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 4 5'
  tf.puts '  APPEND_ITEM item2 8 UINT "Item2"'
  tf.puts '    LIMITS DEFAULT 1 ENABLED 1 2 4 5'
  tf.puts '  APPEND_ITEM item3 8 UINT "Item3"'
  tf.puts '    POLY_READ_CONVERSION 0 2'
  tf.puts '  APPEND_ITEM item4 8 UINT "Item4"'
  tf.puts '    POLY_READ_CONVERSION 0 2'
  tf.puts 'TELEMETRY tgt1 pkt2 BIG_ENDIAN "TGT1 PKT2 Description"'
  tf.puts '  APPEND_ID_ITEM item1 16 UINT 2 "Item1"'
  tf.puts '  APPEND_ITEM item2 8 UINT "Item2"'
  10000.times do |index|
    tf.puts "TELEMETRY tgt1 pkt#{10000 + index} BIG_ENDIAN \"TGT1 PKT#{10000 + index} Description\""
    tf.puts "  APPEND_ID_ITEM item1 16 UINT #{10000 + index} \"Item1\""
    tf.puts '  APPEND_ITEM item2 8 UINT "Item2"'
    tf.puts "COMMAND tgt1 cmd#{10000 + index} BIG_ENDIAN \"TGT1 CMD#{10000 + index} Description\""
    tf.puts "  APPEND_ID_PARAMETER item1 16 UINT #{10000 + index} #{10000 + index} #{10000 + index} \"Item1\""
    tf.puts '  APPEND_PARAMETER item2 8 UINT 0 0 0 "Item2"' 
  end
  tf.close

  target = Target.new('TGT1')
  System.new
  System.targets['TGT1'] = target

  STDOUT.puts "Write time = #{Time.now - tt} seconds"
  tt = Time.now
  pc = PacketConfig.new
  pc.process_file(tf.path, "SYSTEM")
  @tlm = Telemetry.new(pc)
  @cmd = Commands.new(pc)
  STDOUT.puts "Done time = #{Time.now - tt} seconds"
  tf.unlink
  
  buffer = "\x30\x02\x02\x03\x04"

  tt = Time.now
  target.tlm_unique_id_mode = false
  packet = nil
  1000.times do
    packet = @tlm.identify!(buffer, nil)
  end
  STDOUT.puts "Tlm Fast Identify Time = #{Time.now - tt} seconds"
  puts packet.packet_name

  tt = Time.now
  target.tlm_unique_id_mode = true
  packet = nil
  1000.times do
    packet = @tlm.identify!(buffer, nil)
  end
  STDOUT.puts "Tlm Normal Identify Time = #{Time.now - tt} seconds"
  puts packet.packet_name      

  tt = Time.now
  target.cmd_unique_id_mode = false
  packet = nil
  1000.times do
    packet = @cmd.identify(buffer, nil)
  end
  STDOUT.puts "Cmd Fast Identify Time = #{Time.now - tt} seconds"
  puts packet.packet_name

  tt = Time.now
  target.cmd_unique_id_mode = true
  packet = nil
  1000.times do
    packet = @cmd.identify(buffer, nil)
  end
  STDOUT.puts "Cmd Normal Identify Time = #{Time.now - tt} seconds"
  puts packet.packet_name      

end # module Cosmos