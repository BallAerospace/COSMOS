# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

begin
  require 'rspec/core/rake_task'

  desc 'Run all specs with basic output'
  RSpec::Core::RakeTask.new do |t|
    t.pattern = ['spec/*_spec.rb']
    t.rspec_opts = '-f d'
  end

rescue LoadError
  puts "rspec not loaded. gem install rspec"
end

