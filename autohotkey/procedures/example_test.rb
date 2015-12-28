require 'cosmos/tools/test_runner/test'

# This Test demonstrates the usage of the setup and teardown methods
# as well as defining two tests. Notice that the setup and teardown
# methods must be called exactly that. Other test methods must start
# with 'test_' to be picked up by TestRunner.
class ExampleTest < Cosmos::Test
  def setup
    status_bar("setup")
    puts "Running ExampleTest setup"
  end

  def test_case_with_long_name_1
    status_bar("Running test_1")
    puts "Running test_1"
    Cosmos::Test.puts "This test verifies requirement 1"
    check_expression("false == true")
    puts "continue after error"
  end

  def test_2
    status_bar("Running test_2")
    puts "Running test_2"
    Cosmos::Test.puts "This test verifies requirement 2"
    if $manual
      puts "manual"
    else
      puts "not manual"
    end
  end

  def test_3xx
    raise SkipTestCase, "test_3xx unimplemented"
  end

  # Teardown the test case by doing other stuff
  def teardown
    status_bar("teardown")
    puts "Running ExampleTest teardown"
  end

  def helper_method

  end
end

class ExampleTestSuite < Cosmos::TestSuite
  # This setup applies to the entire test suite
  def setup
    puts "Running ExampleTestSuite setup"
  end

  def initialize
    super()
    add_test_setup('ExampleTest')
    add_test('ExampleTest')
    add_test_teardown('ExampleTest')
  end

  # This teardown applies to the entire test suite
  def teardown
    puts "Running ExampleTestSuite teardown"
  end
end

class NoneTestSuite < Cosmos::TestSuite
  def initialize
    super()
  end
end

