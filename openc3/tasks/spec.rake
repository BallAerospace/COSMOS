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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

begin
  require 'rspec/core/rake_task'

  desc 'Run all specs with basic output'
  RSpec::Core::RakeTask.new do |t|
    t.pattern = ['spec/*_spec.rb']
    t.rspec_opts = '-f d --warnings'
  end
rescue LoadError
  puts "rspec not loaded. gem install rspec"
end
