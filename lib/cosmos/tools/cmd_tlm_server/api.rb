# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/script/extract'
require 'cosmos/script/api_shared'
require 'cosmos/tools/tlm_viewer/tlm_viewer_config'
require 'cosmos/utilities/store'
require 'connection_pool'
require 'redis'

REDIS = ConnectionPool.new(size: 10) { Redis.new(url: "redis://localhost:6379/0") }

module Cosmos

  module Api
    include Extract
    include ApiShared

    # Sets api_requests to 0 and initializes the whitelist of allowable API
    # method calls
    def initialize
      @api_whitelist = [
        'cmd',
        'cmd_no_range_check',
        'cmd_no_hazardous_check',
        'cmd_no_checks',
        'cmd_raw',
        'cmd_raw_no_range_check',
        'cmd_raw_no_hazardous_check',
        'cmd_raw_no_checks',
        'send_raw',
        'get_cmd_buffer',
        'get_cmd_list',
        'get_cmd_param_list',
        'get_cmd_hazardous',
        'get_cmd_value',
        'get_cmd_time',
        'tlm',
        'tlm_raw',
        'tlm_formatted',
        'tlm_with_units',
        'tlm_variable',
        'set_tlm',
        'set_tlm_raw',
        'inject_tlm',
        'override_tlm',
        'override_tlm_raw',
        'normalize_tlm',
        'get_tlm_buffer',
        'get_tlm_packet',
        'get_tlm_values',
        'get_tlm_list',
        'get_tlm_item_list',
        'get_tlm_details',
        'get_out_of_limits',
        'get_overall_limits_state',
        'limits_enabled?',
        'enable_limits',
        'disable_limits',
        'get_stale',
        'get_limits',
        'set_limits',
        'get_limits_groups',
        'enable_limits_group',
        'disable_limits_group',
        'get_limits_sets',
        'set_limits_set',
        'get_limits_set',
        'get_target_list',
        'subscribe_limits_events',
        'unsubscribe_limits_events',
        'get_limits_event',
        'subscribe_packet_data',
        'unsubscribe_packet_data',
        'get_packet_data',
        'subscribe_server_messages',
        'unsubscribe_server_messages',
        'get_server_message',
        'get_interface_targets',
        'get_interface_names',
        'connect_interface',
        'disconnect_interface',
        'interface_state',
        'map_target_to_interface',
        'get_router_names',
        'connect_router',
        'disconnect_router',
        'router_state',
        'get_all_target_info',
        'get_target_info',
        'get_target_ignored_parameters',
        'get_target_ignored_items',
        'get_packet_derived_items',
        'get_interface_info',
        'get_all_interface_info',
        'get_router_info',
        'get_all_router_info',
        'get_all_cmd_info',
        'get_all_tlm_info',
        'get_cmd_cnt',
        'get_tlm_cnt',
        'get_packet_loggers',
        'get_packet_logger_info',
        'get_all_packet_logger_info',
        'get_background_tasks',
        'start_background_task',
        'stop_background_task',
        'get_server_status',
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
        'cmd_tlm_reload',
        'cmd_tlm_clear_counters',
        'get_output_logs_filenames',
        'replay_select_file',
        'replay_status',
        'replay_set_playback_delay',
        'replay_play',
        'replay_reverse_play',
        'replay_stop',
        'replay_step_forward',
        'replay_step_back',
        'replay_move_start',
        'replay_move_end',
        'replay_move_index',
        'get_screen_list',
        'get_screen_definition',
        'get_saved_config',
      ]
      @tlm_viewer_config_filename = nil
      @tlm_viewer_config = nil
    end

    ############################################################################
    # Methods Used by cosmos/script
    ############################################################################

    # Send a command packet to a target.
    #
    # Accepts two different calling styles:
    #   cmd("TGT CMD with PARAM1 val, PARAM2 val")
    #   cmd('TGT','CMD','PARAM1'=>val,'PARAM2'=>val)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args [String|Array<String>] See the description for calling style
    # @return [Array<String, String, Hash>] target_name, command_name, parameters
    def cmd(*args)
      cmd_implementation(true, true, false, 'cmd', *args)
    end

    # Send a command packet to a target without performing any value range
    # checks on the parameters. Useful for testing to allow sending command
    # parameters outside the allowable range as defined in the configuration.
    #
    # Accepts two different calling styles:
    #   cmd_no_range_check("TGT CMD with PARAM1 val, PARAM2 val")
    #   cmd_no_range_check('TGT','CMD','PARAM1'=>val,'PARAM2'=>val)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param (see #cmd)
    # @return (see #cmd)
    def cmd_no_range_check(*args)
      cmd_implementation(false, true, false, 'cmd_no_range_check', *args)
    end

    # Send a command packet to a target without performing any hazardous checks
    # both on the command itself and its parameters. Useful in scripts to
    # prevent popping up warnings to the user.
    #
    # Accepts two different calling styles:
    #   cmd_no_hazardous_check("TGT CMD with PARAM1 val, PARAM2 val")
    #   cmd_no_hazardous_check('TGT','CMD','PARAM1'=>val,'PARAM2'=>val)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param (see #cmd)
    # @return (see #cmd)
    def cmd_no_hazardous_check(*args)
      cmd_implementation(true, false, false, 'cmd_no_hazardous_check', *args)
    end

    # Send a command packet to a target without performing any value range
    # checks or hazardous checks both on the command itself and its parameters.
    #
    # Accepts two different calling styles:
    #   cmd_no_checks("TGT CMD with PARAM1 val, PARAM2 val")
    #   cmd_no_checks('TGT','CMD','PARAM1'=>val,'PARAM2'=>val)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param (see #cmd)
    # @return (see #cmd)
    def cmd_no_checks(*args)
      cmd_implementation(false, false, false, 'cmd_no_checks', *args)
    end

    # Send a command packet to a target without running conversions.
    #
    # Accepts two different calling styles:
    #   cmd_raw("TGT CMD with PARAM1 val, PARAM2 val")
    #   cmd_raw('TGT','CMD','PARAM1'=>val,'PARAM2'=>val)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args [String|Array<String>] See the description for calling style
    # @return [Array<String, String, Hash>] target_name, command_name, parameters
    def cmd_raw(*args)
      cmd_implementation(true, true, true, 'cmd_raw', *args)
    end

    # Send a command packet to a target without performing any value range
    # checks on the parameters or running conversions. Useful for testing to allow sending command
    # parameters outside the allowable range as defined in the configuration.
    #
    # Accepts two different calling styles:
    #   cmd_raw_no_range_check("TGT CMD with PARAM1 val, PARAM2 val")
    #   cmd_raw_no_range_check('TGT','CMD','PARAM1'=>val,'PARAM2'=>val)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param (see #cmd)
    # @return (see #cmd)
    def cmd_raw_no_range_check(*args)
      cmd_implementation(false, true, true, 'cmd_raw_no_range_check', *args)
    end

    # Send a command packet to a target without running conversions or performing any hazardous checks
    # both on the command itself and its parameters. Useful in scripts to
    # prevent popping up warnings to the user.
    #
    # Accepts two different calling styles:
    #   cmd_raw_no_hazardous_check("TGT CMD with PARAM1 val, PARAM2 val")
    #   cmd_raw_no_hazardous_check('TGT','CMD','PARAM1'=>val,'PARAM2'=>val)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param (see #cmd)
    # @return (see #cmd)
    def cmd_raw_no_hazardous_check(*args)
      cmd_implementation(true, false, true, 'cmd_raw_no_hazardous_check', *args)
    end

    # Send a command packet to a target without running conversions or performing any value range
    # checks or hazardous checks both on the command itself and its parameters.
    #
    # Accepts two different calling styles:
    #   cmd_raw_no_checks("TGT CMD with PARAM1 val, PARAM2 val")
    #   cmd_raw_no_checks('TGT','CMD','PARAM1'=>val,'PARAM2'=>val)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param (see #cmd)
    # @return (see #cmd)
    def cmd_raw_no_checks(*args)
      cmd_implementation(false, false, true, 'cmd_raw_no_checks', *args)
    end

    # Send a raw binary string to the specified interface.
    #
    # @param interface_name [String] The interface to send the raw binary
    # @param data [String] The raw binary data
    def send_raw(interface_name, data)
      # TODO: Implement New Commanding
      CmdTlmServer.commanding.send_raw(interface_name, data)
      nil
    end

    # Returns the raw buffer from the most recent specified command packet.
    #
    # @param target_name [String] Target name of the command
    # @param command_name [String] Packet name of the command
    # @return [String] last command buffer packet
    def get_cmd_buffer(target_name, command_name)
      # TODO: Implement New Commanding
      packet = System.commands.packet(target_name, command_name)
      return packet.buffer
    end

    # Returns the list of all the command names and their descriptions from the
    # given target.
    #
    # @param target_name [String] Name of the target
    # @return [Array<Array<String, String>>] Array containing \[command name,
    #   command description] for all commands in the target
    def get_cmd_list(target_name)
      list = []
      packets = {}
      REDIS.with do |redis|
        packets = redis.hgetall("cosmoscmd__#{target_name}")
      end
      packets.each do |packet_name, packet_json|
        packet = JSON.parse(packet_json)
        list << [packet_name, packet['description']]
      end
      list.sort
    end

    # Returns the list of all the parameters for the given command.
    #
    # @param target_name (see #get_cmd_list)
    # @param command_name [String] Name of the command
    # @return [Array<Array<String, Object, nil|Array, nil|String, nil|String,
    #   nil|String, Boolean>] Array containing \[name, default, states,
    #   description, units_full, units, required] for all parameters in the
    #   command
    def get_cmd_param_list(target_name, command_name)
      # TODO: Implement New Commanding
      list = []
      packet_json = nil
      REDIS.with do |redis|
        packet_json = redis.hget("cosmoscmd__#{target_name}", command_name)
      end
      if packet_json
        packet = JSON.parse(packet_json)
        packet['items'].each do |item|
          if item['format_string']
            unless item['default'].kind_of?(Array)
              list << [item['name'], sprintf(item['format_string'], item['default']), item['states'], item['description'], item['units_full'], item['units'], item['required'], item['data_type']]
            else
              list << [item['name'], [], item['states'], item['description'], item['units_full'], item['units'], item['required'], item['data_type']]
            end
          else
            list << [item['name'], item['default'], item['states'], item['description'], item['units_full'], item['units'], item['required'], item['data_type']]
          end
        end
      end
      return list
    end

    # Returns whether the specified command is hazardous
    #
    # @param target_name (see #get_cmd_param_list)
    # @param command_name (see #get_cmd_param_list)
    # @param params [Hash] Command parameter hash to test whether a particular
    #   parameter setting makes the command hazardous
    # @return [Boolean] Whether the command is hazardous
    def get_cmd_hazardous(target_name, command_name, params = {})
      # TODO: Implement New Commanding
      # hazardous, _ = System.commands.cmd_hazardous?(target_name, command_name, params)
      # return hazardous
      return false
    end

    # Returns a value from the specified command
    #
    # @param target_name [String] Target name of the command
    # @param command_name [String] Packet name of the command
    # @param parameter_name [String] Parameter name in the command
    # @param value_type [Symbol] How the values should be converted. Must be
    #   one of {Packet::VALUE_TYPES}
    # @return [Varies] value
    def get_cmd_value(target_name, command_name, parameter_name, value_type = :CONVERTED)
      # TODO: Implement New Commanding
      packet = System.commands.packet(target_name, command_name)
      # Virtually support RECEIVED_TIMEFORMATTED, RECEIVED_TIMESECONDS, RECEIVED_COUNT
      # Also PACKET_TIMEFORMATTED and PACKET_TIMESECONDS
      case parameter_name.to_s.upcase
      when 'PACKET_TIMEFORMATTED'
        if packet.packet_time
          return packet.packet_time.formatted
        else
          return 'No Packet Time'
        end
      when 'PACKET_TIMESECONDS'
        if packet.packet_time
          return packet.packet_time.to_f
        else
          return 0.0
        end
      when 'RECEIVED_TIMEFORMATTED'
        if packet.received_time
          return packet.received_time.formatted
        else
          return 'No Packet Received Time'
        end
      when 'RECEIVED_TIMESECONDS'
        if packet.received_time
          return packet.received_time.to_f
        else
          return 0.0
        end
      when 'RECEIVED_COUNT'
        return packet.received_count
      else
        return packet.read(parameter_name, value_type.intern)
      end
    end

    # Returns the time the most recent command was sent
    #
    # @param target_name [String] Target name of the command. If not given then
    #    the most recent time from all commands will be returned
    # @param command_name [String] Packet name of the command. If not given then
    #    then most recent time from the given target will be returned.
    # @return [Array<Target Name, Command Name, Time Seconds, Time Microseconds>]
    def get_cmd_time(target_name = nil, command_name = nil)
      # TODO: Implement New Commanding
      last_command = nil
      if target_name
        if command_name
          last_command = System.commands.packet(target_name, command_name)
        else
          System.commands.packets(target_name).each do |packet_name, command|
            last_command = command if !last_command and command.received_time
            if command.received_time and command.received_time > last_command.received_time
              last_command = command
            end
          end
        end
      else
        commands = System.commands.all
        commands.each do |_, target_commands|
          target_commands.each do |packet_name, command|
            last_command = command if !last_command and command.received_time
            if command.received_time and command.received_time > last_command.received_time
              last_command = command
            end
          end
        end
      end

      if last_command
        if last_command.received_time
          return [last_command.target_name, last_command.packet_name, last_command.received_time.tv_sec, last_command.received_time.tv_usec]
        else
          return [last_command.target_name, last_command.packet_name, nil, nil]
        end
      else
        return [nil, nil, nil, nil]
      end
    end

    # Request a converted telemetry item from a packet.
    #
    # Accepts two different calling styles:
    #   tlm("TGT PKT ITEM")
    #   tlm('TGT','PKT','ITEM')
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args [String|Array<String>] See the description for calling style
    # @return [Numeric] The converted telemetry value without formatting or
    #   units
    def tlm(*args)
      target_name, packet_name, item_name = tlm_process_args(args, 'tlm')
      REDIS.with do |conn|
        result = conn.hmget("tlm__#{target_name}__#{packet_name}", "#{item_name}__C", item_name)
        return JSON.parse(result[0]) if result[0]
        return JSON.parse(result[1]) if result[1]
        return nil
      end
    end

    # Request a raw telemetry item from a packet.
    #
    # Accepts two different calling styles:
    #   tlm_raw("TGT PKT ITEM")
    #   tlm_raw('TGT','PKT','ITEM')
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args (see #tlm)
    # @return [Numeric] The unconverted telemetry value without formatting or
    #   units
    def tlm_raw(*args)
      target_name, packet_name, item_name = tlm_process_args(args, 'tlm_raw')
      REDIS.with do |conn|
        result = conn.hmget("tlm__#{target_name}__#{packet_name}", item_name)
        return JSON.parse(result[0]) if result[0]
        return nil
      end
    end

    # Request a formatted telemetry item from a packet.
    #
    # Accepts two different calling styles:
    #   tlm_formatted("TGT PKT ITEM")
    #   tlm_formatted('TGT','PKT','ITEM')
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args (see #tlm)
    # @return [String] The converted telemetry value with formatting but
    #   without units
    def tlm_formatted(*args)
      target_name, packet_name, item_name = tlm_process_args(args, 'tlm_formatted')
      REDIS.with do |conn|
        result = conn.hmget("tlm__#{target_name}__#{packet_name}",
          "#{item_name}__F",
          "#{item_name}__C",
          item_name)
        return JSON.parse(result[0].to_s) if result[0]
        return JSON.parse(result[1].to_s) if result[1]
        return JSON.parse(result[2].to_s) if result[2]
        return nil
      end
    end

    # Request a telemetry item with units from a packet.
    #
    # Accepts two different calling styles:
    #   tlm_with_units("TGT PKT ITEM")
    #   tlm_with_units('TGT','PKT','ITEM')
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args (see #tlm)
    # @return [String] The converted, formatted telemetry value with units
    def tlm_with_units(*args)
      target_name, packet_name, item_name = tlm_process_args(args, 'tlm_with_units')
      REDIS.with do |conn|
        result = conn.hmget("tlm__#{target_name}__#{packet_name}",
          "#{item_name}__U",
          "#{item_name}__F",
          "#{item_name}__C",
          item_name)
        return JSON.parse(result[0].to_s) if result[0]
        return JSON.parse(result[1].to_s) if result[1]
        return JSON.parse(result[2].to_s) if result[2]
        return JSON.parse(result[3].to_s) if result[3]
        return nil
      end
    end

    # Request a telemetry item from a packet with the specified conversion
    # applied. This method is equivalent to calling the other tlm_xxx methods.
    #
    # Accepts two different calling styles:
    #   tlm_variable("TGT PKT ITEM", :RAW)
    #   tlm_variable('TGT','PKT','ITEM', :RAW)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args The args must either be a string followed by a symbol or
    #   three strings followed by a symbol (see the calling style in the
    #   description). The symbol must be one of {Packet::VALUE_TYPES}.
    # @return [Object] The converted telemetry value
    def tlm_variable(*args)
      target_name, packet_name, item_name, value_type = tlm_variable_process_args(args, 'tlm_variable')
      case value_type
      when :RAW
        return tlm_raw(target_name, packet_name, item_name)
      when :CONVERTED
        return tlm(target_name, packet_name, item_name)
      when :FORMATTED
        return tlm_formatted(target_name, packet_name, item_name)
      when :WITH_UNITS
        return tlm_with_units(target_name, packet_name, item_name)
      end
    end

    # Set a telemetry item in a packet to a particular value and then verifies
    # the value is within the acceptable limits. This method uses any
    # conversions that apply to the item when setting the value.
    #
    # Note: If this is done while COSMOS is currently receiving telemetry,
    # this value could get overwritten at any time. Thus this capability is
    # best used for testing or for telemetry items that are not received
    # regularly through the target interface.
    #
    # Accepts two different calling styles:
    #   set_tlm("TGT PKT ITEM = 1.0")
    #   set_tlm('TGT','PKT','ITEM', 10.0)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args The args must either be a string followed by a value or
    #   three strings followed by a value (see the calling style in the
    #   description).
    def set_tlm(*args)
      target_name, packet_name, item_name, value = set_tlm_process_args(args, 'set_tlm')
      if target_name == 'SYSTEM'.freeze and packet_name == 'META'.freeze
        raise "set_tlm not allowed on #{target_name} #{packet_name} #{item_name}" if ['PKTID', 'CONFIG'].include?(item_name)
      end

      REDIS.with do |conn|
        conn.hmset("tlm__#{target_name}__#{packet_name}", "#{item_name}__C", value)
      end

      # TODO: Need to decide how SYSTEM META will work going forward
      # if target_name == 'SYSTEM'.freeze and packet_name == 'META'.freeze
      #   tlm_packet = System.telemetry.packet('SYSTEM', 'META')
      #   cmd_packet = System.commands.packet('SYSTEM', 'META')
      #   cmd_packet.buffer = tlm_packet.buffer
      # end

      # TODO: May need to somehow force limits checking microservice to recheck
      # System.telemetry.packet(target_name, packet_name).check_limits(System.limits_set, true)
      nil
    end

    # Set a telemetry item in a packet to a particular value and then verifies
    # the value is within the acceptable limits. No conversions are applied.
    #
    # Note: If this is done while COSMOS is currently receiving telemetry,
    # this value could get overwritten at any time. Thus this capability is
    # best used for testing or for telemetry items that are not received
    # regularly through the target interface.
    #
    # Accepts two different calling styles:
    #   set_tlm_raw("TGT PKT ITEM = 1.0")
    #   set_tlm_raw('TGT','PKT','ITEM', 10.0)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args The args must either be a string followed by a value or
    #   three strings followed by a value (see the calling style in the
    #   description).
    def set_tlm_raw(*args)
      target_name, packet_name, item_name, value = set_tlm_process_args(args, 'set_tlm_raw')
      REDIS.with do |conn|
        conn.hmset("tlm__#{target_name}__#{packet_name}", item_name, value)
      end
      # TODO
      #System.telemetry.packet(target_name, packet_name).check_limits(System.limits_set, true)
      nil
    end

    # TODO: Need to add new set_tlm_formatted and set_tlm_with_units

    # Injects a packet into the system as if it was received from an interface
    #
    # @param target_name[String] Target name of the packet
    # @param packet_name[String] Packet name of the packet
    # @param item_hash[Hash] Hash of item_name and value for each item you want to change from the current value table
    # @param value_type[Symbol/String] Type of the values in the item_hash (RAW or CONVERTED)
    # @param send_routers[Boolean] Whether or not to send to routers for the target's interface
    # @param send_packet_log_writers[Boolean] Whether or not to send to the packet log writers for the target's interface
    # @param create_new_logs[Boolean] Whether or not to create new log files before writing this packet to logs
    def inject_tlm(target_name, packet_name, item_hash = nil, value_type = :CONVERTED, send_routers = true, send_packet_log_writers = true, create_new_logs = false)

      # TODO: This API will probably need to change
      # Requires having the packet definition if injecting into IDENTIFY stream, or could just
      # directly inject into decom stream (but not as fully featured)

      received_time = Time.now
      target = System.targets[target_name.upcase]
      raise "Unknown target: #{target_name}" unless target

      # Find and clone the telemetry packet
      cvt_packet = System.telemetry.packet(target_name, packet_name)
      packet = cvt_packet.clone
      packet.received_time = received_time

      if item_hash
        # Update the packet with item_hash
        value_type = value_type.to_s.intern
        item_hash.each do |item_name, item_value|
          packet.write(item_name.to_s, item_value, value_type)
        end
      end

      # Update current value table
      cvt_packet.buffer = packet.buffer(false)
      cvt_packet.received_time = received_time

      # The interface does the following line, but I don't think inject_tlm should because it could confuse the interface
      target.tlm_cnt += 1
      packet.received_count += 1
      cvt_packet.received_count += 1
      CmdTlmServer.instance.identified_packet_callback(packet)

      # Find the interface for this target
      interface = target.interface

      if interface
        # Write to routers
        if send_routers
          interface.routers.each do |router|
            begin
              router.write(packet) if router.write_allowed? and router.connected?
            rescue => err
              Logger.error "Problem writing to router #{router.name} - #{err.class}:#{err.message}"
            end
          end
        end

        # Write to packet log writers
        if create_new_logs or send_packet_log_writers
          interface.packet_log_writer_pairs.each do |packet_log_writer_pair|
            # Optionally create new log files
            packet_log_writer_pair.tlm_log_writer.start if create_new_logs

            # Optionally write to packet logs - Write errors are handled by the log writer
            packet_log_writer_pair.tlm_log_writer.write(packet) if send_packet_log_writers
          end
        end
      else
        # Some packets don't have an interface - Can still write to standard routers and packet logs

        # Write to routers
        if send_routers
          router = CmdTlmServer.instance.routers.all['PREIDENTIFIED_ROUTER']
          if router
            begin
              router.write(packet) if router.write_allowed? and router.connected?
            rescue => err
              Logger.error "Problem writing to router #{router.name} - #{err.class}:#{err.message}"
            end
          end
        end

        if create_new_logs or send_packet_log_writers
          # Handle packet logging
          packet_log_writer_pair = CmdTlmServer.instance.packet_logging.all['DEFAULT']

          if packet_log_writer_pair
            # Optionally create new logs
            packet_log_writer_pair.tlm_log_writer.start if create_new_logs

            # Optionally write to packet logs - Write errors are handled by the log writer
            packet_log_writer_pair.tlm_log_writer.write(packet) if send_packet_log_writers
          end
        end
      end

      nil
    end

    # Override a telemetry item in a packet to a particular value such that it
    # is always returned even when new telemetry packets are received from the
    # target.
    #
    # Accepts two different calling styles:
    #   override_tlm("TGT PKT ITEM = 1.0")
    #   override_tlm('TGT','PKT','ITEM', 10.0)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args The args must either be a string followed by a value or
    #   three strings followed by a value (see the calling style in the
    #   description).
    def override_tlm(*args)
      # TODO
      _override(__method__, set_tlm_process_args(args, __method__))
    end

    # Override a telemetry item in a packet to a particular value such that it
    # is always returned even when new telemetry packets are received from the
    # target. This only accepts RAW data items and any conversions are applied
    # to the raw data when the packet is read.
    #
    # Accepts two different calling styles:
    #   override_tlm_raw("TGT PKT ITEM = 1.0")
    #   override_tlm_raw('TGT','PKT','ITEM', 10.0)
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args The args must either be a string followed by a value or
    #   three strings followed by a value (see the calling style in the
    #   description).
    def override_tlm_raw(*args)
      # TODO
      _override(__method__, set_tlm_process_args(args, __method__))
    end

    # Normalize a telemetry item in a packet to its default behavior. Called
    # after override_tlm and override_tlm_raw to restore standard processing.
    #
    # Accepts two different calling styles:
    #   normalize_tlm("TGT PKT ITEM")
    #   normalize_tlm('TGT','PKT','ITEM')
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args The args must either be a string or three strings
    #   (see the calling style in the description).
    def normalize_tlm(*args)
      # TODO
      _override(__method__, tlm_process_args(args, __method__))
    end

    private

    # TODO
    def _override(method, tgt_pkt_item)
      target = System.targets[tgt_pkt_item[0]]
      raise "Target '#{tgt_pkt_item[0]}' does not exist" unless target
      interface = System.targets[tgt_pkt_item[0]].interface
      raise "Target '#{tgt_pkt_item[0]}' has no interface" unless interface
      found = false
      if interface.read_protocols
        interface.read_protocols.each do |protocol|
          found = true if protocol.kind_of? OverrideProtocol
        end
      end
      if found
        # Test to see if this telemetry item exists
        System.telemetry.value(tgt_pkt_item[0], tgt_pkt_item[1], tgt_pkt_item[2], :RAW)
        interface.public_send("_#{method}", *tgt_pkt_item)
      else
        raise "Interface #{interface.name} does not have override ability. Is 'PROTOCOL READ_WRITE OverrideProtocol' under the interface definition?"
      end
      nil
    end

    public

    # Returns the raw buffer for a telemetry packet.
    #
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @return [String] last telemetry packet buffer
    def get_tlm_buffer(target_name, packet_name)
      topic = "PACKET__#{target_name}__#{packet_name}"
      msg_id, msg_hash = Store.instance.read_topic_last(topic)
      if msg_id
        return msg_hash['buffer']
      else
        return nil
      end
    end

    # Returns all the values (along with their limits state) for a packet.
    #
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @param value_type [Symbol] How the values should be converted. Must be
    #   one of {Packet::VALUE_TYPES}
    # @return (see Cosmos::Packet#read_all_with_limits_states)
    def get_tlm_packet(target_name, packet_name, value_type = :CONVERTED)
      begin
        case value_type
        when :RAW
          desired_item_type = ''
        when :CONVERTED
          desired_item_type = 'C'
        when :FORMATTED
          desired_item_type = 'F'
        else
          desired_item_type = 'U'
        end
        result_hash = {}
        topic = "DECOM__#{target_name}__#{packet_name}"
        msg_id, msg_hash = Store.instance.read_topic_last(topic)
        if msg_id
          json = msg_hash['json_data']
          hash = JSON.parse(json)
          # This should be ordered as desired... need to verify
          hash.each do |key, value|
            split_key = key.split("__")
            item_name = split_key[0].to_s
            item_type = split_key[1]
            result_hash[item_name] ||= [item_name]
            if item_type == 'L'
              result_hash[item_name][2] = value
            else
              if item_type.to_s <= desired_item_type.to_s
                if desired_item_type == 'F' or desired_item_type == 'U'
                  result_hash[item_name][1] = value.to_s
                else
                  result_hash[item_name][1] = value
                end
              end
            end
          end
          return result_hash.values
        else
          return nil
        end
      rescue Exception => err
        STDOUT.puts err.formatted
      end
    end

    # Returns all the item values (along with their limits state). The items
    # can be from any target and packet and thus must be fully qualified with
    # their target and packet names.
    #
    # @param (see Cosmos::Telemetry#values_and_limits_states)
    # @return [Array< Array<Object>, Array<Symbol>, Array<Array<Numeric>>, String>]
    #   Array consisting of an Array of item values, an Array of item limits state
    #   given as symbols such as :RED, :YELLOW, :STALE, an Array of Arrays including
    #   the limits setting such as red low, yellow low, yellow high, red high and
    #   optionally green low and high, and the overall limits state which is
    #   one of {Cosmos::Limits::LIMITS_STATES}.
    def get_tlm_values(item_array, value_types = :CONVERTED)
      items, states, settings = Store.instance.get_tlm_values(item_array, value_types)
      limits_set = get_limits_set()
      return [items, states, settings, limits_set]
    end

    # Returns the sorted packet names and their descriptions for a particular
    # target.
    #
    # @param target_name (see #get_tlm_packet)
    # @return [Array<String, String>] Array of \[packet name, packet
    #   description] sorted by packet name
    def get_tlm_list(target_name)
      list = []
      packets = {}
      REDIS.with do |redis|
        packets = redis.hgetall("cosmostlm__#{target_name}")
      end
      packets.each do |packet_name, packet_json|
        packet = JSON.parse(packet_json)
        list << [packet_name, packet['description']]
      end
      list.sort
    end

    # Returns the item names and their states and descriptions for a particular
    # packet.
    #
    # @param target_name (see #get_tlm_packet)
    # @param packet_name (see #get_tlm_packet)
    # @return [Array<String, Hash, String>] Array of \[item name, item states,
    #   item description]
    def get_tlm_item_list(target_name, packet_name)
      packet = Store.instance.get_packet(target_name, packet_name)
      return packet['items'].map {|item| [item['name'], item['states'], item['description']] }
    end

    # Returns an array of Hashes with all the attributes of the item.
    #
    # @param (see Cosmos::Telemetry#values_and_limits_states)
    # @return [Array<Hash>] Array of hashes describing the items. All the
    #   attributes in {Cosmos::PacketItem} and {Cosmos::StructItem} are
    #   present in the Hash.
    def get_tlm_details(item_array)
      if !item_array.is_a?(Array) || !item_array[0].is_a?(Array)
        raise ArgumentError, "item_array must be nested array: [['TGT','PKT','ITEM'],...]"
      end
      details = []
      item_array.each do |target_name, packet_name, item_name|
        _, item = System.telemetry.packet_and_item(target_name, packet_name, item_name)
        details << item.to_hash
      end
      details
    end

    # (see Cosmos::Limits#out_of_limits)
    def get_out_of_limits
      return System.limits.out_of_limits
    end

    # (see Cosmos::Limits#overall_limits_state)
    def get_overall_limits_state(ignored_items = nil)
      return System.limits.overall_limits_state(ignored_items)
    end

    # Whether the limits are enabled for the given item
    #
    # Accepts two different calling styles:
    #   limits_enabled?("TGT PKT ITEM")
    #   limits_enabled?('TGT','PKT','ITEM')
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args [String|Array<String>] See the description for calling style
    # @return [Boolean] Whether limits are enable for the itme
    def limits_enabled?(*args)
      target_name, packet_name, item_name = tlm_process_args(args, 'limits_enabled?')
      return System.limits.enabled?(target_name, packet_name, item_name)
    end

    # Enable limits checking for a telemetry item
    #
    # Accepts two different calling styles:
    #   enable_limits("TGT PKT ITEM")
    #   enable_limits('TGT','PKT','ITEM')
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args [String|Array<String>] See the description for calling style
    def enable_limits(*args)
      target_name, packet_name, item_name = tlm_process_args(args, 'enable_limits')
      System.limits.enable(target_name, packet_name, item_name)
      nil
    end

    # Disable limit checking for a telemetry item
    #
    # Accepts two different calling styles:
    #   disable_limits("TGT PKT ITEM")
    #   disable_limits('TGT','PKT','ITEM')
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args [String|Array<String>] See the description for calling style
    def disable_limits(*args)
      target_name, packet_name, item_name = tlm_process_args(args, 'disable_limits')
      System.limits.disable(target_name, packet_name, item_name)
      nil
    end

    # Get the list of stale packets for a specific target or pass nil to list
    # all stale packets
    #
    # @param with_limits_only [Boolean] Return only the stale packets
    #   that have limits items and thus affect the overall limits
    #   state of the system
    # @param target [String] The target to find stale packets for or nil to list
    #   all stale packets in the system
    # @return [Array<Array<String, String>>] Array of arrays listing the target
    #   name and packet name
    def get_stale(with_limits_only = false, target = nil)
      stale = []
      System.telemetry.stale(with_limits_only, target).each do |packet|
        stale << [packet.target_name, packet.packet_name]
      end
      stale
    end

    # Get a Hash of all the limits sets defined for an item. Hash keys are the limit
    # set name in uppercase (note there is always a DEFAULT) and the value is an array
    # of limit values: red low, yellow low, yellow high, red high, <green low, green high>.
    # Green low and green high are optional.
    #
    # For example: {'DEFAULT' => [-80, -70, 60, 80, -20, 20],
    #               'TVAC' => [-25, -10, 50, 55] }
    #
    # @return [Hash{String => Array<Number, Number, Number, Number, Number, Number>}]
    def get_limits(target_name, packet_name, item_name)
      limits = {}
      packet = Store.instance.get_packet(target_name, packet_name)
      item = packet['items'].find {|item| item['name'] == item_name }
      item['limits'].each do |key, vals|
        limits[key] = [vals['red_low'], vals['yellow_low'], vals['yellow_high'], vals['red_high']]
        limits[key].concat([vals['green_low'], vals['green_high']]) if vals['green_low']
      end
      return limits
    end

    def set_limits(target_name, packet_name, item_name, red_low, yellow_low, yellow_high, red_high, green_low = nil, green_high = nil, limits_set = :CUSTOM, persistence = nil, enabled = true)
      result = System.limits.set(target_name, packet_name, item_name, red_low, yellow_low, yellow_high, red_high, green_low, green_high, limits_set, persistence, enabled)
      if result[0] != nil
        limits_settings = [target_name, packet_name, item_name].concat(result)
        CmdTlmServer.instance.post_limits_event(:LIMITS_SETTINGS, limits_settings)
        Logger.info("Limits Settings Changed: #{limits_settings}")
      end
      result
    end

    # (see Cosmos::Limits#groups)
    def get_limits_groups
      return System.limits.groups.keys
    end

    # (see Cosmos::Limits#enable_group)
    def enable_limits_group(group_name)
      Logger.info("Enabling Limits Group: #{group_name.upcase}")
      System.limits.enable_group(group_name)
      nil
    end

    # (see Cosmos::Limits#disable_group)
    def disable_limits_group(group_name)
      Logger.info("Disabling Limits Group: #{group_name.upcase}")
      System.limits.disable_group(group_name)
      nil
    end

    # Returns all defined limits sets
    #
    # @return [Array<Symbol>] All defined limits sets
    def get_limits_sets
      REDIS.with do |redis|
        return JSON.parse(redis.hget('cosmos_system', 'limits_sets'))
      end
    end

    # Changes the active limits set that applies to all telemetry
    #
    # @param limits_set [String] The name of the limits set
    def set_limits_set(limits_set)
      REDIS.with do |redis|
        redis.hset('cosmos_system', 'limits_set', limits_set)
      end
    end

    # Returns the active limits set that applies to all telemetry
    #
    # @return [String] The current limits set
    def get_limits_set
      REDIS.with do |redis|
        return redis.hget('cosmos_system', 'limits_set')
      end
    end

    #
    # General Purpose Methods
    #

    # Returns the list of all target names
    #
    # @return [Array<String>] All target names
    def get_target_list
      REDIS.with do |redis|
        return JSON.parse(redis.hget('cosmos_system', 'target_names'))
      end
    end

    # @see CmdTlmServer.subscribe_limits_events
    def subscribe_limits_events(queue_size = CmdTlmServer::DEFAULT_LIMITS_EVENT_QUEUE_SIZE)
      CmdTlmServer.subscribe_limits_events(queue_size)
    end

    # @see CmdTlmServer.unsubscribe_limits_events
    def unsubscribe_limits_events(id)
      CmdTlmServer.unsubscribe_limits_events(id)
    end

    # @see CmdTlmServer.get_limits_event
    def get_limits_event(id, non_block = false)
      CmdTlmServer.get_limits_event(id, non_block)
    end

    # @see CmdTlmServer.subscribe_packet_data
    def subscribe_packet_data(packets,
                              queue_size = CmdTlmServer::DEFAULT_PACKET_DATA_QUEUE_SIZE)
      CmdTlmServer.subscribe_packet_data(packets, queue_size)
    end

    # @see CmdTlmServer.unsubscribe_packet_data
    def unsubscribe_packet_data(id)
      CmdTlmServer.unsubscribe_packet_data(id)
    end

    # @see CmdTlmServer.get_packet_data
    def get_packet_data(id, non_block = false)
      CmdTlmServer.get_packet_data(id, non_block)
    end

    # @see CmdTlmServer.subscribe_server_messages
    def subscribe_server_messages(queue_size = CmdTlmServer::DEFAULT_SERVER_MESSAGES_QUEUE_SIZE)
      CmdTlmServer.subscribe_server_messages(queue_size)
    end

    # @see CmdTlmServer.unsubscribe_server_messages
    def unsubscribe_server_messages(id)
      CmdTlmServer.unsubscribe_server_messages(id)
    end

    # @see CmdTlmServer.get_server_message
    def get_server_message(id, non_block = false)
      CmdTlmServer.get_server_message(id, non_block)
    end

    # Get a packet which was previously subscribed to by
    # subscribe_packet_data. This method can block waiting for new packets or
    # not based on the second parameter. It returns a single Cosmos::Packet instance
    # and will return nil when no more packets are buffered (assuming non_block
    # is false).
    # Usage:
    #   get_packet(id, <true or false to block>)
    def get_packet(id, non_block = false)
      packet = nil
      # The get_packet_data in the CmdTlmServer returns the number of seconds
      # followed by microseconds after the packet_name. This is different that the Script API.
      buffer, target_name, packet_name, rx_sec, rx_usec, rx_count = get_packet_data(id, non_block)
      if buffer
        packet = System.telemetry.packet(target_name, packet_name).clone
        packet.buffer = buffer
        packet.received_time = Time.at(rx_sec, rx_usec).sys
        packet.received_count = rx_count
      end
      packet
    end

    #
    # Methods for scripting
    #

    # @return [Array<String>] All the targets mapped to the given interface
    def get_interface_targets(interface_name)
      CmdTlmServer.interfaces.targets(interface_name)
    end

    # @return [Array<String>] All the interface names
    def get_interface_names
      CmdTlmServer.interfaces.names
    end

    # Connects to an interface and starts its telemetry gathering thread. If
    # optional parameters are given, the interface is recreated with new
    # parameters.
    #
    # @param interface_name [String] The name of the interface
    # @param params [Array] Parameters to pass to the interface.
    def connect_interface(interface_name, *params)
      CmdTlmServer.interfaces.connect(interface_name, *params)
      nil
    end

    # Disconnects from an interface and kills its telemetry gathering thread
    #
    # @param interface_name (see #connect_interface)
    def disconnect_interface(interface_name)
      CmdTlmServer.interfaces.disconnect(interface_name)
      nil
    end

    # @param interface_name (see #connect_interface)
    # @return [String] The state of the interface which is one of 'CONNECTED',
    #   'ATTEMPTING' or 'DISCONNECTED'.
    def interface_state(interface_name)
      CmdTlmServer.interfaces.state(interface_name)
    end

    # Associates a target and all its commands and telemetry with a particular
    # interface. All the commands will go out over and telemetry be received
    # from that interface.
    #
    # @param target_name [String] The name of the target
    # @param interface_name (see #connect_interface)
    def map_target_to_interface(target_name, interface_name)
      CmdTlmServer.interfaces.map_target(target_name, interface_name)
      nil
    end

    # @return [Array<String>] All the router names
    def get_router_names
      CmdTlmServer.routers.names
    end

    # Connects a router and starts its command gathering thread. If
    # optional parameters are given, the router is recreated with new
    # parameters.
    #
    # @param router_name [String] The name of the router
    # @param params [Array] Parameters to pass to the router.
    def connect_router(router_name, *params)
      CmdTlmServer.routers.connect(router_name, *params)
      nil
    end

    # Disconnects a router and kills its command gathering thread
    #
    # @param router_name (see #connect_router)
    def disconnect_router(router_name)
      CmdTlmServer.routers.disconnect(router_name)
      nil
    end

    # @param router_name (see #connect_router)
    # @return [String] The state of the router which is one of 'CONNECTED',
    #   'ATTEMPTING' or 'DISCONNECTED'.
    def router_state(router_name)
      CmdTlmServer.routers.state(router_name)
    end

    # Get information about a target
    #
    # @param target_name [String] Target name
    # @return [Array<Numeric, Numeric>] Array of \[cmd_cnt, tlm_cnt]
    def get_target_info(target_name)
      REDIS.with do |redis|
        int_info = JSON.parse(redis.hget('cosmos_interfaces', name))
      end
      raise "Unknown target: #{target_name}" unless int_info
      return [int_info['cmd_cnt'], target['tlm_cnt']]
    end

    # Get information about all targets
    #
    # @return [Array<Array<String, Numeric, Numeric>] Array of Arrays \[name, cmd_cnt, tlm_cnt]
    def get_all_target_info
      info = []
      REDIS.with do |redis|
        config = redis.hgetall('cosmos_microservices')
        config.each do |key, json|
          next unless key.include?('INTERFACE__')
          config = JSON.parse(json)
          name = key.split('__')[1]
          int_info = JSON.parse(redis.hget('cosmos_interfaces', name))
          config['target_list'].each do |target|
            info << [target['target_name'], name, int_info['cmdcnt'], int_info['tlmcnt'] ]
          end
        end
      end
      info
    end

    # Get the list of ignored command parameters for a target
    #
    # @param target_name [String] Target name
    # @return [Array<String>] All of the ignored command parameters for a target.
    def get_target_ignored_parameters(target_name)
      target = Store.instance.get_target(target_name)
      raise "Unknown target: #{target_name}" unless target
      return target['ignored_parameters']
    end

    # Get the list of ignored telemetry items for a target
    #
    # @param target_name [String] Target name
    # @return [Array<String>] All of the ignored telemetry items for a target.
    def get_target_ignored_items(target_name)
      target = Store.instance.get_target(target_name)
      raise "Unknown target: #{target_name}" unless target
      return target['ignored_items']
    end

    # Get the list of derived telemetry items for a packet
    #
    # @param target_name [String] Target name
    # @param packet_name [String] Packet name
    # @return [Array<String>] All of the ignored telemetry items for a packet.
    def get_packet_derived_items(target_name, packet_name)
      packet = Store.instance.get_packet(target_name, packet_name)
      raise "Unknown target or packet: #{target_name} #{packet_name}" unless packet
      return packet['items'].select {|item| item['data_type'] == 'DERIVED' }.map {|item| item['name']}
    end

    # Get information about an interface
    #
    # @param interface_name [String] Interface name
    # @return [Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>] Array containing \[state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Command count,
    #   Telemetry count] for the interface
    def get_interface_info(interface_name)
      info = []
      REDIS.with do |redis|
        json = redis.hget('cosmos_interfaces', interface_name)
        int = JSON.parse(json)
        info = [int['state'], int['clients'], int['txsize'], int['rxsize'],\
                int['txbytes'], int['rxbytes'], int['cmdcnt'], int['tlmcnt']]
      end
      info
    end

    # Get information about all interfaces
    #
    # @return [Array<Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>>] Array of Arrays containing \[name, state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Command count,
    #   Telemetry count] for all interfaces
    def get_all_interface_info
      info = []
      REDIS.with do |redis|
        interfaces = redis.hgetall('cosmos_interfaces')
        interfaces.each do |name, json|
          int = JSON.parse(json)
          info << [name, int['state'], int['clients'], int['txsize'], int['rxsize'],\
                   int['txbytes'], int['rxbytes'], int['cmdcnt'], int['tlmcnt']]
        end
      end
      info
    end

    # Get information about a router
    #
    # @param router_name [String] Router name
    # @return [Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>] Array containing \[state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Pkts received,
    #   Pkts sent] for the router
    def get_router_info(router_name)
      CmdTlmServer.routers.get_info(router_name)
    end

    # Get information about all routers
    #
    # @return [Array<Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>>] Array of Arrays containing \[name, state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Command count,
    #   Telemetry count] for all routers
    def get_all_router_info
      info = []
      CmdTlmServer.routers.names.sort.each do |router_name|
        info << [router_name].concat(CmdTlmServer.routers.get_info(router_name))
      end
      info
    end

    # Get the transmit count for a command packet
    #
    # @param target_name [String] Target name of the command
    # @param command_name [String] Packet name of the command
    # @return [Numeric] Transmit count for the command
    def get_cmd_cnt(target_name, command_name)
      packet = System.commands.packet(target_name, command_name)
      packet.received_count
    end

    # Get the receive count for a telemetry packet
    #
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @return [Numeric] Receive count for the telemetry packet
    def get_tlm_cnt(target_name, packet_name)
      packet = System.telemetry.packet(target_name, packet_name)
      packet.received_count
    end

    # Get information on all command packets
    #
    # @return [Numeric] Transmit count for the command
    def get_all_cmd_info
      info = []
      REDIS.with do |redis|
        targets = JSON.parse(redis.hget('cosmos_system', 'target_names'))
        targets.each do |target|
          redis.hgetall("cosmoscmd__#{target}").each do |packet, json|
            info << [target, packet, 0] # TODO how to get cmd count
          end
        end
      end
      info
    end

    # Get information on all telemetry packets
    #
    # @return [Numeric] Receive count for the telemetry packet
    def get_all_tlm_info
      info = []
      REDIS.with do |redis|
        targets = JSON.parse(redis.hget('cosmos_system', 'target_names'))
        targets.each do |target|
          redis.hgetall("cosmostlm__#{target}").each do |packet, json|
            info << [target, packet, 0] # TODO how to get tlm count
          end
        end
      end
      info
    end

    # Get the list of packet loggers.
    #
    # @return [Array<String>] Array containing the names of all packet loggers
    def get_packet_loggers
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
    def get_packet_logger_info(packet_logger_name = 'DEFAULT')
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

    def get_all_packet_logger_info
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

    # Get background task information
    #
    # @return [Array<Array<String, String, String>>] Array of Arrays containing
    #   the background task name, thread status, and task status
    def get_background_tasks
      result = []
      # CmdTlmServer.background_tasks.all.each do |task|
      #   if task.thread
      #     thread_status = task.thread.status
      #     thread_status = 'complete' if thread_status == false
      #   else
      #     thread_status = 'no thread'
      #   end
      #   result << [task.name, thread_status, task.status]
      # end
      result
    end

    # Start a background task
    def start_background_task(task_name)
      CmdTlmServer.background_tasks.all.each_with_index do |task, index|
        if task.name == task_name
          CmdTlmServer.background_tasks.start(index)
          break
        end
      end
    end

    # Stop a background task
    def stop_background_task(task_name)
      CmdTlmServer.background_tasks.all.each_with_index do |task, index|
        if task.name == task_name
          CmdTlmServer.background_tasks.stop(index)
          break
        end
      end
    end

    # Get JSON DRB information
    #
    # @return [String, Integer, Integer, Integer, Float, Integer] Server
    #   status including Limits Set, API Port, JSON DRB num clients,
    #   JSON DRB request count, JSON DRB average request time, and the total
    #   number of Ruby threads in the server/
    def get_server_status
      set = ''
      REDIS.with do |redis|
        set = redis.hget('cosmos_system', 'limits_set')
        STDOUT.puts "set:#{set}"
      end
      [ set, 0, 0, 0, 0,
        # TODO: What do we want to expose here?
        # CmdTlmServer.mode == :CMD_TLM_SERVER ? System.ports['CTS_API'] : System.ports['REPLAY_API'],
        # CmdTlmServer.json_drb.num_clients,
        # CmdTlmServer.json_drb.request_count,
        # CmdTlmServer.json_drb.average_request_time,
        Thread.list.length
      ]
    end

    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing the command packet log
    # @return [String] The command packet log filename
    def get_cmd_log_filename(packet_log_writer_name = 'DEFAULT')
      CmdTlmServer.packet_logging.cmd_filename(packet_log_writer_name)
    end

    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing the telemetry packet log
    # @return [String] The telemetry packet log filename
    def get_tlm_log_filename(packet_log_writer_name = 'DEFAULT')
      CmdTlmServer.packet_logging.tlm_filename(packet_log_writer_name)
    end

    # Start both command and telemetry packet logging.
    #
    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing both the command and telemetry logs
    # @param label [String] Optional label to apply to both the command and
    #   telemetry packet log filename
    def start_logging(packet_log_writer_name = 'ALL', label = nil)
      CmdTlmServer.packet_logging.start(packet_log_writer_name, label)
      nil
    end

    # Stop both command and telemetry packet logging.
    #
    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing both the command and telemetry logs
    def stop_logging(packet_log_writer_name = 'ALL')
      CmdTlmServer.packet_logging.stop(packet_log_writer_name)
      nil
    end

    # Start command packet logging.
    #
    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing the command logs
    # @param label [String] Optional label to apply to the command packet log
    #   filename
    def start_cmd_log(packet_log_writer_name = 'ALL', label = nil)
      CmdTlmServer.packet_logging.start_cmd(packet_log_writer_name, label)
      nil
    end

    # Start telemetry packet logging.
    #
    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing the telemetry logs
    # @param label [String] Optional label to apply to the telemetry packet log
    #   filename
    def start_tlm_log(packet_log_writer_name = 'ALL', label = nil)
      CmdTlmServer.packet_logging.start_tlm(packet_log_writer_name, label)
      nil
    end

    # Stop command packet logging.
    #
    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing the command log
    def stop_cmd_log(packet_log_writer_name = 'ALL')
      CmdTlmServer.packet_logging.stop_cmd(packet_log_writer_name)
      nil
    end

    # Stop telemetry packet logging.
    #
    # @param packet_log_writer_name [String] The name of the packet log writer which
    #   is writing the telemetry log
    def stop_tlm_log(packet_log_writer_name = 'ALL')
      CmdTlmServer.packet_logging.stop_tlm(packet_log_writer_name)
      nil
    end

    # Starts raw logging for an interface
    #
    # @param interface_name [String] The name of the interface
    def start_raw_logging_interface(interface_name = 'ALL')
      CmdTlmServer.interfaces.start_raw_logging(interface_name)
      nil
    end

    # Stop raw logging for an interface
    #
    # @param interface_name [String] The name of the interface
    def stop_raw_logging_interface(interface_name = 'ALL')
      CmdTlmServer.interfaces.stop_raw_logging(interface_name)
      nil
    end

    # Starts raw logging for a router
    #
    # @param router_name [String] The name of the router
    def start_raw_logging_router(router_name = 'ALL')
      CmdTlmServer.routers.start_raw_logging(router_name)
      nil
    end

    # Stops raw logging for a router
    #
    # @param router_name [String] The name of the router
    def stop_raw_logging_router(router_name = 'ALL')
      CmdTlmServer.routers.stop_raw_logging(router_name)
      nil
    end

    # @return [String] The server message log filename
    def get_server_message_log_filename
      if CmdTlmServer.message_log
        CmdTlmServer.message_log.filename
      else
        nil
      end
    end

    # Starts a new server message log
    def start_new_server_message_log
      CmdTlmServer.message_log.start if CmdTlmServer.message_log
      nil
    end

    # Reload the default configuration
    def cmd_tlm_reload
      Thread.new do
        CmdTlmServer.instance.reload
      end
      nil
    end

    # Clear server counters
    def cmd_tlm_clear_counters
      CmdTlmServer.clear_counters
    end

    # Get the list of filenames in the outputs logs folder
    def get_output_logs_filenames(filter = '*tlm.bin')
      raise "Filter must not contain slashes" if filter.index('/') or filter.index('\\')
      Dir.glob(File.join(System.paths['LOGS'], '**', filter))
    end

    # Select and start analyzing a file for replay
    #
    # filename [String] filename relative to output logs folder or absolute filename
    def replay_select_file(filename, packet_log_reader = "DEFAULT")
      CmdTlmServer.replay_backend.select_file(filename, packet_log_reader)
    end

    # Get current replay status
    #
    # status, delay, filename, file_start, file_current, file_end, file_index, file_max_index
    def replay_status
      CmdTlmServer.replay_backend.status
    end

    # Set the replay delay
    #
    # @param delay [Float] delay between packets in seconds 0.0 to 1.0, nil = REALTIME
    def replay_set_playback_delay(delay)
      CmdTlmServer.replay_backend.set_playback_delay(delay)
    end

    # Replay start playing forward
    def replay_play
      CmdTlmServer.replay_backend.play
    end

    # Replay start playing backward
    def replay_reverse_play
      CmdTlmServer.replay_backend.reverse_play
    end

    # Replay stop
    def replay_stop
      CmdTlmServer.replay_backend.stop
    end

    # Replay step forward one packet
    def replay_step_forward
      CmdTlmServer.replay_backend.step_forward
    end

    # Replay step backward one packet
    def replay_step_back
      CmdTlmServer.replay_backend.step_back
    end

    # Replay move to start of file
    def replay_move_start
      CmdTlmServer.replay_backend.move_start
    end

    # Replay move to end of file
    def replay_move_end
      CmdTlmServer.replay_backend.move_end
    end

    # Replay move to index
    #
    # @param index [Integer] packet index into file
    def replay_move_index(index)
      CmdTlmServer.replay_backend.move_index(index)
    end

    # Get the organized list of available telemetry screens
    def get_screen_list(config_filename = nil, force_refresh = false)
      if force_refresh or !@tlm_viewer_config or @tlm_viewer_config_filename != config_filename
        @tlm_viewer_config = TlmViewerConfig.new(config_filename, true)
        @tlm_viewer_config_filename = config_filename
      end
      return @tlm_viewer_config.columns
    end

    # Get a specific screen definition
    def get_screen_definition(screen_full_name, config_filename = nil, force_refresh = false)
      get_screen_list(config_filename, force_refresh) if force_refresh or !@tlm_viewer_config
      screen_info = @tlm_viewer_config.screen_infos[screen_full_name.upcase]
      raise "Unknown screen: #{screen_full_name.upcase}" unless screen_info
      screen_definition = File.read(screen_info.filename)
      return screen_definition
    end

    # Get a saved configuration zip file
    def get_saved_config(configuration_name = nil)
      configuration_name ||= System.initial_config.name if System.initial_config
      if configuration_name
        configuration = System.instance.find_configuration(configuration_name)
        if configuration and File.exist?(configuration) and configuration[-4..-1] == ".zip"
          filename = File.basename(configuration)
          data = ''
          File.open(configuration, 'rb') {|file| data = file.read}
          return [filename, data]
        end
      end
      return nil
    end

    private

    def cmd_implementation(range_check, hazardous_check, raw, method_name, *args)
      case args.length
      when 1
        target_name, cmd_name, cmd_params = extract_fields_from_cmd_text(args[0])
      when 2, 3
        target_name = args[0]
        cmd_name    = args[1]
        if args.length == 2
          cmd_params = {}
        else
          cmd_params = args[2]
        end
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{method_name}()"
      end

      # Send the command
      @disconnect = false unless defined? @disconnect
      unless @disconnect
        store.instance.cmd_target(target_name, cmd_name, cmd_params, range_check, hazardous_check, raw)
      end

      [target_name, cmd_name, cmd_params]
    end

    def tlm_process_args(args, function_name)
      case args.length
      when 1
        target_name, packet_name, item_name = extract_fields_from_tlm_text(args[0])
      when 3
        target_name = args[0]
        packet_name = args[1]
        item_name = args[2]
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
      end
      return [target_name, packet_name, item_name]
    end

    def tlm_variable_process_args(args, function_name)
      case args.length
      when 2
        target_name, packet_name, item_name = extract_fields_from_tlm_text(args[0])
        value_type = args[1].to_s.intern
      when 4
        target_name = args[0]
        packet_name = args[1]
        item_name = args[2]
        value_type = args[3].to_s.intern
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
      end
      return [target_name, packet_name, item_name, value_type]
    end

    def set_tlm_process_args(args, function_name)
      case args.length
      when 1
        target_name, packet_name, item_name, value = extract_fields_from_set_tlm_text(args[0])
      when 4
        target_name = args[0]
        packet_name = args[1]
        item_name = args[2]
        value = args[3]
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to #{function_name}()"
      end
      return [target_name, packet_name, item_name, value]
    end

  end # module Api
end # module Cosmos
