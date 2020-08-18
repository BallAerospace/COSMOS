start_time = Time.now
id = ARGV[0]
name = ARGV[1]
bucket = ARGV[2]
require '../config/environment'
#Rails.application.eager_load!
message_log = RunningScript.message_log(id)
bucket ||= Script::DEFAULT_BUCKET_NAME
startup_time = Time.now - start_time
path = File.join(bucket, name)

def run_script_log(id, message, color = 'BLACK')
  line_to_write = Time.now.sys.formatted + " (SCRIPTRUNNER): " + message
  RunningScript.message_log.write(line_to_write + "\n", true)
  ActionCable.server.broadcast("running-script-channel:#{id}", type: :output, line: line_to_write, color: color)
end

run_script_log(id, "Script #{path} spawned in #{startup_time} seconds")

begin
  running_script = RunningScript.new(id, name, bucket)
  running_script.start

  redis = Redis.new(url: ActionCable.server.config.cable["url"])
  redis.subscribe([ActionCable.server.config.cable["channel_prefix"], "cmd-running-script-channel:#{id}"].compact.join(":")) do |on|
    on.message do |channel, msg|
      parsed_cmd = JSON.parse(msg)
      run_script_log(id, "Script #{path} received command: #{msg}") unless parsed_cmd == "shutdown" or parsed_cmd["method"]
      case parsed_cmd
      when "go"
        running_script.go
      when "pause"
        running_script.pause
      when "stop"
        running_script.stop
        redis.unsubscribe
      when "shutdown"
        redis.unsubscribe
      else
        if parsed_cmd["method"]
          case parsed_cmd["method"]
          when "ask_string", /^prompt_.*/
            running_script.user_input = parsed_cmd["result"].to_s
            run_script_log(id, "User input: #{running_script.user_input}")
            running_script.go if running_script.user_input != 'Cancel'
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
    run_script_log(id, "Script cleanup")

    # Remove running script from redis
    redis = Redis.new(url: ActionCable.server.config.cable["url"])
    script = redis.get("running-script:#{id}")
    redis.del("running-script:#{id}") if script
    running = redis.smembers("running-scripts")
    running.each do |item|
      parsed = JSON.parse(item)
      if parsed["id"].to_s == id.to_s
        redis.srem("running-scripts", item)
        break
      end
    end

    run_script_log(id, "Script complete")
  ensure
    message_log.stop
  end
end