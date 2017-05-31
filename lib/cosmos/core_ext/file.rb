# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'find'

# COSMOS specific additions to the Ruby File class
class File
  # Non printable ASCII characters
  NON_ASCII_PRINTABLE = /[^\x21-\x7e\s]/

  # @return [Boolean] Whether the file only contains ASCII characters
  def self.is_ascii?(filename)
    return_value = true
    File.open(filename) do |file|
      while buf = file.read(1024)
        if buf =~ NON_ASCII_PRINTABLE
          return_value = false
          break
        end
      end
    end
    return return_value
  end

  # Builds a String for use in creating a file. The time is formatted as
  # YYYY_MM_DD_HH_MM_SS. The tags and joined with an underscore and appended to
  # the date before appending the extension.
  #
  # For example:
  #   File.build_timestamped_filename(['test','only'], '.bin', Time.now.sys)
  #   # result is YYYY_MM_DD_HH_MM_SS_test_only.bin
  #
  # @param tags [Array<String>] An array of strings to be joined by underscores
  #   after the date. Pass nil or an empty array to use no tags.
  # @param extension [String] The filename extension
  # @param time [Time] The time to format into the filename
  # @return [String] The filename string containing the timestamp, tags, and
  #   extension
  def self.build_timestamped_filename(tags = nil, extension = '.txt', time = Time.now.sys)
    timestamp = sprintf("%04u_%02u_%02u_%02u_%02u_%02u", time.year, time.month, time.mday, time.hour, time.min, time.sec)
    tags ||= []
    tags.compact!
    combined_tags = tags.join("_")
    if combined_tags.length > 0
      filename = timestamp + "_" + combined_tags + extension
    else
      filename = timestamp + extension
    end
    return filename
  end

  # @param filename [String] The file to search for
  # @return [String] The full path to the filename if it was found in the Ruby
  #   search path. nil if the fild was not found.
  def self.find_in_search_path(filename)
    $:.each do |load_path|
      begin
        Find.find(load_path) do |path|
          Find.prune if path =~ /\.svn/
          return path if File.basename(path) == filename
        end
      rescue Errno::ENOENT
        # Ignore non-existent folders
        next
      end
    end
    return nil
  end
end
