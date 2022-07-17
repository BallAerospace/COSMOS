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

require 'openc3/topics/topic'

module OpenC3
  class TimelineTopic < Topic
    PRIMARY_KEY = "__openc3_timelines"

    # Write an activity to the topic
    #
    # ```json
    #  "timeline" => "foobar",
    #  "kind" => "created",
    #  "type" => "activity",
    #  "data" => {
    #    "name" => "foobar",
    #    "start" => 1621875570,
    #    "stop" => 1621875585,
    #    "kind" => "cmd",
    #    "data" => {"cmd"=>"INST ABORT"}
    #    "events" => [{"event"=>"created"}]
    #  }
    # ```
    def self.write_activity(activity, scope:)
      Topic.write_topic("#{scope}#{PRIMARY_KEY}", activity, '*', 1000)
    end
  end
end
