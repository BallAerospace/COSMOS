# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'stringio'
require 'cosmos/core_ext/cosmos_io'

# COSMOS specific additions to the Ruby IO class
class StringIO
  include CosmosIO

  if !(StringIO.method_defined?(:path))
    # @return [nil]
    def path
      nil
    end
  end
end
