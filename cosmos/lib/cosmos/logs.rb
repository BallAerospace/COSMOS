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

module Cosmos
  autoload(:PacketLogWriter, 'cosmos/logs/packet_log_writer.rb')
  autoload(:PacketLogWriterPair, 'cosmos/logs/packet_log_writer_pair.rb')
  autoload(:PacketLogReader, 'cosmos/logs/packet_log_reader.rb')
  autoload(:TextLogWriter, 'cosmos/logs/text_log_writer.rb')
end
