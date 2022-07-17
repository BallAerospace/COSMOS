# Set openc3 main gem version path
base_path = File.expand_path(File.join(__dir__, '..', '..'))
path = File.join(base_path, 'openc3', 'lib', 'openc3', 'version.rb')

puts "Getting the revision from git"
revision = `git rev-parse HEAD`.chomp
puts "Git revision: #{revision}"

version = ENV['OPENC3_RELEASE_VERSION'].to_s.dup
if version.length <= 0
  raise "Version is required"
end

split_version = version.to_s.split('.')
major = split_version[0]
minor = split_version[1]
if version =~ /[a-zA-z]+/
  # Prerelease version
  remainder = split_version[2..-1].join(".")
  remainder.gsub!('-', '.pre.') # Rubygems replaces dashes with .pre.
  remainder_split = remainder.split('.')
  patch = remainder_split[0]
  other = remainder_split[1..-1].join('.')
  gem_version = "#{major}.#{minor}.#{patch}.#{other}"
else
  # Production Release Version
  patch = split_version[2]
  other = split_version[3..-1].join('.')
  gem_version = version
end

puts "Setting version to: #{version}"

# Update main rubygem version.rb
File.open(path, 'wb') do |file|
  file.puts "# encoding: ascii-8bit"
  file.puts ""
  file.puts "OPENC3_VERSION = '#{version}'"
  file.puts "module OpenC3"
  file.puts "  module Version"
  file.puts "    MAJOR = '#{major}'"
  file.puts "    MINOR = '#{minor}'"
  file.puts "    PATCH = '#{patch}'"
  file.puts "    OTHER = '#{other}'"
  file.puts "    BUILD = '#{revision}'"
  file.puts "  end"
  file.puts "  VERSION = '#{version}'"
  file.puts "  GEM_VERSION = '#{gem_version}'"
  file.puts "end"
end
puts "Updated: #{path}"

require path

gemspec_files = [
  'openc3/openc3.gemspec',
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
      mod_data << "  s.version = '#{gem_version}'\n"
    elsif line =~ /s\.add_runtime_dependency 'openc3'/
      mod_data << "  s.add_runtime_dependency 'openc3', '#{gem_version}'\n"
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
  'openc3-init/plugins/openc3-tool-base/package.json',
  'openc3-init/plugins/packages/openc3-demo/package.json',
  'openc3-init/plugins/packages/openc3-tool-admin/package.json',
  'openc3-init/plugins/packages/openc3-tool-autonomic/package.json',
  'openc3-init/plugins/packages/openc3-tool-calendar/package.json',
  'openc3-init/plugins/packages/openc3-tool-cmdsender/package.json',
  'openc3-init/plugins/packages/openc3-tool-cmdtlmserver/package.json',
  'openc3-init/plugins/packages/openc3-tool-common/package.json',
  'openc3-init/plugins/packages/openc3-tool-dataextractor/package.json',
  'openc3-init/plugins/packages/openc3-tool-dataviewer/package.json',
  'openc3-init/plugins/packages/openc3-tool-handbooks/package.json',
  'openc3-init/plugins/packages/openc3-tool-limitsmonitor/package.json',
  'openc3-init/plugins/packages/openc3-tool-packetviewer/package.json',
  'openc3-init/plugins/packages/openc3-tool-scriptrunner/package.json',
  'openc3-init/plugins/packages/openc3-tool-tablemanager/package.json',
  'openc3-init/plugins/packages/openc3-tool-tlmgrapher/package.json',
  'openc3-init/plugins/packages/openc3-tool-tlmviewer/package.json',
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
    elsif line =~ /\"@openc3\/tool-common\":/
      mod_data << "    \"@openc3/tool-common\": \"#{version}\",\n"
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
  'openc3-init/plugins/docker-package-build.sh',
  'openc3-init/plugins/docker-package-install.sh',
  'examples/hostinstall/centos7/openc3_install_openc3.sh',
]

shell_scripts.each do |rel_path|
  full_path = File.join(base_path, rel_path)
  data = nil
  File.open(full_path, 'rb') do |file|
    data = file.read
  end
  mod_data = ''
  data.each_line do |line|
    if line =~ /OPENC3_RELEASE_VERSION=/
      mod_data << "OPENC3_RELEASE_VERSION=#{version}\n"
    else
      mod_data << line
    end
  end
  File.open(full_path, 'wb') do |file|
    file.write(mod_data)
  end
  puts "Updated: #{full_path}"
end

gemfiles = [
  'openc3-cmd-tlm-api/Gemfile',
  'openc3-script-runner-api/Gemfile',
]

gemfiles.each do |rel_path|
  full_path = File.join(base_path, rel_path)
  data = nil
  File.open(full_path, 'rb') do |file|
    data = file.read
  end
  mod_data = ''
  data.each_line do |line|
    if line =~ /gem 'openc3'/ and line !~ /:path/
      mod_data << "  gem 'openc3', '#{gem_version}'\n"
    else
      mod_data << line
    end
  end
  File.open(full_path, 'wb') do |file|
    file.write(mod_data)
  end
  puts "Updated: #{full_path}"
end
