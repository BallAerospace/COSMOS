ENV['COSMOS_USERPATH'] = 'C:/git/COSMOS/demo'
require 'cosmos'
require 'cosmos/io/json_drb_object'
Cosmos::Logger.level = Cosmos::Logger::DEBUG

start_time = Time.utc(1970, 1, 1, 0, 0, 0)
end_time = Time.utc(2020, 1, 1, 0, 0, 0)

request = {}
request['start_time_sec'] = start_time.tv_sec
request['start_time_usec'] = start_time.tv_usec
request['end_time_sec'] = end_time.tv_sec
request['end_time_usec'] = end_time.tv_usec
request['item'] = ['INST', 'HEALTH_STATUS', 'TEMP1']
request['reduction'] = 'HOUR'
request['cmd_tlm'] = 'TLM'
request['offset'] = 0
request['limit'] = 100000
request['value_type'] = 'RAW_AVG'
# request['meta_ids'] = [1, 1062642]

puts "Connecting to Dart Decom Server..."
server = Cosmos::JsonDRbObject.new(Cosmos::System.connect_hosts['DART_DECOM'], Cosmos::System.ports['DART_DECOM'])
puts "Making request"
begin_time = Time.now
result = server.query(request)
finish_time = Time.now
puts result.inspect(10000)
puts "Got result of length #{result.length} in #{finish_time - begin_time} seconds"
puts "Closing..."
server.shutdown
