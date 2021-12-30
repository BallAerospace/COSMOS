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
      # day not necessary because that's the final reduction state
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
      # s3_key is formatted like STARTTIME__ENDTIME__SCOPE__TARGET__PACKET__TYPE.bin
      # e.g. 20211229191610578229500__20211229192610563836500__DEFAULT__INST__HEALTH_STATUS__rt__decom.bin
      _, _, scope, _ = s3_key.split('__')
      case s3_key
      when /__decom\.bin$/
        self.add_decom(filename: s3_key, scope: scope)
      when /__minute\.bin$/
        self.add_minute(filename: s3_key, scope: scope)
      when /__hour\.bin$/
        self.add_hour(filename: s3_key, scope: scope)
      end
    end
  end
end
