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

require 'openc3/models/model'

module OpenC3
  class MetricModel < EphemeralModel
    PRIMARY_KEY = '__openc3__metric'.freeze

    # NOTE: The following three class methods are used by the ModelController
    # and are reimplemented to enable various Model class methods to work
    def self.get(name:, scope:)
      super("#{scope}#{PRIMARY_KEY}", name: name)
    end

    def self.names(scope:)
      super("#{scope}#{PRIMARY_KEY}")
    end

    def self.all(scope:)
      super("#{scope}#{PRIMARY_KEY}")
    end

    def self.destroy(scope:, name:)
      EphemeralStore.hdel("#{scope}#{PRIMARY_KEY}", name)
    end

    def initialize(name:, scope:, metric_name:, label_list:)
      super("#{scope}#{PRIMARY_KEY}", name: name, scope: scope)
      @metric_name = metric_name
      @label_list = label_list
    end

    def as_json(*a)
      {
        'name' => @name,
        'updated_at' => @updated_at,
        'metric_name' => @metric_name,
        'label_list' => @label_list
      }
    end
  end
end
