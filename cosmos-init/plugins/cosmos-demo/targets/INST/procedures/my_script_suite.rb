load 'cosmos/script/suite.rb'

class ExampleGroup < Cosmos::Group
  def setup
    puts "Setup"
  end

  def script_run_method_with_long_name
    puts "Running #{Cosmos::Group.current_suite}:#{Cosmos::Group.current_group}:#{Cosmos::Group.current_script}"
    Cosmos::Group.puts "This test verifies requirement 1"
    raise "error"
    puts "continue past raise"
  end

  def script_2
    puts "Running #{Cosmos::Group.current_suite}:#{Cosmos::Group.current_group}:#{Cosmos::Group.current_script}"
    Cosmos::Group.puts "This test verifies requirement 2"
    helper()
    wait(2)
  end

  def script_3
    puts "Running #{Cosmos::Group.current_suite}:#{Cosmos::Group.current_group}:#{Cosmos::Group.current_script}"
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

class MySuite < Cosmos::Suite
  def initialize
    super()
    add_group('ExampleGroup')
  end
end
