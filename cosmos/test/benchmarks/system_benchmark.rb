require 'cosmos'
require 'benchmark'
ENV['NO_STORE'] = 'true'
ENV['NO_FLUENTD'] = 'true'

dir = File.expand_path(File.join(__dir__, '..', '..', 'spec', 'install', 'config', 'targets'))
puts dir
targets = ["SYSTEM", "INST", "EMPTY"]
n = 5000000
Benchmark.bm do |x|
  x.report("system") do
    Cosmos::System.class_variable_set(:@@instance, nil)
    Cosmos::System.instance(targets, dir)
  end
end
