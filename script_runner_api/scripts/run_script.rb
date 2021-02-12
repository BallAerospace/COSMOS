# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
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

start_time = Time.now
require 'cosmos'
require 'cosmos/config/config_parser'
require 'cosmos/utilities/store'
require 'json'
require '../app/models/script'
require '../app/models/running_script'
#require '../config/environment'

id = ARGV[0]
script = JSON.parse(Cosmos::Store.get("running-script:#{id}"))
scope = script['scope']
name = script['name']
disconnect = script['disconnect']
startup_time = Time.now - start_time
path = File.join(Script::DEFAULT_BUCKET_NAME, scope, 'targets', name)

def run_script_log(id, message, color = 'BLACK')
  line_to_write = Time.now.sys.formatted + " (SCRIPTRUNNER): " + message
  RunningScript.message_log.write(line_to_write + "\n", true)
  #ActionCable.server.broadcast("running-script-channel:#{id}", type: :output, line: line_to_write, color: color)
  Cosmos::Store.publish(["script_runner_api", "running-script-channel:#{id}"].compact.join(":"), JSON.generate({ type: :output, line: line_to_write, color: color }))
end

run_script_log(id, "Script #{path} spawned in #{startup_time} seconds")

begin
  running_script = RunningScript.new(id, scope, name, disconnect)
  if script['suite_runner']
    script['suite_runner'] = JSON.parse(script['suite_runner']) # Convert to hash
    running_script.parse_options(script['suite_runner']['options'])
    if script['suite_runner']['script']
      running_script.run_text("Cosmos::SuiteRunner.start(#{script['suite_runner']['suite']}, #{script['suite_runner']['group']}, '#{script['suite_runner']['script']}')")
    elsif script['suite_runner']['group']
      running_script.run_text("Cosmos::SuiteRunner.#{script['suite_runner']['method']}(#{script['suite_runner']['suite']}, #{script['suite_runner']['group']})")
    else
      running_script.run_text("Cosmos::SuiteRunner.#{script['suite_runner']['method']}(#{script['suite_runner']['suite']})")
    end
  else
    running_script.run
  end

  # Subscribe to the ActionCable generated topic which is namedspaced with channel_prefix
  # (defined in cable.yml) and then the channel stream. This isn't typically how you see these
  # topics used in the Rails ActionCable documentation but this is what is happening under the
  # scenes in ActionCable. Throughout the rest of the code we use ActionCable to broadcast
  #   e.g. ActionCable.server.broadcast("running-script-channel:#{@id}", ...)
  redis = Cosmos::Store.instance.build_redis
  redis.subscribe(["script_runner_api", "cmd-running-script-channel:#{id}"].compact.join(":")) do |on|
    on.message do |channel, msg|
      parsed_cmd = JSON.parse(msg)
      run_script_log(id, "Script #{path} received command: #{msg}") unless parsed_cmd == "shutdown" or parsed_cmd["method"]
      case parsed_cmd
      when "go"
        running_script.go
      when "pause"
        running_script.pause
      when "retry"
        running_script.retry_needed
      when "step"
        running_script.step
      when "stop"
        running_script.stop
        redis.unsubscribe
      when "shutdown"
        redis.unsubscribe
      else
        if parsed_cmd["method"]
          case parsed_cmd["method"]
          when "ask_string", /^prompt_.*/
            if parsed_cmd["password"]
              running_script.user_input = parsed_cmd["password"].to_s
              running_script.continue if running_script.user_input != 'Cancel'
            else
              running_script.user_input = Cosmos::ConfigParser.handle_true_false(parsed_cmd["result"].to_s)
              run_script_log(id, "User input: #{running_script.user_input}")
              running_script.continue if running_script.user_input != 'Cancel'
            end
          when "backtrace"
            Cosmos::Store.publish(["script_runner_api", "running-script-channel:#{id}"].compact.join(":"), JSON.generate({ type: :script, method: :backtrace, args: running_script.current_backtrace }))
          when "debug"
            run_script_log(id, "DEBUG: #{parsed_cmd["args"]}") # Log what we were passed
            running_script.debug(parsed_cmd["args"]) # debug() logs the output of the command
          else
            run_script_log(id, "ERROR: Script method not handled: #{parsed_cmd["method"]}", 'RED')
          end
        else
          run_script_log(id, "ERROR: Script command not handled: #{msg}", 'RED')
        end
      end
    end
  end
rescue Exception => err
  run_script_log(id, err.formatted, 'RED')
ensure
  begin
    # Remove running script from redis
    script = Cosmos::Store.get("running-script:#{id}")
    Cosmos::Store.del("running-script:#{id}") if script
    running = Cosmos::Store.smembers("running-scripts")
    running.each do |item|
      parsed = JSON.parse(item)
      if parsed["id"].to_s == id.to_s
        Cosmos::Store.srem("running-scripts", item)
        break
      end
    end
    Cosmos::Store.publish(["script_runner_api", "running-script-channel:#{id}"].compact.join(":"), JSON.generate({ type: :complete }))
    #ActionCable.server.broadcast("running-script-channel:#{id}", type: :complete)
  ensure
    running_script.stop_message_log if running_script
  end
end
