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

require 'digest'
require 'cosmos/utilities/store'

module Cosmos
  class AuthModel
    PRIMARY_KEY = 'COSMOS__TOKEN'

    def self.is_set?
      Store.exists(PRIMARY_KEY) == 1
    end

    def self.verify(token)
      return false if token.nil? or token.empty?
      Store.get(PRIMARY_KEY) == hash(token)
    end

    def self.set(token)
      raise "Token must not be nil or empty" if token.nil? or token.empty?
      Store.setnx(PRIMARY_KEY, hash(token))
    end

    def self.reset(token, recovery_token)
      # TODO
      raise "Not implemented"
    end

    private
    def self.hash(token)
      Digest::SHA2.hexdigest token
    end
  end
end
