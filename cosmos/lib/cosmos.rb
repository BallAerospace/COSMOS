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

# This file sets up using the COSMOS framework

# Set default encodings
saved_verbose = $VERBOSE; $VERBOSE = nil
Encoding.default_external = Encoding::ASCII_8BIT
Encoding.default_internal = Encoding::ASCII_8BIT
$VERBOSE = saved_verbose

# Add COSMOS bin folder to PATH
require 'cosmos/core_ext/kernel'
if Kernel.is_windows?
  ENV['PATH'] = File.join(File.dirname(__FILE__), '../bin') + ';' + ENV['PATH']
else
  ENV['PATH'] = File.join(File.dirname(__FILE__), '../bin') + ':' + ENV['PATH']
end
require 'cosmos/ext/platform' if RUBY_ENGINE == 'ruby' and !ENV['COSMOS_NO_EXT']
require 'cosmos/version'
require 'cosmos/top_level'
require 'cosmos/core_ext'
require 'cosmos/utilities'
require 'cosmos/conversions'
require 'cosmos/interfaces'
require 'cosmos/processors'
require 'cosmos/packets/packet'
require 'cosmos/packet_logs'
require 'cosmos/text_logs'
require 'cosmos/system'

# COSMOS services need to die if something goes wrong so they can be restarted
require 'thread'
Thread.abort_on_exception = true
