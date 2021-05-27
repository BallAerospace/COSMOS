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
  class PasswordModel
    PRIMARY_KEY = 'COSMOS__PASSWORD'

    def self.is_set?
      Store.exists(PRIMARY_KEY) == 1
    end

    def self.verify(password)
      return false if password.nil? or password.empty?
      Store.get(PRIMARY_KEY) == hash(password)
    end

    def self.set(password)
      raise "Password must not be nil or empty" if password.nil? or password.empty?
      Store.setnx(PRIMARY_KEY, hash(password))
    end

    def self.reset(password, recovery_token)
      # TODO
      raise "Not implemented"
    end

    private
    def self.hash(password)
      Digest::SHA2.hexdigest password
    end
  end
end
