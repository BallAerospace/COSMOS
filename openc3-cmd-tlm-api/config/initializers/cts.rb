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

require 'openc3/api/authorized_api'
require 'openc3/io/json_drb'
require 'openc3/models/settings_model'
require 'openc3/version'

module OpenC3
  class Cts
    include AuthorizedApi

    attr_accessor :json_drb

    @@instance = nil

    def initialize
      @json_drb = JsonDRb.new
      @json_drb.method_whitelist = Api::WHITELIST
      @json_drb.object = self
    end

    def self.instance
      @@instance ||= new()
    end
  end
end

OpenC3::Cts.instance

# Accessing Redis early can break specs
unless ENV['OPENC3_NO_STORE']
  # Set the displayed OpenC3 version
  OpenC3::SettingsModel.set({name: 'version', data: OPENC3_VERSION}, scope: nil)
end
