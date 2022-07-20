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

$openc3_scope = ARGV[0]

require 'json'
require 'openc3'
require 'openc3/script/suite_runner'
require '../app/models/script'
require '../app/models/running_script'
require ARGV[1]

puts OpenC3::SuiteRunner.build_suites.as_json(:allow_nan => true).to_json(:allow_nan => true)
