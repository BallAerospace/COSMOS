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
  class CalendarTopic < Topic
    PRIMARY_KEY = '__openc3_calendar'.freeze

    # Write an activity to the topic
    #
    # ```json
    #  {
    #    "type" => "metadata",
    #    "kind" => "created",
    #    "metadata" => {
    #      "target" => "FOO",
    #      "start" => 1621875570,
    #      "color" => "#FF0000",
    #      "metadata" => {"test"=>"123456"}
    #    },
    #  }
    # ```
    def self.write_entry(entry, scope:)
      Topic.write_topic("#{scope}#{PRIMARY_KEY}", entry, '*', 1000)
    end
  end
end
