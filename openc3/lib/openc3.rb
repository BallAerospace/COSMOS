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

# This file sets up using the OpenC3 framework

# Set default encodings
saved_verbose = $VERBOSE; $VERBOSE = nil
Encoding.default_external = Encoding::ASCII_8BIT
Encoding.default_internal = Encoding::ASCII_8BIT
$VERBOSE = saved_verbose

# Add OpenC3 bin folder to PATH
require 'openc3/core_ext/kernel'
if Kernel.is_windows?
  ENV['PATH'] = File.join(File.dirname(__FILE__), '../bin') + ';' + ENV['PATH']
else
  ENV['PATH'] = File.join(File.dirname(__FILE__), '../bin') + ':' + ENV['PATH']
end
require 'openc3/ext/platform' if RUBY_ENGINE == 'ruby' and !ENV['OPENC3_NO_EXT']
require 'openc3/version'
require 'openc3/top_level'
require 'openc3/core_ext'
require 'openc3/utilities'
require 'openc3/conversions'
require 'openc3/interfaces'
require 'openc3/processors'
require 'openc3/packets/packet'
require 'openc3/logs'
require 'openc3/system'

# OpenC3 services need to die if something goes wrong so they can be restarted
require 'thread'
Thread.abort_on_exception = true
