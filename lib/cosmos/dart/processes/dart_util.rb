# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This code must be run on the database server

require 'ostruct'
require 'optparse'
require 'cosmos/version'

options = OpenStruct.new
options.force = false

parser = OptionParser.new do |option_parser|
  option_parser.banner = "Usage: dart_util <action> [options]"
  option_parser.separator("")

  # Create the help option
  option_parser.on("-h", "--help", "Show this message") do
    puts option_parser
    exit(0)
  end

  # Create the version option
  option_parser.on("-v", "--version", "Show version") do
    puts "COSMOS Version: #{COSMOS_VERSION}"
    puts "User Version: #{USER_VERSION}" if defined? USER_VERSION
    exit(0)
  end

  # Create the system option
  option_parser.on("--system FILE", "Use an alternative system.txt file") do |arg|
    System.instance(File.join(USERPATH, 'config', 'system', arg))
  end

  # Create the force option
  option_parser.on("-f", "--force", "Force parsing entire file") do
    options.force = true
  end
end

parser.parse!(ARGV)
action = ARGV[0]
unless action
  puts parser
  exit(1)
end

ENV['RAILS_ENV'] = 'production'
require File.expand_path('../../config/environment', __FILE__)
require 'dart_database_cleaner'

Cosmos.catch_fatal_exception do
  case action.downcase
  when 'pleerrors'
    ples = PacketLogEntry.where("decom_state >= 3").find_each do |ple|
      puts "#{ple.id}: #{ple.decom_state_string}(#{ple.decom_state})"
    end
  when 'fullcleanup'
    DartDatabaseCleaner.clean(false, true)
  when 'removepacketlog'
    puts "Removing database entries for packet log #{ARGV[1]}"
    puts "Note!!! This does not delete the file"
    DartDatabaseCleaner.remove_packet_log(ARGV[1])
  end
end
