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

require 'openc3/script/extract'
require 'openc3/script/api_shared'
require 'openc3/api/cmd_api'
require 'openc3/api/config_api'
require 'openc3/api/interface_api'
require 'openc3/api/limits_api'
require 'openc3/api/router_api'
require 'openc3/api/settings_api'
require 'openc3/api/target_api'
require 'openc3/api/tlm_api'
require 'openc3/utilities/authorization'
require 'openc3/topics/topic'

module OpenC3
  module Api
    include Extract
    include Authorization
    include ApiShared
  end
end
