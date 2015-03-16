# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file sets up using the COSMOS framework

# Enforce Ruby version
ruby_split = RUBY_VERSION.split('.')
ruby_first = ruby_split[0].to_i
ruby_second = ruby_split[1].to_i
ruby_third = ruby_split[2].to_i
if ruby_first == 1
  if ruby_second <= 8 or (ruby_second == 9 and ruby_third < 3)
    raise "Cosmos 2.x does not support Ruby versions less than 1.9.3"
  end
end

# Set default encodings
saved_verbose = $VERBOSE; $VERBOSE = nil;
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
require 'cosmos/ext/platform'

# Remove warning about dl deprecation in Ruby 2.0 and 2.1
saved_verbose = $VERBOSE; $VERBOSE = nil
begin
  require 'dl'
rescue Exception
end
$VERBOSE = saved_verbose

require 'cosmos/version'
require 'cosmos/top_level'

# Add the COSMOS user's libraries to the ruby search path
# Located immediately after top_level to allow user overrides of files
Cosmos.add_to_search_path(File.join(Cosmos::USERPATH, 'lib'))

require 'cosmos/core_ext'
require 'cosmos/utilities'
require 'cosmos/conversions'
require 'cosmos/system'

begin
  require 'user_version'
rescue Exception
  # Not defined
end
