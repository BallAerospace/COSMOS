# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'dart_common'

class DartDatabaseCleaner
  include DartCommon

  # Clean the DART database of various issues. Note that this code can exit(1)
  # if the DART packet logs were moved and force is false (default). This is
  # deliberate because force causes all the lost (or moved) files to be deleted
  # which forces them to be re-imported at their new location.
  def self.clean(force, full = false)
    Cosmos::Logger::info("Starting database cleanup...")
    cleaner = DartDatabaseCleaner.new
    cleaner.clean_system_configs()
    cleaner.clean_packet_logs(force)
    cleaner.clean_packet_configs()
    cleaner.clean_packet_log_entries()
    if full
      cleaner.clean_decommutation_tables()
      cleaner.clean_reductions()
    end
    Cosmos::Logger::info("Database cleanup complete!")
  end

  def self.remove_packet_log(filename)
    filename = filename.gsub("\\", "/") # Fix slashes
    filename = File.expand_path(filename, Cosmos::System.paths['DART_DATA']) # Make absolute path
  end

  # Ensure we have all the System Configs locally on the DART machine
  def clean_system_configs
    Cosmos::Logger::info("Cleaning up SystemConfig...")
    system_config = SystemConfig.all.each do |sc|
       begin
        # This attempts to load the system config and if it can't be found
        # it is copied from the server to the local DART machine
        switch_and_get_system_config(sc.name)
      rescue => err
        Cosmos::Logger.error("Could not load system_config: #{sc.name}: #{err.message}")
        next
      end
    end
    Cosmos::System.load_configuration
  end

  # Ensure all packet log files still exist
  def clean_packet_logs(force)
    Cosmos::Logger::info("Cleaning up PacketLog...")
    PacketLog.find_each do |pl|
      unless File.exist?(pl.filename)
        # Try to see if it is in the current DART_DATA folder
        moved_filename = File.join(Cosmos::System.paths['DART_DATA'], File.basename(pl.filename))
        if File.exist?(moved_filename)
          pl.filename = moved_filename
          pl.save!
        else
          if force
            Cosmos::Logger.error("Packet Log File Missing: #{pl.filename}")
            pl.destroy # This also destroys linked PacketLogEntry(s)
          else
            Cosmos::Logger.fatal("Packet Log File Missing (Cleanup with --force-cleanup): #{pl.filename}")
            exit(1)
          end
        end
      end
    end
  end

  # Check for bad packet configs and cleanup. This typically doesn't happen because
  # PacketConfig entries are created quickly but if something happens during the setup
  # we attempt to fix it here.
  def clean_packet_configs
    Cosmos::Logger::info("Cleaning up PacketConfig...")
    packet_configs = PacketConfig.where("ready != true")
    return unless packet_configs.length > 0
    Cosmos::Logger::info("Num PacketConfigs requiring cleanup: #{packet_configs.length}")
    packet_configs.each do |packet_config|
      begin
        system_config = SystemConfig.find(packet_config.first_system_config_id)
        packet_model = Packet.find(packet_config.packet_id)
        target_model = Target.find(packet_model.target_id)
        current_config, error = Cosmos::System.load_configuration(system_config.name)
        if current_config == system_config.name
          if packet_model.is_tlm
            packet = Cosmos::System.telemetry.packet(target_model.name, packet_model.name)
          else
            packet = Cosmos::System.commands.packet(target_model.name, packet_model.name)
          end
          setup_packet_config(packet, packet_model.id, packet_config)
          Cosmos::Logger::info("Successfully cleaned up packet_config: #{packet_config.id}")
        else
          Cosmos::Logger::error("Could not switch to system config: #{system_config.name}: #{error}")
        end
      rescue => err
        Cosmos::Logger::error("Error cleaning up packet config: #{packet_config.id}: #{err.formatted}")
        raise "Cleanup failure - Database requires manual correction"
      end
    end
  end

  # Remove not ready packet log entries as well as partially decommutated data.
  def clean_packet_log_entries
    Cosmos::Logger::info("Cleaning up PacketLogEntry...")
    # Remove not ready packet log entries. Packet log entries remain not ready until the
    # log file containing the packet has been flushed to disk. Thus there are always
    # outstanding entries which are not ready while packets are being received.
    # Note the normal shutdown process attempts to flush the log file and mark
    # all outstanding entries as ready so this would only happen during a crash.
    ples = PacketLogEntry.where("ready != true")
    return unless ples.length > 0
    Cosmos::Logger::info("Removing unready packet log entries: #{ples.length}")
    ples.destroy_all
  end

  def clean_decommutation_tables
    Cosmos::Logger::info("Cleaning up Decommutation tables (tX_Y)...")
    # Check for partially decom data and remove. The DartWorker periodically checks the
    # database for a PacketLogEntry which is ready to be decommutated and starts the
    # process of writing into the decommutation table. If this process is interrupted
    # the state could be IN_PROGRESS instead of COMPLETE. Thus delete all the decommutation
    # table rows which were created and allow this process to start from scratch.
    ples = PacketLogEntry.where("decom_state = #{PacketLogEntry::IN_PROGRESS}")
    return unless ples.length > 0
    Cosmos::Logger::info("Num PacketLogEntries requiring cleanup: #{ples.length}")
    ples.each do |ple|
      begin
        packet = read_packet_from_ple(ple)
        packet_config = PacketConfig.where("packet_id = ? and name = ?", ple.packet_id, packet.config_name).first
        # Need to delete any rows for these ples in the table for this packet_config
        packet_config.max_table_index.times do |table_index|
          model = get_decom_table_model(packet_config.id, table_index)
          model.where("ple_id = ?", ple.id).destroy_all
        end
        ple.decom_state = PacketLogEntry::NOT_STARTED
        ple.save!
      rescue => err
        Cosmos::Logger::error("Error cleaning up packet log entry: #{ple.id}: #{err.formatted}")
      end
    end
  end

  def clean_reductions
    Cosmos::Logger::info("Cleaning up Reductions...")
    # TBR: This cleanup may be too slow to be worth it for a large data set...
    each_decom_and_reduced_table() do |packet_config_id, table_index, decom_model, minute_model, hour_model, day_model|
      decom_model.where("reduced_state = #{REDUCED} and reduced_id IS NULL").update_all(:reduced_state => READY_TO_REDUCE)
      minute_model.where("reduced_state = #{REDUCED} and reduced_id IS NULL").update_all(:reduced_state => READY_TO_REDUCE)
      hour_model.where("reduced_state = #{REDUCED} and reduced_id IS NULL").update_all(:reduced_state => READY_TO_REDUCE)
      # Note: These should be destroyed when cleaning up decom tables
      rows = decom_model.where("reduced_state = #{INITIALIZING}")
      rows.destroy_all
      # This cleanup is only here
      rows = minute_model.where("reduced_state = #{INITIALIZING}")
      rows.each do |row|
        decom_model.where("reduced_id = ?", row.id).update_all(:reduced_state => READY_TO_REDUCE, :reduced_id => nil)
      end
      rows.destroy_all
      rows = hour_model.where("reduced_state = #{INITIALIZING}")
      rows.each do |row|
        minute_model.where("reduced_id = ?", row.id).update_all(:reduced_state => READY_TO_REDUCE, :reduced_id => nil)
      end
      rows.destroy_all
      rows = day_model.where("reduced_state = #{INITIALIZING}")
      rows.each do |row|
        hour_model.where("reduced_id = ?", row.id).update_all(:reduced_state => READY_TO_REDUCE, :reduced_id => nil)
      end
      rows.destroy_all
    end
  end
end
