# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'rbconfig'

# Create the overall gemspec
spec = Gem::Specification.new do |s|
  s.name = 'cosmosc2'
  s.summary = 'Ball Aerospace COSMOS'
  s.description =  <<-EOF
    Ball Aerospace COSMOS provides all the functionality needed to send
    commands to and receive data from one or more embedded systems
    referred to as "targets". Out of the box functionality includes:
    Telemetry Display, Telemetry Graphing, Operational and Test Scripting,
    Command Sending, Logging, and more.
  EOF
  s.authors = ['Ryan Melton', 'Jason Thomas']
  s.email = ['rmelton@ball.com', 'jmthomas@ball.com']
  s.homepage = 'https://github.com/BallAerospace/COSMOS'

  if RUBY_ENGINE == 'ruby'
    s.platform = Gem::Platform::RUBY
  elsif RUBY_ENGINE == 'jruby'
    s.platform = "java"
  else
    s.platform = Gem::Platform::CURRENT
  end
  s.version = '5.0.2-beta1'
  s.licenses = ['AGPL-3.0-only', 'Nonstandard']

  s.files = [ 'lib/cosmosc2.rb' ]

  s.required_ruby_version = '>= 2.7'

  # Runtime Dependencies
  s.add_runtime_dependency 'cosmos', '5.0.2-beta1'
end
