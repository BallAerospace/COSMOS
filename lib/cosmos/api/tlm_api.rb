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
      'subscribe_packet_data',
      'unsubscribe_packet_data',
      'get_packet_data',
      'get_packet',
      'get_all_tlm_info',
      'get_tlm_cnt',
      'get_packet_derived_items',
    ])

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
      case args[-1].intern
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
    def inject_tlm(target_name, packet_name, item_hash = nil, value_type = :CONVERTED, send_routers = true,
      send_packet_log_writers = true, create_new_logs = false, scope: $cosmos_scope, token: $cosmos_token)
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

      InterfaceModel.all(scope: scope).each do |name, interface|
        if interface['target_names'].include? target_name
          Store.write_topic("#{scope}__CMDINTERFACE__#{interface['name']}", inject)
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
      return msg_hash['buffer'].b if msg_id # Return as binary
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
    # @param items [Array<String>] Array of items consisting of 'tgt__pkt__item__type'
    # @return [Array<Object, Symbol>]
    #   Array consisting of the item value and limits state
    #   given as symbols such as :RED, :YELLOW, :STALE
    def get_tlm_values(items, scope: $cosmos_scope, token: $cosmos_token)
      if !items.is_a?(Array) || !items[0].is_a?(String)
        raise ArgumentError, "items must be array of strings: ['TGT__PKT__ITEM__TYPE', ...]"
      end
      items.each do |item|
        target_name, packet_name, _, _ = item.split('__')
        authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      end
      Store.instance.get_tlm_values(items, scope: scope)
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

      # packet = Store.instance.get_packet(target_name, packet_name, scope: scope)
      # return packet['items'].map {|item| [item['name'], item['states'], item['description']] }

      # def get_telemetry(target_name, packet_name, scope: $cosmos_scope, token: $cosmos_token)

      details = []
      item_array.each do |target_name, packet_name, item_name|
        authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
        _, item = System.telemetry.packet_and_item(target_name, packet_name, item_name, scope: scope)
        details << item.to_hash
      end
      details
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

    # Get the receive count for a telemetry packet
    #
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @return [Numeric] Receive count for the telemetry packet
    def get_tlm_cnt(target_name, packet_name, scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'system', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      Store.instance.tlm_packet_exist?(target_name, command_name, scope: scope)
      _get_cnt("#{scope}__TELEMETRY__#{target_name}__#{packet_name}")
    end

    # Get information on all telemetry packets
    #
    # @return [Array<String, String, Numeric>] Receive count for all telemetry
    def get_all_tlm_info(scope: $cosmos_scope, token: $cosmos_token)
      get_all_cmd_tlm_info("TELEMETRY", scope: scope, token: token)
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

    # PRIVATE

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
            _, msg_hash = Store.instance.get_oldest_message("#{scope}__DECOM__#{target_name}__#{packet['packet_name']}")
            if msg_hash && msg_hash['time'] && msg_hash['time'].to_i > latest
              packet_name = packet['packet_name']
              latest = msg_hash['time'].to_i
            end
          end
        end
      else
        # Determine if this item exists, it will raise appropriate errors if not
        Store.instance.get_item(target_name, packet_name, item_name, scope: scope)
      end

      return [target_name, packet_name, item_name]
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
