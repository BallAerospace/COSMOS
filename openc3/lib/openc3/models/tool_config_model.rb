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

module OpenC3
  class ToolConfigModel
    def self.list_configs(tool, scope: $openc3_scope)
      Store.hkeys("#{scope}__config__#{tool}")
    end

    def self.load_config(tool, name, scope: $openc3_scope)
      Store.hget("#{scope}__config__#{tool}", name)
    end

    def self.save_config(tool, name, data, scope: $openc3_scope)
      Store.hset("#{scope}__config__#{tool}", name, data)
    end

    def self.delete_config(tool, name, scope: $openc3_scope)
      Store.hdel("#{scope}__config__#{tool}", name)
    end
  end
end
