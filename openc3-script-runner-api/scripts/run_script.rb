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

start_time = Time.now
require 'openc3'
require 'openc3/config/config_parser'
require 'openc3/utilities/store'
require 'json'
require '../app/models/script'
require '../app/models/running_script'

# Important - Preload Aws::S3 before changing $stdout
Aws::S3
ENV['OPENC3_MINIO_USERNAME'] = nil
ENV['OPENC3_MINIO_PASSWORD'] = nil

# Preload Store and remove Redis secrets from ENV
OpenC3::Store.instance
OpenC3::EphemeralStore.instance
ENV['OPENC3_REDIS_USERNAME'] = nil
ENV['OPENC3_REDIS_PASSWORD'] = nil

# Clear other secrets
ENV['OPENC3_PASSWORD'] = nil

id = ARGV[0]
script = JSON.parse(OpenC3::Store.get("running-script:#{id}"), :allow_nan => true, :create_additions => true)
scope = script['scope']
name = script['name']
disconnect = script['disconnect']
startup_time = Time.now - start_time
path = File.join(Script::DEFAULT_BUCKET_NAME, scope, 'targets', name)

def run_script_log(id, message, color = 'BLACK', message_log = true)
  line_to_write = Time.now.sys.formatted + " (SCRIPTRUNNER): " + message
  RunningScript.message_log.write(line_to_write + "\n", true) if message_log
  OpenC3::Store.publish(["script-api", "running-script-channel:#{id}"].compact.join(":"), JSON.generate({ type: :output, line: line_to_write, color: color }))
end

begin
  running_script = RunningScript.new(id, scope, name, disconnect)
  run_script_log(id, "Script #{path} spawned in #{startup_time} seconds <ruby #{RUBY_VERSION}>", 'BLACK')

  if script['environment']
    script['environment'].each do |env|
      begin
        ENV[env['key']] = env['value']
        run_script_log(id, "Loaded environment: #{env}", 'BLACK')
      rescue StandardError
        run_script_log(id, "Failed to load environment: #{env}", 'RED')
      end
    end
  end

  if script['suite_runner']
    script['suite_runner'] = JSON.parse(script['suite_runner'], :allow_nan => true, :create_additions => true) # Convert to hash
    running_script.parse_options(script['suite_runner']['options'])
    if script['suite_runner']['script']
      running_script.run_text("OpenC3::SuiteRunner.start(#{script['suite_runner']['suite']}, #{script['suite_runner']['group']}, '#{script['suite_runner']['script']}')")
    elsif script['suite_runner']['group']
      running_script.run_text("OpenC3::SuiteRunner.#{script['suite_runner']['method']}(#{script['suite_runner']['suite']}, #{script['suite_runner']['group']})")
    else
      running_script.run_text("OpenC3::SuiteRunner.#{script['suite_runner']['method']}(#{script['suite_runner']['suite']})")
    end
  else
    running_script.run
  end

  # Subscribe to the ActionCable generated topic which is namedspaced with channel_prefix
  # (defined in cable.yml) and then the channel stream. This isn't typically how you see these
  # topics used in the Rails ActionCable documentation but this is what is happening under the
  # scenes in ActionCable. Throughout the rest of the code we use ActionCable to broadcast
  #   e.g. ActionCable.server.broadcast("running-script-channel:#{@id}", ...)
  redis = OpenC3::Store.instance.build_redis
  redis.subscribe(["script-api", "cmd-running-script-channel:#{id}"].compact.join(":")) do |on|
    on.message do |channel, msg|
      parsed_cmd = JSON.parse(msg, :allow_nan => true, :create_additions => true)
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
          # This list matches the list in running_script.rb:40
          when "ask", "ask_string", "message_box", "vertical_message_box", "combo_box", "prompt", "prompt_for_hazardous",
            "input_metadata", "open_file_dialog", "open_files_dialog"
            unless running_script.prompt_id.nil?
              if running_script.prompt_id == parsed_cmd["prompt_id"]
                if parsed_cmd["password"]
                  running_script.user_input = parsed_cmd["password"].to_s
                elsif parsed_cmd["method"].include?('open_file')
                  running_script.user_input = parsed_cmd["answer"]
                  run_script_log(id, "File(s): #{running_script.user_input}")
                else
                  running_script.user_input = OpenC3::ConfigParser.handle_true_false(parsed_cmd["answer"].to_s)
                  running_script.user_input = running_script.user_input.convert_to_value if parsed_cmd["method"] == 'ask'
                  run_script_log(id, "User input: #{running_script.user_input}")
                end
                running_script.continue
              else
                run_script_log(id, "INFO: Received answer for prompt #{parsed_cmd["prompt_id"]} when looking for #{running_script.prompt_id}.")
              end
            else
              run_script_log(id, "INFO: Unexpectedly received answer for unknown prompt #{parsed_cmd["prompt_id"]}.")
            end
          when "backtrace"
            OpenC3::Store.publish(["script-api", "running-script-channel:#{id}"].compact.join(":"), JSON.generate({ type: :script, method: :backtrace, args: running_script.current_backtrace }))
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
    script = OpenC3::Store.get("running-script:#{id}")
    OpenC3::Store.del("running-script:#{id}") if script
    running = OpenC3::Store.smembers("running-scripts")
    running.each do |item|
      parsed = JSON.parse(item, :allow_nan => true, :create_additions => true)
      if parsed["id"].to_s == id.to_s
        OpenC3::Store.srem("running-scripts", item)
        break
      end
    end
    sleep 0.2 # Allow the message queue to be emptied before signaling complete
    OpenC3::Store.publish(["script-api", "running-script-channel:#{id}"].compact.join(":"), JSON.generate({ type: :complete }))
  ensure
    running_script.stop_message_log if running_script
  end
end
