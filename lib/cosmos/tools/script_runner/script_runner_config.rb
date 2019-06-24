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
      return unless filename
      @filename = filename
      parser = ConfigParser.new("http://cosmosrb.com/docs/tools/#script-runner-configuration")
      parser.parse_file(filename) do |keyword, params|
        case keyword
        when 'LINE_DELAY'
          parser.verify_num_parameters(1, 1, "#{keyword} <Delay in Seconds>")
          ScriptRunnerFrame.line_delay = params[0].to_f
        when 'PAUSE_ON_ERROR'
          parser.verify_num_parameters(1, 1, "#{keyword} <TRUE or FALSE>")
          ScriptRunnerFrame.pause_on_error = ConfigParser.handle_true_false(params[0])
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

    def write_config
      @filename = File.join(Cosmos::USERPATH, 'config', 'tools', 'script_runner', 'script_runner.txt') unless @filename
      File.open(@filename, 'w') do |file|
        file.puts("LINE_DELAY #{ScriptRunnerFrame.line_delay}")
        file.puts("PAUSE_ON_ERROR #{ScriptRunnerFrame.pause_on_error ? 'TRUE' : 'FALSE'}")
        file.puts("MONITOR_LIMITS") if ScriptRunnerFrame.monitor_limits
        file.puts("PAUSE_ON_RED") if ScriptRunnerFrame.pause_on_red
      end
    end
  end
end
