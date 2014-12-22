# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# A sample Guardfile
# More info at https://github.com/guard/guard#readme

ignore /~$/
ignore /^(?:.*[\\\/])?\.[^\\\/]+\.sw[p-z]$/

guard :bundler do
  watch('Gemfile')
end

guard :rspec, cmd: 'bundle exec rspec --color' do
  watch('spec/spec_helper.rb')    { 'spec' }
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/cosmos/(.+)\.rb$}) { |m| "spec/#{m[1]}/#{m[1]}_spec.rb" }
  watch(%r{^lib/cosmos/(.+)/(.+)\.rb$}) { |m| "spec/#{m[1]}/#{m[2]}_spec.rb" }
end

