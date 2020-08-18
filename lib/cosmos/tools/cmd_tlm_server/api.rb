# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/script/extract'
require 'cosmos/script/api_shared'
require 'cosmos/utilities/store'
require 'cosmos/utilities/authorization'

module Cosmos
  module Api
    include Extract
    include ApiShared
    include Authorization

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
        'get_all_commands',
        'get_command',
        'get_parameter',
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
        'set_tlm_formatted',
        'set_tlm_with_units',
        'inject_tlm',
        'override_tlm',
        'override_tlm_raw',
        'override_tlm_formatted',
        'override_tlm_with_units',
        'normalize_tlm',
        'get_tlm_buffer',
        'get_tlm_packet',
        'get_tlm_values',
        'get_tlm_list',
        'get_all_telemetry',
        'get_telemetry',
        'get_item',
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
        'get_target',
        'get_all_target_info',
        'get_target_info',
        'get_target_ignored_parameters',
        'get_target_ignored_items',
        'get_packet_derived_items',
        'get_interface_info',
        'get_interface',
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
    def cmd(*args, scope: $cosmos_scope, token: $cosmos_token)
      cmd_implementation(true, true, false, 'cmd', *args, scope: scope, token: token)
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
    def cmd_no_range_check(*args, scope: $cosmos_scope, token: $cosmos_token)
      cmd_implementation(false, true, false, 'cmd_no_range_check', *args, scope: scope, token: token)
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
    def cmd_no_hazardous_check(*args, scope: $cosmos_scope, token: $cosmos_token)
      cmd_implementation(true, false, false, 'cmd_no_hazardous_check', *args, scope: scope, token: token)
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
    def cmd_no_checks(*args, scope: $cosmos_scope, token: $cosmos_token)
      cmd_implementation(false, false, false, 'cmd_no_checks', *args, scope: scope, token: token)
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
    def cmd_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      cmd_implementation(true, true, true, 'cmd_raw', *args, scope: scope, token: token)
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
    def cmd_raw_no_range_check(*args, scope: $cosmos_scope, token: $cosmos_token)
      cmd_implementation(false, true, true, 'cmd_raw_no_range_check', *args, scope: scope, token: token)
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
    def cmd_raw_no_hazardous_check(*args, scope: $cosmos_scope, token: $cosmos_token)
      cmd_implementation(true, false, true, 'cmd_raw_no_hazardous_check', *args, scope: scope, token: token)
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
    def cmd_raw_no_checks(*args, scope: $cosmos_scope, token: $cosmos_token)
      cmd_implementation(false, false, true, 'cmd_raw_no_checks', *args, scope: scope, token: token)
    end

    # Send a raw binary string to the specified interface.
    #
    # @param interface_name [String] The interface to send the raw binary
    # @param data [String] The raw binary data
    def send_raw(interface_name, data, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'cmd_raw', interface_name: interface_name, scope: scope, token: token)
      Store.instance.write_interface(interface_name, { 'raw' => data }, scope: scope)
      nil
    end

    # Returns the raw buffer from the most recent specified command packet.
    #
    # @param target_name [String] Target name of the command
    # @param command_name [String] Packet name of the command
    # @return [String] last command buffer packet
    def get_cmd_buffer(target_name, command_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'cmd_info', target_name: target_name, packet_name: command_name, scope: scope, token: token)
      Store.instance.cmd_packet_exist?(target_name, command_name, scope: scope)
      topic = "#{scope}__COMMAND__#{target_name}__#{command_name}"
      msg_id, msg_hash = Store.instance.read_topic_last(topic)
      return msg_hash['buffer'] if msg_id
      nil
    end

    # Returns the list of all the command names and their descriptions from the
    # given target.
    #
    # @deprecated Use #get_all_commands
    # @param target_name [String] Name of the target
    # @return [Array<Array<String, String>>] Array containing \[command name,
    #   command description] for all commands in the target
    def get_cmd_list(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'cmd_info', target_name: target_name, scope: scope, token: token)
      list = []
      commands = Store.instance.get_commands(target_name, scope: scope)
      commands.each do |command|
        list << [command['packet_name'], command['description']]
      end
      list.sort
    end

    # Returns an array of all the commands as a hash
    #
    # @since 5.0.0
    # @param target_name [String] Name of the target
    # @return [Array<Hash>] Array of all commands as a hash
    def get_all_commands(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'cmd_info', target_name: target_name, scope: scope, token: token)
      Store.instance.get_commands(target_name, scope: scope)
    end

    # Returns a hash of the given command
    #
    # @since 5.0.0
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @return [Hash] Command as a hash
    def get_command(target_name, packet_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'cmd_info', target_name: target_name, scope: scope, token: token)
      Store.instance.get_packet(target_name, packet_name, type: 'cmd', scope: scope)
    end

    # Returns a hash of the given command parameter
    #
    # @since 5.0.0
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @param param_name [String] Name of the parameter
    # @return [Hash] Command parameter as a hash
    def get_parameter(target_name, packet_name, param_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'cmd_info', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.get_item(target_name, packet_name, param_name, type: 'cmd', scope: scope)
    end

    # Returns the list of all the parameters for the given command.
    #
    # @deprecated Use #get_command
    # @param target_name [String] Name of the target
    # @param command_name [String] Name of the command
    # @return [Array<Array<String, Object, nil|Array, nil|String, nil|String,
    #   nil|String, Boolean>] Array containing \[name, default, states,
    #   description, units_full, units, required] for all parameters in the
    #   command
    def get_cmd_param_list(target_name, command_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'cmd_info', target_name: target_name, packet_name: command_name, scope: scope, token: token)
      list = []
      packet_json = nil
      packet = Store.instance.get_packet(target_name, command_name, type: 'cmd', scope: scope)
      packet['items'].each do |item|
        states = nil
        if item['states']
          states = {}
          item['states'].each do |key, values|
            states[key] = values['value']
          end
        end
        required = item['required'] ? true : false
        if item['format_string']
          unless item['default'].kind_of?(Array)
            list << [item['name'], sprintf(item['format_string'], item['default']), states, item['description'], item['units_full'], item['units'], required, item['data_type']]
          else
            list << [item['name'], "[]", states, item['description'], item['units_full'], item['units'], required, item['data_type']]
          end
        else
          list << [item['name'], item['default'], states, item['description'], item['units_full'], item['units'], required, item['data_type']]
        end
      end
      return list
    end

    # Returns whether the specified command is hazardous
    #
    # Accepts two different calling styles:
    #   get_cmd_hazardous("TGT CMD with PARAM1 val, PARAM2 val")
    #   get_cmd_hazardous('TGT','CMD','PARAM1'=>val,'PARAM2'=>val)
    #
    # @param args [String|Array<String>] See the description for calling style
    # @return [Boolean] Whether the command is hazardous
    def get_cmd_hazardous(*args, scope: $cosmos_scope, token: $cosmos_token)
      case args.length
      when 1
        target_name, command_name, params = extract_fields_from_cmd_text(args[0])
      when 2, 3
        target_name = args[0]
        command_name = args[1]
        if args.length == 2
          params = {}
        else
          params = args[2]
        end
      else
        # Invalid number of arguments
        raise "ERROR: Invalid number of arguments (#{args.length}) passed to get_cmd_hazardous()"
      end

      authorize(permission: 'cmd_info', target_name: target_name, packet_name: command_name, scope: scope, token: token)
      packet = Store.instance.get_packet(target_name, command_name, type: 'cmd', scope: scope)
      return true if packet['hazardous']

      packet['items'].each do |item|
        next unless params.keys.include?(item['name']) && item['states']
          # States are an array of the name followed by a hash of 'value' and sometimes 'hazardous'
          item['states'].each do |name, hash|
          if hash['value'].to_i == params[item['name']].to_i && hash['hazardous']
            return true
          end
        end
      end

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
    def get_cmd_value(target_name, command_name, parameter_name, value_type = :CONVERTED, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'cmd_info', target_name: target_name, packet_name: command_name, scope: scope, token: token)
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
    def get_cmd_time(target_name = nil, command_name = nil, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'cmd_info', target_name: target_name, packet_name: command_name, scope: scope, token: token)
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
    def tlm(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name = tlm_process_args(args, 'tlm', scope: scope)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.get_tlm_item(target_name, packet_name, item_name, type: :CONVERTED, scope: scope)
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
    def tlm_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name = tlm_process_args(args, 'tlm_raw', scope: scope)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.get_tlm_item(target_name, packet_name, item_name, type: :RAW, scope: scope)
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
    def tlm_formatted(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name = tlm_process_args(args, 'tlm_formatted', scope: scope)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.get_tlm_item(target_name, packet_name, item_name, type: :FORMATTED, scope: scope)
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
    def tlm_with_units(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name = tlm_process_args(args, 'tlm_with_units', scope: scope)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.get_tlm_item(target_name, packet_name, item_name, type: :WITH_UNITS, scope: scope)
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
    def tlm_variable(*args, scope: $cosmos_scope, token: $cosmos_token)
      case args[-1]
      when :RAW
        return tlm_raw(*args[0..-2], scope: scope)
      when :CONVERTED
        return tlm(*args[0..-2], scope: scope)
      when :FORMATTED
        return tlm_formatted(*args[0..-2], scope: scope)
      when :WITH_UNITS
        return tlm_with_units(*args[0..-2], scope: scope)
      else
        raise "Invalid type '#{args[-1]}'. Must be :RAW, :CONVERTED, :FORMATTED, or :WITH_UNITS."
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
    def set_tlm(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name, value = set_tlm_process_args(args, __method__, scope: scope)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      if target_name == 'SYSTEM'.freeze and packet_name == 'META'.freeze
        raise "set_tlm not allowed on #{target_name} #{packet_name} #{item_name}" if ['PKTID', 'CONFIG'].include?(item_name)
      end

      Store.instance.set_tlm_item(target_name, packet_name, item_name, value, scope: scope)

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
    def set_tlm_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name, value = set_tlm_process_args(args, __method__, scope: scope)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.set_tlm_item(target_name, packet_name, item_name, value, type: :RAW, scope: scope)
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
    def inject_tlm(target_name, packet_name, item_hash = nil, value_type = :CONVERTED, send_routers = true, send_packet_log_writers = true, create_new_logs = false, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)

      # Get the packet hash ... this will raise errors if target_name and packet_name do not exist
      packet = Store.instance.get_packet(target_name, packet_name)
      if item_hash
        item_hash.each do |item_name, item_value|
          # Verify the item exists
          Store.instance.get_item_from_packet_hash(packet, item_name)
        end
      end

      inject = {}
      inject['inject_tlm'] = true
      inject['target_name'] = target_name
      inject['packet_name'] = packet_name
      inject['item_hash'] = JSON.generate(item_hash) if item_hash
      inject['value_type'] = value_type
      # TODO: Handle the rest of the parameters
      # inject['send_routers'] = true if send_routers

      Store.instance.get_interfaces.each do |interface|
        if interface['target_names'].include?(target_name)
          Store.instance.write_interface(interface['name'], inject)
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
    def override_tlm(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name, value = set_tlm_process_args(args, __method__, scope: scope)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.override(target_name, packet_name, item_name, value, type: :CONVERTED, scope: scope)
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
    def override_tlm_raw(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name, value = set_tlm_process_args(args, __method__, scope: scope)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.override(target_name, packet_name, item_name, value, type: :RAW, scope: scope)
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
    def normalize_tlm(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name = tlm_process_args(args, __method__, scope: scope)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.normalize(target_name, packet_name, item_name, scope: scope)
    end

    # Returns the raw buffer for a telemetry packet.
    #
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @return [String] last telemetry packet buffer
    def get_tlm_buffer(target_name, packet_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.tlm_packet_exist?(target_name, packet_name, scope: scope)
      topic = "#{scope}__TELEMETRY__#{target_name}__#{packet_name}"
      msg_id, msg_hash = Store.instance.read_topic_last(topic)
      puts "msg:#{msg_id} hash:#{msg_hash}"
      return msg_hash['buffer'] if msg_id
      nil
    end

    # Returns all the values (along with their limits state) for a packet.
    #
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @param value_type [Symbol] How the values should be converted. Must be
    #   one of {Packet::VALUE_TYPES}
    # @return (see Cosmos::Packet#read_all_with_limits_states)
    def get_tlm_packet(target_name, packet_name, value_type = :CONVERTED, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.get_packet(target_name, packet_name, scope: scope)
      value_type = value_type.intern
      case value_type
      when :RAW
        desired_item_type = ''
      when :CONVERTED
        desired_item_type = 'C'
      when :FORMATTED
        desired_item_type = 'F'
      when :WITH_UNITS
        desired_item_type = 'U'
      else
        raise "Unknown value type on read: #{value_type}"
      end
      result_hash = {}
      topic = "#{scope}__DECOM__#{target_name}__#{packet_name}"
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
    end

    # Returns all the item values (along with their limits state). The items
    # can be from any target and packet and thus must be fully qualified with
    # their target and packet names.
    #
    # @version 5.0.0
    # @param (see Cosmos::Telemetry#values_and_limits_states)
    # @return [Array<Array<Object>, Array<Symbol>>]
    #   Array consisting of an Array of item values and an Array of item limits state
    #   given as symbols such as :RED, :YELLOW, :STALE
    def get_tlm_values(item_array, value_types = :CONVERTED, scope: $cosmos_scope, token: $cosmos_token)
      item_array.each do |target_name, packet_name, item_name|
        authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      end
      Store.instance.get_tlm_values(item_array, value_types, scope: scope)
    end

    # Returns an array of all the telemetry packet hashes
    #
    # @since 5.0.0
    # @param target_name [String] Name of the target
    # @return [Array<Hash>] Array of all telemetry packet hashes
    def get_all_telemetry(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', target_name: target_name, scope: scope, token: token)
      Store.instance.get_telemetry(target_name, scope: scope)
    end

    # Returns a telemetry packet hash
    #
    # @since 5.0.0
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @return [Hash] Telemetry packet hash
    def get_telemetry(target_name, packet_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.get_packet(target_name, packet_name, scope: scope)
    end

    # Returns a telemetry packet item hash
    #
    # @since 5.0.0
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @param item_name [String] Name of the packet
    # @return [Hash] Telemetry packet item hash
    def get_item(target_name, packet_name, item_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.get_item(target_name, packet_name, item_name, scope: scope)
    end

    # Returns the sorted packet names and their descriptions for a particular
    # target.
    #
    # @deprecated Use #get_all_telemetry
    # @param target_name (see #get_tlm_packet)
    # @return [Array<String, String>] Array of \[packet name, packet
    #   description] sorted by packet name
    def get_tlm_list(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', target_name: target_name, scope: scope, token: token)
      list = []
      Store.instance.get_telemetry(target_name, scope: scope).each do |packet|
        list << [packet['packet_name'], packet['description']]
      end
      list.sort
    end

    # Returns the item names and their states and descriptions for a particular
    # packet.
    #
    # @deprecated Use #get_telemetry
    # @param target_name (see #get_tlm_packet)
    # @param packet_name (see #get_tlm_packet)
    # @return [Array<String, Hash, String>] Array of \[item name, item states,
    #   item description]
    def get_tlm_item_list(target_name, packet_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      packet = Store.instance.get_packet(target_name, packet_name, scope: scope)
      return packet['items'].map {|item| [item['name'], item['states'], item['description']] }
    end

    # Returns an array of Hashes with all the attributes of the item.
    #
    # @deprecated Use #get_telemetry
    # @param (see Cosmos::Telemetry#values_and_limits_states)
    # @return [Array<Hash>] Array of hashes describing the items. All the
    #   attributes in {Cosmos::PacketItem} and {Cosmos::StructItem} are
    #   present in the Hash.
    def get_tlm_details(item_array, scope: $cosmos_scope, token: $cosmos_token)
      if !item_array.is_a?(Array) || !item_array[0].is_a?(Array)
        raise ArgumentError, "item_array must be nested array: [['TGT','PKT','ITEM'],...]"
      end

      details = []
      item_array.each do |target_name, packet_name, item_name|
        authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
        _, item = System.telemetry.packet_and_item(target_name, packet_name, item_name, scope: scope)
        details << item.to_hash
      end
      details
    end

    # (see Cosmos::Limits#out_of_limits)
    def get_out_of_limits(scope: $cosmos_scope, token: $cosmos_token)
      # Todo: Need to check permission on each returned item
      authorize(permission: 'tlm', scope: scope, token: token)
      return System.limits.out_of_limits(scope: scope)
    end

    # (see Cosmos::Limits#overall_limits_state)
    def get_overall_limits_state(ignored_items = nil, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      return System.limits.overall_limits_state(ignored_items, scope: scope)
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
    def limits_enabled?(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name = tlm_process_args(args, 'limits_enabled?', scope: scope)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      return Store.instance.get_item(target_name, packet_name, item_name, scope: scope)['limits']['enabled'] ? true : false
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
    def enable_limits(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name = tlm_process_args(args, 'enable_limits', scope: scope)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      packet = Store.instance.get_packet(target_name, packet_name, scope: scope)
      item = Store.instance.get_item_from_packet_hash(packet, item_name, scope: scope)
      item['limits']['enabled'] = true
      Store.instance.hset("#{scope}__cosmostlm__#{target_name}", packet_name, JSON.generate(packet))
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
    def disable_limits(*args, scope: $cosmos_scope, token: $cosmos_token)
      target_name, packet_name, item_name = tlm_process_args(args, 'disable_limits', scope: scope)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      packet = Store.instance.get_packet(target_name, packet_name, scope: scope)
      item = Store.instance.get_item_from_packet_hash(packet, item_name, scope: scope)
      item['limits'].delete('enabled')
      Store.instance.hset("#{scope}__cosmostlm__#{target_name}", packet_name, JSON.generate(packet))
    end

    # Get the list of stale packets for a specific target or pass nil to list
    # all stale packets
    #
    # @param with_limits_only [Boolean] Return only the stale packets
    #   that have limits items and thus affect the overall limits
    #   state of the system
    # @param target_name [String] The target to find stale packets for or nil to list
    #   all stale packets in the system
    # @return [Array<Array<String, String>>] Array of arrays listing the target
    #   name and packet name
    def get_stale(with_limits_only = false, target_name = nil, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', target_name: target_name, scope: scope, token: token)
      stale = []
      targets = []
      if target_name
        targets = [target_name]
      else
        targets = get_target_list()
      end
      targets.each do |target|
        get_all_telemetry(target, scope: scope).each do |packet|
          if packet['stale']
            next if with_limits_only && packet['items'].find { |item| item['limits'] }.nil?
            stale << [packet['target_name'], packet['packet_name']]
          end
        end
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
    # @deprecated Use #get_item
    # @return [Hash{String => Array<Number, Number, Number, Number, Number, Number>}]
    def get_limits(target_name, packet_name, item_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      limits = {}
      item = Store.instance.get_item(target_name, packet_name, item_name, scope: scope)
      item['limits'].each do |key, vals|
        next unless vals.is_a?(Hash)
        limits[key] = [vals['red_low'], vals['yellow_low'], vals['yellow_high'], vals['red_high']]
        limits[key].concat([vals['green_low'], vals['green_high']]) if vals['green_low']
      end
      return limits
    end

    def set_limits(target_name, packet_name, item_name, red_low, yellow_low, yellow_high, red_high, green_low = nil, green_high = nil, limits_set = :CUSTOM, persistence = nil, enabled = true, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      packet = Store.instance.get_packet(target_name, packet_name, scope: scope)
      item = Store.instance.get_item_from_packet_hash(packet, item_name, scope: scope)
      item['limits']['persistence_setting'] = persistence
      if enabled
        item['limits']['enabled'] = true
      else
        item['limits'].delete('enabled')
      end
      limits = {}
      limits['red_low'] = red_low
      limits['yellow_low'] = yellow_low
      limits['yellow_high'] = yellow_high
      limits['red_high'] = red_high
      limits['green_low'] = green_low if green_low
      limits['green_high'] = green_high if green_high
      item['limits'][limits_set] = limits
      Store.instance.hset("#{scope}__cosmostlm__#{target_name}", packet_name, JSON.generate(packet))

      limits_settings = [target_name, packet_name, item_name].concat(item.to_a)
      # TODO: Notify system taht limits changed
      # CmdTlmServer.instance.post_limits_event(:LIMITS_SETTINGS, limits_settings)
      Logger.info("Limits Settings Changed: #{limits_settings}")
    end

    # Returns all limits_groups and their members
    # @since 5.0.0 Returns hash with values
    # @return [Hash{String => Array<Array<String, String, String>>]
    def get_limits_groups(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      JSON.parse(Store.instance.hget("#{scope}__cosmos_system", 'limits_groups'))
    end

    # Enables limits for all the items in the group
    def enable_limits_group(group_name, scope: $cosmos_scope, token: $cosmos_token)
      _limits_group(group_name, action: :enable, scope: scope)
    end

    # Disables limits for all the items in the group
    def disable_limits_group(group_name, scope: $cosmos_scope, token: $cosmos_token)
      _limits_group(group_name, action: :disable, scope: scope)
    end

    def _limits_group(group_name, action:, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm_set', scope: scope, token: token)
      group_name.upcase!
      group = get_limits_groups()[group_name]
      raise "LIMITS_GROUP #{group_name} undefined. Ensure your telemetry definition contains the line: LIMITS_GROUP #{group_name}" unless group
      Logger.info("Disabling Limits Group: #{group_name}")
      group.each do |target_name, packet_name, item_name|
        packet = Store.instance.get_packet(target_name, packet_name, scope: scope)
        item = Store.instance.get_item_from_packet_hash(packet, item_name, scope: scope)
        if action == :enable
          item['limits']['enabled'] = true
        elsif action == :disable
          item['limits'].delete('enabled')
        else
          raise "Unknown action #{action}"
        end
        Store.instance.hset("#{scope}__cosmostlm__#{target_name}", packet_name, JSON.generate(packet))
      end
    end

    # Returns all defined limits sets
    #
    # @return [Array<Symbol>] All defined limits sets
    def get_limits_sets(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      JSON.parse(Store.instance.hget("#{scope}__cosmos_system", 'limits_sets'))
    end

    # Changes the active limits set that applies to all telemetry
    #
    # @param limits_set [String] The name of the limits set
    def set_limits_set(limits_set, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm_set', scope: scope, token: token)
      Store.instance.hset("#{scope}__cosmos_system", 'limits_set', limits_set)
    end

    # Returns the active limits set that applies to all telemetry
    #
    # @return [String] The current limits set
    def get_limits_set(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      Store.instance.hget("#{scope}__cosmos_system", 'limits_set')
    end

    #
    # General Purpose Methods
    #

    # Returns the list of all target names
    #
    # @return [Array<String>] All target names
    def get_target_list(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      JSON.parse(Store.instance.hget("#{scope}__cosmos_system", 'target_names'))
    end

    # @see CmdTlmServer.subscribe_limits_events
    def subscribe_limits_events(queue_size = CmdTlmServer::DEFAULT_LIMITS_EVENT_QUEUE_SIZE, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      CmdTlmServer.subscribe_limits_events(queue_size, scope: scope)
    end

    # @see CmdTlmServer.unsubscribe_limits_events
    def unsubscribe_limits_events(id, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      CmdTlmServer.unsubscribe_limits_events(id)
    end

    # @see CmdTlmServer.get_limits_event
    def get_limits_event(id, non_block = false, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      CmdTlmServer.get_limits_event(id, non_block)
    end

    # @see CmdTlmServer.subscribe_packet_data
    def subscribe_packet_data(packets,
                              queue_size = CmdTlmServer::DEFAULT_PACKET_DATA_QUEUE_SIZE, scope: $cosmos_scope, token: $cosmos_token)
      packets.each do |target_name, packet_name|
        authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      end
      CmdTlmServer.subscribe_packet_data(packets, queue_size)
    end

    # @see CmdTlmServer.unsubscribe_packet_data
    def unsubscribe_packet_data(id, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      CmdTlmServer.unsubscribe_packet_data(id)
    end

    # @see CmdTlmServer.get_packet_data
    def get_packet_data(id, non_block = false, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      CmdTlmServer.get_packet_data(id, non_block)
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

    # Get a packet which was previously subscribed to by
    # subscribe_packet_data. This method can block waiting for new packets or
    # not based on the second parameter. It returns a single Cosmos::Packet instance
    # and will return nil when no more packets are buffered (assuming non_block
    # is false).
    # Usage:
    #   get_packet(id, <true or false to block>)
    def get_packet(id, non_block = false, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
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

    # @deprecated Use #get_interface
    # @return [Array<String>] All the targets mapped to the given interface
    def get_interface_targets(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', interface_name: interface_name, scope: scope, token: token)
      interface = JSON.parse(Store.instance.hget("#{scope}__cosmos_microservices", "INTERFACE__#{interface_name}"))
      targets = []
      interface['target_list'].each do |target|
        targets << target['target_name']
      end
      targets
    end

    # @return [Array<String>] All the interface names
    def get_interface_names(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      CmdTlmServer.interfaces.names
    end

    # Connects to an interface and starts its telemetry gathering thread. If
    # optional parameters are given, the interface is recreated with new
    # parameters.
    #
    # @param interface_name [String] The name of the interface
    # @param params [Array] Parameters to pass to the interface.
    def connect_interface(interface_name, *params, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', interface_name: interface_name, scope: scope, token: token)
      CmdTlmServer.interfaces.connect(interface_name, *params)
      nil
    end

    # Disconnects from an interface and kills its telemetry gathering thread
    #
    # @param interface_name (see #connect_interface)
    def disconnect_interface(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', interface_name: interface_name, scope: scope, token: token)
      CmdTlmServer.interfaces.disconnect(interface_name)
      nil
    end

    # @param interface_name (see #connect_interface)
    # @return [String] The state of the interface which is one of 'CONNECTED',
    #   'ATTEMPTING' or 'DISCONNECTED'.
    def interface_state(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', interface_name: interface_name, scope: scope, token: token)
      CmdTlmServer.interfaces.state(interface_name)
    end

    # Associates a target and all its commands and telemetry with a particular
    # interface. All the commands will go out over and telemetry be received
    # from that interface.
    #
    # @param target_name [String] The name of the target
    # @param interface_name (see #connect_interface)
    def map_target_to_interface(target_name, interface_name, scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported in COSMOS 5 - Targets cannot be dynamically remapped"
    end

    # @return [Array<String>] All the router names
    def get_router_names(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      CmdTlmServer.routers.names
    end

    # Connects a router and starts its command gathering thread. If
    # optional parameters are given, the router is recreated with new
    # parameters.
    #
    # @param router_name [String] The name of the router
    # @param params [Array] Parameters to pass to the router.
    def connect_router(router_name, *params, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', router_name: router_name, scope: scope, token: token)
      CmdTlmServer.routers.connect(router_name, *params)
      nil
    end

    # Disconnects a router and kills its command gathering thread
    #
    # @param router_name (see #connect_router)
    def disconnect_router(router_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', router_name: router_name, scope: scope, token: token)
      CmdTlmServer.routers.disconnect(router_name)
      nil
    end

    # @param router_name (see #connect_router)
    # @return [String] The state of the router which is one of 'CONNECTED',
    #   'ATTEMPTING' or 'DISCONNECTED'.
    def router_state(router_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', router_name: router_name, scope: scope, token: token)
      CmdTlmServer.routers.state(router_name)
    end

    # Get cmd and tlm counts for a target
    #
    # @deprecated Use #get_target
    # @param target_name [String] Target name
    # @return [Array<Numeric, Numeric>] Array of \[cmd_cnt, tlm_cnt]
    def get_target_info(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, scope: scope, token: token)
      cmd_cnt = 0
      tlm_cnt = 0
      Store.instance.get_commands(target_name, scope: scope).each do |packet|
        cmd_cnt += get_cmd_cnt(target_name, packet["packet_name"])
      end
      Store.instance.get_telemetry(target_name, scope: scope).each do |packet|
        tlm_cnt += get_tlm_cnt(target_name, packet["packet_name"])
      end
      return [cmd_cnt, tlm_cnt]
    end

    # Get information about all targets
    #
    # @return [Array<Array<String, Numeric, Numeric>] Array of Arrays \[name, interface, cmd_cnt, tlm_cnt]
    def get_all_target_info(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      info = []
      get_target_list().each do |target_name|
        target = Store.instance.get_target(target_name, scope: scope)
        info << [target['name'], target['interface'], target['cmd_cnt'], target['tlm_cnt']]
      end
      info
    end

    # Gets the full target hash
    #
    # @since 5.0.0
    # @param target_name [String] Target name
    # @return [Hash] Hash of all the target properties
    def get_target(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, scope: scope, token: token)
      return Store.instance.get_target(target_name, scope: scope)
    end

    # Get the list of ignored command parameters for a target
    #
    # @deprecated Use #get_target
    # @param target_name [String] Target name
    # @return [Array<String>] All of the ignored command parameters for a target.
    def get_target_ignored_parameters(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, scope: scope, token: token)
      return Store.instance.get_target(target_name, scope: scope)['ignored_parameters']
    end

    # Get the list of ignored telemetry items for a target
    #
    # @deprecated Use get_target
    # @param target_name [String] Target name
    # @return [Array<String>] All of the ignored telemetry items for a target.
    def get_target_ignored_items(target_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, scope: scope, token: token)
      return Store.instance.get_target(target_name, scope: scope)['ignored_items']
    end

    # Get the list of derived telemetry items for a packet
    #
    # @param target_name [String] Target name
    # @param packet_name [String] Packet name
    # @return [Array<String>] All of the ignored telemetry items for a packet.
    def get_packet_derived_items(target_name, packet_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      packet = Store.instance.get_packet(target_name, packet_name, scope: scope)
      raise "Unknown target or packet: #{target_name} #{packet_name}" unless packet
      return packet['items'].select {|item| item['data_type'] == 'DERIVED' }.map {|item| item['name']}
    end

    # Get information about an interface
    #
    # @param interface_name [String] Interface name
    # @return [Hash] Hash of all the interface information
    def get_interface(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', interface_name: interface_name, scope: scope, token: token)
      Store.instance.get_interface(interface_name, scope: scope)
    end

    # Get information about an interface
    #
    # @deprecated Use #get_interface
    # @param interface_name [String] Interface name
    # @return [Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>] Array containing \[state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Command count,
    #   Telemetry count] for the interface
    def get_interface_info(interface_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', interface_name: interface_name, scope: scope, token: token)
      int = get_interface(interface_name, scope: scope)
      return [int['state'], int['clients'], int['txsize'], int['rxsize'],\
              int['txbytes'], int['rxbytes'], int['cmdcnt'], int['tlmcnt']]
    end

    # Get information about all interfaces
    #
    # @return [Array<Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>>] Array of Arrays containing \[name, state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Command count,
    #   Telemetry count] for all interfaces
    def get_all_interface_info(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      info = []
      Store.instance.get_interfaces(scope: scope).each do |int|
        info << [int['name'], int['state'], int['clients'], int['txsize'], int['rxsize'],\
                  int['txbytes'], int['rxbytes'], int['cmdcnt'], int['tlmcnt']]
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
    def get_router_info(router_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', router_name: router_name, scope: scope, token: token)
      Store.instance.get_interface(router_name, scope: scope)
    end

    # Get information about all routers
    #
    # @return [Array<Array<String, Numeric, Numeric, Numeric, Numeric, Numeric,
    #   Numeric, Numeric>>] Array of Arrays containing \[name, state, num clients,
    #   TX queue size, RX queue size, TX bytes, RX bytes, Command count,
    #   Telemetry count] for all routers
    def get_all_router_info(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      info = []
      CmdTlmServer.routers.names.sort.each do |router_name|
        info << [router_name].concat(CmdTlmServer.routers.get_info(router_name))
      end
      info
    end

    def _get_cnt(topic)
      _, _, target_name, packet_name = topic.split('__')
      raise "Packet '#{target_name} #{packet_name}' does not exist" unless Store.instance.exists?(topic)
      id, packet = Store.instance.read_topic_last(topic)
      packet ? packet["received_count"].to_i : 0
    end

    # Get the transmit count for a command packet
    #
    # @param target_name [String] Target name of the command
    # @param command_name [String] Packet name of the command
    # @return [Numeric] Transmit count for the command
    def get_cmd_cnt(target_name, command_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, packet_name: command_name, scope: scope, token: token)
      _get_cnt("#{scope}__COMMAND__#{target_name}__#{command_name}")
    end

    # Get the receive count for a telemetry packet
    #
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @return [Numeric] Receive count for the telemetry packet
    def get_tlm_cnt(target_name, packet_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      _get_cnt("#{scope}__TELEMETRY__#{target_name}__#{packet_name}")
    end

    # Get information on all command packets
    #
    # @return [Array<String, String, Numeric>] Transmit count for all commands
    def get_all_cmd_info(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      result = []
      keys = []
      count = 0
      loop do
        count, part = Store.instance.scan(0, :match => "#{scope}__COMMAND__*", :count => 1000, scope: scope)
        keys.concat(part)
        break if count.to_i == 0
      end
      keys.each do |key|
        _, target, packet = key.split('__')
        result << [target, packet, _get_cnt(key)]
      end
      result
    end

    # Get information on all telemetry packets
    #
    # @return [Array<String, String, Numeric>] Receive count for all telemetry
    def get_all_tlm_info(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      result = []
      keys = []
      count = 0
      loop do
        count, part = Store.instance.scan(0, :match => "#{scope}__TELEMETRY__*", :count => 1000, scope: scope)
        keys.concat(part)
        break if count.to_i == 0
      end
      keys.each do |key|
        _, target, packet = key.split('__')
        result << [target, packet, _get_cnt(key)]
      end
      result
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

    # Get background task information
    #
    # @return [Array<Array<String, String, String>>] Array of Arrays containing
    #   the background task name, thread status, and task status
    def get_background_tasks(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
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
    def start_background_task(task_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', scope: scope, token: token)
      CmdTlmServer.background_tasks.all.each_with_index do |task, index|
        if task.name == task_name
          CmdTlmServer.background_tasks.start(index)
          break
        end
      end
    end

    # Stop a background task
    def stop_background_task(task_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', scope: scope, token: token)
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
    def get_server_status(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', scope: scope, token: token)
      set = Store.instance.hget("#{scope}__cosmos_system", 'limits_set')
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

    # Reload the default configuration
    def cmd_tlm_reload(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Clear server counters
    def cmd_tlm_clear_counters(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system_set', scope: scope, token: token)
      CmdTlmServer.clear_counters
    end

    # Get the list of filenames in the outputs logs folder
    def get_output_logs_filenames(filter = '*tlm.bin', scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Select and start analyzing a file for replay
    #
    # filename [String] filename relative to output logs folder or absolute filename
    def replay_select_file(filename, packet_log_reader = "DEFAULT", scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Get current replay status
    #
    # status, delay, filename, file_start, file_current, file_end, file_index, file_max_index
    def replay_status(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Set the replay delay
    #
    # @param delay [Float] delay between packets in seconds 0.0 to 1.0, nil = REALTIME
    def replay_set_playback_delay(delay, scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay start playing forward
    def replay_play(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay start playing backward
    def replay_reverse_play(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay stop
    def replay_stop(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay step forward one packet
    def replay_step_forward(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay step backward one packet
    def replay_step_back(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay move to start of file
    def replay_move_start(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay move to end of file
    def replay_move_end(scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # Replay move to index
    #
    # @param index [Integer] packet index into file
    def replay_move_index(index, scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    # # Get the organized list of available telemetry screens
    # def get_screen_list(config_filename = nil, force_refresh = false)
    #   if force_refresh or !@tlm_viewer_config or @tlm_viewer_config_filename != config_filename
    #     @tlm_viewer_config = TlmViewerConfig.new(config_filename, true)
    #     @tlm_viewer_config_filename = config_filename
    #   end
    #   return @tlm_viewer_config.columns
    # end

    # # Get a specific screen definition
    # def get_screen_definition(screen_full_name, config_filename = nil, force_refresh = false)
    #   get_screen_list(config_filename, force_refresh) if force_refresh or !@tlm_viewer_config
    #   screen_info = @tlm_viewer_config.screen_infos[screen_full_name.upcase]
    #   raise "Unknown screen: #{screen_full_name.upcase}" unless screen_info
    #   screen_definition = File.read(screen_info.filename)
    #   return screen_definition
    # end

    # Get a saved configuration zip file
    def get_saved_config(configuration_name = nil, scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    private

    def cmd_implementation(range_check, hazardous_check, raw, method_name, *args, scope:, token:)
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
      authorize(permission: 'cmd', target_name: target_name, packet_name: cmd_name, scope: scope, token: token)
      Store.instance.cmd_target(target_name, cmd_name, cmd_params, range_check, hazardous_check, raw, scope: scope)
      [target_name, cmd_name, cmd_params]
    end

    def tlm_process_args(args, function_name, scope: $cosmos_scope, token: $cosmos_token)
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
      if packet_name == 'LATEST'
        latest = 0
        Store.instance.get_telemetry(target_name).each do |packet|
          item = packet['items'].find { |item| item['name'] == item_name }
          if item
            time = Store.instance.get_tlm_item(target_name, packet['name'], 'PACKET_TIMESECONDS', scope: scope)
            # time = packet['items'].find { |item| item['name'] == 'PACKET_TIMESECONDS' }
            puts "time:#{time}"
            puts item
          end
        end
      else
        # Determine if this item exists, it will raise appropriate errors if not
        Store.instance.get_item(target_name, packet_name, item_name, scope: scope)
      end

      return [target_name, packet_name, item_name]
    end

    def tlm_variable_process_args(args, function_name, scope: $cosmos_scope, token: $cosmos_token)
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
      # Determine if this item exists, it will raise appropriate errors if not
      Store.instance.get_item(target_name, packet_name, item_name, scope: scope)

      return [target_name, packet_name, item_name, value_type]
    end

    def set_tlm_process_args(args, function_name, scope: $cosmos_scope, token: $cosmos_token)
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
      # Determine if this item exists, it will raise appropriate errors if not
      Store.instance.get_item(target_name, packet_name, item_name, scope: scope)

      return [target_name, packet_name, item_name, value]
    end
  end
end
