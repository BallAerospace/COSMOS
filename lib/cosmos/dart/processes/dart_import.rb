# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This code must be run on the database server
# The file to be imported should be placed in its final storage location
# Note that it is imported in place with algorithms that attempt to prevent
# duplicate creation of Database entries

require 'ostruct'
require 'optparse'
require 'cosmos/version'

options = OpenStruct.new
options.force = false

parser = OptionParser.new do |option_parser|
  option_parser.banner = "Usage: dart_import filename"
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
unless ARGV[0]
  puts parser
  exit(1)
end

ENV['RAILS_ENV'] = 'production'
require File.expand_path('../../config/environment', __FILE__)
require 'dart_importer'

Cosmos.catch_fatal_exception do
  code = DartImporter.new.import(File.expand_path(ARGV[0]), options.force)
  exit(code)
end
