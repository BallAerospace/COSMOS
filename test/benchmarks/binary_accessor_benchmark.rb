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
