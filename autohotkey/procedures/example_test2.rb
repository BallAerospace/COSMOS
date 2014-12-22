require 'cosmos/tools/test_runner/test'

# This Test demonstrates the usage of the setup and teardown methods
# as well as defining two tests. Notice that the setup and teardown
# methods must be called exactly that. Other test methods must start
# with 'test_' to be picked up by TestRunner.
class ExampleTest < Cosmos::Test
  def setup
    puts "Running ExampleTest setup"
  end

  def test_case_with_long_name_1
    puts "Running test_1"
  end

  # Teardown the test case by doing other stuff
  def teardown
    puts "Running ExampleTest teardown"
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

class XTest < Cosmos::Test
  def test_x1
    puts "Running XTest::test_x1"
  end
  def test_x2
    puts "Running XTest::test_x2"
  end
end

class YTest < Cosmos::Test
  def test_y1
    puts "Running YTest::test_y1"
  end
  def test_y2
    puts "Running YTest::test_y2"
  end
end

class ZTest < Cosmos::Test
  def test_z1
    puts "Running YTest::test_z1"
  end
  def test_z2
    puts "Running YTest::test_z2"
  end
end

class XYZTestSuite < Cosmos::TestSuite
  def initialize
    super()
    add_test_case('XTest', 'test_x1')
  end
end

