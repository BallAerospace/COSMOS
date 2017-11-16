# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'

module Cosmos
  # This class reads the Script Runner configuration file
  class ScriptRunnerConfig
    # Processes the config file
    def initialize(filename)
      parser = ConfigParser.new("http://cosmosrb.com/docs/tools/#script-runner-configuration")
      parser.parse_file(filename) do |keyword, params|
        case keyword
        when 'LINE_DELAY'
          parser.verify_num_parameters(1, 1, "#{keyword} <Delay in Seconds>")
          ScriptRunnerFrame.line_delay = params[0].to_f
        when 'MONITOR_LIMITS'
          parser.verify_num_parameters(0, 0, keyword)
          ScriptRunnerFrame.monitor_limits = true
        when 'PAUSE_ON_RED'
          parser.verify_num_parameters(0, 0, keyword)
          ScriptRunnerFrame.monitor_limits = true
          ScriptRunnerFrame.pause_on_red = true
        else
          # blank config.lines will have a nil keyword and should not raise an exception
          raise parser.error("Unknown keyword '#{keyword}'") if keyword
        end
      end
    end
  end
end
