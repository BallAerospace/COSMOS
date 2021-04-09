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

require 'cosmos/logs/log_writer'

module Cosmos
  # Creates a text log. Can automatically cycle the log based on an elasped
  # time period or when the log file reaches a predefined size.
  class TextLogWriter < LogWriter

    # Write to the log file.
    #
    # If no log file currently exists in the filesystem, a new file will be
    # created.
    #
    # @param time_nsec_since_epoch [Integer] 64 bit integer nsecs since EPOCH
    # @param data [String] String of data
    # @param redis_offset [Integer] The offset of this packet in its Redis stream
    def write(time_nsec_since_epoch, data, redis_offset)
      return if !@logging_enabled
      @mutex.synchronize do
        prepare_write(time_nsec_since_epoch, data.length, redis_offset)
        write_entry(time_nsec_since_epoch, data) if @file
      end
    rescue => err
      Logger.instance.error "Error writing #{@filename} : #{err.formatted}"
      Cosmos.handle_critical_exception(err)
    end

    def write_entry(time_nsec_since_epoch, data)
      @entry.clear
      @entry << "#{time_nsec_since_epoch}\t"
      @entry << "#{data}\n"
      @file.write(@entry)
      @file_size += @entry.length
      @first_time = time_nsec_since_epoch if !@first_time or time_nsec_since_epoch < @first_time
      @last_time = time_nsec_since_epoch if !@last_time or time_nsec_since_epoch > @last_time
    end

    def s3_filename
      "#{first_timestamp}__#{last_timestamp}__notifications" + extension
    end

    def extension
      '.txt'.freeze
    end
  end
end
