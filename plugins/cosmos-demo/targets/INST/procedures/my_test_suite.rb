load 'cosmos/tools/test_runner/test.rb'

class ExampleTest < Cosmos::Test
  def setup
    puts "Setup"
  end

  def test_case_with_long_name
    puts "Running #{Cosmos::Test.current_test_suite}:#{Cosmos::Test.current_test}:#{Cosmos::Test.current_test_case}"
    Cosmos::Test.puts "This test verifies requirement 1"
    raise "error"
    puts "continue past raise"
  end

  def test_2
    puts "Running #{Cosmos::Test.current_test_suite}:#{Cosmos::Test.current_test}:#{Cosmos::Test.current_test_case}"
    Cosmos::Test.puts "This test verifies requirement 2"
    helper()
    wait(2)
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

class MyTestSuite < Cosmos::TestSuite
  def initialize
    super()
    add_test('ExampleTest')
  end
end
