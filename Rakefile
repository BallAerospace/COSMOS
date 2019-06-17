# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'open3'

# Pure Ruby CRC class to avoid circular dependency with c_cosmos
class RakeCrc32
  attr_reader :crc32_poly
  attr_reader :crc32_seed
  attr_reader :crc32_xor
  attr_reader :crc32_table
  attr_reader :crc32_raw_table

  # Default Polynomial for 32-bit CRC
  DEFAULT_CRC32_POLY = 0x04C11DB7

  # Default Seed for 32-bit CRC
  DEFAULT_CRC32_SEED = 0xFFFFFFFF

  def initialize(crc32_poly = DEFAULT_CRC32_POLY, crc32_seed = DEFAULT_CRC32_SEED, crc32_xor = true)
    @crc32_poly = crc32_poly
    @crc32_seed = crc32_seed
    @crc32_xor = crc32_xor
    @crc32_table = []

    (0..255).each do |index|
      entry = compute_crc32_table_entry(index)
      @crc32_table << entry
    end
  end

  # Calculate a 32-bit CRC
  def calc(data, seed = nil)
    seed = @crc32_seed unless seed
    crc  = seed
    data.each_byte do |byte|
      index = ((crc >> 24) ^ byte) & 0xFF
      crc = ((crc << 8) ^ @crc32_table[index]) & 0xFFFFFFFF
    end
    if @crc32_xor
      crc ^ 0xFFFFFFFF
    else
      crc
    end
  end

  protected

  # Compute a single entry in the 32-bit crc lookup table
  def compute_crc32_table_entry(index)
    crc = index << 24

    8.times do
      if ((crc & 0x80000000) != 0)
        crc = (crc << 1) ^ @crc32_poly
      else
        crc = crc << 1
      end
    end

    return (crc & 0xFFFFFFFF)
  end

end

require 'yard' if RUBY_ENGINE == 'ruby'

# Import the rake tasks
import 'tasks/manifest.rake'
import 'tasks/spec.rake'
import 'tasks/gemfile_stats.rake'

# Update the built in task dependencies
task :default => [:spec] # :test

task :require_version do
  unless ENV['VERSION']
    puts "VERSION is required: rake <task> VERSION=X.X.X"
    exit 1
  end
end

task :devkit do
  if RUBY_ENGINE == 'ruby'
    if RUBY_PLATFORM[0..2] == 'x64'
      if File.exist?("C:/msys64/mingw64")
        ENV['RI_DEVKIT'] = "C:\\msys64"
        ENV['MSYSTEM']="MINGW64"
        ENV['PKG_CONFIG_PATH']="/mingw64/lib/pkgconfig:/mingw64/share/pkgconfig"
        ENV['ACLOCAL_PATH']="/mingw64/share/aclocal:/usr/share/aclocal"
        ENV['MANPATH']="/mingw64/share/man"
        ENV['MINGW_PACKAGE_PREFIX']="mingw-w64-x86_64"
        ENV['LANG']="en_US.UTF-8"
        ENV['PATH'] = 'C:\\msys64\\mingw64\\bin;C:\\msys64\\usr\\bin;' + ENV['PATH']
      end
    else
      if File.exist?("C:/msys64/mingw32")
        ENV['RI_DEVKIT'] = "C:\\msys64"
        ENV['MSYSTEM']="MINGW32"
        ENV['PKG_CONFIG_PATH']="/mingw32/lib/pkgconfig:/mingw32/share/pkgconfig"
        ENV['ACLOCAL_PATH']="/mingw32/share/aclocal:/usr/share/aclocal"
        ENV['MANPATH']="/mingw32/share/man"
        ENV['MINGW_PACKAGE_PREFIX']="mingw-w64-i686"
        ENV['LANG']="en_US.UTF-8"
        ENV['PATH'] = 'C:\\msys64\\mingw32\\bin;C:\\msys64\\usr\\bin;' + ENV['PATH']
      end
    end
  end
end

task :build => [:devkit] do
  if RUBY_ENGINE == 'ruby'
    _, platform, *_ = RUBY_PLATFORM.split("-")
    saved = Dir.pwd
    shared_extension = 'so'
    shared_extension = 'bundle' if platform =~ /darwin/

    extensions = [
      'crc',
      'low_fragmentation_array',
      'polynomial_conversion',
      'config_parser',
      'string',
      'array',
      'cosmos_io',
      'tabbed_plots_config',
      'telemetry',
      'line_graph',
      'packet',
      'platform',
      'buffered_file']

    extensions.each do |extension_name|
      Dir.chdir "ext/cosmos/ext/#{extension_name}"
      FileUtils.rm_f Dir.glob('*.o')
      FileUtils.rm_f Dir.glob("*.#{shared_extension}")
      FileUtils.rm_f Dir.glob('*.def')
      FileUtils.rm_f 'Makefile'
      system('ruby extconf.rb')
      system('make')
      FileUtils.copy("#{extension_name}.#{shared_extension}", '../../../../lib/cosmos/ext/.')
      FileUtils.rm_f Dir.glob('*.o')
      FileUtils.rm_f Dir.glob("*.#{shared_extension}")
      FileUtils.rm_f Dir.glob('*.def')
      FileUtils.rm_f 'Makefile'
      Dir.chdir saved
    end
  end
