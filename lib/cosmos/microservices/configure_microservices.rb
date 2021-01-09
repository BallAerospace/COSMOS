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

require 'cosmos'
require 'cosmos/models/scope_model'

module Cosmos
  class ConfigureMicroservices
    def initialize(system_config, cts_config, scope:, url: nil, logger: Logger.new(Logger::INFO, true))
      ScopeModel.new(name: 'DEFAULT').create

      Store.instance.del("cosmos_microservices")

      # Save configuration to redis
      Store.instance.del("#{scope}__cosmos_system")
      Store.instance.hset("#{scope}__cosmos_system", 'limits_set', 'DEFAULT') # Current
      Store.instance.hset("#{scope}__cosmos_system", 'target_names', JSON.generate([]))
      Store.instance.hset("#{scope}__cosmos_system", 'limits_sets', JSON.generate({}))
      Store.instance.hset("#{scope}__cosmos_system", 'limits_groups', JSON.generate({}))
      return

      Store.instance.hset("#{scope}__cosmos_system", 'limits_sets', JSON.generate(System.packet_config.limits_sets))
      Store.instance.hset("#{scope}__cosmos_system", 'limits_groups', JSON.generate(System.packet_config.limits_groups))
    end
  end
end
