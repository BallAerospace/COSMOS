load 'openc3/tools/test_runner/test.rb'

class ExampleTest < OpenC3::Test
  def setup
    puts "Setup"
  end

  def test_case_with_long_name
    puts "Running #{OpenC3::Test.current_test_suite}:#{OpenC3::Test.current_test}:#{OpenC3::Test.current_test_case}"
    OpenC3::Test.puts "This test verifies requirement 1"
    raise "error"
    puts "continue past raise"
  end

  def test_2
    puts "Running #{OpenC3::Test.current_test_suite}:#{OpenC3::Test.current_test}:#{OpenC3::Test.current_test_case}"
    OpenC3::Test.puts "This test verifies requirement 2"
    helper()
    wait(2)
  end

  def test_3
    puts "Running #{OpenC3::Test.current_test_suite}:#{OpenC3::Test.current_test}:#{OpenC3::Test.current_test_case}"
    raise SkipTestCase
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

class MyTestSuite < OpenC3::TestSuite
  def initialize
    super()
    add_test('ExampleTest')
  end
end
