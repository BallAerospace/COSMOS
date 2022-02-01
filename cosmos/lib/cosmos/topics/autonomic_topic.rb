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
  class AutonomicTopic < Topic
    PRIMARY_KEY = "__cosmos_autonomic"

    # Notify to the topic
    #
    # ```json
    #  {  
    #    "kind" => "created",
    #    "type" => "trigger",
    #    "data" => {
    #      "name" => "foobar",
    #      "target": "INST",
    #      "packet": "ADCS",
    #      "left": {
    #        "type": "item",
    #        "item": "POSX",
    #      },
    #      "operation": ">",
    #      "right": {
    #        "type": "value",
    #        "value": 690000,
    #      }
    #    }
    #  }
    # ```
    def self.write_notification(notification, scope:)
      Store.write_topic("#{scope}#{PRIMARY_KEY}", notification, '*', 1000)
    end
  end
end
