load 'openc3/script/suite.rb'
require 'INST/procedures/utilities/collect' # Test requiring files from s3 in suite analysis

class ExampleGroup < OpenC3::Group
  def setup
    puts "Setup"
  end

  def script_run_method_with_long_name
    puts "Running #{OpenC3::Group.current_suite}:#{OpenC3::Group.current_group}:#{OpenC3::Group.current_script}"
    OpenC3::Group.puts "This test verifies requirement 1"
    raise "error"
    puts "continue past raise"
  end

  def script_2
    puts "Running #{OpenC3::Group.current_suite}:#{OpenC3::Group.current_group}:#{OpenC3::Group.current_script}"
    OpenC3::Group.puts "This test verifies requirement 2"
    helper()
    wait(2)
  end

  def script_3
    puts "Running #{OpenC3::Group.current_suite}:#{OpenC3::Group.current_group}:#{OpenC3::Group.current_script}"
    raise SkipScript
  end

  def helper
    if $manual
      answer = ask "Are you sure?"
    else
      answer = 'y'
    end
  end

  def teardown
    puts "teardown"
  end
end

class MySuite < OpenC3::Suite
  def initialize
    super()
    add_group('ExampleGroup')
  end
end
