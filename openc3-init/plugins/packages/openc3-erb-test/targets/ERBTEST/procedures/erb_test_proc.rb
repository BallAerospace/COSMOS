require 'jmespath'

puts JMESPath.search('foo.bar', { foo: { bar: { baz: "value" }}})