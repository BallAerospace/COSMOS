load_utility 'SYSTEM/procedures/example_test.rb'

ExampleTest3.new.run { |result| puts "#{result.test}:#{result.test_case}:#{result.result}" }
