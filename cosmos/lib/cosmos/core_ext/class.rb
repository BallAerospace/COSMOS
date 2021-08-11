# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

# COSMOS specific additions to the Ruby Class class
class Class
  # Creates instance variables in the class which have corresponding class
  # method accessors. NOTE: You must define self.instance for this to work.
  #
  # For example:
  #   class MyClass
  #     instance_attr_reader :test
  #     @@instance = nil
  #     def self.instance
  #       @@instance ||= self.new
  #       return @@instance
  #     end
  #     def initialize
  #       @test = "Test"
  #       @@instance = self
  #     end
  #
  # Will allow the following:
  #   my = MyClass.new
  #   my.test # returns "Test"
  #   MyClass.test # returns "Test"
  #
  # @param args [Array<Symbol>] Array of symbols which should be turned into
  #   instance variables with class method readers
  def instance_attr_reader(*args)
    args.each do |arg|
      # Non-word characters (letter, number, underscore) are disallowed
      raise ArgumentError, "Non-word characters characters parsed" if arg =~ /\W/

      # Fortify: Dynamic Code Evaluation: Code Injection
      # This is true but we're whitelisting the input above
      self.class_eval("def #{arg};@#{arg};end")
      self.instance_eval("def #{arg};self.instance.#{arg};end")
    end
  end

  # @param args [Array<Symbol>] Array of symbols which should be turned into
  #   instance variables with class method accessors (read and write)
  def instance_attr_accessor(*args)
    args.each do |arg|
      # Non-word characters (letter, number, underscore) are disallowed
      raise ArgumentError, "Non-word characters characters parsed" if arg =~ /\W/

      # Fortify: Dynamic Code Evaluation: Code Injection
      # This is true but we're whitelisting the input above
      self.class_eval("def #{arg};@#{arg};end")
      self.instance_eval("def #{arg};self.instance.#{arg};end")
      self.class_eval("def #{arg}=(arg);@#{arg} = arg;end")
      self.instance_eval("def #{arg}=(arg);self.instance.#{arg} = arg;end")
    end
  end
end
