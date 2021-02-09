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

require 'cosmos/utilities/authorization.rb'

module Cosmos
  autoload(:Crc, 'cosmos/utilities/crc.rb')
  autoload(:Crc16, 'cosmos/utilities/crc.rb')
  autoload(:Crc32, 'cosmos/utilities/crc.rb')
  autoload(:Crc64, 'cosmos/utilities/crc.rb')
  autoload(:Csv, 'cosmos/utilities/csv.rb')
  autoload(:Logger, 'cosmos/utilities/logger.rb')
  autoload(:Metric, 'cosmos/utilities/metric.rb')
  autoload(:MessageLog, 'cosmos/utilities/message_log.rb')
  autoload(:Quaternion, 'cosmos/utilities/quaternion.rb')
  autoload(:SimulatedTarget, 'cosmos/utilities/simulated_target.rb')
  autoload(:Sleeper, 'cosmos/utilities/sleeper.rb')
end
autoload(:RubyLexUtils, 'cosmos/utilities/ruby_lex_utils.rb')
