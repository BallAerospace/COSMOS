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

require 'cosmos/script/extract'
require 'cosmos/script/api_shared'
require 'cosmos/api/cmd_api'
require 'cosmos/api/config_api'
require 'cosmos/api/interface_api'
require 'cosmos/api/limits_api'
require 'cosmos/api/router_api'
require 'cosmos/api/settings_api'
require 'cosmos/api/target_api'
require 'cosmos/api/tlm_api'
require 'cosmos/utilities/authorization'
require 'cosmos/topics/topic'

module Cosmos
  module Api
    include Extract
    include Authorization
    include ApiShared
  end
end
