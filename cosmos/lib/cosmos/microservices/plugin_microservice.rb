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

require 'cosmos/microservices/microservice'
require 'cosmos/topics/topic'
require 'cosmos/utilities/s3'

module Cosmos
  class PluginMicroservice < Microservice
    def initialize(name)
      super(name, is_plugin: true)
    end

    def run
      Dir.chdir @work_dir
      # Fortify: Process Control
      # This is dangerous! However, plugins need to be able to run whatever they want.
      # Only admins can install plugins and they need to be vetted for content.
      # NOTE: In COSMOS EE each microservice gets its own container so the potential
      # footprint is much smaller. In OpenSource COSMOS you're in the same container
      # as all the other plugins.
      exec(*@config["cmd"])
    end
  end
end

Cosmos::PluginMicroservice.run if __FILE__ == $0
