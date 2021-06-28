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
    SERVICE_KEY = 'COSMOS__SERVICE__TOKEN'

    def self.is_set?(key = PRIMARY_KEY)
      Store.exists(key) == 1
    end

    def self.verify(token)
      return false if token.nil? or token.empty?
      token_hash = hash(token)
      (Store.get(PRIMARY_KEY) == token_hash) or (Store.get(SERVICE_KEY) == token_hash)
    end

    def self.set(token, old_token, key = PRIMARY_KEY)
      raise "token must not be nil or empty" if token.nil? or token.empty?
      if is_set?(key)
        raise "old_token must not be nil or empty" if old_token.nil? or old_token.empty?
        raise "old_token incorrect" unless verify(old_token)
      end
      Store.set(key, hash(token))
    end

    private
    def self.hash(token)
      Digest::SHA2.hexdigest token
    end
  end
end
