# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  module Script
    private

    def get_interface_targets(interface_name)
      return $cmd_tlm_server.get_interface_targets(interface_name)
    end

    def get_interface_names
      return $cmd_tlm_server.get_interface_names
    end

    def connect_interface(interface_name, *params)
      return $cmd_tlm_server.connect_interface(interface_name, *params)
    end

    def disconnect_interface(interface_name)
      return $cmd_tlm_server.disconnect_interface(interface_name)
    end

    def interface_state(interface_name)
      return $cmd_tlm_server.interface_state(interface_name)
    end

    def map_target_to_interface(target_name, interface_name)
      return $cmd_tlm_server.map_target_to_interface(target_name, interface_name)
    end

    def get_router_names
      return $cmd_tlm_server.get_router_names
    end

    def connect_router(router_name, *params)
      return $cmd_tlm_server.connect_router(router_name, *params)
    end

    def disconnect_router(router_name)
      return $cmd_tlm_server.disconnect_router(router_name)
    end

    def router_state(router_name)
      return $cmd_tlm_server.router_state(router_name)
    end

    def get_target_info(target_name)
      return $cmd_tlm_server.get_target_info(target_name)
    end

    def get_all_target_info
      return $cmd_tlm_server.get_all_target_info
    end

    def get_target_ignored_parameters(target_name)
      return $cmd_tlm_server.get_target_ignored_parameters(target_name)
    end

    def get_target_ignored_items(target_name)
      return $cmd_tlm_server.get_target_ignored_items(target_name)
    end

    def get_interface_info(interface_name)
      return $cmd_tlm_server.get_interface_info(interface_name)
    end

    def get_all_router_info
      return $cmd_tlm_server.get_all_router_info
    end

    def get_all_interface_info
      return $cmd_tlm_server.get_all_interface_info
    end

    def get_router_info(router_name)
      return $cmd_tlm_server.get_router_info(router_name)
    end

    def get_all_cmd_info
      return $cmd_tlm_server.get_all_cmd_info
    end

    def get_all_tlm_info
      return $cmd_tlm_server.get_all_tlm_info
    end

    def get_cmd_cnt(target_name, command_name)
      return $cmd_tlm_server.get_cmd_cnt(target_name, command_name)
    end

    def get_tlm_cnt(target_name, packet_name)
      return $cmd_tlm_server.get_tlm_cnt(target_name, packet_name)
    end

    def get_packet_loggers
      return $cmd_tlm_server.get_packet_loggers
    end

    def get_packet_logger_info(packet_logger_name)
      return $cmd_tlm_server.get_packet_logger_info(packet_logger_name)
    end

    def get_all_packet_logger_info
      return $cmd_tlm_server.get_all_packet_logger_info
    end

    def get_background_tasks
      return $cmd_tlm_server.get_background_tasks
    end

    def start_background_task(task_name)
      return $cmd_tlm_server.start_background_task(task_name)
    end

    def stop_background_task(task_name)
      return $cmd_tlm_server.stop_background_task(task_name)
    end

    def get_server_status
      return $cmd_tlm_server.get_server_status
    end

    def get_cmd_log_filename(packet_log_writer_name = 'DEFAULT')
      return $cmd_tlm_server.get_cmd_log_filename(packet_log_writer_name)
    end

    def get_tlm_log_filename(packet_log_writer_name = 'DEFAULT')
      return $cmd_tlm_server.get_tlm_log_filename(packet_log_writer_name)
    end

    def start_logging(packet_log_writer_name = 'ALL', label = nil)
      return $cmd_tlm_server.start_logging(packet_log_writer_name, label)
    end

    def stop_logging(packet_log_writer_name = 'ALL')
      return $cmd_tlm_server.stop_logging(packet_log_writer_name)
    end

    def start_cmd_log(packet_log_writer_name = 'ALL', label = nil)
      return $cmd_tlm_server.start_cmd_log(packet_log_writer_name, label)
    end

    def start_tlm_log(packet_log_writer_name = 'ALL', label = nil)
      return $cmd_tlm_server.start_tlm_log(packet_log_writer_name, label)
    end

    def stop_cmd_log(packet_log_writer_name = 'ALL')
      return $cmd_tlm_server.stop_cmd_log(packet_log_writer_name)
    end

    def stop_tlm_log(packet_log_writer_name = 'ALL')
      return $cmd_tlm_server.stop_tlm_log(packet_log_writer_name)
    end

    def start_raw_logging_interface(interface_name = 'ALL')
      return $cmd_tlm_server.start_raw_logging_interface(interface_name)
    end

    def stop_raw_logging_interface(interface_name = 'ALL')
      return $cmd_tlm_server.stop_raw_logging_interface(interface_name)
    end

    def start_raw_logging_router(router_name = 'ALL')
      return $cmd_tlm_server.start_raw_logging_router(router_name)
    end

    def stop_raw_logging_router(router_name = 'ALL')
      return $cmd_tlm_server.stop_raw_logging_router(router_name)
    end

    def get_server_message_log_filename
      return $cmd_tlm_server.get_server_message_log_filename
    end

    def start_new_server_message_log
      return $cmd_tlm_server.start_new_server_message_log
    end

    def subscribe_server_messages(queue_size = CmdTlmServer::DEFAULT_SERVER_MESSAGES_QUEUE_SIZE)
      return $cmd_tlm_server.subscribe_server_messages(queue_size)
    end

    def unsubscribe_server_messages(id)
      return $cmd_tlm_server.unsubscribe_server_messages(id)
    end

    def get_server_message(id, non_block = false)
      return $cmd_tlm_server.get_server_message(id, non_block)
    end

    def cmd_tlm_reload
      return $cmd_tlm_server.cmd_tlm_reload
    end

    def cmd_tlm_clear_counters
      return $cmd_tlm_server.cmd_tlm_clear_counters
    end

    def get_output_logs_filenames(filter = '*tlm.bin')
      return $cmd_tlm_server.get_output_logs_filenames(filter)
    end    

    def get_saved_config(configuration_name = nil)
      return $cmd_tlm_server.get_saved_config(configuration_name)
    end
  end
end
