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

require 'cosmos/api/authorized_api'
require 'cosmos/io/json_drb'

module Cosmos
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

Cosmos::Cts.instance
