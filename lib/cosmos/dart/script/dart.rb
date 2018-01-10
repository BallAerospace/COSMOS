require File.expand_path('../../config/environment', __FILE__)
require 'dart_common'
require 'dart_logging'
require 'childprocess'

class Dart
  include DartCommon

  def cleanup
    Cosmos::Logger::info("Starting database cleanup...")

    # Make sure we have all the System Configs
    Cosmos::Logger::info("Cleaning up SystemConfigs...")
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

    # Make sure all packet logs exist and if not drop the associated PacketLogEntry
    # NOTE: This means you can't move packet logs!
    Cosmos::Logger::info("Cleaning up PacketLogs...")
    PacketLog.find_each do |pl|
      unless File.exist?(pl.filename)
        Cosmos::Logger.error("Packet Log File Missing: #{pl.filename}")
        PacketLogEntry.where("packet_log_id = ?", pl.id).destroy_all
      end
    end

    # Check for bad packet configs and cleanup. This typically doesn't happen because
    # PacketConfig entries are created quickly but if something happens during the setup
    # we attempt to fix it here.
    packet_configs = PacketConfig.where("ready != true")
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

    # Remove not ready packet log entries. Packet log entries remain not ready until the
    # log file containing the packet has been flushed to disk. Thus there are always
    # outstanding entries which are not ready while packets are being received.
    # Note the normal shutdown process attempts to flush the log file and mark
    # all outstanding entries as ready so this would only happen during a crash.
    ples = PacketLogEntry.where("ready != true")
    Cosmos::Logger::info("Removing unready packet log entries: #{ples.length}")
    ples.destroy_all

    # Check for partially decom data and remove. The DartWorker periodically checks the
    # database for a PacketLogEntry which is ready to be decommutated and starts the
    # process of writing into the decommutation table. If this process is interrupted
    # the state could be IN_PROGRESS instead of COMPLETE. Thus delete all the decommutation
    # table rows which were created and allow this process to start from scratch.
    ples = PacketLogEntry.where("decom_state = #{PacketLogEntry::IN_PROGRESS}")
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
        ple.save
      rescue => err
        Cosmos::Logger::error("Error cleaning up packet log entry: #{ple.id}: #{err.formatted}")
      end
    end

    Cosmos::Logger::info("Database cleanup complete!")
  end

  # Start all the DART processes:
  # 1. Ingester - writes all packets to the DART log file
  # 2. Reducer - reduces decommutated data by minute, hour, and day
  # 3. Stream Server - TCPIP server which handles requests for raw data
  #      streamed from the packet log binary file
  # 4. Decom Server - JSON DRB server which handles requests for decommutated
  #      or reduced data from the database
  # 5..n Worker - Decommutates data from the packet log binary file into the DB
  def run
    Cosmos::Logger.level = Cosmos::Logger::INFO
    dart_logging = DartLogging.new('dart')

    # Cleanup the database before starting processes
    cleanup()

    ruby_process_name = ENV['DART_RUBY']
    ruby_process_name ||= 'ruby'

    num_workers = ENV['DART_NUM_WORKERS']
    num_workers ||= 1
    num_workers = num_workers.to_i

    process_definitions = [
      [ruby_process_name, File.join(__dir__, 'dart_ingester.rb')],
      [ruby_process_name, File.join(__dir__, 'dart_reducer.rb')],
      [ruby_process_name, File.join(__dir__, 'dart_stream_server.rb')],
      [ruby_process_name, File.join(__dir__, 'dart_decom_server.rb')]
    ]

    num_workers.times do |index|
      process_definitions << [ruby_process_name, File.join(__dir__, 'dart_worker.rb'), index.to_s, num_workers.to_s]
    end

    processes = []
    p_mutex = Mutex.new

    # Start all the processes.rb
    Cosmos::Logger.info("Dart starting each process...")

    process_definitions.each do |p|
      Cosmos::Logger.info("Starting: #{p.join(' ')}")
      processes << ChildProcess.build(*p)
      processes[-1].leader = true
      processes[-1].start
    end

    # Setup signal handlers to shutdown cleanly
    ["TERM", "INT"].each do |sig|
      Signal.trap(sig) do
        @shutdown = true
        Thread.new do
          p_mutex.synchronize do
            Cosmos::Logger.info("Shutting down processes...")
            processes.each_with_index do |p, index|
              Cosmos::Logger.info("Soft Shutting down process: #{process_definitions[index].join(' ')}")
              Process.kill("SIGINT", p.pid)
            end
            sleep(2)
            processes.each_with_index do |p, index|
              unless p.exited?
                Cosmos::Logger.info("Hard Shutting down process: #{process_definitions[index].join(' ')}")
                p.stop
              end
            end
            @shutdown_complete = true
          end
        end
      end
    end

    # Monitor processes and respawn if died
    @shutdown = false
    @shutdown_complete = false
    Cosmos::Logger.info("Dart Monitoring processes...")
    loop do
      p_mutex.synchronize do
        processes.each_with_index do |p, index|
          break if @shutdown
          unless p.alive?
            # Respawn process
            Cosmos::Logger.error("Unexpected process died... respawning! #{process_definitions[index].join(' ')}")
            processes[index] = ChildProcess.build(*process_definitions[index])
            processes[index].leader = true
            processes[index].start
          end
        end
      end
      break if @shutdown
      sleep(1)
      break if @shutdown
    end

    loop do
      break if @shutdown_complete
      sleep(1)
    end

    Cosmos::Logger.info("Dart successful shutdown complete")
    shutdown_cmd_tlm()
    dart_logging.stop
  end

  def self.run
    Cosmos.catch_fatal_exception do
      a = self.new
      a.run
    end
  end
end

DartCommon.handle_argv
