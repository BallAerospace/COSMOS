# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/utilities/store'

module Cosmos
  class Topic
    def self.read_topics(topics, offsets = nil, timeout_ms = 1000, &block)
      Store.read_topics(topics, offsets, timeout_ms, &block)
    end
  end
end