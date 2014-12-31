# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file gems specific to platform

require 'rubygems'
require 'rubygems/command.rb'
require 'rubygems/dependency_installer.rb'

def gem_installed?(name, version = Gem::Requirement.default)
  version = Gem::Requirement.create version unless version.is_a? Gem::Requirement
  Gem::Specification.each.any? { |spec| name == spec.name and version.satisfied_by? spec.version }
end

begin
  Gem::Command.build_args = ARGV
  rescue NoMethodError
end
inst = Gem::DependencyInstaller.new
begin
  if RbConfig::CONFIG['target_os'] !~ /mswin|mingw|cygwin/i
    unless gem_installed?("ruby-termios", "~> 0.9")
      STDOUT.puts "Attempting to install ruby-termios... If this fails please manually \"gem install ruby-termios\" and try again."
      inst.install "ruby-termios", "~> 0.9"
    end
  end
rescue
  exit(1)
end

f = File.open(File.join(File.dirname(__FILE__), "Rakefile"), "w")   # create dummy rakefile to indicate success
f.write("task :default\n")
f.close
