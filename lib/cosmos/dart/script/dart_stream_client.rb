ENV['COSMOS_USERPATH'] = 'C:/git/COSMOS/demo'
require 'cosmos'
Cosmos::Logger.level = Cosmos::Logger::DEBUG

request_packet = Cosmos::Packet.new('DART', 'DART')
request_packet.define_item('REQUEST', 0, 0, :BLOCK)

start_time = Time.utc(1970, 1, 1, 0, 0, 0)
end_time = Time.utc(2010, 1, 1, 0, 0, 0)

request = {}
request['start_time_sec'] = start_time.tv_sec
request['start_time_usec'] = start_time.tv_usec
request['end_time_sec'] = end_time.tv_sec
request['end_time_usec'] = end_time.tv_usec
#~ request['cmd_tlm'] = 'CMD'
#~ request['packets'] = [['INST', 'HEALTH_STATUS'], ['INST', 'ADCS']]
#~ request['meta_ids'] = [4962]
request_packet.write('REQUEST', JSON.dump(request))

interface = Cosmos::TcpipClientInterface.new(
  Cosmos::System.connect_hosts['DART_STREAM'], 
  Cosmos::System.ports['DART_STREAM'], 
  Cosmos::System.ports['DART_STREAM'],
  10, 10, 'PREIDENTIFIED')
puts "Connecting to Dart Stream Server..."
interface.connect
puts "Requesting #{request['packets'].inspect} from #{start_time} to #{end_time}..."
interface.write(request_packet)
puts "Receiving packets..."
while true
  packet = interface.read
  unless packet
    puts "Connection closed by Dart Stream Server"
    break
  end

  # Identify and update packet
  if packet.identified?
    begin
      # Preidentifed packet - place it into the current value table
      identified_packet = Cosmos::System.telemetry.update!(packet.target_name,
                                                   packet.packet_name,
                                                   packet.buffer)
    rescue RuntimeError
      # Packet identified but we don't know about it
      # Clear packet_name and target_name and try to identify
      Logger.warn "Received unknown identified telemetry: #{packet.target_name} #{packet.packet_name}"
      packet.target_name = nil
      packet.packet_name = nil
      identified_packet = Cosmos::System.telemetry.identify!(packet.buffer,
                                                     @interface.target_names)
    end
  else
    # Packet needs to be identified
    identified_packet = Cosmos::System.telemetry.identify!(packet.buffer,
                                                   @interface.target_names)
  end

  if identified_packet
    identified_packet.received_time = packet.received_time
    packet = identified_packet
  else
    unknown_packet = Cosmos::System.telemetry.update!('UNKNOWN', 'UNKNOWN', packet.buffer)
    unknown_packet.received_time = packet.received_time
    packet = unknown_packet
    data_length = packet.length
    string = "#{@interface.name} - Unknown #{data_length} byte packet starting: "
    num_bytes_to_print = [UNKNOWN_BYTES_TO_PRINT, data_length].min
    data_to_print = packet.buffer(false)[0..(num_bytes_to_print - 1)]
    data_to_print.each_byte do |byte|
      string << sprintf("%02X", byte)
    end
    Logger.error string
  end

  # Switch to correct configuration from SYSTEM META when needed
  if packet.target_name == 'SYSTEM'.freeze and packet.packet_name == 'META'.freeze
    Cosmos::System.load_configuration(packet.read('CONFIG'))
  end
  puts "Got: #{packet.target_name} #{packet.packet_name}"
end
