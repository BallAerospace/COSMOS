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

require 'cosmos/utilities/store'

module Cosmos
  class ReducerModel
    KEYS = {
      decom: 'cosmos__reducer__decom'.freeze,
      minute: 'cosmos__reducer__minute'.freeze,
      hour: 'cosmos__reducer__hour'.freeze,
    }

    KEYS.each do |type, key|
      define_singleton_method("add_#{type}") do |filename:, scope: nil|
        Store.sadd("#{scope}__#{key}", filename)
      end
      define_singleton_method("all_#{type}") do |scope: nil|
        Store.smembers("#{scope}__#{key}").sort
      end
      define_singleton_method("rm_#{type}") do |filename:, scope: nil|
        Store.srem("#{scope}__#{key}", filename)
      end
    end

    def self.add_file(s3_key)
      case s3_key
      when /decom/
        self.add_decom(s3_key)
      when /minute/
        self.add_minute(s3_key)
      when /hour/
        self.add_hour(s3_key)
      end
    end
  end
end
