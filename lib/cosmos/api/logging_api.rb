# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

module Cosmos
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
      'get_cmd_log_filename',
      'get_tlm_log_filename',
      'start_logging',
      'stop_logging',
      'start_cmd_log',
      'start_tlm_log',
      'stop_cmd_log',
      'stop_tlm_log',
      'start_raw_logging_interface',
      'stop_raw_logging_interface',
      'start_raw_logging_router',
      'stop_raw_logging_router',
      'get_server_message_log_filename',
      'start_new_server_message_log',
      'get_packet_loggers',
      'get_packet_logger_info',
      'get_all_packet_logger_info',
      'get_output_logs_filenames',
      'subscribe_server_messages',
      'unsubscribe_server_messages',
      'get_server_message',
    ])

    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing the command packet log
    # @return [String] The command packet log filename
    def get_cmd_log_filename(packet_log_writer_name = 'DEFAULT', scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing the telemetry packet log
    # @return [String] The telemetry packet log filename
    def get_tlm_log_filename(packet_log_writer_name = 'DEFAULT', scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Start both command and telemetry packet logging.
    #
    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing both the command and telemetry logs
    # @param label [String] Optional label to apply to both the command and
    #   telemetry packet log filename
    def start_logging(packet_log_writer_name = 'ALL', label = nil, scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Stop both command and telemetry packet logging.
    #
    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing both the command and telemetry logs
    def stop_logging(packet_log_writer_name = 'ALL', scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Start command packet logging.
    #
    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing the command logs
    # @param label [String] Optional label to apply to the command packet log
    #   filename
    def start_cmd_log(packet_log_writer_name = 'ALL', label = nil, scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Start telemetry packet logging.
    #
    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing the telemetry logs
    # @param label [String] Optional label to apply to the telemetry packet log
    #   filename
    def start_tlm_log(packet_log_writer_name = 'ALL', label = nil, scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Stop command packet logging.
    #
    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing the command log
    def stop_cmd_log(packet_log_writer_name = 'ALL', scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Stop telemetry packet logging.
    #
    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing the telemetry log
    def stop_tlm_log(packet_log_writer_name = 'ALL', scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Starts raw logging for an interface
    #
    # @param interface_name [String] The name of the interface
    def start_raw_logging_interface(interface_name = 'ALL', scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Stop raw logging for an interface
    #
    # @param interface_name [String] The name of the interface
    def stop_raw_logging_interface(interface_name = 'ALL', scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Starts raw logging for a router
    #
    # @param router_name [String] The name of the router
    def start_raw_logging_router(router_name = 'ALL', scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Stops raw logging for a router
    #
    # @param router_name [String] The name of the router
    def stop_raw_logging_router(router_name = 'ALL', scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # @return [String] The server message log filename
    def get_server_message_log_filename(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Starts a new server message log
    def start_new_server_message_log(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Get the list of packet loggers.
    #
    # @return [Array<String>] Array containing the names of all packet loggers
    def get_packet_loggers(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      return CmdTlmServer.packet_logging.all.keys
    end

    # Get information about a packet logger.
    #
    # @param packet_logger_name [String] Name of the packet logger
    # @return [Array<<Array<String>, Boolean, Numeric, String, Numeric,
    #   Boolean, Numeric, String, Numeric>] Array containing \[interfaces,
    #   cmd logging enabled, cmd queue size, cmd filename, cmd file size,
    #   tlm logging enabled, tlm queue size, tlm filename, tlm file size]
    #   for the packet logger
    def get_packet_logger_info(packet_logger_name = 'DEFAULT', scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      logger_info = CmdTlmServer.packet_logging.get_info(packet_logger_name)
      packet_log_writer_pair = CmdTlmServer.packet_logging.all[packet_logger_name.upcase]
      interfaces = []
      CmdTlmServer.interfaces.all.each do |interface_name, interface|
        if interface.packet_log_writer_pairs.include?(packet_log_writer_pair)
          interfaces << interface.name
        end
      end
      return [interfaces] + logger_info
    end

    def get_all_packet_logger_info(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      info = []
      CmdTlmServer.packet_logging.all.keys.sort.each do |packet_logger_name|
        packet_log_writer_pair = CmdTlmServer.packet_logging.all[packet_logger_name.upcase]
        interfaces = []
        CmdTlmServer.interfaces.all.each do |interface_name, interface|
          if interface.packet_log_writer_pairs.include?(packet_log_writer_pair)
            interfaces << interface.name
          end
        end
        info << [packet_logger_name, interfaces].concat(CmdTlmServer.packet_logging.get_info(packet_logger_name))
      end
      info
    end

    # Get the list of filenames in the outputs logs folder
    def get_output_logs_filenames(filter = '*tlm.bin', scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # @see CmdTlmServer.subscribe_server_messages
    def subscribe_server_messages(queue_size = CmdTlmServer::DEFAULT_SERVER_MESSAGES_QUEUE_SIZE, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      CmdTlmServer.subscribe_server_messages(queue_size)
    end

    # @see CmdTlmServer.unsubscribe_server_messages
    def unsubscribe_server_messages(id, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      CmdTlmServer.unsubscribe_server_messages(id)
    end

    # @see CmdTlmServer.get_server_message
    def get_server_message(id, non_block = false, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      CmdTlmServer.get_server_message(id, non_block)
    end
  end
end