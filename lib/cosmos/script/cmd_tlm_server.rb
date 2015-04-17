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

  end # module Script

end # module Cosmos
