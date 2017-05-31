# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

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
      self.class_eval("def #{arg};@#{arg};end")
      self.instance_eval("def #{arg};self.instance.#{arg};end")
    end
  end

  # @param args [Array<Symbol>] Array of symbols which should be turned into
  #   instance variables with class method accessors (read and write)
  def instance_attr_accessor(*args)
    args.each do |arg|
      self.class_eval("def #{arg};@#{arg};end")
      self.instance_eval("def #{arg};self.instance.#{arg};end")
      self.class_eval("def #{arg}=(arg);@#{arg} = arg;end")
      self.instance_eval("def #{arg}=(arg);self.instance.#{arg} = arg;end")
    end
  end
end
