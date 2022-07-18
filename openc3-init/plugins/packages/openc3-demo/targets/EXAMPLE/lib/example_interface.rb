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

require 'openc3'
require 'openc3/interfaces/tcpip_client_interface'

class ExampleInterface < OpenC3::TcpipClientInterface
  def initialize (hostname, port, write_timeout = 10.0, read_timeout = nil)
    super(hostname, port, port, write_timeout, read_timeout, 'LENGTH', 0, 32, 4, 1, 'BIG_ENDIAN', 4, nil, nil, true)
  end
end
