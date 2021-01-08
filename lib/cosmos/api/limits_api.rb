module Cosmos
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
      'get_stale',
      'get_out_of_limits',
      'get_overall_limits_state',
      'limits_enabled?',
      'enable_limits',
      'disable_limits',
      'get_limits',
      'set_limits',
      'get_limits_groups',
      'enable_limits_group',
      'disable_limits_group',
      'get_limits_sets',
      'set_limits_set',
      'get_limits_set',
      'subscribe_limits_events',
      'unsubscribe_limits_events',
      'get_limits_event',
    ])

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

    # Return an array of arrays indicating all items in the packet that are out of limits
    #   [[target name, packet name, item name, item limits state], ...]
    #
    # @return [Array<Array<String, String, String, String>>]
    def get_out_of_limits(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      out_of_limits = []
      limits = Store.instance.hgetall("#{scope}__current_limits")
      limits.each do |item, limits_state|
        if %w(RED RED_HIGH RED_LOW YELLOW YELLOW_HIGH YELLOW_LOW).include?(limits_state)
          target_name, packet_name, item_name = item.split('__')
          out_of_limits << [target_name, packet_name, item_name, limits_state]
        end
      end
      out_of_limits
    end

    # Get the overall limits state which is the worse case of all limits items.
    # For example if any limits are YELLOW_LOW or YELLOW_HIGH then the overall limits state is YELLOW.
    # If a single limit item then turns RED_HIGH the overall limits state is RED.
    #
    # @param ignored_items [Array<Array<String, String, String|nil>>] Array of [TGT, PKT, ITEM] strings
    #   to ignore when determining overall state. Note, ITEM can be nil to indicate to ignore entire packet.
    # @return [String] The overall limits state for the system, one of 'GREEN', 'YELLOW', 'RED'
    def get_overall_limits_state(ignored_items = nil, scope: $cosmos_scope, token: $cosmos_token)
      # We only need to check out of limits items so call get_out_of_limits() which authorizes
      out_of_limits = get_out_of_limits(scope: scope, token: token)
      overall = 'GREEN'
      limits_packet_stale = false # TODO: Calculate stale

      # Build easily matchable ignore list
      if ignored_items
        ignored_items.map! do |item|
          raise "Invalid ignored item: #{item}. Must be [TGT, PKT, ITEM] where ITEM can be nil." if item.length != 3
          item.join('__')
        end
      else
        ignored_items = []
      end

      out_of_limits.each do |target_name, packet_name, item_name, limits_state|
        # Ignore this item if we match one of the ignored items. Checking against /^#{item}/
        # allows us to detect matches against a TGT__PKT__ with no item defined.
        next if ignored_items.detect { |item| "#{target_name}__#{packet_name}__#{item_name}" =~ /^#{item}/ }
        case overall
          # If our overall state is currently blue or green we can go to any state
        when 'BLUE', 'GREEN', 'GREEN_HIGH', 'GREEN_LOW'
          overall = limits_state
        # If our overal state is yellow we can only go higher to red
        when 'YELLOW', 'YELLOW_HIGH', 'YELLOW_LOW'
          if limits_state == 'RED' || limits_state == 'RED_HIGH' || limits_state == 'RED_LOW'
            overall = limits_state
            break # Red is as high as we go so no need to look for more
          end
        end
      end
      overall = 'GREEN' if overall == 'GREEN_HIGH' || overall == 'GREEN_LOW' || overall == 'BLUE'
      overall = 'YELLOW' if overall == 'YELLOW_HIGH' || overall == 'YELLOW_LOW'
      overall = 'RED' if overall == 'RED_HIGH' || overall == 'RED_LOW'
      overall = 'STALE' if (overall == 'GREEN' || overall == 'BLUE') && limits_packet_stale
      return overall
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
      Logger.info("Setting Limits Set: #{limits_set}")
      Store.instance.hset("#{scope}__cosmos_system", 'limits_set', limits_set)
    end

    # Returns the active limits set that applies to all telemetry
    #
    # @return [String] The current limits set
    def get_limits_set(scope: $cosmos_scope, token: $cosmos_token)
      authorize(permission: 'tlm', scope: scope, token: token)
      Store.instance.hget("#{scope}__cosmos_system", 'limits_set')
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

  end
end