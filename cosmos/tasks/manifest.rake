# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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

desc 'Create a new manifest'
task :manifest do
  puts "Now calculating the file list from git. Please wait..."
  fn = 'Manifest.txt'
  # Ask git what all our files are
  files = `git ls-tree --full-tree -r --name-only HEAD`.split($\)
  # Remove all the directories
  files.reject! { |f| File::Stat.new(f).directory? or f.include?("vendor") }
  # Write out the manifest file
  File.open(fn, 'w') { |fp| fp.puts files.sort }
  puts "Successfully created #{fn}."
end
