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

ENV['COSMOS_API_SCHEMA'] ||= 'http'
ENV['COSMOS_API_HOSTNAME'] ||= 'localhost'
ENV['COSMOS_API_PORT'] ||= '2900'
ENV['COSMOS_API_PASSWORD'] ||= 'cosmos'
ENV['COSMOS_NO_STORE'] ||= '1'

require 'cosmos'
require 'cosmos/script'

puts get_target_list()

puts get_all_target_info()

puts tlm('INST ADCS POSX')

puts cmd("INST ABORT")
