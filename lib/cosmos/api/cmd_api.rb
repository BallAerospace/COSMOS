module Cosmos
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
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
      'get_all_cmd_info',
      'get_cmd_cnt',
    ])

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
      return msg_hash['buffer'].b if msg_id # Return as binary
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
        if item['format_string'] and item['default']
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
          # To be hazardous the state must be marked hazardous
          # Check if either the state name or value matches the param passed
          if hash['hazardous'] && (name == params[item['name']] || hash['value'].to_f == params[item['name']].to_f)
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
      Store.instance.get_cmd_item(target_name, command_name, parameter_name, type: value_type, scope: scope)
    end

    # Returns the time the most recent command was sent
    #
    # @deprecated Use get_cmd_value with RECEIVED_TIMESECONDS or RECEIVED_TIMEFORMATTED
    # @param target_name [String] Target name of the command. If not given then
    #    the most recent time from all commands will be returned
    # @param command_name [String] Packet name of the command. If not given then
    #    then most recent time from the given target will be returned.
    # @return [Array<Target Name, Command Name, Time Seconds, Time Microseconds>]
    def get_cmd_time(target_name = nil, command_name = nil, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'cmd_info', target_name: target_name, packet_name: command_name, scope: scope, token: token)
      if target_name and command_name
        time = Store.instance.get_cmd_item(target_name, command_name, 'RECEIVED_TIMESECONDS', type: :CONVERTED, scope: scope)
        return [target_name, command_name, time.to_i, ((time.to_f - time.to_i) * 1_000_000).to_i]
      else
        if target_name.nil?
          targets = TargetModel.names(scope: scope)
        else
          targets = [target_name]
        end
        targets.each do |target_name|
          time = 0
          command_name = nil
          Store.instance.get_commands(target_name, scope: scope).each do |packet|
            cur_time = Store.instance.get_cmd_item(target_name, packet["packet_name"], 'RECEIVED_TIMESECONDS', type: :CONVERTED, scope: scope)
            next unless cur_time
            if cur_time > time
              time = cur_time
              command_name = packet["packet_name"]
            end
          end
          target_name = nil unless command_name
          return [target_name, command_name, time.to_i, ((time.to_f - time.to_i) * 1_000_000).to_i]
        end
      end
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

    # Get information on all command packets
    #
    # @return [Array<String, String, Numeric>] Transmit count for all commands
    def get_all_cmd_info(scope: $cosmos_scope, token: $cosmos_token)
      get_all_cmd_tlm_info("COMMAND", scope: scope, token: token)
    end

    # PRIVATE

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

  end
end