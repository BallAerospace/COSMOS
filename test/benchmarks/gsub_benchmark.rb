require 'cosmos'
require 'benchmark/ips'
require 'memory_profiler'

data = "this & that\n5 is > 0 but < 10"
copy = data.dup
puts copy.gsub("&","&amp;").gsub("\n",'').gsub(">","&gt;").gsub("<","&lt;")

copy = data.dup
copy.gsub!("&","&amp;")
copy.gsub!("\n",'')
copy.gsub!(">","&gt;")
copy.gsub!("<","&lt;")
puts copy

copy = data.dup
puts copy.gsub(/&/,"&amp;").gsub(/\n/,'').gsub(/>/,"&gt;").gsub(/</,"&lt;")

copy = data.dup
copy.gsub!(/&/,"&amp;")
copy.gsub!(/\n/,'')
copy.gsub!(/>/,"&gt;")
copy.gsub!(/</,"&lt;")
puts copy

AMP = '&amp;'.freeze
BLANK = ''.freeze
GT = '&gt;'.freeze
LT = '&lt;'.freeze
mapping = {'&'=>AMP,"\n"=>BLANK,'>'=>GT,'<'=>LT}
regex1 = Regexp.new('[&\n><]')
regex2 = Regexp.union(mapping.keys)
copy = data.dup
puts copy.gsub(regex1, mapping)
puts copy.gsub(regex2, mapping)

Benchmark.ips do |x|
  x.report('gsub mapping1') do
    copy = data.dup
    copy.gsub(regex1, mapping)
  end
  x.report('gsub mapping2') do
    copy = data.dup
    copy.gsub(regex1, mapping)
  end
  x.report('gsub! mapping1') do
    copy = data.dup
    copy.gsub!(regex1, mapping)
  end
  x.report('gsub! mapping2') do
    copy = data.dup
    copy.gsub!(regex1, mapping)
  end

  x.report('gsub') do
    copy = data.dup
    copy.gsub("&","&amp;").gsub("\n",'').gsub(">","&gt;").gsub("<","&lt;")
  end
  x.report('gsub!') do
    copy = data.dup
    copy.gsub!("&","&amp;")
    copy.gsub!("\n",'')
    copy.gsub!(">","&gt;")
    copy.gsub!("<","&lt;")
  end

  x.report('gsub regex') do
    copy = data.dup
    copy.gsub(/&/,"&amp;").gsub(/\n/,'').gsub(/>/,"&gt;").gsub(/</,"&lt;")
  end
  x.report('gsub! regex') do
    copy = data.dup
    copy.gsub!(/&/,"&amp;")
    copy.gsub!(/\n/,'')
    copy.gsub!(/>/,"&gt;")
    copy.gsub!(/</,"&lt;")
  end

  x.report('gsub freeze') do
    copy = data.dup
    copy.gsub("&".freeze,"&amp;".freeze).gsub("\n".freeze,''.freeze).gsub(">".freeze,"&gt;".freeze).gsub("<".freeze,"&lt;".freeze)
  end
  x.report('gsub! freeze') do
    copy = data.dup
    copy.gsub!("&".freeze,"&amp;".freeze)
    copy.gsub!("\n".freeze,'')
    copy.gsub!(">".freeze,"&gt;".freeze)
    copy.gsub!("<".freeze,"&lt;".freeze)
  end

  x.report('gsub regex freeze') do
    copy = data.dup
    copy.gsub(/&/,"&amp;".freeze).gsub(/\n/,''.freeze).gsub(/>/,"&gt;".freeze).gsub(/</,"&lt;".freeze)
  end
  x.report('gsub! regex freeze') do
    copy = data.dup
    copy.gsub!(/&/,"&amp;".freeze)
    copy.gsub!(/\n/,''.freeze)
    copy.gsub!(/>/,"&gt;".freeze)
    copy.gsub!(/</,"&lt;".freeze)
  end
end

report = MemoryProfiler.report do
  10000.times do
    copy = data.dup
    copy.gsub(regex1, mapping)
  end
end
File.open(File.build_timestamped_filename(%w(gsub mapping1)),'w') {|file| report.pretty_print(file) }
report = MemoryProfiler.report do
  10000.times do
    copy = data.dup
    copy.gsub(regex2, mapping)
  end
end
File.open(File.build_timestamped_filename(%w(gsub mapping2)),'w') {|file| report.pretty_print(file) }
report = MemoryProfiler.report do
  10000.times do
    copy = data.dup
    copy.gsub("&".freeze,"&amp;".freeze).gsub("\n".freeze,'').gsub(">".freeze,"&gt;".freeze).gsub("<".freeze,"&lt;".freeze)
  end
end
File.open(File.build_timestamped_filename(%w(gsub memory)),'w') {|file| report.pretty_print(file) }
report = MemoryProfiler.report do
  10000.times do
    copy = data.dup
    copy.gsub!("&".freeze,"&amp;".freeze)
    copy.gsub!("\n".freeze,''.freeze)
    copy.gsub!(">".freeze,"&gt;".freeze)
    copy.gsub!("<".freeze,"&lt;".freeze)
  end
end
File.open(File.build_timestamped_filename(%w(gsub! memory)),'w') {|file| report.pretty_print(file) }
report = MemoryProfiler.report do
  10000.times do
    copy = data.dup
    copy.gsub(/&/,"&amp;".freeze).gsub(/\n/,''.freeze).gsub(/>/,"&gt;".freeze).gsub(/</,"&lt;".freeze)
  end
end
File.open(File.build_timestamped_filename(%w(gsub_regex memory)),'w') {|file| report.pretty_print(file) }
report = MemoryProfiler.report do
  10000.times do
    copy = data.dup
    copy.gsub!(/&/,"&amp;".freeze)
    copy.gsub!(/\n/,''.freeze)
    copy.gsub!(/>/,"&gt;".freeze)
    copy.gsub!(/</,"&lt;".freeze)
  end
end
File.open(File.build_timestamped_filename(%w(gsub!_regex memory)),'w') {|file| report.pretty_print(file) }

