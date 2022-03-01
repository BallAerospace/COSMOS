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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'cosmos/topics/topic'

module Cosmos
  class CalendarTopic < Topic
    PRIMARY_KEY = '__cosmos_calendar'.freeze

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
      Store.write_topic("#{scope}#{PRIMARY_KEY}", entry, '*', 1000)
    end
  end
end
