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

require "spec_helper"
require "cosmos"

# In order to run this spec you must be in Linux
# On Windows install WSL2 and type 'bash'
# cd to the root of cosmos source
# Uncomment various things (read the source) in ext/cosmos/ext/platform.c
# 'rake build' from the root
# 'export COSMOS_DEVEL=1'
# 'rspec spec/utilities/segfault_spec.rb'

module Cosmos
  describe SegFault do
    # NOTE: You have to uncomment each test individually
    # because a Segfault completely exits rspec and the test

    # it "creates a logfile at the specified directory" do
    #   ENV['COSMOS_LOGS_DIR'] = File.dirname(__FILE__)
    #   SegFault.segfault
    # end

    # it "does not crash with buffer overflow" do
    #   ENV['COSMOS_LOGS_DIR'] = 'a' * 1000
    #   SegFault.segfault
    # end

    # it "validates the path" do
    #   ENV['COSMOS_LOGS_DIR'] = Dir.pwd + '/no_dir_here'
    #   SegFault.segfault
    # end
  end if false # NOTE: Also remove if false
end
