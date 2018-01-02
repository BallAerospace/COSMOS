require File.expand_path('../../config/environment', __FILE__)
require 'cosmos'
require 'stringio'

# Creates a MessageLog in the DART_LOGS System path for DART logging
class DartLogging
  def initialize(message_log_name)
    @output_sleeper = Cosmos::Sleeper.new
    @string_output = StringIO.new("", "r+")
    $stdout = @string_output
    @message_log = Cosmos::MessageLog.new(message_log_name, Cosmos::System.paths['DART_LOGS'])

    @output_thread = Thread.new do
      while true
        handle_string_output()
        break if @output_sleeper.sleep(1)
      end
    end
  end

  def handle_string_output
    if @string_output.string[-1..-1] == "\n"
      string = @string_output.string.clone
      @string_output.string = @string_output.string[string.length..-1]
      @message_log.write(string, true)
      STDOUT.print string if STDIN.isatty # Have a console
    end
  end

  def graceful_kill
    # Do Nothing
  end

  def stop
    handle_string_output()
    @output_sleeper.cancel
    Cosmos.kill_thread(self, @output_thread)
    handle_string_output()
    @message_log.stop
  end
end
