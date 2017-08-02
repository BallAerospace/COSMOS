# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

if RUBY_ENGINE == 'ruby' and !ENV['COSMOS_NO_EXT']
  require 'cosmos/ext/low_fragmentation_array'
else
  module Cosmos
    class LowFragmentationArray < Array
      # Can't implement low fragmention in native ruby easily
    end
  end
end
