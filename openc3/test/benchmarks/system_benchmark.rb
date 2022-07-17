require 'openc3'
require 'benchmark'
ENV['OPENC3_NO_STORE'] = 'true'

dir = File.expand_path(File.join(__dir__, '..', '..', 'spec', 'install', 'config', 'targets'))
puts dir
targets = ["SYSTEM", "INST", "EMPTY"]
n = 5000000
Benchmark.bm do |x|
  x.report("system") do
    OpenC3::System.class_variable_set(:@@instance, nil)
    OpenC3::System.instance(targets, dir)
  end
end
