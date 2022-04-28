# Set cosmos main gem version path
base_path = File.expand_path(File.join(__dir__, '..', '..'))
path = File.join(base_path, 'cosmos', 'lib', 'cosmos', 'version.rb')

puts "Getting the revision from git"
revision = `git rev-parse HEAD`.chomp
puts "Git revision: #{revision}"

version = ENV['COSMOS_RELEASE_VERSION'].to_s.dup
if version.length <= 0
  raise "Version is required"
end

split_version = version.to_s.split('.')
major = split_version[0]
minor = split_version[1]
if version =~ /[a-zA-z]+/
  # Prerelease version
  remainder = split_version[2..-1].join(".")
  remainder.gsub!('.', '-')
  remainder_split = remainder.split('-')
  patch = remainder_split[0]
  other = remainder_split[1..-1].join('')
  version = "#{major}.#{minor}.#{patch}-#{other}"
else
  # Production Release Version
  patch = split_version[2]
  other = split_version[3..-1].join('.')
end

puts "Setting version to: #{version}"

# Update main rubygem version.rb
File.open(path, 'wb') do |file|
  file.puts "# encoding: ascii-8bit"
  file.puts ""
  file.puts "COSMOS_VERSION = '#{version}'"
  file.puts "module Cosmos"
  file.puts "  module Version"
  file.puts "    MAJOR = '#{major}'"
  file.puts "    MINOR = '#{minor}'"
  file.puts "    PATCH = '#{patch}'"
  file.puts "    OTHER = '#{other}'"
  file.puts "    BUILD = '#{revision}'"
  file.puts "  end"
  file.puts "  VERSION = '#{version}'"
  file.puts "end"
end
puts "Updated: #{path}"

require path

gemspec_files = [
  'cosmos/cosmos.gemspec',
  'cosmos/cosmosc2.gemspec',
]

gemspec_files.each do |rel_path|
  full_path = File.join(base_path, rel_path)
  data = nil
  File.open(full_path, 'rb') do |file|
    data = file.read
  end
  mod_data = ''
  data.each_line do |line|
    if line =~ /s\.version =/
      mod_data << "  s.version = '#{version}'\n"
    elsif line =~ /s\.add_runtime_dependency 'cosmos'/
      mod_data << "  s.add_runtime_dependency 'cosmos', '#{version}'\n"
    else
      mod_data << line
    end
  end
  File.open(full_path, 'wb') do |file|
    file.write(mod_data)
  end
  puts "Updated: #{full_path}"
end

package_dot_json_files = [
  'cosmos-init/plugins/cosmosc2-tool-base/package.json',
  'cosmos-init/plugins/packages/cosmosc2-demo/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-admin/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-autonomic/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-calendar/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-cmdsender/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-cmdtlmserver/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-common/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-dataextractor/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-dataviewer/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-limitsmonitor/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-packetviewer/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-scriptrunner/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-tablemanager/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-tlmgrapher/package.json',
  'cosmos-init/plugins/packages/cosmosc2-tool-tlmviewer/package.json',
]

package_dot_json_files.each do |rel_path|
  full_path = File.join(base_path, rel_path)
  data = nil
  File.open(full_path, 'rb') do |file|
    data = file.read
  end
  mod_data = ''
  data.each_line do |line|
    if line =~ /\"version\":/
      mod_data << "  \"version\": \"#{version}\",\n"
    elsif line =~ /\"@cosmosc2\/tool-common\":/
      mod_data << "    \"@cosmosc2/tool-common\": \"#{version}\",\n"
    else
      mod_data << line
    end
  end
  File.open(full_path, 'wb') do |file|
    file.write(mod_data)
  end
  puts "Updated: #{full_path}"
end

shell_scripts = [
  'cosmos-init/plugins/docker-package-build.sh',
  'cosmos-init/plugins/docker-package-install.sh',
  'examples/hostinstall/centos7/cosmosc2_install_cosmosc2.sh',
]

shell_scripts.each do |rel_path|
  full_path = File.join(base_path, rel_path)
  data = nil
  File.open(full_path, 'rb') do |file|
    data = file.read
  end
  mod_data = ''
  data.each_line do |line|
    if line =~ /COSMOS_RELEASE_VERSION=/
      mod_data << "COSMOS_RELEASE_VERSION=#{version}\n"
    else
      mod_data << line
    end
  end
  File.open(full_path, 'wb') do |file|
    file.write(mod_data)
  end
  puts "Updated: #{full_path}"
end
