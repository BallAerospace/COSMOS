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

  class LimitsParser
    # @param parser [ConfigParser] Configuration parser
    # @param packet [Packet] The current packet
    # @param cmd_or_tlm [String] Whether this is a command or telemetry packet
    # @param item [PacketItem] The packet item to create limits on
    # @param warnings [Array<String>] Array of string warnings which will be
    #   appended with any warnings found when parsing the limits
    def self.parse(parser, packet, cmd_or_tlm, item, warnings)
      raise parser.error("Items with STATE can't define LIMITS") if item.states
      @parser = LimitsParser.new(parser)
      @parser.verify_parameters(cmd_or_tlm)
      @parser.create_limits(packet, item, warnings)
    end

    def initialize(parser)
      @parser = parser
    end

    # @param cmd_or_tlm [String] Whether this is a command or telemetry packet
    def verify_parameters(cmd_or_tlm)
      if cmd_or_tlm == PacketConfig::COMMAND
        raise @parser.error("LIMITS only applies to telemetry items")
      end
      @usage = "LIMITS <LIMITS SET> <PERSISTENCE> <ENABLED/DISABLED> <RED LOW LIMIT> <YELLOW LOW LIMIT> <YELLOW HIGH LIMIT> <RED HIGH LIMIT> <GREEN LOW LIMIT (Optional)> <GREEN HIGH LIMIT (Optional)>"
      @parser.verify_num_parameters(7, 9, @usage)
    end

    # @param packet [Packet] The packet the item should be added to
    def create_limits(packet, item, warnings)
      limits_set = get_limits_set()
      initialize_limits_values(packet, item)
      ensure_consistency_with_default(packet, item, warnings)

      item.limits.values[limits_set] = get_values()
      item.limits.enabled = get_enabled()
      item.limits.persistence_setting = get_persistence()
      item.limits.persistence_count = 0

      packet.update_limits_items_cache(item)
      limits_set
    end

    private

    def initialize_limits_values(packet, item)
      limits_set = get_limits_set()
      # Values must be initialized with a :DEFAULT key
      if !item.limits.values
        if limits_set == :DEFAULT
          item.limits.values = {:DEFAULT => []}
        else
          raise @parser.error("DEFAULT limits set must be defined for #{packet.target_name} #{packet.packet_name} #{item.name} before setting limits set #{limits_set}")
        end
      end
    end

    def ensure_consistency_with_default(packet, item, warnings)
      # Nothing to do if we're already :DEFAULT
      return if get_limits_set() == :DEFAULT

      msg = "TELEMETRY Item #{packet.target_name} #{packet.packet_name} #{item.name} #{get_limits_set()} limits _TYPE_ setting conflict with DEFAULT"
      # XOR our setting with the items current setting
      # If it returns true then we have a mismatch and log the error
      if (get_enabled() ^ item.limits.enabled)
        warnings << msg.sub('_TYPE_', 'enable')
        Logger.instance.warn warnings[-1]
      end
      if item.limits.persistence_setting != get_persistence()
        warnings << msg.sub('_TYPE_', 'persistence')
        Logger.instance.warn warnings[-1]
      end
    end

    def get_limits_set
      @parser.parameters[0].upcase.to_sym
    end

    def get_persistence
      Integer(@parser.parameters[1])
    rescue
      raise @parser.error("Persistence must be an integer.", @usage)
    end

    def get_enabled
      enabled = @parser.parameters[2].upcase
      if enabled != 'ENABLED' and enabled != 'DISABLED'
        raise @parser.error("Initial LIMITS state must be ENABLED or DISABLED.", @usage)
      end
      enabled == 'ENABLED' ? true : false
    end

    def get_values
      values = get_red_yellow_values()
      values += get_green_values(values[1], values[2])
      values
    end

    def get_red_yellow_values
      params = @parser.parameters
      err = nil
      red_low = Float(params[3]) rescue err = "red low"
      yellow_low = Float(params[4]) rescue err = "yellow low"
      yellow_high = Float(params[5]) rescue err = "yellow high"
      red_high = Float(params[6]) rescue err = "red high"
      raise @parser.error("Invalid #{err} limit value. Limits can be integers or floats.", @usage) if err

      # Verify valid limits are specified
      if (red_low > yellow_low) or (yellow_low >= yellow_high) or (yellow_high > red_high)
        raise @parser.error("Invalid limits specified. Ensure yellow limits are within red limits.", @usage)
      end
      [red_low, yellow_low, yellow_high, red_high]
    end

    def get_green_values(yellow_low, yellow_high)
      params = @parser.parameters
      # Since our initial parameter check verifies between 7 and 9 we do a
      # special check for 8 parameters which is an error
      if params.length == 8
        raise @parser.error("Must give both a green low and green high value.", @usage)
      end
      return [] unless params.length == 9

      err = nil
      green_low = Float(params[7]) rescue err = "green low"
      green_high = Float(params[8]) rescue err = "green high"
      raise @parser.error("Invalid #{err} limit value. Limits can be integers or floats.", @usage) if err

      if (yellow_low > green_low) or (green_low >= green_high) or (green_high > yellow_high)
        raise @parser.error("Invalid limits specified. Ensure green limits are within yellow limits.", @usage)
      end
      [green_low, green_high]
    end

  end
end # module Cosmos
