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

require 'openc3/microservices/microservice'
require 'openc3/topics/topic'
require 'openc3/utilities/s3'

module OpenC3
  class PluginMicroservice < Microservice
    def initialize(name)
      super(name, is_plugin: true)
    end

    def run
      Dir.chdir @work_dir
      # Fortify: Process Control
      # This is dangerous! However, plugins need to be able to run whatever they want.
      # Only admins can install plugins and they need to be vetted for content.
      # NOTE: In OpenC3 EE each microservice gets its own container so the potential
      # footprint is much smaller. In OpenSource OpenC3 you're in the same container
      # as all the other plugins.
      exec(*@config["cmd"])
    end
  end
end

OpenC3::PluginMicroservice.run if __FILE__ == $0
