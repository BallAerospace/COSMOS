# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/cmd_tlm_server/cmd_tlm_server_gui'

module Cosmos
  # Implements the GUI functions of the Command and Telemetry Server. All the
  # QT calls are implemented here. The non-GUI functionality is contained in
  # the CmdTlmServer class.
  class Replay < CmdTlmServerGui
  end
end
