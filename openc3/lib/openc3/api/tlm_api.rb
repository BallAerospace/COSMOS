# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'openc3/models/target_model'
require 'openc3/models/cvt_model'
require 'openc3/packets/packet'
require 'openc3/topics/telemetry_topic'
require 'openc3/utilities/s3'

module OpenC3
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
                       'tlm',
                       'tlm_raw',
                       'tlm_formatted',
                       'tlm_with_units',
                       'tlm_variable',
                       'set_tlm',
                       'inject_tlm',
                       'override_tlm',
                       'normalize_tlm',
                       'get_tlm_buffer',
                       'get_tlm_packet',
                       'get_tlm_values',
                       'get_all_telemetry',
                       'get_all_telemetry_names',
                       'get_telemetry',
                       'get_item',
                       'subscribe_packets',
                       'get_packets',
                       'get_tlm_cnt',
                       'get_tlm_cnts',
                       'get_packet_derived_items',
                       'get_oldest_logfile',
                     ])

    # Request a telemetry item from a packet.
    #
    # Accepts two different calling styles:
    #   tlm("TGT PKT ITEM")
    #   tlm('TGT','PKT','ITEM')
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args [String|Array<String>] See the description for calling style
    # @param type [Symbol] Telemetry type, :RAW, :CONVERTED (default), :FORMATTED, or :WITH_UNITS
    # @return [Object] The telemetry value formatted as requested
    def tlm(*args, type: :CONVERTED, scope: $openc3_scope, token: $openc3_token)
      target_name, packet_name, item_name = tlm_process_args(args, 'tlm', scope: scope)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      CvtModel.get_item(target_name, packet_name, item_name, type: type.intern, scope: scope)
    end

    # @deprecated Use tlm with type: :RAW
    def tlm_raw(*args, scope: $openc3_scope, token: $openc3_token)
      tlm(*args, type: :RAW, scope: scope, token: token)
    end

    # @deprecated Use tlm with type: :FORMATTED
    def tlm_formatted(*args, scope: $openc3_scope, token: $openc3_token)
      tlm(*args, type: :FORMATTED, scope: scope, token: token)
    end

    # @deprecated Use tlm with type: :WITH_UNITS
    def tlm_with_units(*args, scope: $openc3_scope, token: $openc3_token)
      tlm(*args, type: :WITH_UNITS, scope: scope, token: token)
    end

    # @deprecated Use tlm with type:
    def tlm_variable(*args, scope: $openc3_scope, token: $openc3_token)
      tlm(*args[0..-2], type: args[-1].intern, scope: scope, token: token)
    end

    # Set a telemetry item in the current value table.
    #
    # Note: If this is done while OpenC3 is currently receiving telemetry,
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
    # @param args [String|Array<String>] See the description for calling style
    # @param type [Symbol] Telemetry type, :RAW, :CONVERTED (default), :FORMATTED, or :WITH_UNITS
    def set_tlm(*args, type: :CONVERTED, scope: $openc3_scope, token: $openc3_token)
      target_name, packet_name, item_name, value = set_tlm_process_args(args, __method__, scope: scope)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      CvtModel.set_item(target_name, packet_name, item_name, value, type: type.intern, scope: scope)
    end

    # Injects a packet into the system as if it was received from an interface
    #
    # @param target_name [String] Target name of the packet
    # @param packet_name [String] Packet name of the packet
    # @param item_hash [Hash] Hash of item_name and value for each item you want to change from the current value table
    # @param type [Symbol] Telemetry type, :RAW, :CONVERTED (default), :FORMATTED, or :WITH_UNITS
    def inject_tlm(target_name, packet_name, item_hash = nil, type: :CONVERTED, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      unless CvtModel::VALUE_TYPES.include?(type.intern)
        raise "Unknown type '#{type}' for #{target_name} #{packet_name}"
      end

      if item_hash
        # Check that the items exist ... exceptions are raised if not
        TargetModel.packet_items(target_name, packet_name, item_hash.keys, scope: scope)
      else
        # Check that the packet exists ... exceptions are raised if not
        TargetModel.packet(target_name, packet_name, scope: scope)
      end

      packet_hash = get_telemetry(target_name, packet_name, scope: scope, token: token)
      packet = Packet.from_json(packet_hash)
      if item_hash
        item_hash.each do |name, value|
          packet.write(name.to_s, value, type)
        end
      end
      packet.received_time = Time.now.sys
      # TODO: New packet so received_count is not correct
      packet.received_count += 1
      TelemetryTopic.write_packet(packet, scope: scope)
    end

    # Override the current value table such that a particular item always
    # returns the same value (for a given type) even when new telemetry
    # packets are received from the target.
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
    # @param type [Symbol] Telemetry type, :RAW, :CONVERTED (default), :FORMATTED, or :WITH_UNITS
    def override_tlm(*args, type: :CONVERTED, scope: $openc3_scope, token: $openc3_token)
      target_name, packet_name, item_name, value = set_tlm_process_args(args, __method__, scope: scope)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      CvtModel.override(target_name, packet_name, item_name, value, type: type.intern, scope: scope)
    end

    # Normalize a telemetry item in a packet to its default behavior. Called
    # after override_tlm to restore standard processing.
    #
    # Accepts two different calling styles:
    #   normalize_tlm("TGT PKT ITEM")
    #   normalize_tlm('TGT','PKT','ITEM')
    #
    # Favor the first syntax where possible as it is more succinct.
    #
    # @param args The args must either be a string or three strings
    #   (see the calling style in the description).
    # @param type [Symbol] Telemetry type, :RAW, :CONVERTED (default), :FORMATTED, or :WITH_UNITS
    #   Also takes :ALL which means to normalize all telemetry types
    def normalize_tlm(*args, type: :ALL, scope: $openc3_scope, token: $openc3_token)
      target_name, packet_name, item_name = tlm_process_args(args, __method__, scope: scope)
      authorize(permission: 'tlm_set', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      CvtModel.normalize(target_name, packet_name, item_name, type: type.intern, scope: scope)
    end

    # Returns the raw buffer for a telemetry packet.
    #
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @return [String] last telemetry packet buffer
    def get_tlm_buffer(target_name, packet_name, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      TargetModel.packet(target_name, packet_name, scope: scope)
      topic = "#{scope}__TELEMETRY__{#{target_name}}__#{packet_name}"
      msg_id, msg_hash = Topic.get_newest_message(topic)
      if msg_id
        msg_hash['buffer'] = msg_hash['buffer'].b
        return msg_hash
      end
      return nil
    end

    # Returns all the values (along with their limits state) for a packet.
    #
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @param type [Symbol] Types returned, :RAW, :CONVERTED (default), :FORMATTED, or :WITH_UNITS
    # @return (see OpenC3::Packet#read_all_with_limits_states)
    def get_tlm_packet(target_name, packet_name, type: :CONVERTED, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      packet = TargetModel.packet(target_name, packet_name, scope: scope)
      t = _validate_tlm_type(type)
      raise ArgumentError, "Unknown type '#{type}' for #{target_name} #{packet_name}" if t.nil?
      items = packet['items'].map { | item | item['name'] }
      cvt_items = items.map { | item | "#{target_name}__#{packet_name}__#{item}__#{type}" }
      current_values = CvtModel.get_tlm_values(cvt_items, scope: scope)
      items.zip(current_values).map { | item , values | [item, values[0], values[1]]}
    end

    # Returns all the item values (along with their limits state). The items
    # can be from any target and packet and thus must be fully qualified with
    # their target and packet names.
    #
    # @since 5.0.0
    # @param items [Array<String>] Array of items consisting of 'tgt__pkt__item__type'
    # @return [Array<Object, Symbol>]
    #   Array consisting of the item value and limits state
    #   given as symbols such as :RED, :YELLOW, :STALE
    def get_tlm_values(items, scope: $openc3_scope, token: $openc3_token)
      if !items.is_a?(Array) || !items[0].is_a?(String)
        raise ArgumentError, "items must be array of strings: ['TGT__PKT__ITEM__TYPE', ...]"
      end

      items.each_with_index do |item, index|
        target_name, packet_name, item_name, item_type = item.split('__')
        if packet_name == 'LATEST'
          _, packet_name, _ = tlm_process_args([target_name, packet_name, item_name], 'get_tlm_values', scope: scope) # Figure out which packet is LATEST
          items[index] = "#{target_name}__#{packet_name}__#{item_name}__#{item_type}" # Replace LATEST with the real packet name
        end
        authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      end
      CvtModel.get_tlm_values(items, scope: scope)
    end

    # Returns an array of all the telemetry packet hashes
    #
    # @since 5.0.0
    # @param target_name [String] Name of the target
    # @return [Array<Hash>] Array of all telemetry packet hashes
    def get_all_telemetry(target_name, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'tlm', target_name: target_name, scope: scope, token: token)
      TargetModel.packets(target_name, type: :TLM, scope: scope)
    end

    # Returns an array of all the telemetry packet names
    #
    # @since 5.0.6
    # @param target_name [String] Name of the target
    # @return [Array<String>] Array of all telemetry packet names
    def get_all_telemetry_names(target_name, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'cmd_info', target_name: target_name, scope: scope, token: token)
      TargetModel.packet_names(target_name, type: :TLM, scope: scope)
    end

    # Returns a telemetry packet hash
    #
    # @since 5.0.0
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @return [Hash] Telemetry packet hash
    def get_telemetry(target_name, packet_name, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      TargetModel.packet(target_name, packet_name, scope: scope)
    end

    # Returns a telemetry packet item hash
    #
    # @since 5.0.0
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @param item_name [String] Name of the packet
    # @return [Hash] Telemetry packet item hash
    def get_item(target_name, packet_name, item_name, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      TargetModel.packet_item(target_name, packet_name, item_name, scope: scope)
    end

    # 2x double underscore since __ is reserved
    SUBSCRIPTION_DELIMITER = '____'

    # Subscribe to a list of packets. An ID is returned which is passed to
    # get_packets(id) to return packets.
    #
    # @param packets [Array<Array<String, String>>] Array of arrays consisting of target name, packet name
    # @return [String] ID which should be passed to get_packets
    def subscribe_packets(packets, scope: $openc3_scope, token: $openc3_token)
      if !packets.is_a?(Array) || !packets[0].is_a?(Array)
        raise ArgumentError, "packets must be nested array: [['TGT','PKT'],...]"
      end

      result = {}
      packets.each do |target_name, packet_name|
        authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
        topic = "#{scope}__DECOM__{#{target_name}}__#{packet_name}"
        id, _ = Topic.get_newest_message(topic)
        result[topic] = id ? id : '0-0'
      end
      result.to_a.join(SUBSCRIPTION_DELIMITER)
    end
    # Alias the singular as well since that matches COSMOS 4
    alias subscribe_packet subscribe_packets

    # Get packets based on ID returned from subscribe_packet.
    # @param id [String] ID returned from subscribe_packets or last call to get_packets
    # @param block [Integer] Number of milliseconds to block when requesting packets
    # @param count [Integer] Maximum number of packets to return from EACH packet stream
    # @return [Array<String, Array<Hash>] Array of the ID and array of all packets found
    def get_packets(id, block: nil, count: 1000, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      # Split the list of topic, ID values and turn it into a hash for easy updates
      lookup = Hash[*id.split(SUBSCRIPTION_DELIMITER)]
      xread = Topic.read_topics(lookup.keys, lookup.values, block, count)
      # Return the original ID and nil if we didn't get anything
      return [id, nil] if xread.empty?
      packets = []
      xread.each do |topic, data|
        data.each do |id, msg_hash|
          lookup[topic] = id # save the new ID
          json_hash = JSON.parse(msg_hash['json_data'], :allow_nan => true, :create_additions => true)
          msg_hash.delete('json_data')
          packets << msg_hash.merge(json_hash)
        end
      end
      return [lookup.to_a.join(SUBSCRIPTION_DELIMITER), packets]
    end

    # Get the receive count for a telemetry packet
    #
    # @param target_name [String] Name of the target
    # @param packet_name [String] Name of the packet
    # @return [Numeric] Receive count for the telemetry packet
    def get_tlm_cnt(target_name, packet_name, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      TargetModel.packet(target_name, packet_name, scope: scope)
      Topic.get_cnt("#{scope}__TELEMETRY__{#{target_name}}__#{packet_name}")
    end

    # Get the transmit counts for telemetry packets
    #
    # @param target_packets [Array<Array<String, String>>] Array of arrays containing target_name, packet_name
    # @return [Numeric] Transmit count for the command
    def get_tlm_cnts(target_packets, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'system', scope: scope, token: token)
      counts = []
      target_packets.each do |target_name, packet_name|
        counts << Topic.get_cnt("#{scope}__TELEMETRY__{#{target_name}}__#{packet_name}")
      end
      counts
    end

    # Get the list of derived telemetry items for a packet
    #
    # @param target_name [String] Target name
    # @param packet_name [String] Packet name
    # @return [Array<String>] All of the ignored telemetry items for a packet.
    def get_packet_derived_items(target_name, packet_name, scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'tlm', target_name: target_name, packet_name: packet_name, scope: scope, token: token)
      packet = TargetModel.packet(target_name, packet_name, scope: scope)
      return packet['items'].select { |item| item['data_type'] == 'DERIVED' }.map { |item| item['name'] }
    end

    def get_oldest_logfile(scope: $openc3_scope, token: $openc3_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      _, list = S3Utilities.get_total_size_and_oldest_list('logs', "#{scope}/decom_logs", 1_000_000_000)
      # The list is a S3 structure containing the file paths
      # Request the path by calling the key method. Returns something like this:
      # DEFAULT/decom_logs/tlm/INST2/MECH/20220104/20220104165449021942700__20220104170449148642700__DEFAULT__INST2__MECH__rt__decom.bin
      # Thus we split and take the start date/time part of the filename
      if list and list[0]
        start = list[0].key.split('/')[-1].split('__')[0]
        # Format as YYYY-MM-DD HH:MM:SS for use by the frontend
        # utc_time = Time.utc(start[0,4], start[4,2], start[6,2], start[8,2], start[10,2], start[12,2])
        return "#{start[0,4]}-#{start[4,2]}-#{start[6,2]} #{start[8,2]}:#{start[10,2]}:#{start[12,2]}"
      else
        return Time.now.utc.to_s[0..18]
      end
    end

    # PRIVATE

    def _validate_tlm_type(type)
      case type.intern
      when :RAW
        return ''
      when :CONVERTED
        return 'C'
      when :FORMATTED
        return 'F'
      when :WITH_UNITS
        return 'U'
      end
      return nil
    end

    def tlm_process_args(args, function_name, scope: $openc3_scope, token: $openc3_token)
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
        latest = -1
        TargetModel.packets(target_name, scope: scope).each do |packet|
          item = packet['items'].find { |item| item['name'] == item_name }
          if item
            _, msg_hash = Topic.get_oldest_message("#{scope}__DECOM__{#{target_name}}__#{packet['packet_name']}")
            if msg_hash && msg_hash['time'] && msg_hash['time'].to_i > latest
              packet_name = packet['packet_name']
              latest = msg_hash['time'].to_i
            end
          end
        end
        raise "Item '#{target_name} LATEST #{item_name}' does not exist" if latest == -1
      else
        # Determine if this item exists, it will raise appropriate errors if not
        TargetModel.packet_item(target_name, packet_name, item_name, scope: scope)
      end

      return [target_name, packet_name, item_name]
    end

    def set_tlm_process_args(args, function_name, scope: $openc3_scope, token: $openc3_token)
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
      TargetModel.packet_item(target_name, packet_name, item_name, scope: scope)

      return [target_name, packet_name, item_name, value]
    end
  end
end
