# This code must be run on the database server
# The file to be imported should be placed in its final storage location - Note that it is
# imported in place with algorithms that attempt to prevent duplicate creation of
# Database entries

require 'ostruct'
require 'optparse'

options = OpenStruct.new
options.force = false

parser = OptionParser.new do |option_parser|
  option_parser.banner = "Usage: dart_import filename"
  option_parser.separator("")

  # Create the help option
  option_parser.on("-h", "--help", "Show this message") do
    puts option_parser
    exit
  end

  # Create the version option
  option_parser.on("-v", "--version", "Show version") do
    puts "COSMOS Version: #{COSMOS_VERSION}"
    puts "User Version: #{USER_VERSION}" if defined? USER_VERSION
    exit
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

require File.expand_path('../../config/environment', __FILE__)
require 'dart_common'
include DartCommon

Cosmos::Logger.level = Cosmos::Logger::INFO

Cosmos.catch_fatal_exception do

  sync_targets_and_packets()

  unless ARGV[0]
    puts parser
    exit
  end

  filename = File.expand_path(ARGV[0])

  directory = File.dirname(filename)
  if directory != Cosmos::System.paths['DART_DATA']
    Cosmos::Logger.fatal("Imported files must be in \"#{Cosmos::System.paths['DART_DATA']}\"")
    Cosmos::Logger.fatal("  File is in: \"#{directory}\"")
    exit(1)
  end

  # Make sure this file isn't already imported
  packet_log = PacketLog.where("filename = ?", filename).first
  if packet_log
    Cosmos::Logger.warn("PacketLog already exists in database: #{filename}")
  end

  # Determine if this is a command or telemetry packet log
  plr = Cosmos::PacketLogReader.new
  plr.open(filename)
  if plr.log_type == :TLM
    is_tlm = true
  else
    is_tlm = false
  end

  build_lookups()

  # Check if first and last packet in the log are already in the database
  last_packet = plr.last
  first_packet = plr.first
  plr.close
  unless first_packet and last_packet
    Cosmos::Logger.fatal("No packets found in file. Exiting...")
    exit(1)
  end

  first_ple = find_packet_log_entry(first_packet, is_tlm)
  last_ple = find_packet_log_entry(last_packet, is_tlm)

  fast = false
  if first_ple and last_ple
    Cosmos::Logger.warn("First and Last Packet in File Already in Database.")
    if options.force
      Cosmos::Logger.warn("Reverifying all packets in database due to force...")
    else
      Cosmos::Logger.info("Complete")
      exit(1)
    end
  elsif !first_ple and !last_ple
    Cosmos::Logger.info("First and Last Packet in File not in database")
    fast = true
  else
    Cosmos::Logger.warn("File partially in database. Will verify each packet before adding")
  end

  unless packet_log
    # Create PacketLog
    Cosmos::Logger.info("Creating PacketLog entry for file: #{filename}")
    packet_log = PacketLog.create(:filename => filename, :is_tlm => is_tlm)
  end

  # Read File and Create PacketLogEntries
  count = 0
  meta_id = nil
  plr.open(filename)
  data_offset = plr.bytes_read
  plr.each(filename) do |packet|
    target_name = packet.target_name
    target_name = 'UNKNOWN' unless target_name
    packet_name = packet.packet_name
    packet_name = 'UNKNOWN' unless packet_name

    target_id, packet_id = lookup_target_and_packet_id(target_name, packet_name, is_tlm)

    if fast
      ple = nil
    else
      ple = find_packet_log_entry(packet, is_tlm)
    end

    unless ple
      ple = PacketLogEntry.new
      ple.target_id = target_id
      ple.packet_id = packet_id
      ple.time = packet.received_time
      ple.packet_log_id = packet_log.id
      ple.data_offset = data_offset
      ple.meta_id = meta_id
      ple.is_tlm = is_tlm
      ple.ready = true
      ple.save!
      count += 1

      if target_name == 'SYSTEM'.freeze and packet_name == 'META'.freeze
        # Need to update meta_id
        meta_id = ple.id
        ple.meta_id = meta_id
        ple.save!
      end
    else
      if target_name == 'SYSTEM'.freeze and packet_name == 'META'.freeze
        # Need to update meta_id
        meta_id = ple.id
      end
    end

    data_offset = plr.bytes_read
  end

  Cosmos::Logger.info("Added #{count} packet log entries to database")
end
