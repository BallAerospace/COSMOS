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
  # Tracks the files which are being stored in S3 for data reduction purposes.
  # Files are stored in a Redis set by spliting their filenames and storing in
  # a set named SCOPE__TARGET__reducer__TYPE, e.g. DEFAULT__INST__reducer__decom
  # Where TYPE can be 'decom', 'minute', or 'hour'. 'day' is not necessary because
  # day is the final reduction state. As files are reduced they are removed from
  # the set. Thus the sets contain the active set of files to be reduced.
  class ReducerModel
    def self.add_file(s3_key)
      # s3_key is formatted like STARTTIME__ENDTIME__SCOPE__TARGET__PACKET__TYPE.bin
      # e.g. 20211229191610578229500__20211229192610563836500__DEFAULT__INST__HEALTH_STATUS__rt__decom.bin
      _, _, scope, target, _ = s3_key.split('__')
      case s3_key
      when /__decom\.bin$/
        Store.sadd("#{scope}__#{target}__reducer__decom", s3_key)
      when /__minute\.bin$/
        Store.sadd("#{scope}__#{target}__reducer__minute", s3_key)
      when /__hour\.bin$/
        Store.sadd("#{scope}__#{target}__reducer__hour", s3_key)
      end
      # No else clause because add_file is called with raw files which are ignored
    end

    def self.rm_file(s3_key)
      _, _, scope, target, _ = s3_key.split('__')
      case s3_key
      when /__decom\.bin$/
        Store.srem("#{scope}__#{target}__reducer__decom", s3_key)
      when /__minute\.bin$/
        Store.srem("#{scope}__#{target}__reducer__minute", s3_key)
      when /__hour\.bin$/
        Store.srem("#{scope}__#{target}__reducer__hour", s3_key)
      else
        # We should only remove files that were previously in the set
        # Thus if we don't match the s3_key it is an error
        raise "Unknown file #{s3_key}"
      end
    end

    def self.all_files(type:, target:, scope:)
      Store.smembers("#{scope}__#{target}__reducer__#{type.downcase}").sort
    end
  end
end