end

task :git_checkout_master do
  system('git checkout master')
end

task :install_crc do
  saved = Dir.pwd
  Dir.chdir 'demo'
  system('bundle exec rake crc_official')
  Dir.chdir saved
  saved = Dir.pwd
  Dir.chdir 'install'
  system('bundle exec rake crc_official')
  Dir.chdir saved
end

task :gem => [:require_version] do
  _, platform, *_ = RUBY_PLATFORM.split("-")
  if platform == 'mswin32' or platform == 'mingw32'
    raise "Building gem is not supported on Windows because file permissions are lost"
  end
  system('gem build cosmos.gemspec')
end

task :commit_release_ticket => [:require_version, :git_checkout_master] do
  system('git add data/crc.txt')
  system('git add demo/config/data/crc.txt')
  system('git add install/config/data/crc.txt')
  system('git add lib/cosmos/version.rb')
  system('git add Manifest.txt')
  system("git commit -m \"Release COSMOS #{ENV['VERSION']}\"")
  system("git push")
end

task :tag_release => [:require_version] do
  system("git tag -a v#{ENV['VERSION']} -m \"COSMOS #{ENV['VERSION']}\"")
  system("git push --tags")
end

task :version => [:require_version] do
  puts "Getting the revision from git"
  revision = `git rev-parse HEAD`.chomp

  # Update cosmos_version.rb
  version = ENV['VERSION'].dup
  major,minor,patch = version.to_s.split('.')
  File.open('lib/cosmos/version.rb', 'w') do |file|
    file.puts "# encoding: ascii-8bit"
    file.puts ""
    file.puts "COSMOS_VERSION = '#{version}'"
    file.puts "module Cosmos"
    file.puts "  module Version"
    file.puts "    MAJOR = '#{major}'"
    file.puts "    MINOR = '#{minor}'"
    file.puts "    PATCH = '#{patch}'"
    file.puts "    BUILD = '#{revision}'"
    file.puts "  end"
    file.puts "  VERSION = '#{version}'"
    file.puts "end"
  end
  puts "Successfully updated lib/cosmos/version.rb"

  # Create the crc.txt file
  crc = RakeCrc32.new
  File.open("data/crc.txt",'w') do |file|
    Dir[File.join('lib','**','*.rb')].each do |filename|
      file_data = File.open(filename, 'rb').read.gsub("\x0D\x0A", "\x0A")
      file.puts "\"#{filename}\" #{sprintf("0x%08X", crc.calc(file_data))}"
    end
  end
end

task :metrics do
  puts "\nRunning flog and creating flog_report.txt"
  `flog lib > flog_report.txt`
  puts "\nRunning flay and creating flay_report.txt"
  `flay lib > flay_report.txt`
  puts "\nRunning reek and creating reek_report.txt"
  `reek lib > reek_report.txt`
  puts "\nRunning roodi and creating roodi_report.txt"
  `roodi -config=roodi.yml lib > roodi_report.txt`
end

task :stress do
  puts "Running each spec individual with GC.stress = true..."
  puts

  ENV['STRESS'] = "1"
  failed = []
  Dir['spec/**/*_spec.rb'].each do |spec_file|
    puts "Running: rspec #{spec_file}"
    output, status = Open3.capture2e("rspec #{spec_file}")
    if status.success?
      puts "  success (#{status}):"
      #puts output
      puts
    else
      puts "  error (#{status}):"
      puts output
      puts
      failed << spec_file
    end
  end

  if failed.length > 0
    puts "Failed specs:"
    failed.each do |f|
      puts "  #{f}"
    end
  else
    puts "Success!"
  end
end

# Make all the main.sh files executable in the demo and install Mac applications
task :mac_app_exec_bit do
  %w(demo install).each do |root|
    Dir["#{root}/tools/mac/**/Contents/MacOS/main.sh"].each do |main|
      `git add --chmod=+x #{main}`
    end
  end
end

if RUBY_ENGINE == 'ruby'
  YARD::Rake::YardocTask.new do |t|
    t.options = ['--protected'] # See all options by typing 'yardoc --help'
  end
end

task :release => [:require_version, :git_checkout_master, :build, :spec, :manifest, :version, :install_crc, :gem]
task :commit_release => [:commit_release_ticket, :tag_release]
