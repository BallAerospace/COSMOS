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

include DartCommon

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

  when 'showdatabase'
    puts "Status:"
    status = Status.last
    puts "  Updated At: #{status.updated_at.formatted}"
    puts "  Decom Count: #{status.decom_count}"
    puts "  Decom Error Count: #{status.decom_error_count}"
    puts "  Decom Message: #{status.decom_message}"
    puts "  Decom Message Time: #{status.decom_message_time.formatted}"
    puts "  Reduction Count: #{status.reduction_count}"
    puts "  Reduction Error Count: #{status.reduction_error_count}"
    puts "  Reduction Message: #{status.reduction_message}"
    puts "  Reduction Message Time: #{status.reduction_message_time}"
    puts ""

    puts "System Configs:"
    SystemConfig.all.each do |system_config|
      puts "  #{sprintf("%6d", system_config.id)} #{system_config.name}"
    end
    puts ""

    puts "Targets:"
    Target.all.each do |target|
      puts "  #{sprintf("%6d", target.id)} #{target.name}"
    end
    puts ""
    
    puts "Packets:"
    Packet.all.each do |packet|
      target = Target.find(packet.target_id)
      puts "  #{sprintf("%6d", packet.id)} #{target.name} #{packet.name} (#{packet.is_tlm ? "TLM" : "CMD"})"
    end
    puts ""

    puts "Items:"
    Item.find_each do |item|
      packet = Packet.find(item.packet_id)
      target = Target.find(packet.target_id)
      puts "  #{sprintf("%6d", item.id)} #{target.name} #{packet.name} #{item.name}"
    end
    puts ""

    puts "Packet Logs:"
    PacketLog.all.each do |packet_log|
      puts "  #{sprintf("%6d", packet_log.id)} #{packet_log.filename} (#{packet_log.is_tlm ? "TLM" : "CMD"}) #{packet_log.created_at.formatted}"
    end
    puts ""
    
    puts "Packet Log Entry Count: #{PacketLogEntry.count}"
    puts ""
    
    puts "Packet Configs:"
    PacketConfig.all.each do |packet_config|
      packet = Packet.find(packet_config.packet_id)
      target = Target.find(packet.target_id)
      puts "  #{sprintf("%6d", packet_config.id)} #{target.name} #{packet.name} (#{packet_config.name}) sysconfig:#{packet_config.first_system_config_id} maxindex:#{packet_config.max_table_index} ready:#{packet_config.ready} start:#{packet_config.start_time.formatted} end:#{packet_config.end_time.formatted}"
    end
    puts ""
    
    value_type_lookup = {0 => "RAW", 1 => "CONVERTED", 2 => "RAW_CON"}
    puts "Item to Decom Table Mappings:"
    ItemToDecomTableMapping.find_each do |itdtm|
      item = Item.find(itdtm.item_id)
      packet = Packet.find(item.packet_id)
      target = Target.find(packet.target_id)
      puts "  #{sprintf("%6d", itdtm.id)} #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]} packet_config:#{itdtm.packet_config_id} item_index:#{itdtm.item_index} table_index:#{itdtm.table_index} reduced:#{itdtm.reduced}"
    end
    puts ""
    
    puts "Decom and Reduced Tables:"
    each_decom_and_reduced_table do |packet_config_id, table_index, decom_model, minute_model, hour_model, day_model|
      puts "  t#{decom_model.name.split("::")[1][1..-1]}: (#{decom_model.count} entries)"
      ItemToDecomTableMapping.where("packet_config_id = ? and table_index = ?", packet_config_id, table_index).order("item_index ASC").each do |itdtm|
        item = Item.find(itdtm.item_id)
        packet = Packet.find(item.packet_id)
        target = Target.find(packet.target_id)
        puts "    i#{itdtm.item_index} #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
      end
      puts ""
      puts "  t#{minute_model.name.split("::")[1][1..-1]}: (#{minute_model.count} entries)"
      ItemToDecomTableMapping.where("packet_config_id = ? and table_index = ? and reduced = true", packet_config_id, table_index).order("item_index ASC").each do |itdtm|
        item = Item.find(itdtm.item_id)
        packet = Packet.find(item.packet_id)
        target = Target.find(packet.target_id)
        puts "    i#{itdtm.item_index}max #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
        puts "    i#{itdtm.item_index}min #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
        puts "    i#{itdtm.item_index}avg #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
        puts "    i#{itdtm.item_index}stddev #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
      end      
      puts ""
      puts "  t#{hour_model.name.split("::")[1][1..-1]}: (#{hour_model.count} entries)"
      ItemToDecomTableMapping.where("packet_config_id = ? and table_index = ? and reduced = true", packet_config_id, table_index).order("item_index ASC").each do |itdtm|
        item = Item.find(itdtm.item_id)
        packet = Packet.find(item.packet_id)
        target = Target.find(packet.target_id)
        puts "    i#{itdtm.item_index}max #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
        puts "    i#{itdtm.item_index}min #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
        puts "    i#{itdtm.item_index}avg #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
        puts "    i#{itdtm.item_index}stddev #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
      end    
      puts ""      
      puts "  t#{day_model.name.split("::")[1][1..-1]}: (#{day_model.count} entries)"
      ItemToDecomTableMapping.where("packet_config_id = ? and table_index = ? and reduced = true", packet_config_id, table_index).order("item_index ASC").each do |itdtm|
        item = Item.find(itdtm.item_id)
        packet = Packet.find(item.packet_id)
        target = Target.find(packet.target_id)
        puts "    i#{itdtm.item_index}max #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
        puts "    i#{itdtm.item_index}min #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
        puts "    i#{itdtm.item_index}avg #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
        puts "    i#{itdtm.item_index}stddev #{target.name} #{packet.name} #{item.name} #{value_type_lookup[itdtm.value_type]}"
      end      
      puts ""
    end
    
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
