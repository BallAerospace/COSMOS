# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'rbconfig'

# Create the overall gemspec
spec = Gem::Specification.new do |s|
  s.name = 'cosmos'
  s.summary = 'Ball Aerospace COSMOS'
  s.description =  <<-EOF
    Ball Aerospace COSMOS provides all the functionality needed to send
    commands to and receive data from one or more embedded systems
    referred to as "targets". Out of the box functionality includes:
    Telemetry Display, Telemetry Graphing, Operational and Test Scripting,
    Command Sending, Logging, Log File Playback, Table Management, and more.
  EOF
  s.authors = ['Ryan Melton', 'Jason Thomas']
  s.email = ['rmelton@ball.com', 'jmthomas@ball.com']
  s.homepage = 'https://github.com/BallAerospace/COSMOS'

  s.platform = Gem::Platform::RUBY
  if ENV['VERSION']
    s.version = ENV['VERSION'].dup
  else
    s.version = '0.0.0'
  end
  s.license = 'GPL-3.0'

  # Executables
  s.executables << 'cosmos'
  s.executables << 'rubysloc'
  s.executables << 'cstol_converter'
  s.executables << 'xtce_converter'

  # Ruby C Extensions
  s.extensions << 'ext/cosmos/ext/array/extconf.rb'
  s.extensions << 'ext/cosmos/ext/buffered_file/extconf.rb'
  s.extensions << 'ext/cosmos/ext/config_parser/extconf.rb'
  s.extensions << 'ext/cosmos/ext/cosmos_io/extconf.rb'
  s.extensions << 'ext/cosmos/ext/crc/extconf.rb'
  s.extensions << 'ext/cosmos/ext/line_graph/extconf.rb'
  s.extensions << 'ext/cosmos/ext/low_fragmentation_array/extconf.rb'
  s.extensions << 'ext/cosmos/ext/packet/extconf.rb'
  s.extensions << 'ext/cosmos/ext/platform/extconf.rb'
  s.extensions << 'ext/cosmos/ext/polynomial_conversion/extconf.rb'
  s.extensions << 'ext/cosmos/ext/string/extconf.rb'
  s.extensions << 'ext/cosmos/ext/tabbed_plots_config/extconf.rb'
  s.extensions << 'ext/cosmos/ext/telemetry/extconf.rb'
  s.extensions << 'ext/mkrf_conf.rb'

  # Files are defined in Manifest.txt
  s.files =
    if test ?f, 'Manifest.txt'
      files = File.readlines('Manifest.txt').map {|fn| fn.chomp.strip}
      files.delete ''
      files
    else [] end

  s.has_rdoc = true

  s.required_ruby_version = '~> 2'

  # Runtime Dependencies
  s.add_runtime_dependency 'bundler', '~> 1.3'
  s.add_runtime_dependency 'rdoc', '>= 3', '< 5'
  s.add_runtime_dependency 'rake', '>= 0', '< 11'
  s.add_runtime_dependency 'json', '>= 1.5', '< 1.9'
  s.add_runtime_dependency 'pry', '>= 0.9', '< 0.11'
  s.add_runtime_dependency 'pry-doc', '>= 0.5', '< 0.7'
  s.add_runtime_dependency 'yard', '~> 0.8.0'
  s.add_runtime_dependency 'uuidtools', '~> 2.1.0'
  s.add_runtime_dependency 'opengl', '>= 0.7', '< 0.10'
  s.add_runtime_dependency 'snmp', '~> 1.0'
  s.add_runtime_dependency 'rubyzip', '~> 1.1.0'
  s.add_runtime_dependency 'qtbindings', '~> 4.8.6', '>= 4.8.6.2'
  s.add_runtime_dependency 'nokogiri', '~> 1.6'

  # Development Dependencies
  s.add_development_dependency 'rspec', '~> 3.2.0'
  s.add_development_dependency 'flog', '~> 4.0'
  s.add_development_dependency 'flay', '~> 2.0'
  s.add_development_dependency 'reek', '~> 1.0'
  s.add_development_dependency 'roodi', '~> 4.0'
  s.add_development_dependency 'guard', '~> 2.0'
  s.add_development_dependency 'listen', '~> 2.0'
  s.add_development_dependency 'guard-bundler', '~> 2.0'
  s.add_development_dependency 'guard-rspec', '~> 4.0'
  s.add_development_dependency 'simplecov', '~> 0.11'
  s.add_development_dependency 'ruby-prof', '~> 0.15.0'
  s.add_development_dependency 'coveralls', '~> 0.8'
  s.add_development_dependency 'benchmark-ips', '~> 2.0'

  s.post_install_message = "Thanks for installing Ball Aerospace COSMOS!\nStart your first project with: cosmos demo demo\n"
end
