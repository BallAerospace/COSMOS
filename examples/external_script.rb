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

ENV['OPENC3_API_SCHEMA'] ||= 'http'
ENV['OPENC3_API_HOSTNAME'] ||= 'localhost'
ENV['OPENC3_API_PORT'] ||= '2900'
ENV['OPENC3_API_PASSWORD'] ||= 'openc3'
ENV['OPENC3_NO_STORE'] ||= '1'

require 'openc3'
require 'openc3/script'

puts get_target_list()

puts get_all_target_info()

puts tlm('INST ADCS POSX')

puts cmd("INST ABORT")

put_target_file("INST/test.txt", "this is a string test")
file = get_target_file("INST/test.txt")
puts file.read
file.unlink
delete_target_file("INST/test.txt")

save_file = Tempfile.new('test')
save_file.write("this is a Io test")
save_file.rewind
put_target_file("INST/test.txt", save_file)
save_file.unlink
file = get_target_file("INST/test.txt")
puts file.read
file.unlink
delete_target_file("INST/test.txt")

put_target_file("INST/test.bin", "\x00\x01\x02\x03\xFF\xEE\xDD\xCC")
file = get_target_file("INST/test.bin")
puts file.read.formatted
file.unlink
delete_target_file("INST/test.bin")
