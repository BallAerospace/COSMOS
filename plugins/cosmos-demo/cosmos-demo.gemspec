# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# Create the overall gemspec
spec = Gem::Specification.new do |s|
  s.name = 'cosmos-demo'
  s.summary = 'Ball Aerospace COSMOS'
  s.description =  <<-EOF
    This plugin adds the COSMOS demo configuration to a base COSMOS installation.
    Install this to experiment with a configured COSMOS system.
  EOF
  s.authors = ['Ryan Melton', 'Jason Thomas']
  s.email = ['rmelton@ball.com', 'jmthomas@ball.com']
  s.homepage = 'https://github.com/BallAerospace/COSMOS'

  s.platform = Gem::Platform::RUBY

  time = Time.now.strftime("%Y%m%d%H%M%S")
  if ENV['VERSION']
    s.version = ENV['VERSION'].dup + ".#{time}"
  else
    s.version = '0.0.0' + ".#{time}"
  end
  s.license = 'GPL-3.0'

  # Files are defined in Manifest.txt
  s.files =Dir.glob("{targets,lib,procedures,tools,microservices}/**/*") + %w(Rakefile LICENSE.txt README.md plugin.txt)

  s.required_ruby_version = '~> 2.5'

  # Runtime Dependencies
  s.add_runtime_dependency 'cosmos'
end
