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
  when 'showpleerrors'
    ples = PacketLogEntry.where("decom_state >= 3").find_each do |ple|
      puts "#{ple.id}: #{ple.decom_state_string}(#{ple.decom_state})"
    end

  when 'resetpleerrors'
    PacketLogEntry.where("decom_state >= 3").update_all(:decom_state => 0)
    puts "All errored PLEs set to decom_state 0"

  when 'fullcleanup'
    Cosmos::Logger.level = Cosmos::Logger::INFO
    DartDatabaseCleaner.clean(false, true)

  when 'removepacketlog'
    puts "Removing database entries for packet log #{ARGV[1]}"
    puts "Note!!! This does not delete the file"
    Cosmos::Logger.level = Cosmos::Logger::INFO
    DartDatabaseCleaner.new.remove_packet_log(ARGV[1])

  when 'showpacketlogs'
    total_size = 0
    packet_logs = PacketLog.all
    filenames = []
    reader = Cosmos::PacketLogReader.new
    packet_logs.each do |pl|
      filenames << pl.filename
      if File.exist?(pl.filename)
        exists = "FOUND  "
        size = File.size(pl.filename)
        reader.open(pl.filename)
        begin
          first_packet = reader.first
          last_packet = reader.last
          start_time = first_packet.packet_time.formatted
          end_time = last_packet.packet_time.formatted
        rescue
          if size == 128 or size == 0
            start_time = "EMPTY                  "
            end_time = "EMPTY                  "
          else
            start_time = "ERROR                  "
            end_time = "ERROR                  "
          end
        ensure
          reader.close
        end
      else
        size = 0
        start_time = "MISSING               "
        end_time = "MISSING               "
        exists = "MISSING"
      end
      puts "#{"%-32.32s" % File.basename(pl.filename)}  #{exists}  #{start_time}  #{end_time}  #{size}"
      total_size += size
    end
    other_size = 0
    Cosmos.set_working_dir do
      Dir[Cosmos::System.paths['DART_DATA'] + '/*.bin'].each do |filename|
        next if filename[0] == '.'
        next if filenames.include?(filename)
        exists = "NOTINDB"
        size = File.size(filename)
        reader.open(filename)
        begin
          first_packet = reader.first
          last_packet = reader.last
          start_time = first_packet.packet_time.formatted
          end_time = last_packet.packet_time.formatted
        rescue
          if size == 128 or size == 0
            start_time = "EMPTY                  "
            end_time = "EMPTY                  "
          else
            start_time = "ERROR                  "
            end_time = "ERROR                  "
          end
        ensure
          reader.close
        end
        puts "#{"%-32.32s" % File.basename(filename)}  #{exists}  #{start_time}  #{end_time}  #{size}"
        other_size += size
      end
    end
    puts "Total size in database: #{"%0.2f GB" % (total_size.to_f / (1024 * 1024 * 1024))}"
    puts "Total size not in database: #{"%0.2f GB" % (other_size.to_f / (1024 * 1024 * 1024))}"
  end
end
